#!/usr/bin/env python3
"""Spec 006, Т15: the behavior fingerprint changed only where the plan says.

For every `test/fixtures/fingerprint/*.jsonl`, takes the old file from a git
ref (default `origin/main`) and the new one from the working tree, normalizes both
line by line and reports, per file, how far they stay equal:

- the probe key `mergeFlash` is renamed `flash` (old file);
- the new probe key `placesUsed` is dropped (new file);
- `goalProgress` is dropped (new glade thresholds, both files).

The expected differences are listed in `specs/006-kuchka/plan.md` (Т15):
`live_tick` and `save_store` equal throughout; `session` equal up to the
step `grass boost over`; the sims differ from the first line on (new
player script).

Usage (repo root): python tool/fingerprint_pile_diff.py [ref]
(ref: the main the branch grew from, e.g. `origin/main`; default `origin/main`)
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DIR = 'test/fixtures/fingerprint'


def normalize(line: str, old: bool) -> object:
    data = json.loads(line)
    if not isinstance(data, dict):
        return data
    if old and 'mergeFlash' in data:
        data['flash'] = data.pop('mergeFlash')
    data.pop('placesUsed', None)
    data.pop('goalProgress', None)
    return data


def differing_keys(a: object, b: object) -> list[str]:
    if not isinstance(a, dict) or not isinstance(b, dict):
        return ['<value>']
    return sorted(
        k
        for k in set(a) | set(b)
        if json.dumps(a.get(k), sort_keys=True)
        != json.dumps(b.get(k), sort_keys=True)
    )


def main() -> int:
    ref = sys.argv[1] if len(sys.argv) > 1 else 'origin/main'
    for path in sorted((ROOT / DIR).glob('*.jsonl')):
        rel = f'{DIR}/{path.name}'
        old_text = subprocess.run(
            ['git', 'show', f'{ref}:{rel}'],
            cwd=ROOT,
            capture_output=True,
            text=True,
            encoding='utf-8',
            check=True,
        ).stdout
        new_text = path.read_text(encoding='utf-8')
        old = [l for l in old_text.replace('\r\n', '\n').split('\n') if l]
        new = [l for l in new_text.replace('\r\n', '\n').split('\n') if l]
        equal = 0
        first = None
        for i, (a, b) in enumerate(zip(old, new)):
            na = normalize(a, old=True)
            nb = normalize(b, old=False)
            if na == nb:
                equal += 1
                continue
            first = (i, na, nb)
            break
        name = path.stem
        if first is None and len(old) == len(new):
            print(f'{name}: EQUAL after normalization ({len(new)} lines)')
            continue
        if first is None:
            print(
                f'{name}: equal for {equal} lines, then lengths differ '
                f'(old {len(old)}, new {len(new)})'
            )
            continue
        i, na, nb = first
        step_old = na.get('step') if isinstance(na, dict) else None
        step_new = nb.get('step') if isinstance(nb, dict) else None
        keys = differing_keys(na, nb)
        last = None
        if i > 0:
            prev = normalize(new[i - 1], old=False)
            last = prev.get('step') if isinstance(prev, dict) else None
        print(
            f'{name}: equal for {equal} lines (last equal step: {last!r}); '
            f'first difference at line {i + 1}, step old={step_old!r} '
            f'new={step_new!r}, keys {keys}'
        )
    return 0


if __name__ == '__main__':
    sys.exit(main())
