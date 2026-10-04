#!/usr/bin/env python3
"""Slice the trait poses (spec 004, Т9) → assets/images/traits/.

Sources in store/art-pack-traits/ (cream background, 1280×720):

- sleep-dream-<skin>.png: four frames in a row — [0] sleep inhale,
  [1] sleep exhale, [2] dreamer looks up, eyes open, [3] eyes half-closed.
  `guard` is drawn facing left: every frame is mirrored after slicing (the
  whole sheet mirrored would also reverse the frame order).
- sleep-bubble.png: three bubbles, small → large.

Out:

- sleep_<skin>_{0,1}.png, dream_<skin>_{0,1}.png: one canvas for all,
  [CANVAS_W]×[CANVAS_H], feet on the bottom row ([BASE_PAD] above the edge,
  as the walk frames), centered. Scale = that skin's walk scale (the factor
  slice_walk_pack.py used for its frame 0), so a pose matches the walk.
- bubble_{0,1,2}.png: one square canvas, bubble bottom-centered.
- store/art-pack-traits/preview-processed.png: all frames on grass.

The nose of each sleep pose (where the bubble rises) is set by hand in
lib/features/game/models/capy_pose.dart, in canvas pixels.

Usage (repo root, Pillow): python tool/slice_traits_pack.py
"""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
from chroma_cream import chroma_cream  # noqa: E402
from slice_walk_pack import chroma_sheet  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'store' / 'art-pack-traits'
WALK = ROOT / 'store' / 'art-pack-walk'
OUT = ROOT / 'assets' / 'images' / 'traits'
PREVIEW = SRC / 'preview-processed.png'

SKINS = ['base', 'lv3', 'nanny', 'gatherer', 'guard']
MIRROR = {'guard'}
PAD = 6
BASE_PAD = 3
CANVAS_W = 320
CANVAS_H = 288
BUBBLE_SCALE = 0.5
BUBBLE_CANVAS = 128


def cells(im: Image.Image, n: int) -> list[Image.Image]:
    w, h = im.size
    fw = w // n
    return [im.crop((i * fw, 0, (i + 1) * fw, h)) for i in range(n)]


def figures(im: Image.Image, n: int) -> list[Image.Image]:
    """The [n] figures of a keyed sheet, left to right, each on a full-height
    strip. The art does not sit in equal cells (a sleeping body crosses the
    quarter line), so strips are cut at the widest empty column gaps; small
    bits (a breath puff) stay with their figure."""
    a = im.getchannel('A')
    w, h = a.size
    px = a.load()
    filled = [any(px[x, y] > 40 for y in range(h)) for x in range(w)]
    runs: list[list[int]] = []
    x = 0
    while x < w:
        if filled[x]:
            start = x
            while x < w and filled[x]:
                x += 1
            runs.append([start, x])
        else:
            x += 1
    # Merge across the narrowest gaps until n groups are left.
    while len(runs) > n:
        gaps = [runs[i + 1][0] - runs[i][1] for i in range(len(runs) - 1)]
        i = gaps.index(min(gaps))
        runs[i] = [runs[i][0], runs[i + 1][1]]
        del runs[i + 1]
    if len(runs) != n:
        raise SystemExit(f'expected {n} figures, found {len(runs)}')
    out = []
    for i, (l, r) in enumerate(runs):
        left = 0 if i == 0 else (runs[i - 1][1] + l) // 2
        right = w if i == n - 1 else (r + runs[i + 1][0]) // 2
        strip = Image.new('RGBA', im.size)
        strip.paste(im.crop((left, 0, right, h)), (left, 0))
        out.append(strip)
    return out


def _beige(c: tuple[int, int, int]) -> bool:
    """Cream background or the beige ground shadow some poses stand on.
    Fur is redder (g < 0.8 r), shawls and leaves are darker or greener."""
    r, g, b = c
    return r >= 180 and g >= 0.82 * r and 0.55 * r <= b <= g + 4


def key_sheet(src: Image.Image) -> Image.Image:
    """slice_walk_pack.chroma_sheet, plus the beige ground shadow under the
    feet (walk frames have none), flooded from the border only."""
    im = chroma_sheet(src)
    rgb = src.convert('RGB')
    w, h = im.size
    op = im.load()
    sp = rgb.load()
    seen = [[False] * w for _ in range(h)]
    stack = [(x, y) for x in range(w) for y in (0, h - 1)]
    stack += [(x, y) for y in range(h) for x in (0, w - 1)]
    while stack:
        x, y = stack.pop()
        if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
            continue
        seen[y][x] = True
        if op[x, y][3] != 0 and not _beige(sp[x, y]):
            continue
        op[x, y] = (0, 0, 0, 0)
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return im


def walk_scale(skin: str) -> float:
    """The factor slice_walk_pack.py applied to this skin's frame 0."""
    keyed = chroma_sheet(Image.open(WALK / f'walk-{skin}.png'))
    cell = cells(keyed, 4)[0]
    l, t, r, b = cell.getbbox()
    w, h = cell.size
    cw = min(w, r + PAD) - max(0, l - PAD)
    ch = min(h, b + PAD) - max(0, t - PAD)
    m = max(cw, ch)
    return 256 / m if m > 256 else 1.0


def _clear_floor(frame: Image.Image, rows: int = 24) -> Image.Image:
    """Shadow specks shut in between the paws (the border flood cannot
    reach them): beige in the lowest [rows] rows of the figure goes."""
    frame = frame.copy()
    l, t, r, b = frame.getbbox()
    px = frame.load()
    for y in range(max(t, b - rows), b):
        for x in range(l, r):
            p = px[x, y]
            if p[3] and _beige(p[:3]):
                px[x, y] = (0, 0, 0, 0)
    return frame


def pose_frames(frames: list[Image.Image], scale: float) -> list[Image.Image]:
    """One box for every frame of a pose, aligned on the back (left edge)
    and the feet (bottom), so the body does not jitter between frames.
    Scaled, on the shared canvas with the feet [BASE_PAD] above the edge."""
    frames = [_clear_floor(f) for f in frames]
    boxes = [f.getbbox() for f in frames]
    bw = max(b[2] - b[0] for b in boxes)
    bh = max(b[3] - b[1] for b in boxes)
    out = []
    for f, (l, _, _, b) in zip(frames, boxes):
        crop = f.crop((l, b - bh, l + bw, b))
        w = max(1, round(crop.width * scale))
        h = max(1, round(crop.height * scale))
        if (w, h) != crop.size:
            crop = crop.resize((w, h), Image.Resampling.LANCZOS)
        if w > CANVAS_W or h + BASE_PAD > CANVAS_H:
            raise SystemExit(f'pose {w}x{h} does not fit {CANVAS_W}x{CANVAS_H}')
        canvas = Image.new('RGBA', (CANVAS_W, CANVAS_H))
        canvas.alpha_composite(
            crop, ((CANVAS_W - w) // 2, CANVAS_H - BASE_PAD - h)
        )
        out.append(canvas)
    return out


def bubbles() -> list[Image.Image]:
    sheet = Image.open(SRC / 'sleep-bubble.png').convert('RGBA')
    out = []
    keyed_sheet = chroma_cream(sheet, max_side=4096)
    for keyed in figures(keyed_sheet, 3):
        l, t, r, b = keyed.getbbox()
        crop = keyed.crop((l, t, r, b))
        w = max(1, round(crop.width * BUBBLE_SCALE))
        h = max(1, round(crop.height * BUBBLE_SCALE))
        crop = crop.resize((w, h), Image.Resampling.LANCZOS)
        canvas = Image.new('RGBA', (BUBBLE_CANVAS, BUBBLE_CANVAS))
        canvas.alpha_composite(crop, ((BUBBLE_CANVAS - w) // 2, BUBBLE_CANVAS - h))
        out.append(canvas)
    return out


def preview(rows: list[tuple[str, list[Image.Image]]]) -> Image.Image:
    grass = (118, 170, 82, 255)
    gap = 12
    width = gap + max(sum(i.width + gap for i in imgs) for _, imgs in rows)
    height = gap + sum(max(i.height for i in imgs) + gap + 14 for _, imgs in rows)
    sheet = Image.new('RGBA', (width, height), grass)
    draw = ImageDraw.Draw(sheet)
    y = gap
    for label, imgs in rows:
        draw.text((gap, y), label, fill=(255, 255, 255, 255))
        y += 14
        x = gap
        for img in imgs:
            # Thin baseline under the canvas so the feet line reads.
            draw.line(
                (x, y + img.height - BASE_PAD, x + img.width, y + img.height - BASE_PAD),
                fill=(90, 130, 60, 255),
            )
            sheet.alpha_composite(img, (x, y))
            x += img.width + gap
        y += max(i.height for i in imgs) + gap
    return sheet.convert('RGB')


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    rows: list[tuple[str, list[Image.Image]]] = []
    for skin in SKINS:
        scale = walk_scale(skin)
        keyed = key_sheet(Image.open(SRC / f'sleep-dream-{skin}.png'))
        frames = figures(keyed, 4)
        if skin in MIRROR:
            frames = [f.transpose(Image.Transpose.FLIP_LEFT_RIGHT) for f in frames]
        sleep = pose_frames(frames[0:2], scale)
        dream = pose_frames(frames[2:4], scale)
        for i, img in enumerate(sleep):
            img.save(OUT / f'sleep_{skin}_{i}.png', optimize=True)
        for i, img in enumerate(dream):
            img.save(OUT / f'dream_{skin}_{i}.png', optimize=True)
        print(f'{skin}: walk scale {scale:.3f}')
        rows.append((f'{skin}: sleep 0-1, dream 0-1', sleep + dream))
    bub = bubbles()
    for i, img in enumerate(bub):
        img.save(OUT / f'bubble_{i}.png', optimize=True)
    rows.append(('bubble 0-2', bub))
    preview(rows).save(PREVIEW, optimize=True)
    print(f'canvas {CANVAS_W}x{CANVAS_H}, bubble {BUBBLE_CANVAS}, -> {OUT}')
    print(f'preview -> {PREVIEW}')


if __name__ == '__main__':
    main()
