# TetrIC 2025

A port of TetrIC to the Tang Nano 20k

## Layout

| Folder | |
|---|---|
| `rtl/` | the system RTL (`rtl/top.v`: CPU, SDRAM, memory controller, video, sound, gamepad, flash reader) |
| `tangnano20k/` | the Tang Nano 20K top level, PLLs and pins of the system |
| `tangnano20k_test/` | FPGA test projects: `hdmi` (HDMI 4 kHz tone), `sdram`, `sdram_video`, `lcd_480x272`, `lcd_800x480` |
| `sim/models/` | simulation models: SPI flash, SDRAM, PS2 gamepad, Gowin primitives |
| `sim/system/` | full-system simulation (iverilog) |
| `sim/sound/` | sound unit simulation (Verilator) against `tools/sound_ref.py` |
| `sim/pytest/` | module testbenches (digsim) |
| `game_code/` | the TetrIC game |
| `test_code/` | test programs |
| `tools/` | assembler (`abnasm.py`), sound reference model |
| `old_vhdl/` | the original TetrIC VHDL, for reference |

## Setup

### APT Install python stuff

```
sudo apt install python3-venv python3-pip
```

### Create python virtual environment if needed...

```
python3 -m venv <my_special_venv_folder>
```

### Activate python virtual environment

```
source <my_special_venv_folder>/bin/activate
```

### Install needed python packages

```
pip3 install "digsim-logic-simulator==1.10.0" ruff pytest
```

### Install needed apt packages

```
sudo apt install iverilog verilator
```

## Simulation

Full system (iverilog): `run` (test_code/prg.s), `sound` (audio bit exact),
`fwd` (register forwarding), or `check` for all three:

```
make -C sim/system check
```

Sound unit alone (Verilator; `beat`, `mod`, `fxmod`):

```
make -C sim/sound fxmod
```

## Build and Flash code

###  Build

```
make -C test_code
```

###  Flash

```
make -C test_code program-flash-code
```

## Synth and Program Tang Nano 20k FPGA

### Synth

```
make -C tangnano20k synth
```

### Program FPGA (RAM)

The program targets don't build: build the bitstream (`make -C tangnano20k`) first.

```
make -C tangnano20k program-sram-top
```

### Program FPGA (FLASH)

```
make -C tangnano20k program-flash-top
```

A built bitstream is in `tangnano20k/bitstream/tetric.fs`, to flash it without building:

```
openFPGALoader -btangnano20k -f tangnano20k/bitstream/tetric.fs
make -C game_code program-flash
```

## Module Testing

The module testbenches (`sim/pytest/**/test_*_tb.py`, testing `rtl/`) use digsim 1.10.0. Run them in
a temporary uv environment (Python 3.12, digsim 1.10.0, pytest):

```
./uv_run_pytest.sh
```

or with the packages above installed: `pytest`. Arguments go to pytest, e.g.
`./uv_run_pytest.sh sim/pytest/processor/alu -k overflow`.

## Code Formatting

The Verilog files are formatted with the digsim 1.10.0 formatter, the Python code with ruff
(the rules of digsim, in `ruff.toml`):

```
./uv_format_verilog.sh          # or --check to only list the files that would change
./uv_ruff.sh                    # ruff format + ruff check
```

# BUGS found

 * The program counter is word based
 * BGT / BGE only handles unsigned values
 * Forwarding from WB was lost when the instruction in EX did not write a
   register but named the same one (fixed, `make -C sim/system fwd`)
