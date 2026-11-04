#!/usr/bin/env python3
"""Reference model of the sound unit (rtl/sound/sound.v, sound_seq.v).

Replays the register writes logged by sim/system/tb_system.v / sim/sound/tb_sound.v
(+audio=<file>) on the program image and compares every 48 kHz output
sample with the simulation. Sample words are fetched instantly here (the
hardware has 4..8 samples of buffer), so the output must match exactly as
long as there is no underrun.

The MOD sequencer is checked separately: the model plays the song from the
memory image at the logged sequencer events (E start / tick / stop) and the
channel writes it makes must equal the logged ones (C lines); the tick
intervals must follow WAITCLK. The mix replays the logged channel writes.

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

    def chan_write(self, c, kind, data):
        """START (1), VOL (2), END (3), LSTART (4), LEND (5), FREQ (6)"""
        ch = self.ch[c]
        if kind == 1:
            ch.faddr = data & MASK20
            ch.cur_v = ch.nxt_v = ch.playing = False
            ch.idx = ch.frac = 0
        elif kind == 2:
            ch.vol = data & 0x7F
        elif kind == 3:
            ch.fend = data & MASK20
            if ch.fend == 0:  # stop now
                ch.cur_v = ch.nxt_v = ch.playing = False
        elif kind == 4:
            ch.lstart = data & MASK20
        elif kind == 5:
            ch.lend = data & MASK20
        elif kind == 6:
            ch.freq = data & 0xFFFF
        self.fill(c)

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
        self.chan_write(4 + (reg & 3), reg >> 2, data)

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


def nclamp(n):
    return 108 if n < 108 else min(n, 907)


def vclamp(v):
    return 0 if v < 0 else min(v, 64)


def vslide(v, prm):
    return vclamp(v + (prm >> 4)) if prm >> 4 else vclamp(v - (prm & 15))


class ModChannel:
    def __init__(self):
        self.note = self.inst = self.fx = self.param = self.pspeed = 0
        self.slideto = self.sdir = self.vol = 0


class Seq:
    """sound_seq.v: returns the channel writes (ch, reg, data) per event"""

    R_START, R_VOL, R_END, R_LSTART, R_LEND, R_FREQ = 4, 8, 12, 16, 20, 24

    def __init__(self, mem):
        self.mem = mem
        self.offset = self.lut = self.status = 0
        self.waitclk = 504000
        self.playing = False
        self.c = [ModChannel() for _ in range(4)]
        self.speed, self.tickcount = 6, 1
        self.songpos = self.songlen = self.curpat = self.patrow = 0

    def rd(self, a):
        a &= MASK20
        return self.mem[a] if a < len(self.mem) else 0

    def reg_write(self, reg, data):
        if reg == 0:
            self.offset = data & MASK20
        elif reg == 1:
            self.lut = data & MASK20
        elif reg == 3:
            self.status = data & 7
        elif reg == 28:
            self.waitclk = data & MASK20

    def start(self):
        w = self.rd(self.offset + 124)
        self.songlen, self.curpat = (w >> 24) & 127, w & 127
        self.speed, self.tickcount = 6, 1
        self.songpos = self.patrow = 0
        self.playing = True

    def stop(self):
        self.playing = False
        return [(c, self.R_END, 0) for c in range(4)]

    def tick(self):
        if self.tickcount == 1:
            self.tickcount = self.speed
            return self.row()
        self.tickcount = (self.tickcount - 1) & 31
        out = []
        for n, c in enumerate(self.c):
            pitch = c.fx in (1, 2, 3, 5)
            vfx = c.fx in (5, 6, 10)
            if c.fx == 1:
                c.note = nclamp(c.note - c.pspeed)
            elif c.fx == 2:
                c.note = nclamp(c.note + c.pspeed)
            elif c.fx in (3, 5):
                if c.sdir:
                    t = c.note + c.pspeed
                    if t >= c.slideto:
                        c.note, c.fx = c.slideto, 0
                    else:
                        c.note = nclamp(t)
                else:
                    t = c.note - c.pspeed
                    if t <= c.slideto:
                        c.note, c.fx = c.slideto, 0
                    else:
                        c.note = nclamp(t)
            if vfx:
                c.vol = vslide(c.vol, c.param)
                out.append((n, self.R_VOL, c.vol))
            if pitch and c.note:
                out.append((n, self.R_FREQ, self.rd(self.lut + c.note) & 0xFFFF))
        return out

    def row(self):
        out = []
        brk = jump = False
        base = self.offset
        for n, c in enumerate(self.c):
            pat = self.rd(base + 157 + (self.curpat << 8) + (self.patrow << 2) + n)
            inst, note = pat >> 27, (pat >> 16) & 0x7FF
            fx, prm = (pat >> 8) & 255, pat & 255
            ei = inst if inst else c.inst
            porta = fx in (3, 5)
            hdr = ei != 0 and (inst != 0 or note != 0)
            trig = ei != 0 and note != 0 and not porta
            if hdr:
                h = [self.rd(base + (ei - 1) * 4 + k) for k in range(4)]
                h_start = (base + ((h[0] >> 2) & MASK20)) & MASK20
                h_vol, h_end = (h[1] >> 24) & 127, (base + ((h[1] >> 2) & MASK20)) & MASK20
                h_ls = (base + ((h[2] >> 2) & MASK20)) & MASK20
                h_le = (
                    0 if (h[3] >> 2) & 0xFFFFFF == 0 else (base + ((h[3] >> 2) & MASK20)) & MASK20
                )
            if note and not porta:
                c.note = note
            if inst:
                c.vol = h_vol
                c.inst = inst
            if fx in (1, 2):
                c.pspeed = prm
            elif fx == 3:
                if prm:
                    c.pspeed = prm
                if note:
                    c.slideto = note
                c.sdir = 1 if c.note < c.slideto else 0
            elif fx == 0x0B:
                if not jump:
                    self.patrow, jump, self.songpos = 0, True, prm & 127
            elif fx == 0x0C:
                c.vol = vclamp(prm & 127)
            elif fx == 0x0D:
                if not brk:
                    self.patrow, brk = prm & 63, True
                    if not jump:
                        self.songpos = (self.songpos + 1) & 127
            elif fx == 0x0E:
                hi, lo = prm >> 4, prm & 15
                if hi == 1:
                    c.note = nclamp(c.note - lo)
                elif hi == 2:
                    c.note = nclamp(c.note + lo)
                elif hi == 0xA:
                    c.vol = vclamp(c.vol + lo)
                elif hi == 0xB:
                    c.vol = vclamp(c.vol - lo)
            elif fx == 0x0F and 0 < prm < 32:
                self.speed = prm
            c.fx, c.param = fx, prm
            if hdr:
                out += [(n, self.R_END, h_end), (n, self.R_LSTART, h_ls), (n, self.R_LEND, h_le)]
            if trig:
                out.append((n, self.R_START, h_start))
            out.append((n, self.R_VOL, c.vol))
            if c.note:
                out.append((n, self.R_FREQ, self.rd(self.lut + c.note) & 0xFFFF))
        # next row / song position
        if not jump and not brk and self.patrow != 63:
            self.patrow += 1
            return out
        if not jump and not brk:
            self.patrow = 0
            self.songpos = (self.songpos + 1) & 127
        if self.songpos >= self.songlen:
            if not self.status & 4:
                self.status &= ~1
                self.playing = False
                return out + self.stop()
            self.songpos = 0
        w = self.rd(base + 125 + (self.songpos >> 2))
        self.curpat = (w >> (8 * (self.songpos & 3))) & 127
        return out


def check_seq(events, mem):
    """the sequencer writes and tick timing; returns the number of errors"""
    seq = Seq(mem)
    expected, got = [], []
    ticks = []  # pass of each tick (None: song (re)started / stopped)
    paused = []  # paused samples before each tick
    pause_at, pause_n = None, 0
    errors = 0
    for e in events:
        if e[0] == "W":
            if e[3] == 3:
                # a write in pass k: the sample counter stops / runs from k + 1
                if e[4] & 2 and pause_at is None:
                    pause_at = e[1]
                elif not e[4] & 2 and pause_at is not None:
                    pause_n += e[1] - pause_at
                    pause_at = None
            seq.reg_write(e[3], e[4])
        elif e[0] == "C":
            got.append((e[3], e[4], e[5]))
        elif e[0] == "E":
            if e[1] == "start":
                seq.start()
                ticks.append(None)
                paused.append(0)
                pause_n = 0
            elif e[1] == "tick":
                ticks.append(e[2])
                paused.append(pause_n)
                pause_n = 0
                expected += seq.tick()
                if not seq.playing:  # song end: stop (no E stop for it here)
                    pass
            elif e[1] == "stop":
                if seq.playing:
                    expected += seq.stop()
                ticks.append(None)
                paused.append(0)
    # song end without loop logs E stop after the row writes; the model
    # already added the END writes there
    for n, (a, b) in enumerate(zip(expected, got)):
        if a != b:
            if errors < 10:
                print(
                    f"SEQ MISMATCH write {n}: sim ch {b[0]} reg {b[1]} data {b[2]}, "
                    f"ref ch {a[0]} reg {a[1]} data {a[2]}"
                )
            errors += 1
    if len(expected) != len(got):
        print(f"SEQ MISMATCH: {len(got)} writes in the simulation, {len(expected)} in the model")
        errors += 1
    # tick intervals: +525 per sample, a tick when WAITCLK is passed
    acc, last, n_ticks = 0, None, 0
    for t, p in zip(ticks, paused):
        if t is None:
            last = None
            continue
        if last is not None:
            t -= p
            n, a = 0, acc
            while True:
                n += 1
                a += 525
                if a >= seq.waitclk:
                    a -= seq.waitclk
                    break
            if t - last != n:
                if errors < 10:
                    print(f"SEQ TICK interval {t - last} samples, expected {n} (tick at {t})")
                errors += 1
            acc = a
            t += p
        else:
            acc = 0
        last = t
        n_ticks += 1
    print(f"sequencer: {n_ticks} ticks, {len(got)} channel writes")
    return errors


def sat16(v):
    return max(-32768, min(32767, v))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("log")
    ap.add_argument("bin")
    ap.add_argument("--wav")
    args = ap.parse_args()

    with open(args.bin, "rb") as file:
        data = file.read()
    data += b"\0" * (-len(data) % 4)
    mem = list(struct.unpack(f">{len(data) // 4}I", data))

    writes = {}  # (pass, phase) -> [("W", reg, data) / ("C", ch, reg, data)]
    sim = []
    events = []
    with open(args.log) as file:
        lines = file.readlines()
    for line in lines:
        f = line.split()
        if f[0] == "W":
            w = ("W", int(f[3]), int(f[4]))
            writes.setdefault((int(f[1]), int(f[2])), []).append(w)
            events.append(("W", int(f[1]), int(f[2]), int(f[3]), int(f[4])))
        elif f[0] == "C":
            w = ("C", int(f[3]), int(f[4]), int(f[5]))
            writes.setdefault((int(f[1]), int(f[2])), []).append(w)
            events.append(("C", int(f[1]), int(f[2]), int(f[3]), int(f[4]), int(f[5])))
        elif f[0] == "E":
            events.append(("E", f[1], int(f[2])))
        elif f[0] == "S":
            sim.append((int(f[1]), int(f[2])))

    snd = Sound(mem)
    ref = []

    def apply(ws):
        for w in ws:
            if w[0] == "W":
                snd.write(w[1], w[2])
            else:
                snd.chan_write(w[1], w[2] >> 2, w[3])

    # writes before pass 1 have pass 0 / phase 8; pass k ends with phase 8
    apply(writes.get((0, 8), []))
    for k in range(1, len(sim) + 1):
        acc = [0, 0]
        for c in range(8):
            s = snd.mix(c)
            acc[0 if c in (0, 3, 4, 7) else 1] += s
            apply(writes.get((k, c), []))
        ref.append((sat16(acc[0]), sat16(acc[1])))
        apply(writes.get((k, 8), []))

    errors = 0
    if any(e[0] in "CE" for e in events):
        errors += check_seq(events, mem)
    for n, (a, b) in enumerate(zip(sim, ref)):
        if a != b:
            if errors < 10:
                print(f"MISMATCH sample {n}: sim {a} ref {b}")
            errors += 1
    nz = sum(1 for l, r in sim if l or r)
    peak = max([max(abs(l), abs(r)) for l, r in sim] + [0])
    n_writes = sum(1 for v in writes.values() for w in v if w[0] == "W")
    print(
        f"{len(sim)} samples ({len(sim) / 48.0:.1f} ms), {nz} non-silent, peak {peak}, "
        f"{n_writes} register writes"
    )
    if snd.underruns:
        print(f"reference model underruns: {snd.underruns}")
    if args.wav:
        with wave.open(args.wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(48000)
            w.writeframes(b"".join(struct.pack("<hh", l, r) for l, r in sim))
    if errors or not sim or nz == 0:
        print(f"FAIL: {errors} mismatches")
        sys.exit(1)
    print("PASS: simulation matches the reference model bit exact")


if __name__ == "__main__":
    main()
