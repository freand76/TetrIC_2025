#!/bin/env bash

VERILOG_FILES="src/top/processor/processor.v"
VERILOG_FILES+=" src/top/processor/pipereg/pipereg.v"
VERILOG_FILES+=" src/top/processor/instr_or_nop/instr_or_nop.v"
VERILOG_FILES+=" src/top/processor/mux2/mux2.v"

python3 -m digsim.synth synth -i $VERILOG_FILES -t processor -o src/top/processor/processor.json
