//! Window (minifb), sound (cpal) and gamepads (gilrs).
//!
//! The emulation is paced by the sound output: it runs until the sound queue
//! holds about 60 ms of samples, so it follows the 48 kHz of the hardware
//! exactly as the audio device plays it. Without a sound device it is paced
//! by the wall clock.

use crate::{make_system, write_ppm, Options};
use cpal::traits::{DeviceTrait, HostTrait, StreamTrait};
use cpal::{FromSample, SizedSample};
use minifb::{Key, KeyRepeat, Scale, ScaleMode, Window, WindowOptions};
use std::collections::VecDeque;
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tetric::system::{Pad, CLOCK_HZ};
use tetric::video::{LINES, WIDTH};

type Queue = Arc<Mutex<VecDeque<(i16, i16)>>>;

/// samples (48 kHz) to keep queued for the sound device
const TARGET_QUEUE: usize = 2880; // 60 ms

struct Audio {
    _stream: cpal::Stream,
    queue: Queue,
}

fn start_audio() -> Option<Audio> {
    let host = cpal::default_host();
    let device = host.default_output_device()?;
    let supported = device.default_output_config().ok()?;
    let format = supported.sample_format();
    let mut config: cpal::StreamConfig = supported.into();
    // 48 kHz if the device can do it (no resampling then)
    if let Ok(mut cfgs) = device.supported_output_configs() {
        if cfgs.any(|c| {
            c.channels() == config.channels
                && c.min_sample_rate().0 <= 48_000
                && c.max_sample_rate().0 >= 48_000
                && c.sample_format() == format
        }) {
            config.sample_rate = cpal::SampleRate(48_000);
        }
    }
    let queue: Queue = Arc::new(Mutex::new(VecDeque::new()));
    let stream = match format {
        cpal::SampleFormat::F32 => build::<f32>(&device, &config, queue.clone()),
        cpal::SampleFormat::I16 => build::<i16>(&device, &config, queue.clone()),
        cpal::SampleFormat::U16 => build::<u16>(&device, &config, queue.clone()),
        cpal::SampleFormat::I32 => build::<i32>(&device, &config, queue.clone()),
        _ => None,
    }?;
    stream.play().ok()?;
    eprintln!(
        "sound: {} Hz, {} channels ({:?})",
        config.sample_rate.0, config.channels, format
    );
    Some(Audio {
        _stream: stream,
        queue,
    })
}

fn build<T: SizedSample + FromSample<f32>>(
    device: &cpal::Device,
    config: &cpal::StreamConfig,
    queue: Queue,
) -> Option<cpal::Stream> {
    let channels = config.channels as usize;
    let step = 48_000.0 / config.sample_rate.0 as f64;
    let mut pos = 0.0f64; // position between prev and next
    let mut prev = (0.0f32, 0.0f32);
    let mut next = (0.0f32, 0.0f32);
    let cb = move |data: &mut [T], _: &cpal::OutputCallbackInfo| {
        let mut q = queue.lock().unwrap();
        for frame in data.chunks_mut(channels) {
            pos += step;
            while pos >= 1.0 {
                pos -= 1.0;
                prev = next;
                if let Some((l, r)) = q.pop_front() {
                    next = (l as f32 / 32768.0, r as f32 / 32768.0);
                }
                // an empty queue repeats the last sample (no click)
            }
            let t = pos as f32;
            let l = prev.0 + (next.0 - prev.0) * t;
            let r = prev.1 + (next.1 - prev.1) * t;
            for (i, s) in frame.iter_mut().enumerate() {
                let v = match i {
                    0 => l,
                    1 => r,
                    _ => 0.0,
                };
                *s = T::from_sample(if channels == 1 { 0.5 * (l + r) } else { v });
            }
        }
    };
    device
        .build_output_stream(config, cb, |e| eprintln!("sound error: {e}"), None)
        .ok()
}

/// Keyboard state -> pad
fn keyboard(window: &Window, pad: &mut Pad) {
    let k = |key| window.is_key_down(key);
    pad.up |= k(Key::Up);
    pad.down |= k(Key::Down);
    pad.left |= k(Key::Left);
    pad.right |= k(Key::Right);
    pad.start |= k(Key::Enter) || k(Key::NumPadEnter);
    pad.select |= k(Key::Backspace);
    pad.square |= k(Key::Z) || k(Key::A);
    pad.cross |= k(Key::X) || k(Key::Space);
    pad.circle |= k(Key::C);
    pad.triangle |= k(Key::S) || k(Key::V);
}

fn gamepads(gilrs: &mut gilrs::Gilrs, pad: &mut Pad) {
    use gilrs::{Axis, Button};
    while gilrs.next_event().is_some() {}
    for (_, gp) in gilrs.gamepads() {
        let b = |btn| gp.is_pressed(btn);
        let ax = |a| gp.value(a);
        pad.up |= b(Button::DPadUp) || ax(Axis::LeftStickY) > 0.5 || ax(Axis::DPadY) > 0.5;
        pad.down |= b(Button::DPadDown) || ax(Axis::LeftStickY) < -0.5 || ax(Axis::DPadY) < -0.5;
        pad.left |= b(Button::DPadLeft) || ax(Axis::LeftStickX) < -0.5 || ax(Axis::DPadX) < -0.5;
        pad.right |= b(Button::DPadRight) || ax(Axis::LeftStickX) > 0.5 || ax(Axis::DPadX) > 0.5;
        pad.start |= b(Button::Start);
        pad.select |= b(Button::Select);
        pad.cross |= b(Button::South);
        pad.circle |= b(Button::East);
        pad.square |= b(Button::West);
        pad.triangle |= b(Button::North);
        pad.l1 |= b(Button::LeftTrigger);
        pad.r1 |= b(Button::RightTrigger);
        pad.l2 |= b(Button::LeftTrigger2);
        pad.r2 |= b(Button::RightTrigger2);
    }
}

/// State shared between the window thread and the emulation thread.
#[derive(Default)]
struct Shared {
    pad: Pad,
    paused: bool,
    fast: bool,
    reset: bool,
    quit: bool,
    /// the newest finished frame and its number
    frame: Vec<u32>,
    frame_no: u64,
    // statistics
    clk: u64,
    video_frames: u32,
    late_frames: u64,
}

/// The emulation thread: paced by the wall clock, a little faster or slower
/// (up to 2 %) to keep the sound queue at its target, so the frames come
/// evenly and the sound follows the device's clock.
fn emulate(o: &Options, shared: Arc<Mutex<Shared>>, audio: Option<Queue>) {
    let mut sys = make_system(o);
    let start_clk = sys.clk();
    let mut last = Instant::now();
    let mut debt = 0.0f64; // clocks to run
    let mut uart_seen = 0;
    loop {
        let (pad, paused, fast, reset, quit) = {
            let mut sh = shared.lock().unwrap();
            let r = (sh.pad, sh.paused, sh.fast, sh.reset, sh.quit);
            sh.reset = false;
            r
        };
        if quit {
            return;
        }
        if reset {
            sys = make_system(o);
            uart_seen = 0;
        }
        let mut pad = pad;
        let ms = (sys.clk() - start_clk) as f64 * 1000.0 / CLOCK_HZ as f64;
        for (b, t0, t1) in &o.presses {
            if ms >= *t0 && ms < *t1 {
                crate::set_button(&mut pad, b, true);
            }
        }
        sys.board.pad = pad;

        let now = Instant::now();
        let dt = now.duration_since(last).as_secs_f64().min(0.1);
        last = now;
        if !paused {
            let queued = audio.as_ref().map(|q| q.lock().unwrap().len());
            let rate = match queued {
                Some(n) => {
                    let err = (TARGET_QUEUE as f64 - n as f64) / TARGET_QUEUE as f64;
                    1.0 + (0.02 * err).clamp(-0.02, 0.02)
                }
                None => 1.0,
            };
            debt += dt * CLOCK_HZ as f64 * rate;
            if fast {
                debt = debt.max(tetric::video::FRAME_CLOCKS as f64); // as fast as it goes
            }
            if matches!(queued, Some(n) if n < TARGET_QUEUE / 4) {
                // sound device starved (start up, slow machine): catch up
                debt = debt.max((TARGET_QUEUE / 2 * 525) as f64);
            }
            // up to the end of the next frame at most
            let target = sys.clk() + debt.max(0.0) as u64;
            let before = sys.clk();
            sys.run_until_frame(target);
            debt -= (sys.clk() - before) as f64;
            debt = debt.clamp(-(CLOCK_HZ as f64) / 10.0, CLOCK_HZ as f64 / 10.0);
        } else {
            debt = 0.0;
        }
        // sound to the device
        if let Some(q) = &audio {
            let mut q = q.lock().unwrap();
            if paused || fast {
                sys.board.audio.clear();
            }
            q.extend(sys.board.audio.drain(..));
            while q.len() > 4 * TARGET_QUEUE {
                q.pop_front(); // never more than ~0.2 s behind
            }
        } else {
            sys.board.audio.clear();
        }
        let late = sys.board.uart_out[uart_seen..]
            .iter()
            .filter(|&&c| c == b'L')
            .count();
        uart_seen = sys.board.uart_out.len();
        {
            let mut sh = shared.lock().unwrap();
            if sys.board.video.frame_ready {
                sys.board.video.frame_ready = false;
                sh.frame.copy_from_slice(&sys.board.video.frame);
                sh.frame_no += 1;
            }
            sh.clk = sys.clk();
            sh.video_frames = sys.board.video.frame_counter;
            sh.late_frames += late as u64;
        }
        if paused || debt < (tetric::video::FRAME_CLOCKS / 8) as f64 {
            std::thread::sleep(Duration::from_millis(1));
        }
    }
}

pub fn run(o: &Options) {
    // The window is exactly the visible DVI area (640 x 480) times the
    // scale, not resizable (no letterbox borders); the picture is scaled here.
    let sc = o.scale.clamp(1, 4);
    let (sw, sh) = (WIDTH * sc, 2 * LINES * sc);
    let mut window = Window::new(
        "TetrIC",
        sw,
        sh,
        WindowOptions {
            resize: false,
            scale: Scale::X1,
            scale_mode: ScaleMode::Stretch,
            ..WindowOptions::default()
        },
    )
    .unwrap_or_else(|e| {
        eprintln!("cannot open a window: {e}");
        std::process::exit(1)
    });
    window.set_target_fps(0);

    let audio = if o.mute { None } else { start_audio() };
    if audio.is_none() && !o.mute {
        eprintln!("no sound device, running without sound");
    }
    let mut gilrs = match gilrs::Gilrs::new() {
        Ok(g) => {
            for (_, gp) in g.gamepads() {
                eprintln!("gamepad: {}", gp.name());
            }
            Some(g)
        }
        Err(e) => {
            eprintln!("no gamepad support: {e}");
            None
        }
    };

    let shared = Arc::new(Mutex::new(Shared {
        frame: vec![0; WIDTH * LINES],
        ..Shared::default()
    }));
    let emu = {
        let shared = shared.clone();
        let queue = audio.as_ref().map(|a| a.queue.clone());
        let o = o.clone();
        std::thread::spawn(move || emulate(&o, shared, queue))
    };

    let mut screen = vec![0u32; sw * sh];
    let mut frame = vec![0u32; WIDTH * LINES];
    let mut shown_no = 0u64;
    let mut shot = 0;
    let t_start = Instant::now();
    let mut title_t = Instant::now();
    let mut frames_shown = 0u32;
    let (mut clk_t, mut vf_t, mut late_t) = (0u64, 0u32, 0u64);
    let (mut upd_time, mut upd_n) = (0.0f64, 0u32);
    let (mut tot_shown, mut tot_secs) = (0u64, 0u64);
    let (mut min_fps, mut max_fps) = (f64::MAX, 0.0f64);
    let mut paused = false;

    while window.is_open() && !window.is_key_down(Key::Escape) {
        if o.seconds_set && t_start.elapsed().as_secs_f64() >= o.seconds {
            break;
        }
        // ---- input ----
        let mut pad = Pad::default();
        keyboard(&window, &mut pad);
        if let Some(g) = &mut gilrs {
            gamepads(g, &mut pad);
        }
        if window.is_key_pressed(Key::P, KeyRepeat::No) {
            paused = !paused;
        }
        let reset = window.is_key_pressed(Key::F2, KeyRepeat::No);
        let fast = window.is_key_down(Key::Tab);
        let new_frame = {
            let mut s = shared.lock().unwrap();
            s.pad = pad;
            s.paused = paused;
            s.fast = fast;
            s.reset |= reset;
            if s.frame_no != shown_no {
                shown_no = s.frame_no;
                frame.copy_from_slice(&s.frame);
                true
            } else {
                false
            }
        };
        if window.is_key_pressed(Key::F12, KeyRepeat::No) {
            let name = format!("tetric_{shot}.ppm");
            shot += 1;
            match write_ppm(&name, &frame) {
                Ok(()) => eprintln!("screenshot: {name}"),
                Err(e) => eprintln!("{name}: {e}"),
            }
        }

        // ---- display ----
        if new_frame {
            scale_frame(&frame, sc, &mut screen);
            frames_shown += 1;
            let tu = Instant::now();
            window.update_with_buffer(&screen, sw, sh).ok();
            upd_time += tu.elapsed().as_secs_f64();
            upd_n += 1;
        } else {
            window.update();
            std::thread::sleep(Duration::from_millis(1));
        }

        // ---- statistics ----
        if title_t.elapsed() >= Duration::from_secs(1) {
            let t = title_t.elapsed().as_secs_f64();
            let (clk, vf, late) = {
                let s = shared.lock().unwrap();
                (s.clk, s.video_frames, s.late_frames)
            };
            let emu_s = clk.saturating_sub(clk_t) as f64 / CLOCK_HZ as f64;
            let shown = frames_shown as f64 / t;
            if o.fps && tot_secs > 0 {
                eprintln!(
                    "fps: {:.1} shown, {:.1} emulated video frames/s, speed {:.1} %, {} late game frames, window update {:.1} ms",
                    shown,
                    vf.wrapping_sub(vf_t) as f64 / t,
                    100.0 * emu_s / t,
                    late - late_t,
                    1000.0 * upd_time / upd_n.max(1) as f64
                );
            }
            if tot_secs > 0 {
                // (the first second includes the start up)
                min_fps = min_fps.min(shown);
                max_fps = max_fps.max(shown);
                tot_shown += frames_shown as u64;
            }
            tot_secs += 1;
            window.set_title(&format!(
                "TetrIC - {:.0} fps, {:.0} % speed{}",
                shown,
                100.0 * emu_s / t,
                if paused { " (paused)" } else { "" }
            ));
            (clk_t, vf_t, late_t) = (clk, vf, late);
            (upd_time, upd_n) = (0.0, 0);
            title_t = Instant::now();
            frames_shown = 0;
        }
    }
    shared.lock().unwrap().quit = true;
    let _ = emu.join();
    drop(window);
    if o.fps && tot_secs > 1 {
        eprintln!(
            "fps summary: {:.2} average, {:.1} min, {:.1} max frames shown per second over {} s",
            tot_shown as f64 / (tot_secs - 1) as f64,
            min_fps,
            max_fps,
            tot_secs - 1
        );
    }
    // exit here: dropping the sound stream can block (ALSA)
    std::process::exit(0);
}

/// 640x240 picture -> (640 sc) x (480 sc), every screen line 2 sc times
fn scale_frame(frame: &[u32], sc: usize, out: &mut [u32]) {
    let w = WIDTH * sc;
    for y in 0..LINES {
        let row = &frame[y * WIDTH..(y + 1) * WIDTH];
        let first = 2 * sc * y * w;
        let dst = &mut out[first..first + w];
        for (x, p) in row.iter().enumerate() {
            dst[x * sc..(x + 1) * sc].fill(*p);
        }
        for k in 1..2 * sc {
            out.copy_within(first..first + w, first + k * w);
        }
    }
}
