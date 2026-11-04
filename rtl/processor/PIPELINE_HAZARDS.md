# TetrIC processor: pipeline hazards and required NOPs

The processor (`processor.v`) is a 5-stage pipeline (IF, ID, EX, MEM, WB). It has
**no hazard detection and no pipeline flush**. Every fetched instruction is
executed, and some register dependencies are not forwarded. The program (or the
assembler) must insert NOPs, or other useful independent instructions,
as listed below.

"Distance" *d* means how many instructions after the producer the consumer is:
*d = 1* is the next instruction, and *d = 1 + number of NOPs in between*.

## Summary table

### Control flow: delay slots

These are always executed, whether a branch is taken or not.

| Instruction | Delay slots | NOPs after it | Notes |
|---|---|---|---|
| `beq bne bge bgt beqz bnez bgez bgtz b` | **3** | **3** | Resolved in MEM. Target = branch + 1 + offset. |
| `jr`, `jalr` | **3** | **3** | Resolved in MEM. |
| `j` | **1** | **1** | Resolved in ID. |
| `jal` | **1** | **1** | Resolved in ID. **Return address = `jal` + 1**, so the delay-slot instruction executes a second time after the return. Keep it a NOP, or something that is harmless to run twice. |

Do **not** put a branch or jump in any delay slot (see [Control flow](#control-flow)).

### Register dependencies

| Producer → consumer | d=1 | d=2 | d≥3 | NOPs needed |
|---|---|---|---|---|
| ALU result → ALU operand, branch operand, `jr` target, `lw`/`sw` base address | ✅ | ✅ | ✅ | 0 |
| `lw` result → same uses as above | ❌¹ | ✅ | ✅ | **1 NOP** after `lw` |
| ALU result or `lw` result → **`sw` data register** (`rt`) | ❌ | ❌ | ✅ | **2 NOPs** between producer and `sw` |
| `jal`/`jalr` → `$ra` (`$31`) | ❌² | ✅ | ✅ | Do not read `$ra` in the delay slot |
| `mfc0..3` → ALU operand | ✅ | ✅ | ✅ | 0 |

1. `lw` at d = 1 forwards the **address** instead of the loaded data.
2. In the `jal` delay slot, `$ra` reads as **0** (the ALU result of `jal`).

d = 1 and 2 are forwarded. d = 3 is covered by the register file write-through, as in the original VHDL design (`reg.vhd`).

### Practical rules (safe and simple)

* After `beq/bne/bge/bgt/beqz/bnez/bgez/bgtz/b/jr/jalr`: 3 NOPs.
* After `j`/`jal`: 1 NOP. After `jal`, the NOP also runs again on return. `prg.s` uses 3, which also works.
* After `lw`: 1 NOP before using the loaded register.
* Before `sw`: the stored register must be written ≥ 3 instructions earlier, so 2 NOPs. The old TetrIC `_SW` macro (`nop; nop; sw`) does exactly this.
* No branches or jumps in delay slots.

## Assembler check

`tools/abnasm.py` checks these rules after assembling. The default is that a broken rule is an **error**:

```
prg.s:83: error: $8 written by LW $08 0x0400 $00 (line 82) at distance 1: lw result is not available at distance 1 (1 nop needed)
prg.s:165: error: $8 written by ADDI $08 $00 0x0005 (line 163) at distance 2: sw data register is not forwarded, needs distance >= 3
prg.s:587: error: J in delay slot 2 of BEQ $00 $00 0x0007 (line 585)
prg.s: 3 pipeline hazard error(s), no prg.bin written (...)
```

* **Execution order, not source order.** The distances are counted along every possible execution path:
  * delay slots;
  * taken and not-taken branches;
  * `j`/`jal` targets;
  * `jr` returning to every `jal`+1.

  So hazards across a branch, into a subroutine or out of one are found too. For example, an `lw` in the last delay slot of a branch, used at the branch target, is distance 1.
* **Not covered:** `jr` to computed addresses other than `jal` return points.
* **Delay slots:** a branch or jump in a delay slot is an error. A non-NOP `jal` delay slot is a warning, because it is executed again after the return.
* **Options:** `--hazards=warn` reports violations without failing, and `--hazards=off` disables the check.

### NOP removal proposals

`--suggest-nops` lists the NOPs that can be removed without breaking any rule. `--remove-nops OUT.s` also writes a copy of the source without them:

```
$ python3 tools/abnasm.py --suggest-nops prg.s
prg.s:63-65: remove 2 of 3 nops (keep 1)   after JAL 0x000000e3 (line 62), before LUI $09 0x0123 (line 66)
prg.s:152-154: remove 3 of 3 nops (keep 0)   at label PRINT_CHAR, before MOV $26 $31 (line 155)
prg.s:175-181: remove 7 of 7 nops (keep 0)   after LW $10 0x0000 $01 (line 174), before ADDI $01 $01 0x0001 (line 182)
prg.s:278-284: remove 5 of 7 nops (keep 2)   after LW $03 0x0000 $09 (line 277), before SW $03 0x0000 $10 (line 285)
...
prg.s: 78 of 135 nops can be removed (52 nops are in delay slots and are kept; 265 instructions -> 187)
```

* **How it works:** each NOP is removed in turn, and the full hazard check is run again on the new layout. That means shifted addresses, moved branch targets and new execution paths. A removal is kept only if there are no errors and no new warnings. The final set is therefore checked as a whole.
* **Delay-slot NOPs are never proposed.** Removing one moves the next instruction into the slot, which then runs whether the branch is taken or not and changes what the program does. Filling delay slots with useful instructions is a manual optimisation.
* **Macro NOPs:** `--remove-nops` only deletes source lines that contain nothing but a `nop`. NOPs generated inside macros are reported but left in place.
* **Timing:** removing NOPs changes timing, which matters for code that relies on cycle counts.
* **Verified on `prg.s`** (before the register file write-through, with the stricter rules of that time):
  * After `--remove-nops`, the program assembled with no hazards, and printed exactly the same UART output in the full CPU + SDRAM simulation (`sim/system/`).

## Why (RTL details)

### Control flow

* **Branches** compare in EX (`alu` SUB → `n_zero` / `overflow`) and are decided in MEM by `branchlogic`. `pcmux1` then selects `pcmux3` = `s_mem_pc7`, the target computed in EX as `pc+1+imm`. The three instructions fetched while the branch was in ID, EX and MEM have already entered the pipeline, and nothing flushes them. Hence 3 delay slots.
* **`jr`/`jalr`** use the same path, with `pcmux3` selecting `s_mem_res` (rs, passed through the ALU). Hence 3 delay slots.
* **`j`/`jal`** are decoded in ID (`ctrl.ife_ctrl`), and `pcmux2` selects the 26-bit target from `s_id_instr`. Only the instruction already in IF is executed: 1 delay slot.
* **`jal`/`jalr` link value** is `pc1` of the jump itself, i.e. jump address + 1 (the delay slot). Writing goes through `datamux` input C in WB. `jalr` always links to `$31`, whatever `rd` says.
* **Jumps or branches in delay slots.** `pcmux2` (j/jal in ID) has priority over `pcmux1` (branch/jr in MEM).
  * A `j`/`jal` in the 2nd delay slot of a taken branch therefore **overrides the branch**. The branch is lost, which was verified in simulation.
  * Other combinations give hard-to-follow fetch sequences.

### Data hazards

* **Forwarding unit** (`fwunit`): during ID it compares the source registers with the destination of the instruction in EX (d=1) and in MEM (d=2). In EX, `fwmux1/2` then select `s_mem_res` (d=1) or `s_wb_data` (d=2).
  * The d=1 path forwards the **ALU result**. For `lw` that is the address, and for `jal` it is 0.
  * The d=2 path forwards the final WB value, so load data and link address are both correct there.
* **d = 3.** The producer is in WB while the consumer is in ID. `regbank_sram` writes its RAM16SDP4 cells on the clock edge, but a read of the register that is written in the same cycle returns `w_data` directly (write-through, as `reg.vhd` of the original VHDL). Without it, the ID/EX register latched the old value, unless a pipeline stall happened to let the write land first, which made d = 3 an intermittent bug.
* **`sw` data** (`rt`) goes to memory through `exmem_data2 <= s_ex_data2`, the value read in ID, **without forwarding**. Only the base address (`rs`) is forwarded. With the write-through, d = 3 reads the right value.

## How this was verified

1. **Testbench:** a standalone testbench drove `processor.v` with:
   * an ideal instruction memory;
   * a data memory with the same stall behaviour as `memory_arbiter`;
   * optional random `imem_ack` stalls, to imitate icache misses.
2. **Test program:** each case uses a "stale" value (100), so stale reads are recognisable (101 instead of 6). The program measures:
   * every producer/consumer pair at d = 1..5;
   * the delay-slot counts, by counting executed increments;
   * the `jal` return address;
   * `$ra` read in the `jal` delay slot;
   * a `j` in the 2nd slot of a taken branch.
3. **Results** (with the write-through):
   * Without stalls, the results match the table exactly.
   * With 40 % random stalls (4 seeds), every result was identical to the run without stalls.
   * Before the write-through, all d = 3 cases (and `sw` data at d = 3) failed without stalls, and passed or failed randomly with stalls.
4. **Assembler check:** on the test program it reports exactly the cases that fail in simulation, and nothing else.

## Possible hardware improvements

These are not implemented.

* **Forward `sw` data:** use the forwarded `s_ex_pre_alu1` instead of `s_ex_data2` for `exmem_data2`. `sw` data then only needs the `lw` → use NOP.
* **Load-use:** a 1-cycle interlock (stall ID/IF when EX is a `lw` and its destination is used) would remove the last data NOP.
