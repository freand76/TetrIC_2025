#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow"]  # only for --src
# ///
"""Create the 1 MByte flash image for sdram_video.

Layout: 320x240 RGB565 frame buffer at offset 0, packed (640 bytes per line),
pixels stored big endian (high byte first). The flash reader shifts MSB first,
so every 32-bit SDRAM word holds two pixels: left pixel in bits 31:16.
The rest of the 1 MByte is filled with the frame repeated / random data.

Outputs:
  -o image.bin          raw image to program at FLASH_START
  --memtxt MEM.TXT      $readmemh file for the SPI flash simulation model
                        (with an @address directive for FLASH_START)
  --hexwords FILE       the image as 32-bit words ($readmemh) for the test bench
"""

import argparse
import random
import struct


W, H = 320, 240
SIZE = 1 << 20


def rgb565(r, g, b):
    return ((r >> 3) << 11) | ((g >> 2) << 5) | (b >> 3)


def test_pattern():
    """Colour bars, gradients, a 1-pixel border and a grid."""
    bars = [
        (255, 255, 255),
        (255, 255, 0),
        (0, 255, 255),
        (0, 255, 0),
        (255, 0, 255),
        (255, 0, 0),
        (0, 0, 255),
        (0, 0, 0),
    ]
    px = []
    for y in range(H):
        for x in range(W):
            if x == 0 or y == 0 or x == W - 1 or y == H - 1:
                c = (255, 255, 255)
            elif y < 100:
                c = bars[x * 8 // W]
            elif y < 140:
                v = x * 255 // (W - 1)
                c = (v, v, v)
            elif y < 170:
                c = (x * 255 // (W - 1), 0, 255 - x * 255 // (W - 1))
            else:
                c = (0, 255 - (y - 170) * 255 // 69, x * 255 // (W - 1))
                if x % 32 == 0 or (y - 170) % 16 == 0:
                    c = (255, 128, 0)
            px.append(rgb565(*c))
    return px


def from_picture(path):
    from PIL import Image  # pip install pillow

    img = Image.open(path).convert("RGB").resize((W, H))
    return [rgb565(*img.getpixel((x, y))) for y in range(H) for x in range(W)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("-o", "--output", required=True)
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--pattern", action="store_true", help="test pattern (default)")
    g.add_argument("--random", action="store_true", help="random data (simulation)")
    ap.add_argument("--src", help="picture to convert (needs Pillow)")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--memtxt")
    ap.add_argument("--flash-start", type=lambda s: int(s, 0), default=0x600000)
    ap.add_argument("--hexwords")
    a = ap.parse_args()

    if a.random:
        rnd = random.Random(a.seed)
        data = bytes(rnd.getrandbits(8) for _ in range(SIZE))
    else:
        px = from_picture(a.src) if a.src else test_pattern()
        frame = b"".join(struct.pack(">H", p) for p in px)
        data = (frame * (SIZE // len(frame) + 1))[:SIZE]

    with open(a.output, "wb") as f:
        f.write(data)

    if a.memtxt:
        with open(a.memtxt, "w") as f:
            f.write(f"@{a.flash_start:x}\n")
            f.writelines(
                " ".join(f"{b:02x}" for b in data[i : i + 16]) + "\n" for i in range(0, SIZE, 16)
            )

    if a.hexwords:
        with open(a.hexwords, "w") as f:
            f.writelines(
                "{:08x}\n".format(struct.unpack(">I", data[i : i + 4])[0])
                for i in range(0, SIZE, 4)
            )


if __name__ == "__main__":
    main()
