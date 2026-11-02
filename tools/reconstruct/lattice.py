"""Lattice assignment: links neighboring tiles and gives each a depth index m inside its
connected surface component (see tiles.py for the coordinates)."""
from collections import deque, defaultdict

import numpy as np
from scipy import ndimage

DILATE = 2


def neighbors(tiles, labels):
    """Returns {tile id: set of tile ids} of tiles whose fills are within DILATE pixels."""
    nb = defaultdict(set)
    struct = np.ones((2 * DILATE + 1, 2 * DILATE + 1), bool)
    h, w = labels.shape
    for t in tiles:
        y0, x0 = t.pixels.min(0) - DILATE - 1
        y1, x1 = t.pixels.max(0) + DILATE + 2
        y0, x0 = max(y0, 0), max(x0, 0)
        y1, x1 = min(y1, h), min(x1, w)
        mask = np.zeros((y1 - y0, x1 - x0), bool)
        mask[t.pixels[:, 0] - y0, t.pixels[:, 1] - x0] = True
        grown = ndimage.binary_dilation(mask, struct)
        for other in np.unique(labels[y0:y1, x0:x1][grown]):
            if other == 0 or other - 1 == t.id: continue
            nb[t.id].add(int(other) - 1)
    return nb


def edge_step(a, b):
    """Returns (step, confidence) for tile a to its edge neighbor b (|dk| = 1): step +1 when
    their shared edge is below a's center and above b's center, -1 for the opposite, 0 when
    unclear. The shared edge is located at the closest pairs of fill pixels; the confidence is
    the smaller distance in pixels of that edge from the two centers."""
    pa = a.pixels.astype(float)
    pb = b.pixels.astype(float)
    d = ((pa[:, None, :] - pb[None, :, :]) ** 2).sum(2)
    close = d <= d.min() + 2.0
    ia, ib = np.nonzero(close)
    mid_y = ((pa[ia, 0] + pb[ib, 0]) / 2).mean() + 0.5
    da = mid_y - a.cy
    db = b.cy - mid_y
    conf = min(abs(da), abs(db))
    if da > 0 and db > 0: return 1, conf
    if da < 0 and db < 0: return -1, conf
    return 0, 0.0


class _OffsetUnion:
    """Union-find that keeps the m offset of every node from its root."""

    def __init__(self, n):
        self.parent = list(range(n))
        self.offset = [0] * n

    def find(self, i):
        """Returns (root, offset of i from the root), compressing the path."""
        if self.parent[i] == i: return i, 0
        root, off = self.find(self.parent[i])
        self.parent[i] = root
        self.offset[i] += off
        return root, self.offset[i]

    def union(self, a, b, step):
        """Links b = a + step; returns False when it contradicts the known offsets."""
        ra, oa = self.find(a)
        rb, ob = self.find(b)
        if ra == rb: return oa + step == ob
        self.parent[rb] = ra
        self.offset[rb] = oa + step - ob
        return True


def assign(tiles, nb, min_conf=0.6):
    """Gives every tile a component and a relative m: edges are added most confident first
    (maximum spanning forest); contradicting edges are returned as conflicts (a, b, step)."""
    edges = []
    for a in tiles:
        for bid in nb[a.id]:
            b = tiles[bid]
            if bid < a.id or abs(b.k - a.k) != 1: continue
            step, conf = edge_step(a, b)
            if step == 0 or conf < min_conf: continue
            edges.append((conf, a.id, bid, step))
    edges.sort(reverse=True)
    uf = _OffsetUnion(len(tiles))
    conflicts = []
    for conf, a, b, step in edges:
        if not uf.union(a, b, step): conflicts.append((a, b, step, conf))
    roots = {}
    for t in tiles:
        root, off = uf.find(t.id)
        t.comp = roots.setdefault(root, len(roots))
        t.m = off
    # Normalize: parity of m follows k, smallest m of a component near 0.
    by_comp = {}
    for t in tiles: by_comp.setdefault(t.comp, []).append(t)
    for group in by_comp.values():
        base = min(t.m for t in group)
        shift = -base
        if (group[0].m + shift - group[0].k) % 2: shift += 1
        for t in group: t.m += shift
    return conflicts
