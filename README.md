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

### Install needed apt packages

```
sudo apt install iverilog
```

## Build and execute iverilog simulation

```
make -C iverilog all run
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

```
make -C tangnano20k program-sram-top
```

### Program FPGA (FLASH)

```
make -C tangnano20k program-flash-top
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

# BUGS found

 * The program counter is word based
 * BGT / BGE only handles unsigned values
