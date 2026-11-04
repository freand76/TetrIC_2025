#!/usr/bin/env python3
"""Test song for the MOD sequencer: the effects the game music does not use.

  fxmod.py <game Lut.raw> <out prefix>

Writes <prefix>.hex (tb_sound +mem), <prefix>.bin (tools/sound_ref.py) and
<prefix>.txt (tb_sound +script). The song plays to its end without loop
(the sequencer stops it), is restarted with loop, stopped, restarted,
paused and resumed. Channel 4 plays an effect sample at the same time.
"""
import math
import struct
import sys

LUT = 0x100            # word address of the frequency table
SONG = 0x1000          # word address of the song
MEM_WORDS = 0x4000

mem = [0] * MEM_WORDS
lut = open(sys.argv[1], "rb").read()
for i in range(len(lut) // 4):
    mem[LUT + i] = struct.unpack(">I", lut[4 * i:4 * i + 4])[0]


def pack(samples):
    samples = list(samples) + [0] * (-len(samples) % 4)
    return [int.from_bytes(bytes(s & 255 for s in samples[i:i + 4]), "big")
            for i in range(0, len(samples), 4)]


# ---- samples (placed after the patterns) ----
NPAT = 3
data_word = 157 + NPAT * 256
saw = pack([((i * 5) % 200) - 100 for i in range(1600)])                 # one shot
sine = pack([int(90 * math.sin(2 * math.pi * i / 32)) for i in range(256)])  # looped
square = pack([60 if (i // 16) & 1 else -60 for i in range(512)])        # loop part

insts = []
for words, vol, loop in ((saw, 64, None), (sine, 48, (0, len(sine))),
                         (square, 40, (32, len(square)))):
    start = data_word
    for n, w in enumerate(words):
        mem[SONG + data_word + n] = w
    data_word += len(words)
    end = data_word
    ls, le = (start + loop[0], start + loop[1]) if loop else (0, 0)
    insts.append((start, end, vol, ls, le))
for i, (start, end, vol, ls, le) in enumerate(insts):
    mem[SONG + 4 * i + 0] = start << 2
    mem[SONG + 4 * i + 1] = (vol << 24) | (end << 2)
    mem[SONG + 4 * i + 2] = ls << 2
    mem[SONG + 4 * i + 3] = le << 2

# ---- song: order 0, 1, 2 ----
order = [0, 1, 2]
mem[SONG + 124] = (len(order) << 24) | (4 << 16) | order[0]
for i, p in enumerate(order):
    mem[SONG + 125 + i // 4] |= p << (8 * (i % 4))

pats = [[[(0, 0, 0, 0)] * 4 for _ in range(64)] for _ in range(NPAT)]


def note(p, r, c, inst=0, period=0, fx=0, prm=0):
    pats[p][r][c] = (inst, period, fx, prm)


# pattern 0
note(0, 0, 0, 1, 428, 0xF, 3)          # speed 3
note(0, 0, 1, 2, 300)
note(0, 0, 2, 1, 214, 0xC, 0x20)       # set volume
note(0, 0, 3, 3, 500, 0xA, 0x04)       # volume slide down
note(0, 1, 0, 0, 0, 1, 3)              # portamento up
note(0, 1, 1, 0, 0, 2, 2)              # portamento down
note(0, 1, 2, 0, 0, 0xA, 0x30)         # volume slide up
note(0, 1, 3, 0, 0, 6, 0x05)           # (vibrato +) volume slide
note(0, 2, 0, 0, 600, 3, 8)            # tone portamento up to 600
note(0, 2, 1, 2, 0)                    # instrument, no note: volume reset
note(0, 2, 3, 0, 0, 0xC, 70)           # set volume > 64
note(0, 3, 0, 0, 0, 3, 0)              # continue tone portamento
note(0, 3, 1, 0, 200)                  # note, last instrument
note(0, 3, 2, 0, 0, 0xE, 0x15)         # fine portamento up
note(0, 3, 3, 0, 0, 0xE, 0xA3)         # fine volume up
note(0, 4, 0, 0, 150, 5, 0x02)         # tone portamento down + volume slide
note(0, 4, 2, 0, 0, 0xE, 0x23)         # fine portamento down
note(0, 4, 3, 0, 0, 0xE, 0xB9)         # fine volume down
note(0, 5, 2, 0, 500, 3, 0x30)         # tone portamento (fast)
note(0, 5, 1, 0, 0, 0xF, 0)            # F00: ignored
note(0, 6, 0, 0, 0, 0xD, 4)            # break: next pattern, row 4
# pattern 1
note(1, 4, 0, 2, 320, 0xA, 0x0F)
note(1, 4, 1, 0, 0, 0xB, 2)            # jump to position 2 ...
note(1, 4, 2, 0, 0, 0xD, 10)           # ... row 10 (break in the same row)
# pattern 2
note(2, 10, 0, 3, 254, 0xF, 1)         # speed 1
note(2, 10, 3, 1, 160)
note(2, 20, 1, 2, 113)
note(2, 30, 2, 3, 907, 1, 40)          # portamento up to the limit
note(2, 40, 2, 0, 0, 2, 255)           # portamento down to the limit
note(2, 50, 0, 1, 0)                   # instrument only

for p in range(NPAT):
    for r in range(64):
        for c in range(4):
            inst, period, fx, prm = pats[p][r][c]
            mem[SONG + 157 + p * 256 + r * 4 + c] = (inst << 27) | (period << 16) | (fx << 8) | prm

# effect channel 4: the saw sample of instrument 1
fx_start, fx_end = SONG + insts[0][0], SONG + insts[0][1]

prefix = sys.argv[2]
with open(prefix + ".hex", "w") as f:
    for w in mem:
        f.write("%08x\n" % w)
with open(prefix + ".bin", "wb") as f:
    f.write(struct.pack(">%dI" % len(mem), *mem))

ms = 48   # samples per ms
script = [
    (10, 1, LUT - 108), (10, 28, 504000), (10, 37, 0x77777777),
    (10, 0, SONG), (10, 3, 1),                          # play, no loop
    (300 * ms, 24, 22050), (300 * ms, 4, fx_start), (300 * ms, 8, 40),
    (300 * ms, 12, fx_end),                             # effect on channel 4
    (1800 * ms, 3, 5),                                  # restart (ended at ~1.7 s), loop
    (2300 * ms, 3, 0),                                  # stop
    (2350 * ms, 3, 5),                                  # start
    (2600 * ms, 3, 7),                                  # pause
    (2700 * ms, 3, 5),                                  # resume
]
with open(prefix + ".txt", "w") as f:
    f.write("# fxmod.py: MOD sequencer effects test\n")
    for t, reg, data in script:
        f.write("%d %d %x\n" % (t, reg, data))
