#!/usr/bin/env python3
"""Chroma-key cream backdrops on soft-pixel art (flood from borders).

Usage:
  python3 tool/chroma_cream.py store/art-pack-multipliers/01-role-nanny.png \\
      -o assets/images/role_nanny.png

Matches the pipeline used for multiplier icon pack (cream → transparent + crop).
Requires Pillow.
"""
from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image


def chroma_cream(
    im: Image.Image,
    thr: float = 24.0,
    soft: float = 10.0,
    max_side: int = 512,
) -> Image.Image:
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

    bbox = out.getbbox()
    if not bbox:
        return out
    pad = 6
    l, t, r, b = bbox
    cropped = out.crop(
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
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('src', type=Path)
    p.add_argument('-o', '--out', type=Path, required=True)
    p.add_argument('--thr', type=float, default=24.0)
    p.add_argument('--soft', type=float, default=10.0)
    p.add_argument('--max-side', type=int, default=512)
    args = p.parse_args()
    out = chroma_cream(Image.open(args.src), thr=args.thr, soft=args.soft,
                       max_side=args.max_side)
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out, optimize=True)
    print(f'{args.src.name} -> {args.out} {out.size}')


if __name__ == '__main__':
    main()
