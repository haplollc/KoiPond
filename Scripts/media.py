#!/usr/bin/env python3
"""Cuts the README's animations from the demo's recorded takes (Scripts/record.sh).

usage: Scripts/media.py <takes-dir> <assets-dir>

<takes-dir> holds hero.mp4, pond.mp4 and pool.mp4 (SCRIPT=hero, pond and
pool). Each animation is an animated WebP with rounded, transparent corners,
so one file sits right on GitHub's light and dark pages alike. (A GIF of
moving water is ten times the size: every pixel changes on every frame.)

A stretch of pond doesn't end where it began (the koi have moved on), so each
loop dissolves its last half second into its first: it plays through
without a jump.

Needs ffmpeg, img2webp (libwebp) and Pillow.
"""
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

W, H = 1320, 2868                 # a 17 Pro Max screen, px
FPS = 30
QUALITY = 75
FADE = 0.5

# name: (take, from s, to s, crop top and bottom as fractions of the screen).
# The crop is the screen's full width; each clip is 600 px wide, shown at 300.
CLIPS = {
    "feed":   ("pond", 2.30, 6.30, (0.27, 0.71)),
    "stir":   ("pond", 6.10, 8.90, (0.34, 0.78)),
    "pad":    ("pond", 0.55, 3.15, (0.10, 0.54)),
    "fling":  ("pool", 2.10, 6.90, (0.22, 0.65)),
    "switch": ("hero", 6.40, 9.20, (0.22, 0.78)),
}
CLIP_WIDTH = 600
# The banner: the pond and the pool side by side, 1200 px wide, shown at 720.
BANNER = [("pond", 0.40, 6.40, (0.20, 0.63)), ("pool", 2.20, 8.20, (0.22, 0.65))]
BANNER_CARD, BANNER_PAD = 552, 32


def shots(video, start, end, band, width):
    """The video's frames between two times at FPS, each cropped to a band
    of the screen (top and bottom as fractions) and scaled to `width`."""
    top, bottom = int(band[0] * H), int(band[1] * H)
    height = round(width * (bottom - top) / W)
    # Cropped after converting to RGB: a crop of the 4:2:0 video would be
    # rounded to even rows, and the frames read here would drift.
    proc = subprocess.Popen(["ffmpeg", "-v", "error", "-ss", f"{start}", "-i", video, "-t", f"{end - start}",
                             "-vf", f"fps={FPS},format=rgb24,crop={W}:{bottom - top}:0:{top}",
                             "-f", "rawvideo", "-pix_fmt", "rgb24", "-"], stdout=subprocess.PIPE)
    size = W * (bottom - top) * 3
    out = []
    while True:
        raw = proc.stdout.read(size)
        if len(raw) < size:
            break
        out.append(Image.frombytes("RGB", (W, bottom - top), raw).resize((width, height), Image.LANCZOS))
    proc.wait()
    return out


def loop(images):
    """Dissolves the last FADE seconds into the first, so the loop has no seam."""
    k = min(int(FADE * FPS), len(images) // 3)
    if k < 1:
        return images
    head, body, tail = images[:k], images[k:-k], images[-k:]
    blended = [Image.blend(t, h, (i + 1) / (k + 1)) for i, (t, h) in enumerate(zip(tail, head))]
    return body + blended


def rounded(size, radius):
    """An anti-aliased rounded-rectangle mask."""
    s = 4
    mask = Image.new("L", (size[0] * s, size[1] * s), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size[0] * s - 1, size[1] * s - 1), radius=radius * s, fill=255)
    return mask.resize(size, Image.LANCZOS)


def encode(cards, boxes, size, radius, out):
    """Lays the cards, rounded, on a transparent canvas and writes the loop
    as an animated WebP."""
    masks = [rounded(card[0].size, radius) for card in cards]
    with tempfile.TemporaryDirectory() as folder:
        names = []
        for n in range(min(len(card) for card in cards)):
            canvas = Image.new("RGBA", size, (0, 0, 0, 0))
            for card, mask, (x, y) in zip(cards, masks, boxes):
                canvas.paste(card[n], (x, y), mask)
            names.append(os.path.join(folder, f"{n:04d}.png"))
            canvas.save(names[-1])
        subprocess.run(["img2webp", "-loop", "0", "-lossy", "-q", str(QUALITY), "-m", "4",
                        "-d", str(round(1000 / FPS)), *names, "-o", out], check=True, capture_output=True)
    print(out, f"{len(names)} frames, {os.path.getsize(out) / 1e6:.1f} MB")


def main():
    takes, assets = sys.argv[1], sys.argv[2]
    os.makedirs(assets, exist_ok=True)

    cards = [loop(shots(os.path.join(takes, f"{take}.mp4"), start, end, band, BANNER_CARD))
             for take, start, end, band in BANNER]
    pad, cw, ch = BANNER_PAD, BANNER_CARD, cards[0][0].height
    encode(cards, [(pad, pad), (pad * 2 + cw, pad)], (pad * 3 + cw * 2, pad * 2 + ch), 52,
           os.path.join(assets, "banner.webp"))

    for name, (take, start, end, band) in CLIPS.items():
        clip = loop(shots(os.path.join(takes, f"{take}.mp4"), start, end, band, CLIP_WIDTH))
        encode([clip], [(0, 0)], clip[0].size, 48, os.path.join(assets, f"{name}.webp"))


if __name__ == "__main__":
    main()
