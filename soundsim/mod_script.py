#!/usr/bin/env python3
"""Write the register script of the MOD test (InitSound + StartMusic(1) of
game_code) with the addresses from the assembler listing.

  mod_script.py <TetrIC.2 listing> <out script>
"""
import re
import sys

addr = {}
for line in open(sys.argv[1], encoding="latin-1"):
    m = re.match(r"(0x[0-9a-f]+)\s+;\s*\d+\s+\.FILE\s+(\S+)", line)
    if m:
        addr[m.group(2)] = int(m.group(1), 16)
lut = addr["TLib/Data/Lut.raw"]
song = addr["Data/mod_gamemusic.raw"]
with open(sys.argv[2], "w") as f:
    f.write("# InitSound + StartMusic(1): Lut %#x, TetricMod %#x\n" % (lut, song))
    f.write("10 1 %x\n" % (lut - 108))        # SFX_LUT
    f.write("10 28 7b0c0\n")                  # SFX_WAITCLK = 504000
    f.write("10 37 77775555\n")               # SFX_MASTERVOL
    f.write("10 3 0\n")                       # stop
    f.write("10 0 %x\n" % song)               # SFX_OFFSET
    f.write("10 3 5\n")                       # loop | play
