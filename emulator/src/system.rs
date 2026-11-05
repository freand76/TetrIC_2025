//! The TetrIC system (rtl/top.v): CPU, 4 MByte SDRAM, instruction cache,
//! video, sound, UART and gamepad, with a cycle count model of the stalls.

use crate::cpu::{Bus, Cpu, MemOp};
use crate::sound::{Sound, CLOCKS_PER_SAMPLE};
use crate::video::Video;
use std::collections::VecDeque;
use std::io::Write;

/// SDRAM size in words (processor address 0x0xxxxx).
pub const MEM_WORDS: usize = 1 << 20;
/// Words copied from the flash to SDRAM at power on (COPY_WORDS in rtl/top.v).
pub const COPY_WORDS: usize = 262_144;
/// Flash byte offset of the program in a full flash image.
pub const FLASH_START: usize = 0x50_0000;
/// CPU clock.
pub const CLOCK_HZ: u64 = 25_200_000;

/// Extra clocks of the stall sources. The defaults are averages measured
/// in the RTL simulation of the game (sim/system, +stats).
#[derive(Clone, Copy, Debug)]
pub struct Timing {
    /// instruction cache line fill (8 words)
    pub icache_miss: u32,
    /// load from SDRAM
    pub load: u32,
    /// store to SDRAM (posted)
    pub store: u32,
    /// store to a peripheral
    pub periph: u32,
}

impl Default for Timing {
    fn default() -> Self {
        Timing {
            icache_miss: 14,
            load: 14,
            store: 3,
            periph: 1,
        }
    }
}

/// Instruction cache (rtl/icache): direct mapped, 32 lines x 8 words, no
/// invalidation on stores (as the hardware).
#[derive(Default)]
pub struct ICache {
    tag: [u32; 32],
    valid: [bool; 32],
    data: [[u32; 8]; 32],
    pub misses: u64,
}

impl ICache {
    /// true on a hit; a miss fills the line from `mem`
    #[inline]
    fn lookup(&mut self, addr: u32, mem: &[u32]) -> bool {
        let line = ((addr >> 3) & 31) as usize;
        let tag = addr >> 8;
        if self.valid[line] && self.tag[line] == tag {
            return true;
        }
        let base = (addr & !7) as usize;
        self.data[line].copy_from_slice(&mem[base..base + 8]);
        self.tag[line] = tag;
        self.valid[line] = true;
        self.misses += 1;
        false
    }

    #[inline]
    fn read(&self, addr: u32) -> u32 {
        self.data[((addr >> 3) & 31) as usize][(addr & 7) as usize]
    }
}

/// Gamepad buttons (PlayStation layout as rtl/gamepad, true = pressed).
#[derive(Clone, Copy, Default, Debug, PartialEq, Eq)]
pub struct Pad {
    pub up: bool,
    pub down: bool,
    pub left: bool,
    pub right: bool,
    pub start: bool,
    pub select: bool,
    /// TetrIC A
    pub square: bool,
    /// TetrIC B
    pub cross: bool,
    /// TetrIC C
    pub circle: bool,
    pub triangle: bool,
    pub l1: bool,
    pub r1: bool,
    pub l2: bool,
    pub r2: bool,
}

impl Pad {
    /// MFC2: {8'h00, buttons2, buttons1, joy}, active low
    pub fn mfc2(&self) -> u32 {
        let b = |v: bool, n: u32| if v { 1u32 << n } else { 0 };
        let b1 = b(self.select, 0)
            | b(self.start, 3)
            | b(self.up, 4)
            | b(self.right, 5)
            | b(self.down, 6)
            | b(self.left, 7);
        let b2 = b(self.l2, 0)
            | b(self.r2, 1)
            | b(self.l1, 2)
            | b(self.r1, 3)
            | b(self.triangle, 4)
            | b(self.circle, 5)
            | b(self.cross, 6)
            | b(self.square, 7);
        let joy = b(self.up, 0)
            | b(self.square, 1)
            | b(self.down, 2)
            | b(self.right, 3)
            | b(self.cross, 4)
            | b(self.left, 5)
            | b(self.start, 6)
            | b(self.circle, 7);
        let b1 = !b1 & 0xff;
        let b2 = !b2 & 0xff;
        let joy = !joy & 0xff;
        (b2 << 16) | (b1 << 8) | joy
    }
}

/// Everything except the CPU (the CPU's bus).
pub struct Board {
    pub mem: Vec<u32>,
    pub icache: ICache,
    pub video: Video,
    pub sound: Sound,
    pub pad: Pad,
    /// the gamepad as the hardware sees it (polled ~60 times per second)
    pad_seen: u32,
    next_pad_poll: u64,
    /// CPU clock now
    pub clk: u64,
    next_sample: u64,
    /// output samples not yet taken by the frontend
    pub audio: VecDeque<(i16, i16)>,
    pub audio_enabled: bool,
    pub uart_busy_until: u64,
    pub uart_out: Vec<u8>,
    pub uart_echo: bool,
    /// a store to 0x8xxxxx (ends the RTL simulation)
    pub halted: bool,
    pub bad_loads: u64,
    /// +fix_beam: MFC1 bits 19:0 read as 0
    pub fix_beam: bool,
    /// ideal timing (for comparing two builds of a program): instructions
    /// take no time, the UART is always ready, and a second MFC1 read with
    /// the same value (a wait loop) moves the time to the next frame. Every
    /// game frame is then one video frame, whatever the code's speed.
    pub ideal: bool,
    last_mfc1: Option<u32>,
    /// MFC values to replay (from an RTL trace), instead of the real ones
    pub mfc_replay: Option<VecDeque<u32>>,
    pub replay_exhausted: bool,
    /// swap log: (image hash, registers) per GFXADDR write
    pub swaplog: Option<Vec<String>>,
    /// trace output (R / S / M lines as +cputrace)
    pub trace: Option<Box<dyn Write>>,
}

impl Board {
    fn new(mem: Vec<u32>) -> Self {
        Board {
            mem,
            icache: ICache::default(),
            video: Video::new(),
            sound: Sound::default(),
            pad: Pad::default(),
            pad_seen: 0x00ff_ffff,
            next_pad_poll: 0,
            clk: 0,
            next_sample: 0,
            audio: VecDeque::new(),
            audio_enabled: true,
            uart_busy_until: 0,
            uart_out: Vec::new(),
            uart_echo: true,
            halted: false,
            bad_loads: 0,
            fix_beam: false,
            ideal: false,
            last_mfc1: None,
            mfc_replay: None,
            replay_exhausted: false,
            swaplog: None,
            trace: None,
        }
    }

    /// Run the peripherals (video lines, audio samples, pad polls) up to the
    /// current clock.
    #[inline]
    fn run_peripherals(&mut self) {
        self.video.run_to(self.clk, &self.mem);
        while self.next_sample <= self.clk {
            let s = self.sound.sample(&self.mem);
            if self.audio_enabled {
                self.audio.push_back(s);
            }
            self.next_sample += CLOCKS_PER_SAMPLE;
        }
        if self.clk >= self.next_pad_poll {
            self.pad_seen = self.pad.mfc2();
            self.next_pad_poll = self.clk + CLOCK_HZ / 60;
        }
    }
}

impl Bus for Board {
    #[inline]
    fn fetch(&mut self, addr: u32) -> u32 {
        self.icache.read(addr)
    }

    #[inline]
    fn load(&mut self, addr: u32) -> u32 {
        if addr >> 20 == 0 {
            self.mem[(addr & 0xf_ffff) as usize]
        } else {
            // the hardware waits forever for a load from a peripheral
            self.bad_loads += 1;
            0
        }
    }

    fn store(&mut self, addr: u32, data: u32) {
        match addr >> 20 {
            0x0 => self.mem[(addr & 0xf_ffff) as usize] = data,
            0xe => {
                self.video.write(addr & 15, data);
                if addr & 15 == 5 {
                    if let Some(log) = &mut self.swaplog {
                        let r = self.video.regs;
                        let h = self.video.swap_hash(&self.mem, data & 0xf_ffff);
                        let n = log.len();
                        log.push(format!(
                            "{} {:08x} top {} left {} ppl {} lines {} pixread {}",
                            n, h, r.toppos, r.leftpos, r.pixperline, r.lineperimg, r.pixread
                        ));
                    }
                }
            }
            0x4 => self.sound.cpu_write(addr & 63, data, &self.mem),
            0xf => {
                let c = data as u8;
                self.uart_out.push(c);
                if self.uart_echo {
                    let mut o = std::io::stdout();
                    let _ = o.write_all(&[c]);
                    let _ = o.flush();
                }
                // 115200 baud, 10 bits
                self.uart_busy_until = self.clk + CLOCK_HZ * 10 / 115_200;
            }
            0x8 => self.halted = true,
            _ => {}
        }
    }

    fn mfc(&mut self, n: u32) -> u32 {
        if let Some(q) = &mut self.mfc_replay {
            if let Some(v) = q.pop_front() {
                return v;
            }
            self.replay_exhausted = true;
        }
        match n {
            0 => (self.ideal || self.clk >= self.uart_busy_until) as u32,
            1 => {
                let mut s = self.video.status(self.clk);
                if self.fix_beam || self.ideal {
                    s &= 0xfff0_0000;
                }
                if self.ideal {
                    if self.last_mfc1 == Some(s) {
                        // waiting: on to the next frame counter change
                        // (xpos 640 of line 479)
                        let f = crate::video::FRAME_CLOCKS;
                        let end = 479 * crate::video::H_TOTAL + 640;
                        let k = if self.clk < end {
                            0
                        } else {
                            (self.clk - end) / f + 1
                        };
                        self.clk = k * f + end;
                        self.run_peripherals();
                        s = self.video.status(self.clk) & 0xfff0_0000;
                    }
                    self.last_mfc1 = Some(s);
                }
                s
            }
            2 => self.pad_seen,
            _ => 0,
        }
    }
}

pub struct System {
    pub cpu: Cpu,
    pub board: Board,
    pub timing: Timing,
    /// pipeline steps (instructions issued)
    pub steps: u64,
}

/// The program words from a flash file: a plain program image (copied to
/// SDRAM address 0), or a full flash image with the program at 0x500000.
pub fn program_from_flash(bytes: &[u8]) -> Vec<u32> {
    let img = if bytes.len() > FLASH_START {
        &bytes[FLASH_START..]
    } else {
        bytes
    };
    let mut mem = vec![0u32; MEM_WORDS];
    for (i, w) in img.chunks(4).take(COPY_WORDS).enumerate() {
        let mut b = [0u8; 4];
        b[..w.len()].copy_from_slice(w);
        mem[i] = u32::from_be_bytes(b);
    }
    mem
}

impl System {
    /// A system with the program copied to SDRAM. `start_clk` is the clock
    /// (DVI timing) at which the CPU starts after the flash copy.
    pub fn new(mem: Vec<u32>, start_clk: u64) -> Self {
        let mut board = Board::new(mem);
        board.clk = start_clk;
        // the video timing runs from the start (the frame counter counts)
        let first_line = start_clk / crate::video::H_TOTAL;
        board.video.skip_to_line(first_line);
        board.next_sample = start_clk - start_clk % CLOCKS_PER_SAMPLE + CLOCKS_PER_SAMPLE;
        System {
            cpu: Cpu::new(),
            board,
            timing: Timing::default(),
            steps: 0,
        }
    }

    /// One pipeline step, with its stall clocks.
    #[inline]
    pub fn step(&mut self) {
        let b = &mut self.board;
        let mut stall = 0u32;
        if !b.icache.lookup(self.cpu.pc & 0xf_ffff, &b.mem) {
            stall += self.timing.icache_miss;
        }
        match self.cpu.pending_mem() {
            MemOp::None => {}
            MemOp::Load(_) => stall += self.timing.load,
            MemOp::Store(a, _) => {
                stall += if a >> 20 == 0 {
                    self.timing.store
                } else {
                    self.timing.periph
                };
            }
        }
        if !b.ideal {
            b.clk += stall as u64;
        }
        b.run_peripherals();
        let info = self.cpu.step(b);
        if !b.ideal {
            b.clk += 1;
        }
        self.steps += 1;
        if let Some(t) = &mut b.trace {
            if let Some((r, d)) = info.reg_write {
                let _ = writeln!(t, "R {} {:08x}", r, d);
            }
            if let MemOp::Store(a, d) = info.mem {
                let _ = writeln!(t, "S {:06x} {:08x}", a, d);
            }
            if let Some(v) = info.mfc {
                let _ = writeln!(t, "M {:08x}", v);
            }
        }
    }

    /// Run until the clock has reached `clk`.
    pub fn run_until(&mut self, clk: u64) {
        while self.board.clk < clk && !self.board.halted {
            self.step();
        }
        self.board.run_peripherals();
    }

    /// Run until the clock has reached `clk`, or a frame has been finished.
    pub fn run_until_frame(&mut self, clk: u64) {
        while self.board.clk < clk && !self.board.halted && !self.board.video.frame_ready {
            self.step();
        }
        self.board.run_peripherals();
    }

    pub fn clk(&self) -> u64 {
        self.board.clk
    }
}
