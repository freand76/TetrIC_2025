//! Sound unit (rtl/sound/sound.v) and MOD sequencer (rtl/sound/sound_seq.v).
//!
//! The same model as tools/sound_ref.py, which is checked bit exact against
//! the RTL: 8 channels of signed 8 bit samples (4 per word, first in bits
//! 31:24), mixed at 48 kHz, left = channels 0,3,4,7, right = 1,2,5,6.
//! Channels 0..3 are played by the MOD sequencer. Sample words are fetched
//! instantly (the hardware has a 2 word buffer per channel, which never
//! underruns in practice).

const MASK20: u32 = 0xF_FFFF;

/// Output sample rate of the hardware (25.2 MHz / 525).
pub const SAMPLE_RATE: u32 = 48_000;
/// CPU clocks per output sample.
pub const CLOCKS_PER_SAMPLE: u64 = 525;

#[derive(Clone, Default)]
struct Channel {
    faddr: u32,
    fend: u32,
    lstart: u32,
    lend: u32,
    freq: u32,
    vol: u32,
    mvol: u32,
    cur: u32,
    nxt: u32,
    cur_v: bool,
    nxt_v: bool,
    idx: u32,
    frac: u32,
    playing: bool,
}

/// One channel write: START (1), VOL (2), END (3), LSTART (4), LEND (5), FREQ (6).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct ChanWrite {
    pub ch: u8,
    /// FX register number (4 START, 8 VOL, 12 END, 16 LSTART, 20 LEND, 24 FREQ)
    pub reg: u8,
    pub data: u32,
}

pub struct Mixer {
    ch: [Channel; 8],
    chan_on: u32,
    pub underruns: u64,
}

impl Default for Mixer {
    fn default() -> Self {
        let mut ch: [Channel; 8] = Default::default();
        for c in ch.iter_mut() {
            c.mvol = 7;
        }
        Mixer {
            ch,
            chan_on: 0xff,
            underruns: 0,
        }
    }
}

impl Mixer {
    fn fill(&mut self, c: usize, mem: &[u32]) {
        let ch = &mut self.ch[c];
        while ch.faddr < ch.fend && !(ch.cur_v && ch.nxt_v) {
            let w = mem.get(ch.faddr as usize).copied().unwrap_or(0);
            if !ch.cur_v {
                ch.cur = w;
                ch.cur_v = true;
            } else {
                ch.nxt = w;
                ch.nxt_v = true;
            }
            let mut nf = (ch.faddr + 1) & MASK20;
            if ch.lend != 0 && nf >= ch.lend {
                nf = ch.lstart;
            }
            ch.faddr = nf;
        }
    }

    /// kind: START (1), VOL (2), END (3), LSTART (4), LEND (5), FREQ (6)
    pub fn chan_write(&mut self, c: usize, kind: u32, data: u32, mem: &[u32]) {
        let ch = &mut self.ch[c];
        match kind {
            1 => {
                ch.faddr = data & MASK20;
                ch.cur_v = false;
                ch.nxt_v = false;
                ch.playing = false;
                ch.idx = 0;
                ch.frac = 0;
            }
            2 => ch.vol = data & 0x7f,
            3 => {
                ch.fend = data & MASK20;
                if ch.fend == 0 {
                    ch.cur_v = false;
                    ch.nxt_v = false;
                    ch.playing = false;
                }
            }
            4 => ch.lstart = data & MASK20,
            5 => ch.lend = data & MASK20,
            6 => ch.freq = data & 0xffff,
            _ => {}
        }
        self.fill(c, mem);
    }

    /// A CPU register write (registers 2, 4..27, 37).
    pub fn write(&mut self, reg: u32, data: u32, mem: &[u32]) {
        match reg {
            2 => self.chan_on = data & 0xff,
            37 => {
                for (c, sh) in [
                    (4, 28),
                    (5, 24),
                    (6, 20),
                    (7, 16),
                    (0, 12),
                    (1, 8),
                    (2, 4),
                    (3, 0),
                ] {
                    self.ch[c].mvol = (data >> sh) & 7;
                }
            }
            4..=27 => self.chan_write(4 + (reg & 3) as usize, reg >> 2, data, mem),
            _ => {}
        }
    }

    /// One channel of a mix pass, returns its sample.
    pub fn mix(&mut self, c: usize, mem: &[u32]) -> i32 {
        let chan_on = self.chan_on;
        let ch = &mut self.ch[c];
        let mut sample = 0i32;
        let more = ch.faddr < ch.fend;
        if !ch.playing {
            if more || ch.cur_v {
                ch.playing = true;
            }
        } else if ch.cur_v {
            let b = ((ch.cur >> (24 - 8 * ch.idx)) & 0xff) as u8 as i8 as i32;
            let v = ch.vol.min(64);
            let eff = if ch.mvol == 0 { 0 } else { v >> (7 - ch.mvol) };
            if (chan_on >> (7 - c)) & 1 != 0 {
                sample = b * eff as i32;
            }
            let inc = (ch.freq * 22370) >> 14;
            let pos = ch.frac + inc;
            ch.frac = pos & 0xffff;
            let ni = ch.idx + (pos >> 16);
            if ni >= 4 {
                ch.idx = ni - 4;
                if ch.nxt_v {
                    ch.cur = ch.nxt;
                    ch.nxt_v = false;
                } else {
                    ch.cur_v = false;
                }
                self.fill(c, mem);
            } else {
                ch.idx = ni;
            }
        } else if more || ch.nxt_v {
            self.underruns += 1;
        } else {
            ch.playing = false;
        }
        sample
    }
}

pub fn sat16(v: i32) -> i16 {
    v.clamp(-32768, 32767) as i16
}

// ---------------------------------------------------------------------------
// MOD sequencer
// ---------------------------------------------------------------------------

fn nclamp(n: i32) -> u32 {
    n.clamp(108, 907) as u32
}

fn vclamp(v: i32) -> u32 {
    v.clamp(0, 64) as u32
}

fn vslide(v: u32, prm: u32) -> u32 {
    if prm >> 4 != 0 {
        vclamp(v as i32 + (prm >> 4) as i32)
    } else {
        vclamp(v as i32 - (prm & 15) as i32)
    }
}

#[derive(Clone, Copy, Default)]
struct ModChannel {
    note: u32,
    inst: u32,
    fx: u32,
    param: u32,
    pspeed: u32,
    slideto: u32,
    sdir: bool,
    vol: u32,
}

const R_START: u8 = 4;
const R_VOL: u8 = 8;
const R_END: u8 = 12;
const R_LSTART: u8 = 16;
const R_LEND: u8 = 20;
const R_FREQ: u8 = 24;

/// sound_seq.v
pub struct Seq {
    pub offset: u32,
    pub lut: u32,
    pub status: u32,
    pub waitclk: u32,
    pub playing: bool,
    stop_req: bool,
    tick_acc: u32,
    tick_pend: bool,
    c: [ModChannel; 4],
    speed: u32,
    tickcount: u32,
    songpos: u32,
    songlen: u32,
    curpat: u32,
    patrow: u32,
}

impl Default for Seq {
    fn default() -> Self {
        Seq {
            offset: 0,
            lut: 0,
            status: 0,
            waitclk: 504_000,
            playing: false,
            stop_req: false,
            tick_acc: 0,
            tick_pend: false,
            c: Default::default(),
            speed: 6,
            tickcount: 1,
            songpos: 0,
            songlen: 0,
            curpat: 0,
            patrow: 0,
        }
    }
}

/// Events of the sequencer (for the comparison with the RTL log).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum SeqEvent {
    Start,
    Tick,
    Stop,
}

impl Seq {
    fn rd(mem: &[u32], a: u32) -> u32 {
        mem.get((a & MASK20) as usize).copied().unwrap_or(0)
    }

    /// CPU register write (0 OFFSET, 1 LUT, 3 SONGSTATUS, 28 WAITCLK).
    pub fn reg_write(&mut self, reg: u32, data: u32) {
        match reg {
            0 => self.offset = data & MASK20,
            1 => self.lut = data & MASK20,
            3 => {
                self.status = data & 7;
                if data & 1 == 0 {
                    self.stop_req = true;
                }
            }
            28 => self.waitclk = data & MASK20,
            _ => {}
        }
    }

    /// One output sample (mix_tick): count the tick time.
    pub fn sample_tick(&mut self) {
        if self.playing && self.status & 2 == 0 {
            if self.tick_acc + 525 >= self.waitclk {
                self.tick_acc = self.tick_acc + 525 - self.waitclk;
                self.tick_pend = true;
            } else {
                self.tick_acc += 525;
            }
        }
    }

    /// The idle state of the state machine: start / stop / tick. Returns the
    /// event and appends the channel writes.
    pub fn process(&mut self, mem: &[u32], out: &mut Vec<ChanWrite>) -> Option<SeqEvent> {
        if self.stop_req {
            self.stop_req = false;
            if self.playing {
                self.playing = false;
                self.stop(out);
                return Some(SeqEvent::Stop);
            }
            None
        } else if !self.playing && self.status & 1 != 0 && self.status & 2 == 0 {
            self.start(mem);
            self.tick(mem, out);
            Some(SeqEvent::Start)
        } else if self.playing && self.tick_pend {
            self.tick_pend = false;
            self.tick(mem, out);
            Some(SeqEvent::Tick)
        } else {
            None
        }
    }

    pub fn start(&mut self, mem: &[u32]) {
        let w = Self::rd(mem, self.offset + 124);
        self.songlen = (w >> 24) & 127;
        self.curpat = w & 127;
        self.speed = 6;
        self.tickcount = 1;
        self.songpos = 0;
        self.patrow = 0;
        self.playing = true;
        self.tick_acc = 0;
        self.tick_pend = false;
    }

    pub fn stop(&mut self, out: &mut Vec<ChanWrite>) {
        self.playing = false;
        for ch in 0..4 {
            out.push(ChanWrite {
                ch,
                reg: R_END,
                data: 0,
            });
        }
    }

    pub fn tick(&mut self, mem: &[u32], out: &mut Vec<ChanWrite>) {
        if self.tickcount == 1 {
            self.tickcount = self.speed;
            self.row(mem, out);
            return;
        }
        self.tickcount = (self.tickcount - 1) & 31;
        let lut = self.lut;
        for (n, c) in self.c.iter_mut().enumerate() {
            let pitch = matches!(c.fx, 1 | 2 | 3 | 5);
            let vfx = matches!(c.fx, 5 | 6 | 10);
            match c.fx {
                1 => c.note = nclamp(c.note as i32 - c.pspeed as i32),
                2 => c.note = nclamp(c.note as i32 + c.pspeed as i32),
                3 | 5 => {
                    if c.sdir {
                        let t = c.note as i32 + c.pspeed as i32;
                        if t >= c.slideto as i32 {
                            c.note = c.slideto;
                            c.fx = 0;
                        } else {
                            c.note = nclamp(t);
                        }
                    } else {
                        let t = c.note as i32 - c.pspeed as i32;
                        if t <= c.slideto as i32 {
                            c.note = c.slideto;
                            c.fx = 0;
                        } else {
                            c.note = nclamp(t);
                        }
                    }
                }
                _ => {}
            }
            let ch = n as u8;
            if vfx {
                c.vol = vslide(c.vol, c.param);
                out.push(ChanWrite {
                    ch,
                    reg: R_VOL,
                    data: c.vol,
                });
            }
            if pitch && c.note != 0 {
                out.push(ChanWrite {
                    ch,
                    reg: R_FREQ,
                    data: Self::rd(mem, lut + c.note) & 0xffff,
                });
            }
        }
    }

    fn row(&mut self, mem: &[u32], out: &mut Vec<ChanWrite>) {
        let mut brk = false;
        let mut jump = false;
        let base = self.offset;
        for n in 0..4 {
            let pat = Self::rd(
                mem,
                base + 157 + (self.curpat << 8) + (self.patrow << 2) + n as u32,
            );
            let inst = pat >> 27;
            let note = (pat >> 16) & 0x7ff;
            let fx = (pat >> 8) & 255;
            let prm = pat & 255;
            let c = &mut self.c[n];
            let ei = if inst != 0 { inst } else { c.inst };
            let porta = fx == 3 || fx == 5;
            let hdr = ei != 0 && (inst != 0 || note != 0);
            let trig = ei != 0 && note != 0 && !porta;
            let (mut h_start, mut h_vol, mut h_end, mut h_ls, mut h_le) = (0, 0, 0, 0, 0);
            if hdr {
                let h: Vec<u32> = (0..4)
                    .map(|k| Self::rd(mem, base + (ei - 1) * 4 + k))
                    .collect();
                h_start = (base + ((h[0] >> 2) & MASK20)) & MASK20;
                h_vol = (h[1] >> 24) & 127;
                h_end = (base + ((h[1] >> 2) & MASK20)) & MASK20;
                h_ls = (base + ((h[2] >> 2) & MASK20)) & MASK20;
                h_le = if (h[3] >> 2) & 0xff_ffff == 0 {
                    0
                } else {
                    (base + ((h[3] >> 2) & MASK20)) & MASK20
                };
            }
            if note != 0 && !porta {
                c.note = note;
            }
            if inst != 0 {
                c.vol = h_vol;
                c.inst = inst;
            }
            match fx {
                1 | 2 => c.pspeed = prm,
                3 => {
                    if prm != 0 {
                        c.pspeed = prm;
                    }
                    if note != 0 {
                        c.slideto = note;
                    }
                    c.sdir = c.note < c.slideto;
                }
                0x0b => {
                    if !jump {
                        self.patrow = 0;
                        jump = true;
                        self.songpos = prm & 127;
                    }
                }
                0x0c => c.vol = vclamp((prm & 127) as i32),
                0x0d => {
                    if !brk {
                        self.patrow = prm & 63;
                        brk = true;
                        if !jump {
                            self.songpos = (self.songpos + 1) & 127;
                        }
                    }
                }
                0x0e => {
                    let (hi, lo) = (prm >> 4, (prm & 15) as i32);
                    match hi {
                        1 => c.note = nclamp(c.note as i32 - lo),
                        2 => c.note = nclamp(c.note as i32 + lo),
                        0xa => c.vol = vclamp(c.vol as i32 + lo),
                        0xb => c.vol = vclamp(c.vol as i32 - lo),
                        _ => {}
                    }
                }
                0x0f => {
                    if prm > 0 && prm < 32 {
                        self.speed = prm;
                    }
                }
                _ => {}
            }
            c.fx = fx;
            c.param = prm;
            let ch = n as u8;
            if hdr {
                out.push(ChanWrite {
                    ch,
                    reg: R_END,
                    data: h_end,
                });
                out.push(ChanWrite {
                    ch,
                    reg: R_LSTART,
                    data: h_ls,
                });
                out.push(ChanWrite {
                    ch,
                    reg: R_LEND,
                    data: h_le,
                });
            }
            if trig {
                out.push(ChanWrite {
                    ch,
                    reg: R_START,
                    data: h_start,
                });
            }
            out.push(ChanWrite {
                ch,
                reg: R_VOL,
                data: c.vol,
            });
            if c.note != 0 {
                out.push(ChanWrite {
                    ch,
                    reg: R_FREQ,
                    data: Self::rd(mem, self.lut + c.note) & 0xffff,
                });
            }
        }
        // next row / song position
        if !jump && !brk && self.patrow != 63 {
            self.patrow += 1;
            return;
        }
        if !jump && !brk {
            self.patrow = 0;
            self.songpos = (self.songpos + 1) & 127;
        }
        if self.songpos >= self.songlen {
            if self.status & 4 == 0 {
                self.status &= !1;
                self.stop(out);
                return;
            }
            self.songpos = 0;
        }
        let w = Self::rd(mem, base + 125 + (self.songpos >> 2));
        self.curpat = (w >> (8 * (self.songpos & 3))) & 127;
    }
}

/// The whole sound unit as seen by the CPU.
#[derive(Default)]
pub struct Sound {
    pub mixer: Mixer,
    pub seq: Seq,
    writes: Vec<ChanWrite>,
}

impl Sound {
    /// CPU write to 0x4xxxxx, register = address bits 5:0.
    pub fn cpu_write(&mut self, reg: u32, data: u32, mem: &[u32]) {
        match reg {
            0 | 1 | 3 | 28 => self.seq.reg_write(reg, data),
            _ => self.mixer.write(reg, data, mem),
        }
    }

    /// One 48 kHz output sample. The sequencer handles a tick before the
    /// mix pass. (The hardware needs about one sample time for a row, so
    /// the last channel's writes of a row can be one sample later there.)
    pub fn sample(&mut self, mem: &[u32]) -> (i16, i16) {
        self.seq.sample_tick();
        let mut w = std::mem::take(&mut self.writes);
        w.clear();
        self.seq.process(mem, &mut w);
        for cw in &w {
            self.mixer
                .chan_write(cw.ch as usize, (cw.reg >> 2) as u32, cw.data, mem);
        }
        self.writes = w;
        let mut l = 0;
        let mut r = 0;
        for c in 0..8 {
            let s = self.mixer.mix(c, mem);
            if matches!(c, 0 | 3 | 4 | 7) {
                l += s;
            } else {
                r += s;
            }
        }
        (sat16(l), sat16(r))
    }
}
