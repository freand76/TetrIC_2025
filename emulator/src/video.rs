//! Video unit (rtl/video/video.v): RGB565 frame buffer in SDRAM shown on a
//! fixed 640x480 @ 60 Hz DVI timing (800 x 525 pixel clocks, pixel clock =
//! CPU clock = 25.2 MHz). Every image pixel is two DVI lines high.
//!
//! The model follows the RTL at the line level: the registers written by the
//! CPU become active at the start of a frame (ypos 524, xpos 0), and each
//! image line is fetched from memory at the time the RTL requests it (xpos
//! 640 of the DVI line before the screen line), into one of two line
//! memories. The DMA itself is taken as instant.

pub const H_TOTAL: u64 = 800;
pub const V_TOTAL: u64 = 525;
pub const FRAME_CLOCKS: u64 = H_TOTAL * V_TOTAL; // 420000
pub const WIDTH: usize = 640;
pub const LINES: usize = 240; // screen lines (2 DVI lines each)

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Regs {
    pub toppos: u32,
    pub leftpos: u32,
    pub pixperline: u32,
    pub lineperimg: u32,
    pub pixread: u32,
    pub gfxaddr: u32,
    pub deltaaddr: u32,
}

impl Default for Regs {
    fn default() -> Self {
        Regs {
            toppos: 0,
            leftpos: 0,
            pixperline: 320,
            lineperimg: 240,
            pixread: 2,
            gfxaddr: 0x200,
            deltaaddr: 0,
        }
    }
}

pub struct Video {
    /// registers as written by the CPU (r_* = p_* in the RTL)
    pub regs: Regs,
    /// registers of the current frame (a_*)
    active: Regs,
    line_ptr: u32,
    line_mem: [[u32; 160]; 2],
    line_vis: [bool; 2],
    pub frame_counter: u32,
    /// the picture being built (640 x 240 RGB888, one row per screen line)
    work: Vec<u32>,
    /// the last finished picture
    pub frame: Vec<u32>,
    pub frame_ready: bool,
    /// clock of the next event, and the DVI position of it
    next_line_clock: u64,
    line_y: u64,
}

impl Default for Video {
    fn default() -> Self {
        Self::new()
    }
}

/// RGB565 -> RGB888 as the RTL expands it
#[inline]
pub fn expand(p: u32) -> u32 {
    let r = (p >> 11) & 31;
    let g = (p >> 5) & 63;
    let b = p & 31;
    ((r << 3 | r >> 2) << 16) | ((g << 2 | g >> 4) << 8) | (b << 3 | b >> 2)
}

impl Video {
    pub fn new() -> Self {
        Video {
            regs: Regs::default(),
            active: Regs::default(),
            line_ptr: 0x200,
            line_mem: [[0; 160]; 2],
            line_vis: [false; 2],
            frame_counter: 0,
            work: vec![0; WIDTH * LINES],
            frame: vec![0; WIDTH * LINES],
            frame_ready: false,
            next_line_clock: 0,
            line_y: 0,
        }
    }

    /// Start the DVI timing at line `line` (counted from power on).
    pub fn skip_to_line(&mut self, line: u64) {
        self.next_line_clock = line * H_TOTAL;
        self.line_y = line % V_TOTAL;
    }

    /// CPU write to 0xExxxxx, register = address bits 3:0.
    pub fn write(&mut self, reg: u32, data: u32) {
        let r = &mut self.regs;
        match reg {
            0 => r.toppos = data & 0x1ff,
            1 => r.leftpos = data & 0x1ff,
            2 => r.pixperline = data & 0x1ff,
            3 => r.lineperimg = data & 0x1ff,
            4 => r.pixread = data & 0x3ff,
            5 => r.gfxaddr = data & 0xf_ffff,
            6 => r.deltaaddr = data & 0xf_ffff,
            _ => {}
        }
    }

    /// MFC1 status at clock `clk`: [31:20] frame counter, [19:9] xpos, [8:0] screen line.
    pub fn status(&self, clk: u64) -> u32 {
        let in_frame = clk % FRAME_CLOCKS;
        let x = in_frame % H_TOTAL;
        let y = in_frame / H_TOTAL;
        // frame counter: +1 at xpos 639 of ypos 479
        let mut fc = (clk / FRAME_CLOCKS) as u32;
        if in_frame >= 479 * H_TOTAL + 640 {
            fc += 1;
        }
        ((fc & 0xfff) << 20) | ((x as u32) << 9) | ((y >> 1) as u32)
    }

    /// Run the video timing up to clock `clk` (exclusive). Each DVI line is
    /// handled at its xpos 640 (line request) - that is after the visible
    /// part of the line, so the picture of screen line s is complete then.
    pub fn run_to(&mut self, clk: u64, mem: &[u32]) {
        while self.next_line_clock + 640 < clk {
            let y = self.line_y;
            self.line_event(y, mem);
            self.next_line_clock += H_TOTAL;
            self.line_y = if y + 1 == V_TOTAL { 0 } else { y + 1 };
        }
    }

    /// ypos `y`, at xpos 640
    fn line_event(&mut self, y: u64, mem: &[u32]) {
        if y == V_TOTAL - 1 {
            // xpos 0 of this line: frame start, the registers become active
            self.active = self.regs;
            if self.active.pixread == 0 {
                self.active.pixread = 1;
            }
            self.line_ptr = self.regs.gfxaddr;
        }
        if y == 479 {
            // xpos 639: frame end (the frame counter is computed from the clock)
            self.frame_counter = self.frame_counter.wrapping_add(1);
            std::mem::swap(&mut self.frame, &mut self.work);
            self.frame_ready = true;
        }
        // line request for screen line next_line
        if y == V_TOTAL - 1 || (y < 478 && y.is_multiple_of(2)) {
            let next_line = if y == V_TOTAL - 1 {
                0
            } else {
                (y / 2 + 1) as u32
            };
            let a = &self.active;
            let img_line = next_line.wrapping_sub(a.toppos) & 0x3ff;
            let vis = next_line >= a.toppos && img_line < a.lineperimg && a.pixperline != 0;
            let odd = (next_line & 1) as usize;
            self.line_vis[odd] = vis;
            if vis {
                let words = ((a.pixperline + 1) >> 1) as usize;
                for i in 0..words {
                    let la = i & 0xff; // 8 bit line address
                    if la < 160 {
                        let addr = (self.line_ptr as usize + i) & 0xf_ffff;
                        self.line_mem[odd][la] = mem.get(addr).copied().unwrap_or(0);
                    }
                }
                self.line_ptr = (self.line_ptr + words as u32 + a.deltaaddr) & 0xf_ffff;
            }
            if (next_line as usize) < LINES {
                self.render_line(next_line as usize);
            }
        }
    }

    /// The pixels of screen line `s` (its line memory has just been filled;
    /// it is shown during the next two DVI lines with the active registers).
    fn render_line(&mut self, s: usize) {
        let odd = s & 1;
        let a = self.active;
        let row = &mut self.work[s * WIDTH..(s + 1) * WIDTH];
        if !self.line_vis[odd] {
            row.fill(0);
            return;
        }
        let lm = &self.line_mem[odd];
        let start = 2 * a.leftpos as usize;
        let pr = a.pixread.max(1) as usize;
        for (x, px) in row.iter_mut().enumerate() {
            *px = 0;
            if x < start || start >= 800 {
                continue;
            }
            let ix = ((x - start) / pr).min(0x3ff);
            if ix >= a.pixperline as usize {
                continue;
            }
            let pa = ix & 0x1ff;
            let blk = pa >> 5;
            let w = (pa >> 1) & 15;
            let word = if blk < 10 { lm[blk * 16 + w] } else { lm[w] };
            let p = if pa & 1 == 1 {
                word & 0xffff
            } else {
                word >> 16
            };
            *px = expand(p);
        }
    }

    /// FNV-1a hash over the image the registers point at (as +swaplog in
    /// sim/system/tb_system.v).
    pub fn swap_hash(&self, mem: &[u32], addr: u32) -> u32 {
        let r = &self.regs;
        let mut h: u32 = 0x811c9dc5;
        let words = r.pixperline.div_ceil(2);
        for sy in 0..r.lineperimg {
            for sx in 0..words {
                let a = (addr + sy * (words + r.deltaaddr) + sx) as usize;
                h = (h ^ mem.get(a).copied().unwrap_or(0)).wrapping_mul(16777619);
            }
        }
        h
    }
}
