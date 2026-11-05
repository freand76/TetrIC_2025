#!/bin/bash
# Compare two builds of a program (e.g. before / after an assembler or nop
# change) in the emulator with ideal timing: instructions take no time and
# every game frame is one video frame, so builds that differ only in speed
# must show the same frames. A behaviour change (e.g. a missing hazard nop)
# makes the frames differ.
#
#   compare_builds.sh old.bin new.bin [seconds]     (default 20 s of game)
#
# The gamepad script starts a game and plays a few moves.
set -e
cd "$(dirname "$0")"
OLD=$(realpath "$1")
NEW=$(realpath "$2")
SEC=${3:-20}
cargo build --release -q
OUT=out/compare
mkdir -p $OUT
PRESS="--press start:2000:2300 --press cross:2700:2900 --press left:5000:5300 --press down:7000:7200
       --press cross:9000:9200 --press right:11000:11500 --press down:13000:13200"
for b in old new; do
    f=$OLD; [ $b = new ] && f=$NEW
    target/release/tetric_emu --flash "$f" --headless --seconds "$SEC" --ideal-timing $PRESS \
        --swaplog $OUT/$b.txt --screenshot $OUT/$b.ppm > /dev/null
done
N=$(wc -l < $OUT/old.txt)
if cmp -s <(cut -d' ' -f2- $OUT/old.txt) <(cut -d' ' -f2- $OUT/new.txt); then
    echo "PASS: $N frames equal"
else
    echo "FAIL: frames differ"
    cmp <(cut -d' ' -f2- $OUT/old.txt) <(cut -d' ' -f2- $OUT/new.txt) | sed 's/.*line/  first difference at frame/'
    exit 1
fi
