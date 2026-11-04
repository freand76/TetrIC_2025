#!/bin/bash
# Format and check the Python code with ruff (rules in ruff.toml, as in digsim)
set -e
cd "$(dirname "$0")"
echo " * Ruff Format..."
uv tool run ruff format
echo " * Ruff Check..."
uv tool run ruff check
