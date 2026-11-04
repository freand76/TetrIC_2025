#!/bin/bash
# Run the digsim pytest testbenches (src/**/test_*_tb.py) in a temporary uv
# environment with digsim 1.10.0; arguments go to pytest, e.g.
#   ./uv_run_pytest.sh src/top/processor/alu -k overflow
set -e
cd "$(dirname "$0")"
exec uv run --no-project --python 3.12 \
     --with 'digsim-logic-simulator==1.10.0' --with pytest \
     pytest "$@"
