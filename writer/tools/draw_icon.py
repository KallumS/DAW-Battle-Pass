#!/usr/bin/env python3
"""Draws Resources/icon-1024.png: a plum-to-magenta rounded square, a gold
fountain-pen nib and a lemon sparkle. Needs Pillow (pip install pillow).
make_app.sh turns it into every size the Mac wants."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

S = 1024
here = os.path.dirname(os.path.abspath(__file__))
out = os.path.join(here, "..", "Resources", "icon-1024.png")

img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
grad = Image.new("RGBA", (S, S))
gd = ImageDraw.Draw(grad)
top, bot = (0x4A, 0x25, 0x5E), (0xC2, 0x3B, 0x7E)
for y in range(S):
    t = y / S
    gd.line([(0, y), (S, y)], fill=tuple(int(top[i] * (1 - t) + bot[i] * t) for i in range(3)) + (255,))
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle([100, 100, 924, 924], radius=185, fill=255)
body = Image.new("RGBA", (S, S), (0, 0, 0, 0))
body.paste(grad, (0, 0), mask)
shadow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle([100, 112, 924, 936], radius=185, fill=(0, 0, 0, 110))
img = Image.alpha_composite(img, shadow.filter(ImageFilter.GaussianBlur(18)))
img = Image.alpha_composite(img, body)
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([262, 250, 762, 750], fill=(255, 200, 61, 90))
img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(60)))
d = ImageDraw.Draw(img)

cx = 512
gold, edge, light = (255, 200, 61, 255), (185, 134, 42, 255), (255, 228, 140, 255)

def nib(off, col):
    d.polygon([(cx - 150 + off, 300 + off), (cx + 150 + off, 300 + off), (cx + 170 + off, 430 + off),
               (cx + 110 + off, 560 + off), (cx + off, 800 + off), (cx - 110 + off, 560 + off),
               (cx - 170 + off, 430 + off)], fill=col)

nib(10, (60, 20, 60, 140))
nib(0, gold)
d.polygon([(cx - 150, 300), (cx, 300), (cx, 800), (cx - 110, 560), (cx - 170, 430)], fill=light)
d.line([(cx, 470), (cx, 790)], fill=edge, width=14)
d.ellipse([cx - 34, 430, cx + 34, 498], fill=(74, 37, 94, 255))
d.rounded_rectangle([cx - 175, 250, cx + 175, 312], radius=18, fill=(30, 22, 40, 255))
d.rounded_rectangle([cx - 175, 250, cx + 175, 268], radius=10, fill=(70, 52, 86, 255))

def sparkle(x, y, r, col):
    pts = []
    for i in range(8):
        a = i * math.pi / 4 - math.pi / 2
        rr = r if i % 2 == 0 else r * 0.28
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    d.polygon(pts, fill=col)

sparkle(735, 265, 95, (255, 242, 0, 255))
sparkle(300, 690, 50, (255, 255, 255, 230))
sparkle(760, 700, 34, (255, 63, 164, 255))
img.save(out)
print("wrote", os.path.normpath(out))
