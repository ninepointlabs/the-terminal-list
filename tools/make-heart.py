#!/usr/bin/env python3
"""Draw the Good Folk marker: a pink heart with a dark outline and a soft
highlight, as a 64x64 32-bit TGA with alpha (WoW reads uncompressed TGA).

    python3 tools/make-heart.py                # writes Media/Heart.tga

No dependencies; same approach and format as tools/make-crosshair.py (4x4
supersampling, exact signed distances). Tim asked for "a heart next to their
name instead of the target icon" (2026-11-24). The shape is a solid filled
heart (two circles on a 45-degree square), so it can't be mistaken for the
open ring-and-ticks crosshair, and nothing here resembles a raid-target icon.
"""
import math
import os
import struct
import sys

SIZE = 64
SS = 4  # supersamples per axis
C = (SIZE - 1) / 2.0

PINK = (255, 120, 181)
LIGHT = (255, 214, 232)   # highlight on the upper-left lobe
DARK = (28, 6, 16)

SIDE = 31.0               # side of the 45-degree square that forms the point
OUTLINE = 1.8             # dark outline around the heart
HALF_DIAG = SIDE / math.sqrt(2)
R = SIDE / 2              # lobe radius (circles on the two upper edges)
# Centre the shape vertically: top of the lobes to the bottom point.
TOP = -HALF_DIAG / 2 - R
BOTTOM = HALF_DIAG
CY = C - (TOP + BOTTOM) / 2

HL_X, HL_Y, HL_R = -HALF_DIAG / 2 - 3.5, -HALF_DIAG / 2 - 4.5, 4.2  # highlight (relative)


def heart_dist(x, y):
    """Signed distance to the heart (<= 0 means inside)."""
    dx, dy = x - C, y - CY
    # The square, rotated 45 degrees.
    u = (dx + dy) / math.sqrt(2)
    v = (dy - dx) / math.sqrt(2)
    qx, qy = abs(u) - SIDE / 2, abs(v) - SIDE / 2
    d_sq = math.hypot(max(qx, 0), max(qy, 0)) + min(max(qx, qy), 0)
    # Two lobes centred on the midpoints of the upper-left and upper-right edges.
    d_l = math.hypot(dx + HALF_DIAG / 2, dy + HALF_DIAG / 2) - R
    d_r = math.hypot(dx - HALF_DIAG / 2, dy + HALF_DIAG / 2) - R
    return min(d_sq, d_l, d_r)


def highlight(x, y):
    dx, dy = x - C - HL_X, y - CY - HL_Y
    # A small ellipse leaning along the lobe.
    return (dx / 1.25) ** 2 + (dy / 0.85) ** 2 <= HL_R ** 2


def pixel(px, py):
    fill = light = dark = 0.0
    for sy in range(SS):
        for sx in range(SS):
            x = px + (sx + 0.5) / SS - 0.5
            y = py + (sy + 0.5) / SS - 0.5
            d = heart_dist(x, y)
            if d <= 0:
                if highlight(x, y):
                    light += 1
                else:
                    fill += 1
            elif d <= OUTLINE:
                dark += 1
    n = SS * SS
    cover = fill + light + dark
    if cover == 0:
        return (0, 0, 0, 0)
    rgb = tuple(int(round((PINK[i] * fill + LIGHT[i] * light + DARK[i] * dark) / cover)) for i in range(3))
    return rgb + (int(round(cover / n * 255)),)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "Media", "Heart.tga")
    # TGA header: no id, no colour map, type 2 (uncompressed true colour),
    # 32 bpp, descriptor 0x28 = 8 alpha bits + top-left origin.
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, SIZE, SIZE, 32, 0x28)
    body = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            r, g, b, a = pixel(x, y)
            body += bytes((b, g, r, a))  # TGA stores BGRA
    with open(out, "wb") as f:
        f.write(header + bytes(body))
    print("wrote", out)


if __name__ == "__main__":
    main()
