#!/usr/bin/env bash
# TetrIC_2025 toolchain setup for a WSL2 Ubuntu distro (see wsl/README.md).
# Run INSIDE the distro (wsl -d tetric) as your normal user, not as root:
#   bash setup_tetric.sh
# Everything except apt packages and udev rules is installed under $HOME.
# Safe to run again: finished steps are skipped or redone.
set -euo pipefail

SRC="$HOME/src"            # where nextpnr / openFPGALoader sources go
PREFIX="$HOME/.local"      # install prefix for built tools
JOBS="$(nproc)"
mkdir -p "$SRC" "$PREFIX/bin"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- step 2
step "Step 2: apt packages (sudo will ask for your password)"
sudo apt-get update
sudo apt-get install -y \
  yosys iverilog verilator gtkwave git cmake build-essential pkg-config \
  python3-dev libboost-all-dev libeigen3-dev libftdi1-dev libhidapi-dev \
  libudev-dev zlib1g-dev libusb-1.0-0-dev \
  libasound2-dev libx11-dev libxkbcommon-dev curl ca-certificates \
  libasound2-plugins pulseaudio-utils alsa-utils

step "Audio: route ALSA to WSLg's PulseAudio server"
# WSL has no ALSA sound card; WSLg provides PulseAudio at /mnt/wslg/PulseServer.
if [ -f "$HOME/.asoundrc" ] && ! grep -q 'pulse' "$HOME/.asoundrc"; then
  cp "$HOME/.asoundrc" "$HOME/.asoundrc.bak"
  echo "existing ~/.asoundrc backed up to ~/.asoundrc.bak"
fi
if ! grep -q 'pcm.!default pulse' "$HOME/.asoundrc" 2>/dev/null; then
  cat > "$HOME/.asoundrc" <<'EOF'
pcm.!default pulse
ctl.!default pulse
EOF
fi
pactl info 2>/dev/null | grep -E 'Server String|Default Sink' \
  || echo "WARNING: PulseAudio not reachable; try 'wsl --shutdown' in PowerShell and reopen."

step "Cloning TetrIC_2025 into ~/TetrIC_2025"
if [ ! -d "$HOME/TetrIC_2025/.git" ]; then
  git clone https://github.com/freand76/TetrIC_2025 "$HOME/TetrIC_2025"
else
  echo "already cloned, skipping"
fi

# ---------------------------------------------------------------- step 3
step "Step 3: uv"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi
# shellcheck disable=SC1091
[ -f "$PREFIX/bin/env" ] && . "$PREFIX/bin/env"
export PATH="$PREFIX/bin:$PATH"

step "Step 3: Rust (rustup)"
if ! command -v cargo >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi
# shellcheck disable=SC1091
. "$HOME/.cargo/env"

step "Step 3: Apicula 0.35"
uv tool install --force apycula==0.35
APYCULA_PY="$(uv tool dir)/apycula/bin/python"
"$APYCULA_PY" -c "import apycula; print('apycula OK')"

# ---------------------------------------------------------------- step 4
step "Step 4: nextpnr-himbaechel (Gowin GW2A-18C)"
if [ ! -d "$SRC/nextpnr/.git" ]; then
  git clone --recursive https://github.com/YosysHQ/nextpnr "$SRC/nextpnr"
fi
cmake -S "$SRC/nextpnr" -B "$SRC/nextpnr/build" \
  -DARCH=himbaechel -DHIMBAECHEL_UARCH=gowin \
  -DHIMBAECHEL_GOWIN_DEVICES=GW2A-18C \
  -DPython3_EXECUTABLE="$APYCULA_PY" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$SRC/nextpnr/build" -j"$JOBS"
cmake --install "$SRC/nextpnr/build"

step "Step 4: openFPGALoader"
if [ ! -d "$SRC/openFPGALoader/.git" ]; then
  git clone https://github.com/trabucayre/openFPGALoader "$SRC/openFPGALoader"
fi
cmake -S "$SRC/openFPGALoader" -B "$SRC/openFPGALoader/build" \
  -DCMAKE_INSTALL_PREFIX="$PREFIX"
cmake --build "$SRC/openFPGALoader/build" -j"$JOBS"
cmake --install "$SRC/openFPGALoader/build"

step "Step 4: udev rules for the board"
sudo cp "$SRC/openFPGALoader/99-openfpgaloader.rules" /etc/udev/rules.d/
sudo udevadm control --reload-rules 2>/dev/null || true
sudo udevadm trigger 2>/dev/null || true
sudo usermod -aG plugdev "$USER"

# ---------------------------------------------------------------- check
step "Versions"
yosys -V | head -1
nextpnr-himbaechel --version 2>&1 | head -1
gowin_pack -h >/dev/null 2>&1 && echo "gowin_pack OK"
openFPGALoader --Version 2>&1 | head -1
iverilog -V 2>&1 | head -1
verilator --version
cargo --version
uv --version

echo
echo "Done. Close and reopen the terminal (or run: exec \$SHELL -l) so PATH and group changes apply."
