"""Builds a level JSON (blocks with per tile corners) from the reconstructed lattice."""
import json
from collections import defaultdict

import numpy as np

from vertices import HS, height

BLOCK = 3
SHADE_LEVELS = [0.2, 0.27, 0.35, 0.52, 0.75, 0.99]


def tile_shades(group):
    """Returns the shade entry of a tile from its fill components: one value, or [first, second]
    triangle values for split tiles, plus the split ("main" splits left/right on screen,
    "anti" splits top/bottom)."""
    if len(group) == 1:
        return SHADE_LEVELS[group[0].level], None
    group = sorted(group, key=lambda t: -len(t.pixels))[:2]
    a, b = group
    dx = abs(a.cx - b.cx)
    dy = abs(a.cy - b.cy)
    if dx >= dy:
        left, right = (a, b) if a.cx < b.cx else (b, a)
        return [SHADE_LEVELS[left.level], SHADE_LEVELS[right.level]], 'main'
    top, bottom = (a, b) if a.cy < b.cy else (b, a)
    return [SHADE_LEVELS[top.level], SHADE_LEVELS[bottom.level]], 'anti'


def build(fit_tiles, verts, offsets, sy0, origin, paint=None):
    """Returns the level dictionary from the fit.

    fit_tiles: {(comp, k, m): [level0, level1, split]}; verts: {(comp, kv, mv): sy};
    offsets: {tile key: m offset} (tiles missing from it are skipped);
    origin: world tile coordinates (x0, z0) of lattice x = 0, z = 0.
    """
    blocks = {}
    x0, z0 = origin
    for (comp, k, m), (lv0, lv1, split) in fit_tiles.items():
        if (comp, k, m) not in offsets: continue
        off = offsets[(comp, k, m)]
        corners = [(k, m), (k + 1, m + 1), (k - 1, m + 1), (k, m + 2)]  # h00, h10, h01, h11
        hs = [height(mv + off, verts[(comp, kv, mv)], sy0) for kv, mv in corners]
        x = (m + off + k) // 2 + x0
        z = (m + off - k) // 2 + z0
        bx, bz = x // BLOCK, z // BLOCK
        c, r = x % BLOCK, z % BLOCK
        b = blocks.setdefault((bx, bz), {'tiles': [[None] * 3 for _ in range(3)], 'shades': [[None] * 3 for _ in range(3)], 'splits': [['main'] * 3 for _ in range(3)]})
        if b['tiles'][r][c] is not None:
            # Two components claim the same tile: keep the higher one (it is the visible one).
            if max(b['tiles'][r][c]) >= max(hs): continue
        b['tiles'][r][c] = hs
        b['shades'][r][c] = SHADE_LEVELS[lv0] if lv0 == lv1 else [SHADE_LEVELS[lv0], SHADE_LEVELS[lv1]]
        b['splits'][r][c] = split
    out = {}
    max_b = 0
    for (bx, bz), b in sorted(blocks.items()):
        if bx < 0 or bz < 0: raise SystemExit(f'block out of grid: {bx},{bz}; move the origin')
        max_b = max(max_b, bx + 1, bz + 1)
        vals = [h for row in b['tiles'] for t in row if t for h in t]
        elev = round(float(np.floor(min(vals) * 100) / 100), 2)
        tiles_rel = [[None if t is None else [round(h - elev, 4) for h in t] for t in row] for row in b['tiles']]
        out[f'{bx},{bz}'] = {
            'bx': bx, 'bz': bz, 'isVoid': False, 'elevation': elev, 'slope': 0, 'tilt': 0,
            'rotation': 0, 'shape': 'flat', 'element': 'none', 'elemRotation': 0,
            'decal': 'none', 'decalRotation': 0, 'tiles': tiles_rel, 'tileSplit': b['splits'],
            'subShades': b['shades'],
        }
        if paint and (bx, bz) in paint: out[f'{bx},{bz}']['paint'] = paint[(bx, bz)]
    return {'version': 1, 'cols': max_b, 'rows': max_b, 'blocks': out}


def lattice_bounds(fit_tiles, offsets):
    """Returns (min x, min z, max x, max z) of the placed tiles in lattice coordinates."""
    xs, zs = [], []
    for (comp, k, m) in fit_tiles:
        if (comp, k, m) not in offsets: continue
        mm = m + offsets[(comp, k, m)]
        xs.append((mm + k) // 2)
        zs.append((mm - k) // 2)
    return min(xs), min(zs), max(xs), max(zs)
