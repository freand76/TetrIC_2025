#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Write the register script of the MOD test (InitSound + StartMusic(1) of
game_code) with the addresses from the assembler listing.

  mod_script.py <TetrIC.2 listing> <out script>
"""

import re
import sys


addr = {}
with open(sys.argv[1], encoding="latin-1") as listing:
    for line in listing:
        m = re.match(r"(0x[0-9a-f]+)\s+;\s*\d+\s+\.FILE\s+(\S+)", line)
        if m:
            addr[m.group(2)] = int(m.group(1), 16)
lut = addr["TLib/Data/Lut.raw"]
song = addr["Data/mod_gamemusic.raw"]
with open(sys.argv[2], "w") as f:
    f.write(f"# InitSound + StartMusic(1): Lut {lut:#x}, TetricMod {song:#x}\n")
    f.write("10 1 %x\n" % (lut - 108))  # SFX_LUT
    f.write("10 28 7b0c0\n")  # SFX_WAITCLK = 504000
    f.write("10 37 77775555\n")  # SFX_MASTERVOL
    f.write("10 3 0\n")  # stop
    f.write(f"10 0 {song:x}\n")  # SFX_OFFSET
    f.write("10 3 5\n")  # loop | play
