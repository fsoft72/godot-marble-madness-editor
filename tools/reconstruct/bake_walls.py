"""Bakes the shadow of the yellow (+Z) walls of the reference: for every 1/8 unit column of
every wall, the depth interval below the wall top that is orange (in the shadow) in the
reference. Output: {(bx, bz): 3 rows x 24 [start, end]} for the block "wallShadow" field."""
from collections import defaultdict

import numpy as np

from assemble import _tile_tuple
from vertices import HS, height
from walls import wall_kind, YELLOW, ORANGE
from zrender import render_into, WALL_Z, H, W

SAMPLES = 8
NONE = [-1.0, -1.0]
MAX_DEPTH = 63.0


def _wall_state(img):
    """Per pixel: 1 lit yellow wall, 2 shadowed (orange) wall, 0 other; seams take the state
    of the stripe next to them."""
    state = np.zeros(img.shape[:2], int)
    state[(img == np.array(YELLOW)).all(2)] = 1
    state[(img == np.array(ORANGE)).all(2)] = 2
    gray = (img[:, :, 0] == img[:, :, 1]) & (img[:, :, 1] == img[:, :, 2])
    for dx in (1, -1, 2, -2):
        nb = np.roll(state, dx, axis=1)
        fill = gray & (state == 0) & (nb > 0)
        state[fill] = nb[fill]
    return state


def bake_walls(img, fit_tiles, verts, offsets, sy0, origin):
    """Returns {(bx, bz): wallShadow rows} for blocks with observed +Z wall pixels."""
    keys = {(c, k, m, o) for (c, k, m), o in offsets.items()}
    order = [key for key in fit_tiles if key in offsets]
    tiles = [_tile_tuple(fit_tiles, verts, key, offsets[key], keys, sy0) for key in order]
    owner = np.full((H, W), -1, int)
    _, cls = render_into(tiles, np.full((H, W), -1e9), np.zeros((H, W), int), owner)
    state = _wall_state(img)
    x0, z0 = origin
    samples = defaultdict(list)
    ys, xs = np.nonzero((cls == WALL_Z) & (state > 0))
    for py, px in zip(ys, xs):
        comp, k, m = order[owner[py, px]]
        off = offsets[(comp, k, m)]
        mm = m + off
        tx, tz = (mm + k) // 2, (mm - k) // 2  # lattice tile
        ez = tz + 1                            # wall plane z (lattice)
        xl = (px + 0.5) / 8.0 + ez             # lattice x of the pixel on the plane z = ez
        fu = xl - tx
        if fu < 0 or fu > 1: continue
        y = (4.0 * (xl + ez) + sy0 - (py + 0.5)) / HS
        h01 = height(m + 1 + off, verts[(comp, k - 1, m + 1)], sy0)
        h11 = height(m + 2 + off, verts[(comp, k, m + 2)], sy0)
        depth = h01 + (h11 - h01) * fu - y
        wx, wz = tx + x0, tz + z0
        bx, bz = wx // 3, wz // 3
        col = int(np.floor((wx - bx * 3 + fu) * SAMPLES))
        samples[(bx, bz, wz % 3, min(col, 3 * SAMPLES - 1))].append((depth, state[py, px] == 2))
    out = {}
    for (bx, bz, row, col), vals in samples.items():
        rows = out.setdefault((bx, bz), [[NONE] * (3 * SAMPLES) for _ in range(3)])
        shadow = [d for d, s in vals if s]
        if not shadow:
            rows[row][col] = [0.0, 0.0]
            continue
        lo = max(min(shadow) - 0.5 / HS, 0.0)
        hi = max(shadow) + 0.5 / HS
        # Shadow reaching the lowest observed pixel continues below it.
        if max(shadow) >= max(d for d, s in vals) - 1e-6: hi = MAX_DEPTH
        rows[row][col] = [round(lo, 3), round(min(hi, MAX_DEPTH), 3)]
    return out
