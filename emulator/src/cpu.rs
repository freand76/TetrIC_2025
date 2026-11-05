//! TetrIC processor: a model of the 5 stage pipeline in rtl/processor/.
//!
//! Every pipeline register of processor.v is modelled, and one call of
//! [`Cpu::step`] is one clock edge on which the pipeline advances (imem_ack
//! high). Stall cycles freeze the whole pipeline in the RTL and do not change
//! what it computes, so they are only counted (by the caller), not modelled
//! here.
//!
//! Because the pipeline itself is modelled, all the quirks of the hardware
//! come out as on the real chip, without special cases:
//!   * 3 delay slots after branches / jr / jalr (resolved in MEM), 1 after
//!     j / jal (resolved in ID), jal links to jal + 1,
//!   * forwarding at distance 1 (ALU result, so `lw` gives the address and
//!     `jal` gives 0) and 2, write-through register file at distance 3,
//!   * `sw` data is not forwarded,
//!   * the unsigned BGE/BGT compare, SLT as the sign of A - B, the
//!     ones-extended ANDI immediate, shifts of rs (not rt) by the immediate.

/// Control signals of one instruction (ctrl.v).
#[derive(Clone, Copy, Default, Debug, PartialEq, Eq)]
pub struct Ctrl {
    /// j / jal: next PC from the ID stage
    pub ife: bool,
    /// immediate extension: 00 sign, 10 ones, else zero
    pub id: u8,
    /// [7:6] destination (00 rt, 01 rd, 1x $31), [5] immediate operand, [4:0] ALU op
    pub ex: u8,
    /// [4:2] branch kind, [1] load, [0] store
    pub mem: u8,
    /// [2:1] WB data (00 ALU, 01 load, 10 PC + 1), [0] register write
    pub wb: u8,
}

/// Decode, exactly as ctrl.v (including the defaults for unknown codes).
pub fn decode(instr: u32) -> Ctrl {
    let opcode = instr >> 26;
    let func = instr & 0x3f;
    let ife = opcode == 0b000010 || opcode == 0b000011;

    // function field (opcode 0)
    let (mut f_id, mut f_ex, mut f_mem, mut f_wb) = (0u8, 0b0110_1000u8, 0u8, 0b001u8);
    match func {
        0b000000 => f_ex = 0b0110_1000, // nop, sll
        0b100001 => f_ex = 0b0101_0001, // addu
        0b100100 => f_ex = 0b0101_0100, // and
        0b100000 => f_ex = 0b0101_0000, // add
        0b100111 => f_ex = 0b0101_0111, // nor
        0b100101 => f_ex = 0b0101_0101, // or
        0b000100 => f_ex = 0b0100_1100, // sllv
        0b000011 => {
            f_id = 0b11; // sra
            f_ex = 0b0110_1011;
        }
        0b000111 => f_ex = 0b0100_0111, // srav
        0b000010 => {
            f_id = 0b11; // srl
            f_ex = 0b0110_1010;
        }
        0b000110 => f_ex = 0b0100_1110, // srlv
        0b100010 => f_ex = 0b0101_0010, // sub
        0b100011 => f_ex = 0b0101_0011, // subu
        0b100110 => f_ex = 0b0101_0110, // xor
        0b101010 => f_ex = 0b0101_1010, // slt
        0b101011 => f_ex = 0b0101_1011, // sltu
        0b001001 => {
            f_ex = 0b1000_0011; // jalr
            f_mem = 0b01100;
            f_wb = 0b101;
        }
        0b001000 => {
            f_ex = 0b0100_0011; // jr
            f_mem = 0b01100;
            f_wb = 0b000;
        }
        _ => {}
    }

    let (mut id, mut ex, mut mem, mut wb) = (0u8, 0b0011_0000u8, 0u8, 0u8);
    match opcode {
        0b000000 => {
            id = f_id;
            ex = f_ex;
            mem = f_mem;
            wb = f_wb;
        }
        0b001000 => {
            ex = 0b0011_0000; // addi
            wb = 1;
        }
        0b001001 => {
            id = 0b01; // addiu
            ex = 0b0011_0001;
            wb = 1;
        }
        0b001100 => {
            id = 0b10; // andi
            ex = 0b0011_0100;
            wb = 1;
        }
        0b001101 => {
            id = 0b11; // ori
            ex = 0b0011_0101;
            wb = 1;
        }
        0b001110 => {
            id = 0b11; // xori
            ex = 0b0011_0110;
            wb = 1;
        }
        0b001111 => {
            id = 0b11; // lui
            ex = 0b0010_1111;
            wb = 1;
        }
        0b001010 => {
            ex = 0b0011_1010; // slti
            wb = 1;
        }
        0b001011 => {
            id = 0b01; // sltiu
            ex = 0b0011_1011;
            wb = 1;
        }
        0b000100 => {
            ex = 0b0001_0010; // beq
            mem = 0b00100;
        }
        0b000001 => {
            ex = 0b0001_0010; // bge
            mem = 0b10100;
        }
        0b000111 => {
            ex = 0b0001_0010; // bgt
            mem = 0b11000;
        }
        0b000101 => {
            ex = 0b0001_0010; // bne
            mem = 0b01000;
        }
        0b000010 => {
            id = 0b01; // j
            ex = 0;
        }
        0b000011 => {
            id = 0b01; // jal
            ex = 0b1000_0000;
            wb = 0b101;
        }
        0b010000 => {
            ex = 0b0101_1100; // mfc0
            wb = 1;
        }
        0b010001 => {
            ex = 0b0101_1101; // mfc1
            wb = 1;
        }
        0b010010 => {
            ex = 0b0101_1110; // mfc2
            wb = 1;
        }
        0b010011 => {
            ex = 0b0101_1111; // mfc3
            wb = 1;
        }
        0b100011 => {
            id = 0b01; // lw
            ex = 0b0011_0000;
            mem = 0b00010;
            wb = 0b011;
        }
        0b101011 => {
            id = 0b01; // sw
            ex = 0b0011_0000;
            mem = 0b00001;
        }
        _ => {}
    }
    Ctrl {
        ife,
        id,
        ex,
        mem,
        wb,
    }
}

fn signext(imm: u32, ctrl: u8) -> u32 {
    match ctrl {
        0b00 => imm as u16 as i16 as i32 as u32,
        0b10 => 0xffff_0000 | imm,
        _ => imm,
    }
}

/// The ALU (alu.v): (result, n_zero, overflow). `mfc` gives the coprocessor
/// register for MFC0..3 (0..3).
#[inline]
pub fn alu(a: u32, b: u32, op: u8, mfc: &mut impl FnMut(u32) -> u32) -> (u32, bool, bool) {
    let mut overflow = false;
    let fix_sh = (b >> 6) & 31;
    let var_sh = a & 31;
    let result = match op {
        0b00011 => a,                             // jr, jalr
        0b00111 => ((b as i32) >> var_sh) as u32, // srav
        0b01000 => a << fix_sh,                   // sll (of rs)
        0b01010 => a >> fix_sh,                   // srl
        0b01011 => ((a as i32) >> fix_sh) as u32, // sra
        0b01100 => b << var_sh,                   // sllv
        0b01110 => b >> var_sh,                   // srlv (ctrl[0] = 0: logical)
        0b01111 => b << 16,                       // lui
        0b10000 | 0b10001 => a.wrapping_add(b),   // add, addu, lw, sw
        0b10010 => {
            // sub, branches: overflow = borrow of A - B
            overflow = a < b;
            a.wrapping_sub(b)
        }
        0b10011 => a.wrapping_sub(b), // subu
        0b10100 => a & b,
        0b10101 => a | b,
        0b10110 => a ^ b,
        0b10111 => !(a | b),
        0b11010 => a.wrapping_sub(b) >> 31, // slt: sign of A - B
        0b11011 => (a < b) as u32,          // sltu: borrow
        0b11100 => mfc(0),
        0b11101 => mfc(1),
        0b11110 => mfc(2),
        0b11111 => {
            mfc(3); // mfc3: not implemented in the hardware, reads 0
            0
        }
        _ => 0,
    };
    (result, result != 0, overflow)
}

/// What the MEM stage asks of the memory in a step.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum MemOp {
    None,
    Load(u32),
    Store(u32, u32),
}

/// The processor's view of the system.
pub trait Bus {
    /// instruction word at word address `addr` (20 bits)
    fn fetch(&mut self, addr: u32) -> u32;
    /// data load, `addr` = processor address bits 23:0
    fn load(&mut self, addr: u32) -> u32;
    /// data store
    fn store(&mut self, addr: u32, data: u32);
    /// coprocessor register n (MFC0..3)
    fn mfc(&mut self, n: u32) -> u32;
}

#[derive(Clone, Default)]
pub struct Cpu {
    pub regs: [u32; 32],
    // IF
    pub pc: u32,
    // IF/ID
    pub id_pc1: u32,
    pub id_instr: u32,
    // ID/EX
    pub ex_pc1: u32,
    pub ex_data1: u32,
    pub ex_data2: u32,
    pub ex_data3: u32,
    pub ex_r2: u8,
    pub ex_rd: u8,
    pub ex_ctrl: Ctrl,
    pub ex_sel1: u8,
    pub ex_sel2: u8,
    // EX/MEM
    pub mem_pc7: u32,
    pub mem_pc1: u32,
    pub mem_res: u32,
    pub mem_data2: u32,
    pub mem_nzero: bool,
    pub mem_ovf: bool,
    pub mem_ctrl: u8,
    pub mem_wb: u8,
    pub mem_regdest: u8,
    // MEM/WB
    pub wb_pc1: u32,
    pub wb_data4: u32,
    pub wb_res: u32,
    pub wb_wb: u8,
    pub wb_regdest: u8,
    /// last word on dmem_data_in (only used by loads)
    pub dmem_in: u32,
}

/// Everything a pipeline step did that the outside may want to know.
#[derive(Clone, Copy, Debug)]
pub struct StepInfo {
    /// address of the instruction fetched in this step (IF)
    pub fetch_addr: u32,
    /// register written in WB (rd != 0)
    pub reg_write: Option<(u8, u32)>,
    /// MFC result computed in EX
    pub mfc: Option<u32>,
    /// memory access of the MEM stage
    pub mem: MemOp,
}

impl Cpu {
    pub fn new() -> Self {
        Self::default()
    }

    /// Memory access the MEM stage will do in the next step (for the stall
    /// model: it is known before the step).
    pub fn pending_mem(&self) -> MemOp {
        let addr = self.mem_res & 0xff_ffff;
        if self.mem_ctrl & 1 != 0 {
            MemOp::Store(addr, self.mem_data2)
        } else if self.mem_ctrl & 2 != 0 {
            MemOp::Load(addr)
        } else {
            MemOp::None
        }
    }

    /// One pipeline step (one clock edge on which the pipeline advances).
    #[inline]
    pub fn step<B: Bus>(&mut self, bus: &mut B) -> StepInfo {
        // ---- WB ----
        let wb_data = match (self.wb_wb >> 1) & 3 {
            0 => self.wb_res,
            1 => self.wb_data4,
            2 => self.wb_pc1,
            _ => 0,
        };
        let wb_we = self.wb_wb & 1 != 0;
        let wb_rd = self.wb_regdest;

        // ---- ID ----
        let instr = self.id_instr;
        let c = decode(instr);
        let r1 = ((instr >> 21) & 31) as u8;
        let r2 = ((instr >> 16) & 31) as u8;
        let rd = ((instr >> 11) & 31) as u8;
        let read = |r: u8| -> u32 {
            if r == 0 {
                0
            } else if wb_we && wb_rd == r {
                wb_data // write-through
            } else {
                self.regs[r as usize]
            }
        };
        let id_data1 = read(r1);
        let id_data2 = read(r2);
        let id_data3 = signext(instr & 0xffff, c.id);

        // forwarding unit (selects for the next EX)
        let ex_regdest = match self.ex_ctrl.ex >> 6 {
            0 => self.ex_r2,
            1 => self.ex_rd,
            _ => 31,
        };
        let mem_we = self.ex_ctrl.wb & 1 != 0; // instruction now in EX
        let wbs_we = self.mem_wb & 1 != 0; // instruction now in MEM
                                           // as fwunit.v
        #[allow(clippy::nonminimal_bool)]
        let fwsel = |r: u8| -> u8 {
            let is_mem = r == ex_regdest;
            let is_wb = r == self.mem_regdest;
            let mut s = 0;
            if mem_we && is_mem {
                s = 2;
            }
            if (wbs_we && is_wb && !is_mem) || (wbs_we && is_wb && is_mem && !mem_we) {
                s = 1;
            }
            s
        };
        let id_sel1 = fwsel(r1);
        let id_sel2 = fwsel(r2);

        // ---- EX ----
        let fw = |sel: u8, d: u32| -> u32 {
            match sel {
                0 => d,
                1 => wb_data,
                2 => self.mem_res,
                _ => 0,
            }
        };
        let alu0 = fw(self.ex_sel1, self.ex_data1);
        let pre1 = fw(self.ex_sel2, self.ex_data2);
        let alu1 = if self.ex_ctrl.ex & 0x20 != 0 {
            self.ex_data3
        } else {
            pre1
        };
        let op = self.ex_ctrl.ex & 31;
        let mut mfc_val = None;
        let (ex_res, ex_nzero, ex_ovf) = alu(alu0, alu1, op, &mut |n| {
            let v = bus.mfc(n);
            mfc_val = Some(if n == 3 { 0 } else { v });
            v
        });
        let ex_pc7 = self.ex_pc1.wrapping_add(self.ex_data3);

        // ---- MEM ----
        let (pcmux1, pcmux3) = match (self.mem_ctrl >> 2) & 7 {
            0b011 => (true, true),
            0b001 => (!self.mem_nzero, false),
            0b010 => (self.mem_nzero, false),
            0b101 => (!self.mem_nzero || !self.mem_ovf, false),
            0b110 => (self.mem_nzero && !self.mem_ovf, false),
            _ => (false, false),
        };
        let mem = self.pending_mem();
        match mem {
            MemOp::Load(a) => self.dmem_in = bus.load(a),
            MemOp::Store(a, d) => bus.store(a, d),
            MemOp::None => {}
        }

        // ---- IF ----
        let fetch_addr = self.pc;
        let if_instr = bus.fetch(fetch_addr & 0xf_ffff);
        let if_pc1 = self.pc.wrapping_add(1);
        let next_pc = if c.ife {
            instr & 0x03ff_ffff
        } else if pcmux1 {
            if pcmux3 {
                self.mem_res
            } else {
                self.mem_pc7
            }
        } else {
            if_pc1
        };

        // ---- clock edge ----
        let reg_write = if wb_we && wb_rd != 0 {
            self.regs[wb_rd as usize] = wb_data;
            Some((wb_rd, wb_data))
        } else {
            None
        };

        // MEM -> WB
        self.wb_pc1 = self.mem_pc1;
        self.wb_data4 = self.dmem_in;
        self.wb_res = self.mem_res;
        self.wb_wb = self.mem_wb;
        self.wb_regdest = self.mem_regdest;
        // EX -> MEM
        self.mem_pc7 = ex_pc7;
        self.mem_pc1 = self.ex_pc1;
        self.mem_res = ex_res;
        self.mem_data2 = self.ex_data2; // sw data: not forwarded
        self.mem_nzero = ex_nzero;
        self.mem_ovf = ex_ovf;
        self.mem_ctrl = self.ex_ctrl.mem;
        self.mem_wb = self.ex_ctrl.wb;
        self.mem_regdest = ex_regdest;
        // ID -> EX
        self.ex_pc1 = self.id_pc1;
        self.ex_data1 = id_data1;
        self.ex_data2 = id_data2;
        self.ex_data3 = id_data3;
        self.ex_r2 = r2;
        self.ex_rd = rd;
        self.ex_ctrl = c;
        self.ex_sel1 = id_sel1;
        self.ex_sel2 = id_sel2;
        // IF -> ID
        self.id_pc1 = if_pc1;
        self.id_instr = if_instr;
        self.pc = next_pc;

        StepInfo {
            fetch_addr,
            reg_write,
            mfc: mfc_val,
            mem,
        }
    }
}
