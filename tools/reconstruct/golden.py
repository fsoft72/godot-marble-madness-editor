#!/usr/bin/env python3
"""Writes tests/golden/level01_surface.json from data/level01.json with an independent Python
evaluation of the per tile surface heights ("tiles" blocks, main / anti diagonal split), so
the GDScript BlockSurface.surface_y is checked against a second implementation.

Usage: python3 tools/reconstruct/golden.py
"""
import json
import os
import random

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
SAMPLES = [0.0, 0.25, 0.5, 1.5, 2.2, 2.75]


def tile_y(block, u, v):
    """Height of a "tiles" block at local (u, v); holes give the elevation."""
    c = min(int(u if u < 3 else 2), 2)
    r = min(int(v if v < 3 else 2), 2)
    t = block['tiles'][r][c]
    e = block['elevation']
    if t is None: return e
    fu, fv = u - c, v - r
    h00, h10, h01, h11 = t
    if block['tileSplit'][r][c] == 'anti':
        if fu + fv <= 1: return e + h00 + (h10 - h00) * fu + (h01 - h00) * fv
        return e + h11 + (h01 - h11) * (1 - fu) + (h10 - h11) * (1 - fv)
    if fu >= fv: return e + h00 * (1 - fu) + h10 * (fu - fv) + h11 * fv
    return e + h00 * (1 - fv) + h01 * (fv - fu) + h11 * fu


def main():
    level = json.load(open(os.path.join(ROOT, 'data', 'level01.json')))
    rng = random.Random(1)
    blocks = sorted(level['blocks'].values(), key=lambda b: (b['bx'], b['bz']))
    samples = []
    for b in rng.sample(blocks, min(40, len(blocks))):
        for _ in range(5):
            u, v = rng.choice(SAMPLES), rng.choice(SAMPLES)
            samples.append({'bx': b['bx'], 'bz': b['bz'], 'u': u, 'v': v, 'y': round(tile_y(b, u, v), 6)})
    out = {'block_count': len(blocks), 'cols': level['cols'], 'rows': level['rows'], 'samples': samples}
    with open(os.path.join(ROOT, 'tests', 'golden', 'level01_surface.json'), 'w') as f:
        json.dump(out, f, indent=1)
        f.write('\n')
    print(f'golden: {len(samples)} samples')


if __name__ == '__main__':
    main()
