#!/bin/bash
# Format the Verilog files of the project with the digsim 1.10.0 formatter
# (indentation and the whitespace around lines only).
#   ./uv_format_verilog.sh          format all tracked .v files in place
#   ./uv_format_verilog.sh --check  only list the files that would change
set -e
cd "$(dirname "$0")"
mode=--in-place
if [ "$1" = "--check" ]; then mode=--check; fi
git ls-files -z '*.v' | xargs -0 uv run --no-project --python 3.12 \
    --with 'digsim-logic-simulator==1.10.0' \
    python -m digsim.verilog format $mode
