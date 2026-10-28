#!/usr/bin/env python3
"""Draws Resources/AppIcon.png (the flame used on the Overview page). Needs Pillow."""
from PIL import Image, ImageDraw, ImageFilter
import os

S = 4096          # supersampled canvas, downscaled to 1024
OUT = 1024

def bezier(p0, p1, p2, p3, n=60):
    pts = []
    for i in range(n + 1):
        t = i / n
        a = (1 - t) ** 3; b = 3 * (1 - t) ** 2 * t; c = 3 * (1 - t) * t ** 2; d = t ** 3
        pts.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0],
                    a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return pts

def flame(cx, cy, w, h):
    """Flame outline in a unit box scaled to (w, h) centred on (cx, cy)."""
    def P(x, y): return (cx + (x - 0.5) * w, cy + (y - 0.5) * h)
    pts = []
    pts += bezier(P(0.50, 0.00), P(0.56, 0.20), P(0.86, 0.34), P(0.88, 0.64))   # right side up to tip
    pts += bezier(P(0.88, 0.64), P(0.90, 0.88), P(0.72, 1.00), P(0.50, 1.00))   # right bottom
    pts += bezier(P(0.50, 1.00), P(0.28, 1.00), P(0.10, 0.88), P(0.12, 0.64))   # left bottom
    pts += bezier(P(0.12, 0.64), P(0.13, 0.50), P(0.22, 0.42), P(0.30, 0.34))   # left side
    pts += bezier(P(0.30, 0.34), P(0.32, 0.44), P(0.38, 0.48), P(0.42, 0.46))   # notch
    pts += bezier(P(0.42, 0.46), P(0.36, 0.28), P(0.44, 0.10), P(0.50, 0.00))   # left tip
    return pts

def gradient(size, top, bottom):
    img = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        img.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return img.resize((size, size))

# Background: macOS icon grid (824/1024) rounded square, dark graphite.
canvas = Image.new("RGBA", (S, S), (0, 0, 0, 0))
inset = int(S * 100 / 1024)
box = (inset, inset, S - inset, S - inset)
bg = gradient(S, (58, 60, 68), (22, 23, 28)).convert("RGBA")
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle(box, radius=int(S * 0.2237 * 0.8047), fill=255)
canvas.paste(bg, (0, 0), mask)

# Soft glow behind the flame.
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((S * 0.28, S * 0.30, S * 0.72, S * 0.80), fill=(255, 120, 20, 120))
glow = glow.filter(ImageFilter.GaussianBlur(S * 0.07))
canvas = Image.alpha_composite(canvas, glow)

# Outer flame (orange -> red gradient), inner flame (yellow).
cx, cy = S * 0.5, S * 0.53
def layer(points, top, bottom):
    m = Image.new("L", (S, S), 0)
    ImageDraw.Draw(m).polygon(points, fill=255)
    g = gradient(S, top, bottom).convert("RGBA")
    out = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    out.paste(g, (0, 0), m)
    return out

canvas = Image.alpha_composite(canvas, layer(flame(cx, cy, S * 0.46, S * 0.56), (255, 176, 32), (232, 52, 28)))
canvas = Image.alpha_composite(canvas, layer(flame(cx, cy + S * 0.10, S * 0.24, S * 0.30), (255, 244, 170), (255, 170, 40)))

os.makedirs("Resources", exist_ok=True)
canvas.resize((OUT, OUT), Image.LANCZOS).save("Resources/AppIcon.png")
print("Wrote Resources/AppIcon.png")
