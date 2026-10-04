#!/usr/bin/env python3
"""Spec 004, Т13: the behavior fingerprint changed only by name fields.

For every `test/fixtures/fingerprint/*.jsonl`, takes the old file from a git
ref (default `main`) and the new one from the working tree, removes the
capy name fields from the new one and compares:

1. Text: the keys `"name"`, `"epithet"`, `"customName"`, `"trait"` are cut
   out of every capy object as written by `Capybara.toJson` (they come last,
   after `y` / `role`). The rest must be byte-identical to the old file.
   Save blobs inside the fingerprint (JSON in a string) are cut the same way.
2. Data: both files parsed (save blobs too); the same keys dropped from
   every object that has `id` and `level` (a capy). The rest must be equal.

Any other difference means the game behaves differently.

Usage (repo root): python tool/fingerprint_names_diff.py [ref]
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = 'test/fixtures/fingerprint'
KEYS = ('name', 'epithet', 'customName', 'trait')

# Name fields of one capy, in Capybara.toJson order, right after "y" or
# "role". Name keys are lower-case latin; an own name is any JSON string.
_JSON_STR = r'"(?:[^"\\]|\\.)*"'
_CAPY_TAIL = re.compile(
    r'(?P<head>"y":-?[0-9.eE+-]+(?:,"role":"[a-z]+")?)'
    r'(?P<names>(?:,"name":"[a-z]+")(?:,"epithet":true)?'
    rf'(?:,"customName":{_JSON_STR})?(?:,"trait":"[a-zA-Z]+")?)'
    r'(?=\})'
)


# The same inside a save blob: a JSON string holding JSON, quotes escaped.
_Q = r'\\"'
_ESC_STR = rf'{_Q}(?:[^"\\]|\\.)*?{_Q}'
_CAPY_TAIL_ESC = re.compile(
    rf'(?P<head>{_Q}y{_Q}:-?[0-9.eE+-]+(?:,{_Q}role{_Q}:{_Q}[a-z]+{_Q})?)'
    rf'(?P<names>(?:,{_Q}name{_Q}:{_Q}[a-z]+{_Q})(?:,{_Q}epithet{_Q}:true)?'
    rf'(?:,{_Q}customName{_Q}:{_ESC_STR})?'
    rf'(?:,{_Q}trait{_Q}:{_Q}[a-zA-Z]+{_Q})?)'
    r'(?=\})'
)


def strip_text(text: str) -> tuple[str, int]:
    count = 0

    def cut(m: re.Match[str]) -> str:
        nonlocal count
        count += 1
        return m.group('head')

    text = _CAPY_TAIL.sub(cut, text)
    return _CAPY_TAIL_ESC.sub(cut, text), count


def strip_data(v: object) -> object:
    if isinstance(v, dict):
        capy = 'id' in v and 'level' in v
        return {
            k: strip_data(x)
            for k, x in v.items()
            if not (capy and k in KEYS)
        }
    if isinstance(v, list):
        return [strip_data(x) for x in v]
    if isinstance(v, str) and v.startswith('{'):
        # A save blob kept as a string: compare what it holds.
        try:
            return {'<json>': strip_data(json.loads(v))}
        except ValueError:
            return v
    return v


def old_file(ref: str, rel: str) -> str | None:
    try:
        raw = subprocess.run(
            ['git', 'show', f'{ref}:{rel}'],
            cwd=ROOT, check=True, capture_output=True,
        ).stdout
    except subprocess.CalledProcessError:
        return None
    return raw.decode('utf-8').replace('\r\n', '\n')


def main() -> int:
    ref = sys.argv[1] if len(sys.argv) > 1 else 'main'
    files = sorted((ROOT / DIR).glob('*.jsonl'))
    ok = True
    total = 0
    for path in files:
        rel = f'{DIR}/{path.name}'
        new = path.read_text(encoding='utf-8').replace('\r\n', '\n')
        old = old_file(ref, rel)
        if old is None:
            print(f'{path.name}: not in {ref}')
            ok = False
            continue
        cut, count = strip_text(new)
        total += count
        text_same = cut == old
        old_lines = [strip_data(json.loads(x)) for x in old.splitlines() if x]
        new_lines = [strip_data(json.loads(x)) for x in new.splitlines() if x]
        data_same = old_lines == new_lines
        changed = new != old
        print(
            f'{path.name}: names cut {count}, '
            f'text {"same" if text_same else "DIFFERS"}, '
            f'data {"same" if data_same else "DIFFERS"}'
            f'{"" if changed else " (file unchanged)"}'
        )
        if not (text_same and data_same):
            ok = False
            a, b = old.split('\n'), cut.split('\n')
            for i in range(max(len(a), len(b))):
                x = a[i] if i < len(a) else '<none>'
                y = b[i] if i < len(b) else '<none>'
                if x != y:
                    print(f'  first difference at line {i + 1}')
                    print(f'  old: {x[:300]}')
                    print(f'  new: {y[:300]}')
                    break
    print(f'capy name groups cut: {total}')
    print('OK: only names and traits differ' if ok else 'FAIL')
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
