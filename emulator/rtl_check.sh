#!/bin/bash
# Cross check of the emulator against the RTL simulation (sim/system, Verilator).
#
#   rtl_check.sh [seconds]      (default 3.6 s of game, ~9 minutes of simulation)
#
# 1. The game (game_code/out/TetrIC.bin) runs in the RTL simulation with the
#    gamepad pressed (START at 2.0 s, CROSS at 2.7 s), with
#      +cputrace  every register write, store and MFC value,
#      +swaplog   a hash of every frame the game shows,
#      +audio     the sound unit's register writes and output samples.
# 2. The emulator runs the same program, with the MFC values (beam position,
#    frame counter, gamepad) replayed from the RTL trace, so both execute the
#    same instruction stream whatever the timing. Its trace must be equal
#    line for line, and the frame hashes must be equal.
# 3. The sound model is checked against the RTL audio log (tetric_check),
#    with the memory of the emulator run (equal to the RTL's, as the trace is).
# 4. The test programs (test_code) must print the same UART output.
set -e
cd "$(dirname "$0")"
EMU=$PWD
ROOT=$(cd .. && pwd)
SECONDS_RUN=${1:-3.6}
OUT=$EMU/out/rtl_check
NS=$(python3 -c "print(int($SECONDS_RUN * 1e9))")

cargo build --release
make -C "$ROOT/game_code"
make -C "$ROOT/test_code" prg.bin fwd_test.bin sound_test.bin
make -C "$ROOT/sim/system" out/vl/tb_system

mkdir -p "$OUT"
cp "$ROOT/game_code/out/TetrIC.bin" "$OUT/"
cd "$OUT"
xxd -p -c4 TetrIC.bin > game.hex
hexdump -v -e '4/1 "%02x " "\n"' TetrIC.bin > MEM.TXT

echo "== RTL simulation, $SECONDS_RUN s of game (Verilator, about 2.5 minutes per second)"
"$ROOT/sim/system/out/vl/tb_system" +preload=game.hex +stats +cputrace=rtl_raw.trace \
    +swaplog=rtl_swaps.txt +audio=audio.log \
    +press_ns=2000000000 +release_ns=2300000000 \
    +press2_ns=2700000000 +release2_ns=2900000000 +press2_cross \
    +run_ns=$NS > sim.log 2>&1
grep -E "^stats|^stalls|^swaplog|^sound" sim.log
sed 's/^M [0-9]* /M /' rtl_raw.trace > rtl.trace

echo "== emulator, MFC values replayed from the RTL trace"
"$EMU/target/release/tetric_emu" --flash TetrIC.bin --headless --seconds $((${SECONDS_RUN%.*} + 1)) \
    --mfc-replay rtl_raw.trace --trace emu.trace --swaplog emu_swaps.txt --dump-mem mem.bin --stats
N=$(wc -l < rtl.trace)
if head -n "$N" emu.trace | cmp -s - rtl.trace; then
    echo "PASS: CPU trace equal ($N lines: register writes, stores, MFC values)"
else
    echo "FAIL: CPU traces differ:"
    head -n "$N" emu.trace | cmp - rtl.trace || true
    exit 1
fi
NS_SWAPS=$(wc -l < rtl_swaps.txt)
if head -n "$NS_SWAPS" emu_swaps.txt | cmp -s - rtl_swaps.txt; then
    echo "PASS: $NS_SWAPS frames equal (image hashes and video registers)"
else
    echo "FAIL: frames differ:"
    diff <(head -n "$NS_SWAPS" emu_swaps.txt) rtl_swaps.txt | head
    exit 1
fi

echo "== sound"
# with the memory of the replay run (the game builds songs in memory)
"$EMU/target/release/tetric_check" audio audio.log mem.bin

echo "== test programs (UART output)"
make -s -C "$ROOT/sim/system" run fwd > /dev/null
for t in run:prg fwd:fwd_test; do
    dir=${t%%:*}
    prg=${t##*:}
    if diff <(sed -n '/^UART output/,/^SDRAM MODEL/p' "$ROOT/sim/system/out/$dir/sim.log" | sed '1d;$d' | sed '/^$/d') \
        <("$EMU/target/release/tetric_emu" --flash "$ROOT/test_code/$prg.bin" --headless --seconds 0.5 | sed '/^$/d') > /dev/null; then
        echo "PASS: $prg UART output equal"
    else
        echo "FAIL: $prg UART output differs"
        exit 1
    fi
done
echo "ALL PASS"
