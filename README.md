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
