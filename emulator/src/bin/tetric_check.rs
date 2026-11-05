//! Cross checks of the emulator's sound model against the RTL simulation.
//!
//!   tetric_check audio <audio.log> <program.bin | memory dump>
//!
//! audio.log is written by sim/system (or sim/sound) with +audio=<file>:
//!   W <pass> <phase> <reg> <data>        CPU register write
//!   C <pass> <phase> <ch> <reg> <data>   MOD sequencer channel write
//!   E start|tick|stop <pass>             MOD sequencer event
//!   S <left> <right>                     one 48 kHz output sample
//! (phase = mixer channel in that clock, 8 = between passes)
//!
//! Three checks, as tools/sound_ref.py:
//!   1. mixer: the logged W and C writes replayed at their positions, every
//!      output sample must be equal,
//!   2. sequencer: driven by the logged events, its channel writes must equal
//!      the logged C writes, and the tick intervals must follow WAITCLK,
//!   3. free running: only the CPU writes (W) are replayed, the emulator's
//!      own sequencer runs the song as in the emulator (writes applied at the
//!      next sample); reports how many samples differ.

use std::collections::HashMap;
use std::process::exit;
use tetric::sound::{sat16, ChanWrite, Mixer, Seq, Sound};
use tetric::system::program_from_flash;

#[derive(Clone)]
enum Ev {
    W(u32, u32),
    C(u8, u8, u32),
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if args.len() != 4 || args[1] != "audio" {
        eprintln!("usage: tetric_check audio <audio.log> <program.bin>");
        exit(2)
    }
    let log = std::fs::read_to_string(&args[2]).unwrap_or_else(|e| {
        eprintln!("{}: {e}", args[2]);
        exit(1)
    });
    // a program image, or a memory dump of the emulator (tetric_emu
    // --dump-mem, 4 MByte): for songs the program builds in memory
    let bytes = std::fs::read(&args[3]).unwrap();
    let mem: Vec<u32> = if bytes.len() == 4 * tetric::system::MEM_WORDS {
        bytes
            .chunks(4)
            .map(|w| u32::from_be_bytes([w[0], w[1], w[2], w[3]]))
            .collect()
    } else {
        program_from_flash(&bytes)
    };

    let mut writes: HashMap<(u64, u32), Vec<Ev>> = HashMap::new();
    let mut sim: Vec<(i16, i16)> = Vec::new();
    // sequencer events in order: W (reg, data), C, E
    enum SE {
        W(u64, u32, u32),
        C(ChanWrite),
        Start,
        Tick(u64),
        Stop,
    }
    let mut events = Vec::new();
    for line in log.lines() {
        let f: Vec<&str> = line.split_whitespace().collect();
        let n = |i: usize| -> u64 { f[i].parse().unwrap() };
        match f.first() {
            Some(&"W") => {
                writes
                    .entry((n(1), n(2) as u32))
                    .or_default()
                    .push(Ev::W(n(3) as u32, n(4) as u32));
                events.push(SE::W(n(1), n(3) as u32, n(4) as u32));
            }
            Some(&"C") => {
                let cw = ChanWrite {
                    ch: n(3) as u8,
                    reg: n(4) as u8,
                    data: n(5) as u32,
                };
                writes
                    .entry((n(1), n(2) as u32))
                    .or_default()
                    .push(Ev::C(cw.ch, cw.reg, cw.data));
                events.push(SE::C(cw));
            }
            Some(&"E") => match f[1] {
                "start" => events.push(SE::Start),
                "tick" => events.push(SE::Tick(n(2))),
                "stop" => events.push(SE::Stop),
                _ => {}
            },
            Some(&"S") => sim.push((f[1].parse().unwrap(), f[2].parse().unwrap())),
            _ => {}
        }
    }
    let mut errors = 0usize;

    // ---- 1. mixer ----
    let mut mix = Mixer::default();
    let apply = |mix: &mut Mixer, ws: Option<&Vec<Ev>>| {
        for w in ws.into_iter().flatten() {
            match *w {
                Ev::W(reg, data) => mix.write(reg, data, &mem),
                Ev::C(ch, reg, data) => mix.chan_write(ch as usize, (reg >> 2) as u32, data, &mem),
            }
        }
    };
    apply(&mut mix, writes.get(&(0, 8)));
    let mut mix_err = 0;
    for (k, s) in sim.iter().enumerate() {
        let k = k as u64 + 1;
        let (mut l, mut r) = (0, 0);
        for c in 0..8 {
            let v = mix.mix(c, &mem);
            if matches!(c, 0 | 3 | 4 | 7) {
                l += v;
            } else {
                r += v;
            }
            apply(&mut mix, writes.get(&(k, c as u32)));
        }
        let out = (sat16(l), sat16(r));
        if out != *s {
            if mix_err < 10 {
                println!(
                    "MIXER MISMATCH sample {}: sim {:?} emulator {:?}",
                    k - 1,
                    s,
                    out
                );
            }
            mix_err += 1;
        }
        apply(&mut mix, writes.get(&(k, 8)));
    }
    let nz = sim.iter().filter(|s| s.0 != 0 || s.1 != 0).count();
    println!(
        "mixer: {} samples ({:.1} ms), {} non-silent, {} mismatches",
        sim.len(),
        sim.len() as f64 / 48.0,
        nz,
        mix_err
    );
    errors += mix_err;

    // ---- 2. sequencer ----
    let mut seq = Seq::default();
    let mut expected: Vec<ChanWrite> = Vec::new();
    let mut got: Vec<ChanWrite> = Vec::new();
    let mut ticks: Vec<Option<u64>> = Vec::new();
    let mut paused: Vec<u64> = Vec::new();
    let (mut pause_at, mut pause_n): (Option<u64>, u64) = (None, 0);
    for e in &events {
        match e {
            SE::W(pass, reg, data) => {
                if *reg == 3 {
                    if data & 2 != 0 && pause_at.is_none() {
                        pause_at = Some(*pass);
                    } else if data & 2 == 0 {
                        if let Some(p) = pause_at.take() {
                            pause_n += pass - p;
                        }
                    }
                }
                // only the registers (a stop request is an E stop event here)
                match reg {
                    0 | 1 | 28 => seq.reg_write(*reg, *data),
                    3 => seq.status = data & 7,
                    _ => {}
                }
            }
            SE::C(cw) => got.push(*cw),
            SE::Start => {
                seq.start(&mem);
                ticks.push(None);
                paused.push(0);
                pause_n = 0;
            }
            SE::Tick(pass) => {
                ticks.push(Some(*pass));
                paused.push(pause_n);
                pause_n = 0;
                seq.tick(&mem, &mut expected);
            }
            SE::Stop => {
                if seq.playing {
                    seq.stop(&mut expected);
                }
                ticks.push(None);
                paused.push(0);
            }
        }
    }
    let mut seq_err = 0;
    for (n, (a, b)) in expected.iter().zip(got.iter()).enumerate() {
        if a != b {
            if seq_err < 10 {
                println!("SEQ MISMATCH write {n}: sim {b:?}, emulator {a:?}");
            }
            seq_err += 1;
        }
    }
    if expected.len() != got.len() {
        println!(
            "SEQ MISMATCH: {} writes in the simulation, {} in the emulator",
            got.len(),
            expected.len()
        );
        seq_err += 1;
    }
    // tick intervals: +525 per sample, a tick when WAITCLK is passed
    let (mut acc, mut last, mut n_ticks) = (0u64, None::<u64>, 0);
    let waitclk = seq.waitclk as u64;
    for (t, p) in ticks.iter().zip(paused.iter()) {
        let Some(mut t) = *t else {
            last = None;
            continue;
        };
        if let Some(l) = last {
            t -= p;
            let (mut n, mut a) = (0, acc);
            loop {
                n += 1;
                a += 525;
                if a >= waitclk {
                    a -= waitclk;
                    break;
                }
            }
            if t - l != n {
                if seq_err < 10 {
                    println!(
                        "SEQ TICK interval {} samples, expected {} (tick at {})",
                        t - l,
                        n,
                        t
                    );
                }
                seq_err += 1;
            }
            acc = a;
            t += p;
        } else {
            acc = 0;
        }
        last = Some(t);
        n_ticks += 1;
    }
    println!(
        "sequencer: {} ticks, {} channel writes, {} mismatches",
        n_ticks,
        got.len(),
        seq_err
    );
    errors += seq_err;

    // ---- 3. free running (as in the emulator) ----
    let mut snd = Sound::default();
    for w in writes.get(&(0, 8)).into_iter().flatten() {
        if let Ev::W(reg, data) = *w {
            snd.cpu_write(reg, data, &mem);
        }
    }
    let mut free_diff = 0;
    let mut first = None;
    for (k, s) in sim.iter().enumerate() {
        let k = k as u64 + 1;
        let out = snd.sample(&mem);
        if out != *s {
            free_diff += 1;
            first.get_or_insert(k - 1);
        }
        for c in 0..9 {
            for w in writes.get(&(k, c)).into_iter().flatten() {
                if let Ev::W(reg, data) = *w {
                    snd.cpu_write(reg, data, &mem);
                }
            }
        }
    }
    println!(
        "free running: {} of {} samples differ{}",
        free_diff,
        sim.len(),
        first
            .map(|f| format!(" (first at sample {f})"))
            .unwrap_or_default()
    );

    if errors != 0 || sim.is_empty() {
        println!("FAIL");
        exit(1)
    }
    println!("PASS: mixer and sequencer match the RTL simulation bit exact");
}
