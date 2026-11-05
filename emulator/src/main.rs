//! tetric_emu: TetrIC emulator with a window, sound and keyboard / gamepad.
//!
//!   tetric_emu --flash game_code/out/TetrIC.bin
//!
//! See emulator/README.md, or `tetric_emu --help`.

mod frontend;

use std::collections::VecDeque;
use std::fs::File;
use std::io::{BufRead, BufReader, BufWriter, Write};
use std::process::exit;
use tetric::system::{program_from_flash, System, CLOCK_HZ};
use tetric::video::{LINES, WIDTH};

const HELP: &str = "\
tetric_emu - emulator for the TetrIC ASIC (Tang Nano 20K version)

usage: tetric_emu --flash <binary file> [options]

  --flash <file>        program image (game_code/out/TetrIC.bin), or a full
                        flash image with the program at 0x500000
  --scale <n>           window size: n x 640x480 (default 1)
  --mute                no sound
  --fps                 print frame rate / speed statistics every second
  --seconds <s>         quit after s seconds (wall clock)

Keys: arrows = joystick, Enter = START, Z = A (square), X = B (cross),
      C = C (circle), Backspace = SELECT, P = pause, Tab (held) = fast
      forward, F2 = reset, F12 = screenshot (tetric_<n>.ppm), Esc = quit.
A USB gamepad works as well (d-pad / left stick, START, the face buttons).

Test options (no window with --headless):
  --headless            run without window and sound
  --seconds <s>         emulated time (default 5)
  --press <b>:<t0>:<t1> hold button b (start, cross, square, circle, up, down,
                        left, right) from t0 to t1 ms (emulated time)
  --trace <file>        CPU trace: register writes, stores, MFC values
                        (as +cputrace in sim/system/tb_system.v)
  --mfc-replay <file>   MFC values from an RTL +cputrace (lockstep check)
  --fix-beam            MFC1 reads the beam position as 0 (+fix_beam)
  --ideal-timing        instructions take no time, one game frame per video
                        frame: for comparing two builds of a program (with
                        --swaplog), whatever their speed
  --swaplog <file>      image hash per screen swap (+swaplog)
  --wav <file>          write the sound output
  --screenshot <file>   write the last frame (PPM) at the end
  --dump-mem <file>     write the SDRAM (4 MByte, big endian words) at the end
  --start-line <n>      DVI line at which the CPU starts (default 98)
  --stats               print instruction / stall statistics
";

#[derive(Clone)]
pub struct Options {
    pub flash: String,
    pub scale: usize,
    pub mute: bool,
    pub headless: bool,
    pub seconds: f64,
    pub presses: Vec<(String, f64, f64)>,
    pub trace: Option<String>,
    pub mfc_replay: Option<String>,
    pub fix_beam: bool,
    pub ideal: bool,
    pub swaplog: Option<String>,
    pub wav: Option<String>,
    pub screenshot: Option<String>,
    pub dump_mem: Option<String>,
    pub start_line: u64,
    pub stats: bool,
    pub fps: bool,
    pub seconds_set: bool,
}

fn parse_args() -> Options {
    let mut o = Options {
        flash: String::new(),
        scale: 1,
        mute: false,
        headless: false,
        seconds: 5.0,
        presses: Vec::new(),
        trace: None,
        mfc_replay: None,
        fix_beam: false,
        ideal: false,
        swaplog: None,
        wav: None,
        screenshot: None,
        dump_mem: None,
        start_line: 98,
        stats: false,
        fps: false,
        seconds_set: false,
    };
    let args: Vec<String> = std::env::args().skip(1).collect();
    let mut i = 0;
    let need = |i: usize| -> String {
        args.get(i + 1).cloned().unwrap_or_else(|| {
            eprintln!("missing value for {}", args[i]);
            exit(2)
        })
    };
    let num = |s: String| -> f64 {
        s.parse().unwrap_or_else(|_| {
            eprintln!("not a number: {s}");
            exit(2)
        })
    };
    while i < args.len() {
        let a = args[i].as_str();
        match a {
            "-h" | "--help" => {
                print!("{HELP}");
                exit(0)
            }
            "--flash" => o.flash = need(i),
            "--scale" => o.scale = num(need(i)).max(1.0) as usize,
            "--mute" => {
                o.mute = true;
                i += 1;
                continue;
            }
            "--headless" => {
                o.headless = true;
                i += 1;
                continue;
            }
            "--fix-beam" => {
                o.fix_beam = true;
                i += 1;
                continue;
            }
            "--ideal-timing" => {
                o.ideal = true;
                i += 1;
                continue;
            }
            "--fps" => {
                o.fps = true;
                i += 1;
                continue;
            }
            "--stats" => {
                o.stats = true;
                i += 1;
                continue;
            }
            "--seconds" => {
                o.seconds = num(need(i));
                o.seconds_set = true;
            }
            "--press" => {
                let v = need(i);
                let f: Vec<&str> = v.split(':').collect();
                if f.len() != 3 {
                    eprintln!("--press <button>:<t0 ms>:<t1 ms>");
                    exit(2)
                }
                o.presses
                    .push((f[0].to_lowercase(), num(f[1].into()), num(f[2].into())));
            }
            "--trace" => o.trace = Some(need(i)),
            "--mfc-replay" => o.mfc_replay = Some(need(i)),
            "--swaplog" => o.swaplog = Some(need(i)),
            "--wav" => o.wav = Some(need(i)),
            "--screenshot" => o.screenshot = Some(need(i)),
            "--dump-mem" => o.dump_mem = Some(need(i)),
            "--start-line" => o.start_line = num(need(i)) as u64,
            _ => {
                eprintln!("unknown option {a}, see --help");
                exit(2)
            }
        }
        i += 2;
    }
    if o.flash.is_empty() {
        eprint!("{HELP}");
        exit(2)
    }
    o
}

pub fn make_system(o: &Options) -> System {
    let bytes = std::fs::read(&o.flash).unwrap_or_else(|e| {
        eprintln!("{}: {e}", o.flash);
        exit(1)
    });
    let mut sys = System::new(
        program_from_flash(&bytes),
        o.start_line * tetric::video::H_TOTAL,
    );
    sys.board.fix_beam = o.fix_beam;
    sys.board.ideal = o.ideal;
    sys
}

/// 640x240 picture -> 640x480 (every screen line twice)
#[allow(dead_code)]
pub fn double_lines(frame: &[u32], out: &mut [u32]) {
    for y in 0..LINES {
        let row = &frame[y * WIDTH..(y + 1) * WIDTH];
        out[2 * y * WIDTH..(2 * y + 1) * WIDTH].copy_from_slice(row);
        out[(2 * y + 1) * WIDTH..(2 * y + 2) * WIDTH].copy_from_slice(row);
    }
}

pub fn write_ppm(path: &str, frame: &[u32]) -> std::io::Result<()> {
    let mut f = BufWriter::new(File::create(path)?);
    write!(f, "P6\n{} {}\n255\n", WIDTH, 2 * LINES)?;
    for y in 0..2 * LINES {
        for x in 0..WIDTH {
            let p = frame[(y / 2) * WIDTH + x];
            f.write_all(&[(p >> 16) as u8, (p >> 8) as u8, p as u8])?;
        }
    }
    Ok(())
}

pub fn write_wav(path: &str, samples: &[(i16, i16)]) -> std::io::Result<()> {
    let mut f = BufWriter::new(File::create(path)?);
    let data_len = (samples.len() * 4) as u32;
    f.write_all(b"RIFF")?;
    f.write_all(&(36 + data_len).to_le_bytes())?;
    f.write_all(b"WAVEfmt ")?;
    f.write_all(&16u32.to_le_bytes())?;
    f.write_all(&1u16.to_le_bytes())?; // PCM
    f.write_all(&2u16.to_le_bytes())?;
    f.write_all(&48_000u32.to_le_bytes())?;
    f.write_all(&(48_000u32 * 4).to_le_bytes())?;
    f.write_all(&4u16.to_le_bytes())?;
    f.write_all(&16u16.to_le_bytes())?;
    f.write_all(b"data")?;
    f.write_all(&data_len.to_le_bytes())?;
    for (l, r) in samples {
        f.write_all(&l.to_le_bytes())?;
        f.write_all(&r.to_le_bytes())?;
    }
    Ok(())
}

pub fn set_button(pad: &mut tetric::system::Pad, name: &str, v: bool) -> bool {
    match name {
        "start" => pad.start = v,
        "select" => pad.select = v,
        "cross" | "b" => pad.cross = v,
        "square" | "a" => pad.square = v,
        "circle" | "c" => pad.circle = v,
        "triangle" => pad.triangle = v,
        "up" => pad.up = v,
        "down" => pad.down = v,
        "left" => pad.left = v,
        "right" => pad.right = v,
        _ => return false,
    }
    true
}

fn headless(o: &Options) {
    let mut sys = make_system(o);
    sys.board.audio_enabled = o.wav.is_some();
    if let Some(t) = &o.trace {
        let f = File::create(t).unwrap_or_else(|e| {
            eprintln!("{t}: {e}");
            exit(1)
        });
        sys.board.trace = Some(Box::new(BufWriter::with_capacity(1 << 20, f)));
    }
    if let Some(r) = &o.mfc_replay {
        // the M lines of an RTL trace: "M <cycle> <value>"
        let f = File::open(r).unwrap_or_else(|e| {
            eprintln!("{r}: {e}");
            exit(1)
        });
        let mut q = VecDeque::new();
        for line in BufReader::with_capacity(1 << 20, f).lines() {
            let line = line.unwrap();
            if let Some(rest) = line.strip_prefix("M ") {
                let v = rest.split_whitespace().last().unwrap();
                q.push_back(u32::from_str_radix(v, 16).unwrap());
            }
        }
        eprintln!("{} MFC values to replay", q.len());
        sys.board.mfc_replay = Some(q);
    }
    if o.swaplog.is_some() {
        sys.board.swaplog = Some(Vec::new());
    }
    for (b, _, _) in &o.presses {
        if !set_button(&mut tetric::system::Pad::default(), b, true) {
            eprintln!("unknown button {b}");
            exit(2)
        }
    }

    let start = sys.clk();
    let end = start + (o.seconds * CLOCK_HZ as f64) as u64;
    let mut wav = Vec::new();
    let t0 = std::time::Instant::now();
    let chunk = CLOCK_HZ / 1000; // 1 ms
    while sys.clk() < end && !sys.board.halted {
        let ms = (sys.clk() - start) as f64 * 1000.0 / CLOCK_HZ as f64;
        let mut pad = tetric::system::Pad::default();
        for (b, t0, t1) in &o.presses {
            if ms >= *t0 && ms < *t1 {
                set_button(&mut pad, b, true);
            }
        }
        sys.board.pad = pad;
        sys.run_until((sys.clk() + chunk).min(end));
        wav.extend(sys.board.audio.drain(..));
        if sys.board.replay_exhausted {
            eprintln!("MFC replay values exhausted at step {}", sys.steps);
            break;
        }
    }
    let wall = t0.elapsed().as_secs_f64();
    let emu = (sys.clk() - start) as f64 / CLOCK_HZ as f64;
    if let Some(t) = &mut sys.board.trace {
        t.flush().unwrap();
    }
    if let (Some(p), Some(log)) = (&o.swaplog, &sys.board.swaplog) {
        let mut f = BufWriter::new(File::create(p).unwrap());
        for l in log {
            writeln!(f, "{l}").unwrap();
        }
    }
    if let Some(p) = &o.wav {
        write_wav(p, &wav).unwrap();
    }
    if let Some(p) = &o.screenshot {
        write_ppm(p, &sys.board.video.frame).unwrap();
    }
    if let Some(p) = &o.dump_mem {
        let bytes: Vec<u8> = sys.board.mem.iter().flat_map(|w| w.to_be_bytes()).collect();
        std::fs::write(p, bytes).unwrap();
    }
    if o.stats {
        eprintln!(
            "{:.3} s emulated in {:.3} s ({:.1}x real time), {} steps, {} clocks, {} icache misses, {} frames",
            emu,
            wall,
            emu / wall,
            sys.steps,
            sys.clk() - start,
            sys.board.icache.misses,
            sys.board.video.frame_counter
        );
    }
    if sys.board.bad_loads != 0 {
        eprintln!(
            "warning: {} loads from peripheral addresses (they hang the hardware)",
            sys.board.bad_loads
        );
    }
}

fn main() {
    let o = parse_args();
    if o.headless {
        headless(&o);
    } else {
        frontend::run(&o);
        // do not wait for the sound / gamepad threads
        exit(0);
    }
}
