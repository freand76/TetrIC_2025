#!/usr/bin/env python3
"""Reference model of the sound unit (src/top/sound/sound.v).

Replays the register writes logged by iverilog_top.v (+audio=<file>) on the
program image and compares every 48 kHz output sample with the simulation.
Sample words are fetched instantly here (the hardware has 4..8 samples of
buffer), so the output must match exactly as long as there is no underrun.

  sound_ref.py <audio log> <program .bin> [--wav out.wav]
"""
import argparse
import struct
import sys
import wave

MASK20 = 0xFFFFF


class Channel:
    def __init__(self):
        self.faddr = self.fend = self.lstart = self.lend = 0
        self.freq = self.vol = 0
        self.mvol = 7
        self.cur = self.nxt = 0
        self.cur_v = self.nxt_v = False
        self.idx = self.frac = 0
        self.playing = False


class Sound:
    def __init__(self, mem):
        self.mem = mem
        self.ch = [Channel() for _ in range(8)]
        self.chan_on = 0xFF
        self.underruns = 0

    def word(self, addr):
        return self.mem[addr] if addr < len(self.mem) else 0

    def fill(self, c):
        ch = self.ch[c]
        while ch.faddr < ch.fend and not (ch.cur_v and ch.nxt_v):
            w = self.word(ch.faddr)
            if not ch.cur_v:
                ch.cur, ch.cur_v = w, True
            else:
                ch.nxt, ch.nxt_v = w, True
            nf = (ch.faddr + 1) & MASK20
            if ch.lend != 0 and nf >= ch.lend:
                nf = ch.lstart
            ch.faddr = nf

    def write(self, reg, data):
        if reg == 2:
            self.chan_on = data & 0xFF
            return
        if reg == 37:
            for c, sh in zip((4, 5, 6, 7, 0, 1, 2, 3), (28, 24, 20, 16, 12, 8, 4, 0)):
                self.ch[c].mvol = (data >> sh) & 7
            return
        if not 4 <= reg <= 27:
            return
        c = 4 + (reg & 3)
        ch = self.ch[c]
        kind = reg >> 2
        if kind == 1:
            ch.faddr = data & MASK20
            ch.cur_v = ch.nxt_v = ch.playing = False
            ch.idx = ch.frac = 0
        elif kind == 2:
            ch.vol = data & 0x7F
        elif kind == 3:
            ch.fend = data & MASK20
        elif kind == 4:
            ch.lstart = data & MASK20
        elif kind == 5:
            ch.lend = data & MASK20
        elif kind == 6:
            ch.freq = data & 0xFFFF
        self.fill(c)

    def mix(self, c):
        """One channel of a mix pass, returns its sample."""
        ch = self.ch[c]
        sample = 0
        more = ch.faddr < ch.fend
        if not ch.playing:
            if more or ch.cur_v:
                ch.playing = True
        elif ch.cur_v:
            b = (ch.cur >> (24 - 8 * ch.idx)) & 0xFF
            b = b - 256 if b & 0x80 else b
            v = min(ch.vol, 64)
            eff = 0 if ch.mvol == 0 else v >> (7 - ch.mvol)
            if (self.chan_on >> (7 - c)) & 1:
                sample = b * eff
            inc = (ch.freq * 22370) >> 14
            pos = ch.frac + inc
            ch.frac = pos & 0xFFFF
            ni = ch.idx + (pos >> 16)
            if ni >= 4:
                ch.idx = ni - 4
                if ch.nxt_v:
                    ch.cur, ch.nxt_v = ch.nxt, False
                else:
                    ch.cur_v = False
                self.fill(c)
            else:
                ch.idx = ni
        elif more or ch.nxt_v:
            self.underruns += 1
        else:
            ch.playing = False
        return sample


def sat16(v):
    return max(-32768, min(32767, v))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("bin")
    ap.add_argument("--wav")
    args = ap.parse_args()

    data = open(args.bin, "rb").read()
    data += b"\0" * (-len(data) % 4)
    mem = list(struct.unpack(">%dI" % (len(data) // 4), data))

    writes = {}      # (pass, phase) -> [(reg, data)]
    sim = []
    for line in open(args.log):
        f = line.split()
        if f[0] == "W":
            writes.setdefault((int(f[1]), int(f[2])), []).append((int(f[3]), int(f[4])))
        elif f[0] == "S":
            sim.append((int(f[1]), int(f[2])))

    snd = Sound(mem)
    ref = []
    # writes before pass 1 have pass 0 / phase 8; pass k ends with phase 8
    for w in writes.get((0, 8), []):
        snd.write(*w)
    for k in range(1, len(sim) + 1):
        acc = [0, 0]
        for c in range(8):
            s = snd.mix(c)
            acc[0 if c in (0, 3, 4, 7) else 1] += s
            for w in writes.get((k, c), []):
                snd.write(*w)
        ref.append((sat16(acc[0]), sat16(acc[1])))
        for w in writes.get((k, 8), []):
            snd.write(*w)

    errors = 0
    for n, (a, b) in enumerate(zip(sim, ref)):
        if a != b:
            if errors < 10:
                print("MISMATCH sample %d: sim %s ref %s" % (n, a, b))
            errors += 1
    nz = sum(1 for l, r in sim if l or r)
    peak = max([max(abs(l), abs(r)) for l, r in sim] + [0])
    print("%d samples (%.1f ms), %d non-silent, peak %d, %d register writes"
          % (len(sim), len(sim) / 48.0, nz, peak, sum(len(v) for v in writes.values())))
    if snd.underruns:
        print("reference model underruns: %d" % snd.underruns)
    if args.wav:
        w = wave.open(args.wav, "wb")
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes(b"".join(struct.pack("<hh", l, r) for l, r in sim))
        w.close()
    if errors or not sim or nz == 0:
        print("FAIL: %d mismatches" % errors)
        sys.exit(1)
    print("PASS: simulation matches the reference model bit exact")


if __name__ == "__main__":
    main()
