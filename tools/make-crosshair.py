#!/usr/bin/env python3
"""Draw the list marker: a red crosshair (ring + four ticks + centre dot) with a
dark outline, as a 64x64 32-bit TGA with alpha (WoW reads uncompressed TGA).

    python3 tools/make-crosshair.py            # writes Media/Crosshair.tga

No dependencies. 4x4 supersampling for smooth edges. Tim chose a crosshair,
not a skull (2026-11-20), so nothing here resembles a raid-target icon.
"""
import math
import os
import struct
import sys

SIZE = 64
SS = 4  # supersamples per axis
C = (SIZE - 1) / 2.0

RED = (235, 48, 48)
DARK = (12, 6, 6)

RING_R, RING_W = 20.0, 4.0           # ring radius and stroke width
TICK_W = 4.0                          # tick stroke width
TICK_OUT, TICK_IN = 31.0, 9.0         # ticks run from the edge to near the centre
DOT_R = 3.0
OUTLINE = 1.6                         # dark outline around every red stroke


def red_dist(x, y):
    """Signed-ish distance outside the red shape (<= 0 means inside)."""
    dx, dy = x - C, y - C
    r = math.hypot(dx, dy)
    d_ring = abs(r - RING_R) - RING_W / 2
    d_dot = r - DOT_R
    # vertical tick (both halves), horizontal tick (both halves)
    def tick(a, b):
        # a: across-axis offset, b: along-axis distance from centre
        along = abs(b)
        if along < TICK_IN:
            d_along = TICK_IN - along
        elif along > TICK_OUT:
            d_along = along - TICK_OUT
        else:
            d_along = 0.0
        d_across = abs(a) - TICK_W / 2
        if d_along <= 0:
            return d_across
        return math.hypot(max(d_across, 0), d_along) if d_across > 0 else d_along
    return min(d_ring, d_dot, tick(dx, dy), tick(dy, dx))


def pixel(px, py):
    red = dark = 0.0
    for sy in range(SS):
        for sx in range(SS):
            x = px + (sx + 0.5) / SS - 0.5
            y = py + (sy + 0.5) / SS - 0.5
            d = red_dist(x, y)
            if d <= 0:
                red += 1
            elif d <= OUTLINE:
                dark += 1
    n = SS * SS
    a = (red + dark) / n
    if a == 0:
        return (0, 0, 0, 0)
    mix = red / (red + dark)
    rgb = tuple(int(round(RED[i] * mix + DARK[i] * (1 - mix))) for i in range(3))
    return rgb + (int(round(a * 255)),)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(root, "Media", "Crosshair.tga")
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
