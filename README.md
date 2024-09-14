# TetrIC 2025

A future port of TetrIC to the Tang Nano 20k

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
pip3 install digsim-logic-simulator ruff pytest
```

## Module Testing

```
pytest
```

## Code Formatting

```
ruff check
ruff format
```

## Done

### Processor
```
datamux.vhd      ==> src/top/processor/mux4/mux4.v
fwmux1           ==> src/top/processor/mux4/mux4.v
fwmux2           ==> src/top/processor/mux4/mux4.v
imem             ==> src/top/processor/instr_or_nop/instr_or_nop.v
immux.vhd        ==> src/top/processor/mux2/mux2.v
pcmux1.vhd       ==> src/top/processor/mux2/mux2.v
pcmux2.vhd       ==> src/top/processor/mux2/mux2.v
pcmux3.vhd       ==> src/top/processor/mux2/mux2.v
pipereg.vhd      ==> src/top/processor/pipereg/pipereg.v
reg.vhd          ==> src/top/processor/regbank/regbank.v
```

## Started

### Processor
```
alu.vhd          ==> src/top/processor/alu/alu.v
```

## Todo

### Top
```
arb
memctrl
```

### Processor
```
branchlogic
ctrl
ex_dmem
fwunit
mem_dmem
noplogic
pcadd1
pcadd2
regdestmux
s_unit
signandshift
signext
```


### Sound

```
mixer
mult
resample
sampleoutput
mainunit
ljudxbox
```

### Display
```
gfxbox
```
