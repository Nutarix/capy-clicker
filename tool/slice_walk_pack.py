#!/usr/bin/env python3
"""Slice cream-bg 4-frame walk sheets → assets/images/walk/{type}_{0..3}.png.

Usage (from repo root, with Pillow):
  python3 tool/slice_walk_pack.py
"""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'store' / 'art-pack-walk'
OUT = ROOT / 'assets' / 'images' / 'walk'

MAPPING = {
    'walk-base.png': 'base',
    'walk-lv3.png': 'lv3',
    'walk-nanny.png': 'nanny',
    'walk-gatherer.png': 'gatherer',
    'walk-guard.png': 'guard',
}


def chroma_sheet(im: Image.Image, thr: float = 32.0, soft: float = 14.0) -> Image.Image:
    im = im.convert('RGBA')
    w, h = im.size
    px = im.load()
    keys: list[tuple[int, int, int]] = []
    for ox, oy in ((0, 0), (w - 32, 0), (0, h - 32), (w - 32, h - 32)):
        for x in range(max(0, ox), min(w, ox + 32)):
            for y in range(max(0, oy), min(h, oy + 32)):
                keys.append(px[x, y][:3])
    kr = sum(k[0] for k in keys) / len(keys)
    kg = sum(k[1] for k in keys) / len(keys)
    kb = sum(k[2] for k in keys) / len(keys)

    def dist(c: tuple[int, int, int]) -> float:
        return ((c[0] - kr) ** 2 + (c[1] - kg) ** 2 + (c[2] - kb) ** 2) ** 0.5

    vis = [[False] * w for _ in range(h)]
    q: deque[tuple[int, int]] = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if x < 0 or y < 0 or x >= w or y >= h or vis[y][x]:
            continue
        if dist(px[x, y]) > thr:
            continue
        vis[y][x] = True
        q.append((x + 1, y))
        q.append((x - 1, y))
        q.append((x, y + 1))
        q.append((x, y - 1))

    out = Image.new('RGBA', (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, _a = px[x, y]
            if vis[y][x]:
                op[x, y] = (0, 0, 0, 0)
                continue
            d = dist((r, g, b))
            near = False
            for dx, dy in (
                (1, 0), (-1, 0), (0, 1), (0, -1),
                (1, 1), (-1, -1), (1, -1), (-1, 1),
            ):
                nx, ny = x + dx, y + dy
                if 0 <= nx < w and 0 <= ny < h and vis[ny][nx]:
                    near = True
                    break
            if near and d < thr + soft:
                t = max(0.0, min(1.0, (d - thr * 0.3) / (thr + soft)))
                op[x, y] = (r, g, b, int(255 * t))
            else:
                op[x, y] = (r, g, b, 255)

    # Global near-cream cleanup (islands between legs).
    for y in range(h):
        for x in range(w):
            r, g, b, a = op[x, y]
            if a == 0:
                continue
            d = dist((r, g, b))
            if d < 28:
                op[x, y] = (0, 0, 0, 0)
            elif d < 40:
                t = (d - 28) / 12
                op[x, y] = (r, g, b, int(a * t))
    return out


def crop_pad_resize(im: Image.Image, max_side: int = 256) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    pad = 6
    l, t, r, b = bbox
    w, h = im.size
    cropped = im.crop(
        (max(0, l - pad), max(0, t - pad), min(w, r + pad), min(h, b + pad))
    )
    cw, ch = cropped.size
    m = max(cw, ch)
    if m > max_side:
        scale = max_side / m
        cropped = cropped.resize(
            (max(1, int(cw * scale)), max(1, int(ch * scale))),
            Image.Resampling.LANCZOS,
        )
    return cropped


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for src_name, prefix in MAPPING.items():
        src = SRC / src_name
        if not src.exists():
            print(f'missing {src}', file=sys.stderr)
            continue
        keyed = chroma_sheet(Image.open(src))
        w, h = keyed.size
        fw = w // 4
        for i in range(4):
            cell = keyed.crop((i * fw, 0, (i + 1) * fw, h))
            out = crop_pad_resize(cell, 256)
            path = OUT / f'{prefix}_{i}.png'
            out.save(path, optimize=True)
            print(f'{path.relative_to(ROOT)} {out.size}')


if __name__ == '__main__':
    main()
