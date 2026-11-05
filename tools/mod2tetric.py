#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Convert a ProTracker MOD (4 channels) to the TetrIC song format.

  mod2tetric.py song.mod song.raw [--wav preview.wav --seconds 30]

The output is the song as the MOD sequencer of the sound unit reads it
(rtl/sound/sound_seq.v), big endian 32-bit words, to include in the game
with ".file song.raw" and start with OFFSET = its word address:

  0..123    31 instruments, 4 words: [25:2] start, [30:24] volume and
            [23:2] end, [25:2] loop start, [25:2] loop end (byte offsets
            from the song start; end and loop end exclusive, loop end 0 =
            no loop)
  124       [30:24] song length, [23:16] 4, [6:0] first pattern
  125..156  pattern order, 4 per word, entry n in bits [8n+6:8n]
  157..     patterns: 64 rows x 4 channels, one word per note:
            [31:27] instrument, [26:16] Amiga period (108..907),
            [15:8] effect, [7:0] parameter
  then      the samples, 8-bit signed, 4 per word (first in bits 31:24)

What the hardware does differently from ProTracker, and what is done here:
  - only the patterns in the song order are written, renumbered
  - samples are played a word at a time: a sample and its loop start on a
    word, so 2 zero bytes are put in front of a sample when its loop starts
    on an odd 16-bit word, and a loop of 2 mod 4 bytes is written twice
    (--loops round instead rounds the loop to words: smaller, as the 2001
    converter did)
  - the data after the loop end is not written (ProTracker doesn't play it)
  - finetune is put into the note periods (the frequency table has every
    period 108..907)
  - D (pattern break): the row is binary, the MOD parameter is BCD
  - not supported, dropped with a count: 0 arpeggio, 4 vibrato, 7 tremolo,
    8, 9 sample offset, E effects other than E1/E2/EA/EB, F00, F tempo
    (>= 32: the tick is WAITCLK, set by the program; 50 Hz = 125 BPM)
  - 6 is played as volume slide only (no vibrato)

--wav renders the converted song with the sound unit model in
tools/sound_ref.py (TetrIC frequency table, 48 kHz).
"""

from __future__ import annotations

import argparse
import struct
import sys
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
LUT_FILE = ROOT / "game_code" / "TLib" / "Data" / "Lut.raw"
PERIOD_MIN, PERIOD_MAX = 108, 907
CLK_CPU = 25_200_000


class ModError(Exception):
    pass


def read_mod(data: bytes):
    """-> title, samples [(name, bytes, finetune, volume, loop start, loop length)],
    order list, patterns [64 rows of 4 (instrument, period, effect, parameter)]"""
    tag = data[1080:1084]
    if tag in (b"M.K.", b"M!K!", b"4CHN", b"FLT4"):
        nsamples, pos = 31, 950
    elif tag[1:4] == b"CHN" or tag[2:4] == b"CH" or tag in (b"FLT8", b"OKTA", b"CD81"):
        raise ModError(f"{tag.decode('latin-1')}: only 4 channel MODs are supported")
    else:
        nsamples, pos = 15, 470  # old Soundtracker MOD without a tag
    title = data[:20].split(b"\0")[0].decode("latin-1")
    hdr = []
    for i in range(nsamples):
        s = data[20 + 30 * i : 50 + 30 * i]
        name = s[:22].split(b"\0")[0].decode("latin-1")
        length, ft, vol, ls, ll = struct.unpack(">HBBHH", s[22:30])
        ft = ft & 15
        hdr.append((name, 2 * length, ft - 16 if ft > 7 else ft, min(vol, 64), 2 * ls, 2 * ll))
    songlen = data[pos]
    order = list(data[pos + 2 : pos + 130])
    pat_start = pos + 130 + (4 if nsamples == 31 else 0)
    npat = max(order) + 1  # as ProTracker: all 128 entries count
    patterns = []
    for p in range(npat):
        rows = []
        for r in range(64):
            row = []
            for c in range(4):
                o = pat_start + p * 1024 + r * 16 + c * 4
                b0, b1, b2, b3 = data[o : o + 4] if o + 4 <= len(data) else b"\0\0\0\0"
                row.append(((b0 & 0xF0) | (b2 >> 4), ((b0 & 0x0F) << 8) | b1, b2 & 0x0F, b3))
            rows.append(row)
        patterns.append(rows)
    o = pat_start + npat * 1024
    samples = []
    for name, length, ft, vol, ls, ll in hdr:
        raw = data[o : o + length]
        o += length
        if len(raw) < length:
            raw += b"\0" * (length - len(raw))
        samples.append((name, raw, ft, vol, ls, ll))
    return title, samples, order[:songlen], patterns


def finetune_period(period: int, ft: int) -> int:
    return round(period * 2 ** (-ft / 96.0)) if ft else period


def convert(data: bytes, use_finetune: bool = True, exact_loops: bool = True):
    """-> (words, report lines)"""
    title, samples, order, patterns = read_mod(data)
    if not order:
        raise ModError("the song is empty")
    report = [f'"{title}": {len(order)} positions']
    dropped = Counter()

    # patterns in the song order, renumbered by first use
    used = []
    for p in order:
        if p not in used:
            used.append(p)
    newnum = {p: n for n, p in enumerate(used)}
    if len(used) > 128:
        raise ModError("more than 128 patterns")

    # instrument of every channel, followed through the song order, for the
    # finetune of notes without an instrument number
    last_inst = [0] * 4
    out_pats = {}
    tempo = None
    clamped = 0
    for p in order:
        rows = patterns[p]
        conv = []
        for r, row in enumerate(rows):
            crow = []
            for c, (inst, period, fx, prm) in enumerate(row):
                if inst:
                    last_inst[c] = inst
                if inst > 31:
                    inst = 0
                ei = last_inst[c]
                if period:
                    ft = samples[ei - 1][2] if use_finetune and 0 < ei <= len(samples) else 0
                    period = finetune_period(period, ft)
                    if period < PERIOD_MIN or period > PERIOD_MAX:
                        clamped += 1
                        period = min(max(period, PERIOD_MIN), PERIOD_MAX)
                nfx, nprm = fx, prm
                if fx == 0 and prm:
                    dropped["0 arpeggio"] += 1
                    nfx = nprm = 0
                elif fx in (4, 7, 8, 9):
                    dropped[
                        {4: "4 vibrato", 7: "7 tremolo", 8: "8", 9: "9 sample offset"}[fx]
                    ] += 1
                    nfx = nprm = 0
                elif fx == 6:
                    dropped["6 (vibrato part)"] += 1
                elif fx == 0xD:
                    nprm = min((prm >> 4) * 10 + (prm & 15), 63)
                elif fx == 0xE and prm >> 4 not in (1, 2, 0xA, 0xB):
                    if prm >> 4:  # E0 (filter) is silent anyway
                        dropped[f"E{prm >> 4:X}"] += 1
                    nfx = nprm = 0
                elif fx == 0xF:
                    if prm == 0:
                        dropped["F00"] += 1
                        nfx = nprm = 0
                    elif prm >= 32:
                        if tempo is None:
                            tempo = prm
                        dropped["F tempo"] += 1
                        nfx = nprm = 0
                elif fx == 0 and prm == 0:
                    nfx = nprm = 0
                crow.append((inst, period, nfx, nprm))
            conv.append(crow)
        out_pats.setdefault(p, conv)

    # samples
    words_hdr = [0] * 157
    data_bytes = bytearray()
    base = 4 * (157 + 256 * len(used))
    inst_hdr = []
    for name, raw, ft, vol, ls, ll in samples:
        if len(raw) < 4 or vol == 0 and not raw.strip(b"\0"):
            inst_hdr.append(None)
            continue
        loop = ll > 2
        if loop:
            ls = min(ls, len(raw))
            ll = min(ll, len(raw) - ls)
            loop = ll >= 2
        if loop and exact_loops:
            pad = (-ls) % 4
            body = bytes(pad) + raw[: ls + ll]
            lstart = pad + ls
            if ll % 4:
                body += raw[ls : ls + ll]  # loop twice: a multiple of 4 bytes
            lend = len(body)
        elif loop:
            # loop start down and loop end up to a word (as the 2001 converter)
            lstart = ls & ~3
            lend = min((ls + ll + 3) & ~3, len(raw) + (-len(raw) % 4))
            body = raw[:lend]
        else:
            body = raw
            lstart = lend = 0
        body += bytes(-len(body) % 4)
        start = base + len(data_bytes)
        inst_hdr.append(
            (
                start,
                start + len(body),
                vol,
                start + lstart if loop else 0,
                start + lend if loop else 0,
            )
        )
        data_bytes += body
    end = base + len(data_bytes)
    for i in range(31):
        h = inst_hdr[i] if i < len(inst_hdr) else None
        if h is None:
            h = (end, end, 0, 0, 0)
        start, send, vol, ls, le = h
        words_hdr[4 * i + 0] = start
        words_hdr[4 * i + 1] = (vol << 24) | send
        words_hdr[4 * i + 2] = ls
        words_hdr[4 * i + 3] = le
        if send >> 24 or le >> 26:
            raise ModError("the song is larger than the 16 MB the format can address")

    words_hdr[124] = (len(order) << 24) | (4 << 16) | newnum[order[0]]
    for i, p in enumerate(order):
        words_hdr[125 + i // 4] |= newnum[p] << (8 * (i % 4))

    words = list(words_hdr)
    for p in used:
        for row in out_pats[p]:
            for inst, period, fx, prm in row:
                words.append((inst << 27) | (period << 16) | (fx << 8) | prm)
    words += list(struct.unpack(f">{len(data_bytes) // 4}I", bytes(data_bytes)))

    n_inst = sum(1 for h in inst_hdr if h)
    report.append(
        f"{len(used)} patterns (of {len(patterns)}), {n_inst} samples, "
        f"{len(words)} words = {4 * len(words)} bytes"
    )
    if clamped:
        report.append(
            f"warning: {clamped} notes outside the periods {PERIOD_MIN}..{PERIOD_MAX}, clamped"
        )
    for what, n in sorted(dropped.items()):
        report.append(f"not supported, dropped: effect {what} x{n}")
    if tempo is not None:
        waitclk = round(CLK_CPU * 2.5 / tempo)
        if waitclk > 0xFFFFF:
            report.append(
                f"note: the song sets tempo {tempo} BPM (F{tempo:02X}); WAITCLK is 20 bits, "
                f"the slowest tick is {CLK_CPU * 2.5 / 0xFFFFF:.1f} BPM"
            )
        else:
            report.append(
                f"note: the song sets tempo {tempo} BPM (F{tempo:02X}); the default tick is "
                f"125 BPM, WAITCLK (register 28) = {waitclk} plays it at {tempo} BPM"
            )
    return words, report


def render(words: list[int], seconds: float, wav: str):
    """Play the converted song with the tools/sound_ref.py model, write a WAV."""
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import wave

    import sound_ref

    lut = LUT_FILE.read_bytes()
    lut_words = list(struct.unpack(f">{len(lut) // 4}I", lut))
    lut_at, song_at = 0x400, 0x1000
    mem = [0] * (song_at + len(words))
    mem[lut_at : lut_at + len(lut_words)] = lut_words
    mem[song_at : song_at + len(words)] = words

    snd = sound_ref.Sound(mem)
    seq = sound_ref.Seq(mem)
    seq.reg_write(0, song_at)
    seq.reg_write(1, lut_at - PERIOD_MIN)
    seq.reg_write(3, 1)  # play, no loop
    seq.start()
    acc = 0
    frames = bytearray()
    for _ in range(int(seconds * 48000)):
        acc += 525
        if seq.playing and acc >= seq.waitclk:
            acc -= seq.waitclk
            for ch, reg, d in seq.tick():
                snd.chan_write(ch, reg >> 2, d)
        left = snd.mix(0) + snd.mix(3)
        right = snd.mix(1) + snd.mix(2)
        frames += struct.pack("<hh", max(-32768, min(32767, left)), max(-32768, min(32767, right)))
        if not seq.playing and not any(snd.ch[c].playing for c in range(4)):
            break
    with wave.open(wav, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes(bytes(frames))
    return len(frames) // 4 / 48000.0


def main() -> int:
    ap = argparse.ArgumentParser(description="Convert a 4 channel MOD to the TetrIC song format")
    ap.add_argument("mod")
    ap.add_argument("out", help="the song, big endian words (for .file in the game)")
    ap.add_argument("--no-finetune", action="store_true", help="ignore the sample finetune")
    ap.add_argument(
        "--loops",
        choices=("exact", "round"),
        default="exact",
        help="exact: loops as in the MOD (may cost memory: a loop of 2 mod 4 bytes is "
        "written twice); round: loop start/end rounded to words (smaller)",
    )
    ap.add_argument("--wav", help="render a preview with the sound unit model")
    ap.add_argument("--seconds", type=float, default=30.0, help="preview length (default 30)")
    args = ap.parse_args()
    try:
        words, report = convert(
            Path(args.mod).read_bytes(), not args.no_finetune, args.loops == "exact"
        )
    except ModError as e:
        print(f"{args.mod}: {e}", file=sys.stderr)
        return 1
    Path(args.out).write_bytes(struct.pack(f">{len(words)}I", *words))
    for line in report:
        print(line)
    print(f"wrote {args.out} ({len(words)} words)")
    if args.wav:
        t = render(words, args.seconds, args.wav)
        print(f"wrote {args.wav} ({t:.1f} s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
