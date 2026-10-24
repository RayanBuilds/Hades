#!/usr/bin/env python3
"""Generate Hades launcher icons without external image dependencies."""

import math
import os
import struct
import zlib

SIZE = 1024
SS = 3  # supersampling factor


def lerp(a, b, t):
    return a + (b - a) * t


def mix(c1, c2, t):
    return tuple(lerp(c1[i], c2[i], t) for i in range(4))


def rounded_rect(px, py, x0, y0, x1, y1, radius):
    if px < x0 or px > x1 or py < y0 or py > y1:
        return False
    cx = min(max(px, x0 + radius), x1 - radius)
    cy = min(max(py, y0 + radius), y1 - radius)
    return (px - cx) ** 2 + (py - cy) ** 2 <= radius * radius


def over(dst, src):
    a = src[3]
    if a <= 0:
        return dst
    na = a + dst[3] * (1 - a)
    if na <= 0:
        return (0.0, 0.0, 0.0, 0.0)
    out = []
    for i in range(3):
        out.append((src[i] * a + dst[i] * dst[3] * (1 - a)) / na)
    out.append(na)
    return tuple(out)


def render(with_background, size=SIZE, ss=SS):
    w = size * ss
    buf = [(0.0, 0.0, 0.0, 0.0)] * (w * w)

    def put(x, y, color):
        if 0 <= x < w and 0 <= y < w:
            buf[y * w + x] = over(buf[y * w + x], color)

    def circle(cx, cy, r, color):
        for y in range(max(0, int(cy - r)), min(w, int(cy + r) + 1)):
            for x in range(max(0, int(cx - r)), min(w, int(cx + r) + 1)):
                if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                    put(x, y, color)

    def rrect(x0, y0, x1, y1, radius, color, gradient=None):
        for y in range(max(0, int(y0)), min(w, int(y1) + 1)):
            for x in range(max(0, int(x0)), min(w, int(x1) + 1)):
                if rounded_rect(x, y, x0, y0, x1, y1, radius):
                    c = gradient(x, y) if gradient else color
                    put(x, y, c)

    s = w / 1024.0

    if with_background:
        rrect(0, 0, w - 1, w - 1, 210 * s, (0.047, 0.031, 0.024, 1.0))
        # Warm glow behind the emblem.
        cx, cy = w / 2, w * 0.56
        for y in range(0, w, 1):
            for x in range(0, w, 2):
                d = math.hypot(x - cx, y - cy) / (w * 0.62)
                if d < 1:
                    a = (1 - d) ** 2 * 0.30
                    put(x, y, (1.0, 0.33, 0.10, a))
                    put(x + 1, y, (1.0, 0.33, 0.10, a))

    # Decorative ring.
    ring_c = (w / 2, w / 2)
    ring_r = 318 * s
    for y in range(int(ring_c[1] - ring_r - 4 * s), int(ring_c[1] + ring_r + 4 * s)):
        for x in range(int(ring_c[0] - ring_r - 4 * s), int(ring_c[0] + ring_r + 4 * s)):
            d = math.hypot(x - ring_c[0], y - ring_c[1])
            if abs(d - ring_r) <= 5 * s:
                put(x, y, (1.0, 0.48, 0.16, 0.38))

    # H monogram, gradient from molten gold to deep ember.
    left = 338 * s
    right = 686 * s
    top = 316 * s
    bottom = 708 * s
    bar = 78 * s
    radius = 26 * s

    def h_gradient(x, y):
        t = max(0.0, min(1.0, (y - top) / (bottom - top)))
        c = mix((1.0, 0.80, 0.38, 1.0), (1.0, 0.25, 0.05, 1.0), t)
        # Slight vertical sheen.
        edge = abs(x - (left + right) / 2) / (right - left)
        c = mix(c, (1.0, 0.93, 0.72, 1.0), max(0.0, 1 - edge * 3) * 0.16)
        return c

    rrect(left, top, left + bar, bottom, radius, None, h_gradient)
    rrect(right - bar, top, right, bottom, radius, None, h_gradient)
    rrect(left, 473 * s, right, 551 * s, radius * 0.8, None, h_gradient)

    # Embers.
    circle(512 * s, 246 * s, 13 * s, (1.0, 0.62, 0.22, 0.95))
    circle(456 * s, 218 * s, 6 * s, (1.0, 0.45, 0.14, 0.8))
    circle(568 * s, 224 * s, 8 * s, (1.0, 0.52, 0.18, 0.85))

    # Downsample.
    out = bytearray()
    for y in range(size):
        out.append(0)
        for x in range(size):
            r = g = b = a = 0.0
            for sy in range(ss):
                for sx in range(ss):
                    px = buf[(y * ss + sy) * w + (x * ss + sx)]
                    r += px[0]
                    g += px[1]
                    b += px[2]
                    a += px[3]
            n = ss * ss
            out.extend(
                (
                    max(0, min(255, int(r / n * 255 + 0.5))),
                    max(0, min(255, int(g / n * 255 + 0.5))),
                    max(0, min(255, int(b / n * 255 + 0.5))),
                    max(0, min(255, int(a / n * 255 + 0.5))),
                )
            )
    return bytes(out)


def write_png(path, size, raw):
    def chunk(tag, data):
        return (
            struct.pack(">I", len(data))
            + tag
            + data
            + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(
        b"IDAT", zlib.compress(raw, 9)
    ) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out = os.path.join(root, "assets", "icon")
    os.makedirs(out, exist_ok=True)
    write_png(os.path.join(out, "icon.png"), SIZE, render(True))
    write_png(os.path.join(out, "icon_foreground.png"), SIZE, render(False))
    print("Wrote icons to", out)


if __name__ == "__main__":
    main()
