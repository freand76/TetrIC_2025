//! The test programs of test_code/ (assembled with `make -C test_code`):
//! their UART output must be the one the RTL simulation prints
//! (sim/system: make run, make fwd).

use tetric::system::{program_from_flash, System, CLOCK_HZ};

fn run(name: &str) -> Option<String> {
    let path = format!("{}/../test_code/{name}", env!("CARGO_MANIFEST_DIR"));
    let bytes = std::fs::read(&path).ok()?;
    let mut sys = System::new(program_from_flash(&bytes), 98 * 800);
    sys.board.uart_echo = false;
    sys.board.audio_enabled = false;
    let end = sys.clk() + CLOCK_HZ / 2;
    sys.run_until(end);
    Some(String::from_utf8_lossy(&sys.board.uart_out).into_owned())
}

#[test]
fn forwarding() {
    let Some(out) = run("fwd_test.bin") else {
        eprintln!("test_code/fwd_test.bin not built, skipped");
        return;
    };
    assert_eq!(
        out.split_whitespace().collect::<Vec<_>>(),
        ["00000005", "00000005", "0000000A"]
    );
}

#[test]
fn prg() {
    let Some(out) = run("prg.bin") else {
        eprintln!("test_code/prg.bin not built, skipped");
        return;
    };
    let expect = "DEADBEEF\n01234567\n00000000\nHello World!\n(Next line)\n00000001\n00000002\nFA1337FA\nHello World!\n";
    assert_eq!(out.replace('\r', ""), expect);
}

#[test]
fn delay_slots_and_forwarding_quirks() {
    use tetric::cpu::{Bus, Cpu};
    struct Mem(Vec<u32>, Vec<(u32, u32)>);
    impl Bus for Mem {
        fn fetch(&mut self, a: u32) -> u32 {
            self.0.get(a as usize).copied().unwrap_or(0)
        }
        fn load(&mut self, a: u32) -> u32 {
            self.0.get(a as usize).copied().unwrap_or(0)
        }
        fn store(&mut self, a: u32, d: u32) {
            self.1.push((a, d));
        }
        fn mfc(&mut self, _: u32) -> u32 {
            0
        }
    }
    let addi =
        |rt: u32, rs: u32, imm: u32| (0b001000 << 26) | (rs << 21) | (rt << 16) | (imm & 0xffff);
    let sw =
        |rt: u32, rs: u32, imm: u32| (0b101011 << 26) | (rs << 21) | (rt << 16) | (imm & 0xffff);
    let beq =
        |rs: u32, rt: u32, off: u32| (0b000100 << 26) | (rs << 21) | (rt << 16) | (off & 0xffff);
    let prog = vec![
        addi(8, 0, 100), // 0: $8 = 100
        addi(8, 0, 5),   // 1: $8 = 5
        sw(8, 0, 0x200), // 2: sw data at distance 1 and 2 is not forwarded: the old 0
        beq(0, 0, 3),    // 3: taken, target 3 + 1 + 3 = 7
        addi(9, 9, 1),   // 4: delay slot 1
        addi(9, 9, 1),   // 5: delay slot 2
        addi(9, 9, 1),   // 6: delay slot 3
        sw(9, 0, 0x201), // 7: $9 = 3 at distance 1 not seen, 1 (distance 3, write-through) is
        0,
        0,
        sw(9, 0, 0x202), // 10: distance >= 3: 3 (all delay slots executed)
        0,
        0,
        0,
        0,
    ];
    let mut m = Mem(prog, Vec::new());
    let mut cpu = Cpu::new();
    for _ in 0..20 {
        cpu.step(&mut m);
    }
    assert_eq!(m.1, [(0x200, 0), (0x201, 1), (0x202, 3)]);
}
