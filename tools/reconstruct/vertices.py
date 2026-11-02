"""Vertex height estimation from the tile fills.

A tile (k, m) has its top vertex at lattice point (k, m), right (k + 1, m + 1), bottom
(k, m + 2) and left (k - 1, m + 1). Lattice point (kv, mv) is world (x, z) with
x - z = kv, x + z = mv. Its screen position is sx = 8 kv, sy = 4 mv - HS * y + SY0.
"""
from collections import defaultdict

import numpy as np

# Logical pixels per world unit of height: true orthographic camera at 30 degrees pitch
# (16 / sqrt(2) * cos(30 deg)).
HS = 16.0 / np.sqrt(2.0) * np.cos(np.pi / 6.0)
# Offsets calibrated on a flat tile: fill starts 2 rows below the top vertex, ends 2 rows
# above the bottom vertex; the side vertices sit half a pixel above the side pixel centers.
TOP_GAP = 2.0
BOTTOM_GAP = 2.0
SIDE_BIAS = -0.5
# Weight of side estimates against top and bottom estimates.
SIDE_WEIGHT = 0.35


def tile_corner_estimates(t):
    """Returns [(kv, mv, sy, weight)] screen row estimates of the corners of tile t."""
    ys = t.pixels[:, 0].astype(float)
    xs = t.pixels[:, 1]
    out = []
    col = (xs == 8 * t.k - 1) | (xs == 8 * t.k)
    if col.any():
        out.append((t.k, t.m, ys[col].min() - TOP_GAP, 1.0))
        out.append((t.k, t.m + 2, ys[col].max() + 1 + BOTTOM_GAP, 1.0))
    left = xs == xs.min()
    right = xs == xs.max()
    if xs.min() < 8 * t.k - 3:
        out.append((t.k - 1, t.m + 1, ys[left].mean() + 0.5 + SIDE_BIAS, SIDE_WEIGHT))
    if xs.max() > 8 * t.k + 2:
        out.append((t.k + 1, t.m + 1, ys[right].mean() + 0.5 + SIDE_BIAS, SIDE_WEIGHT))
    return out


def estimate(tiles):
    """Returns {(comp, kv, mv): sy} weighted mean screen rows of all lattice vertices."""
    acc = defaultdict(lambda: [0.0, 0.0])
    for t in tiles:
        if t.comp < 0: continue
        for kv, mv, sy, w in tile_corner_estimates(t):
            a = acc[(t.comp, kv, mv)]
            a[0] += sy * w
            a[1] += w
    return {key: s / w for key, (s, w) in acc.items()}


def height(mv, sy, sy0):
    """World height of a lattice vertex from its screen row."""
    return (4.0 * mv + sy0 - sy) / HS
