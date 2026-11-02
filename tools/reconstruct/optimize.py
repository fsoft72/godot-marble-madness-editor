"""Fits vertex screen rows, tile shade levels and diagonal splits to the reference by
coordinate descent on the exact pixel match of the Python rasterizer (raster.py)."""
from collections import defaultdict

import numpy as np

from raster import raster_tile, corners_of

H, W = 590, 288
SPLITS = ('main', 'anti')


class Fit:
    """Holds the tiles {(comp, k, m): [level0, level1, split]} and vertices
    {(comp, kv, mv): sy} of the fit, scored against the reference level map."""

    def __init__(self, ref_levels, tiles, verts):
        self.ref = ref_levels
        self.tiles = tiles
        self.verts = verts
        self.vert_tiles = defaultdict(list)
        for key in tiles:
            for v in self.corner_keys(key):
                self.vert_tiles[v].append(key)

    @staticmethod
    def corner_keys(key):
        """Returns the vertex keys (top, right, left, bottom) of a tile key."""
        comp, k, m = key
        return [(comp, k, m), (comp, k + 1, m + 1), (comp, k - 1, m + 1), (comp, k, m + 2)]

    def tile_score(self, key, levels=None, split=None):
        """Returns (score, matched, covered) of one tile: +1 per matching pixel, -1 per other."""
        lv0, lv1, sp = self.tiles[key]
        if levels is not None: lv0, lv1 = levels
        if split is not None: sp = split
        comp = key[0]
        c = corners_of(key[1], key[2], lambda kv, mv: self.verts[(comp, kv, mv)])
        ys, xs, lev = raster_tile(c, (lv0, lv1), sp)
        inb = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
        ys, xs, lev = ys[inb], xs[inb], lev[inb]
        hit = int((self.ref[ys, xs] == lev).sum())
        return 2 * hit - len(lev), hit, len(lev)

    def vertex_score(self, v):
        """Sum of the scores of the tiles around a vertex."""
        return sum(self.tile_score(key)[0] for key in self.vert_tiles[v])

    def refine_vertices(self, radius=2.0, step=0.25):
        """One sweep over all vertices; returns the number of changed vertices."""
        changed = 0
        for v in list(self.vert_tiles):
            base = self.verts[v]
            best = (self.vertex_score(v), 0.0)
            for d in np.arange(-radius, radius + 1e-9, step):
                if d == 0: continue
                self.verts[v] = base + d
                s = self.vertex_score(v)
                if s > best[0]: best = (s, d)
            self.verts[v] = base + best[1]
            if best[1] != 0: changed += 1
        return changed

    def refine_levels(self):
        """Picks the best level pair and split of every tile; returns the number changed."""
        changed = 0
        for key, (lv0, lv1, sp) in self.tiles.items():
            best = (self.tile_score(key)[0], lv0, lv1, sp)
            for split in SPLITS:
                for a in range(6):
                    for b in range(6):
                        s = self.tile_score(key, (a, b), split)[0]
                        if s > best[0]: best = (s, a, b, split)
            if best[1:] != (lv0, lv1, sp):
                self.tiles[key] = list(best[1:])
                changed += 1
        return changed

    def total(self):
        """Returns (matched pixels, covered pixels) of all tiles."""
        hit = cov = 0
        for key in self.tiles:
            _, h, c = self.tile_score(key)
            hit += h
            cov += c
        return hit, cov


def _edge_neighbors(key):
    """Returns [(neighbor key, shared vertex pair of key, far pair mapping)] for the four edge
    neighbors of a tile. Each item: (nkey, [(shared_v, mirror_src)], ...)."""
    comp, k, m = key
    return [(comp, k + 1, m + 1), (comp, k - 1, m + 1), (comp, k + 1, m - 1), (comp, k - 1, m - 1)]


class Grower:
    """Region growing by analysis by synthesis: proposes tiles next to the fitted ones,
    extrapolates their missing vertices, fits them and keeps those that explain reference
    pixels no other tile explains."""

    def __init__(self, fit, min_ratio=0.62, min_pixels=12):
        self.fit = fit
        self.min_ratio = min_ratio
        self.min_pixels = min_pixels

    def _explained(self):
        """Mask of reference pixels matched by the current tiles."""
        mask = np.zeros(self.fit.ref.shape, bool)
        cover = np.zeros(self.fit.ref.shape, bool)
        for key, (l0, l1, sp) in self.fit.tiles.items():
            comp = key[0]
            c = corners_of(key[1], key[2], lambda kv, mv: self.fit.verts[(comp, kv, mv)])
            ys, xs, lev = raster_tile(c, (l0, l1), sp)
            inb = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
            ys, xs, lev = ys[inb], xs[inb], lev[inb]
            cover[ys, xs] = True
            mask[ys[self.fit.ref[ys, xs] == lev], xs[self.fit.ref[ys, xs] == lev]] = True
        return mask, cover

    def _extrapolate(self, key):
        """Fills missing vertices of tile key by linear continuation of the known neighbors.
        Returns the list of new vertex keys, or None when it cannot."""
        comp, k, m = key
        corners = Fit.corner_keys(key)
        new = [v for v in corners if v not in self.fit.verts]
        if len(new) > 2: return None
        V = self.fit.verts
        for v in new:
            _, kv, mv = v
            ests = []
            # Continue straight lines through the lattice: v = 2 * a - b along the 4 lattice axes.
            for dk, dm in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                a = (comp, kv + dk, mv + dm)
                b = (comp, kv + 2 * dk, mv + 2 * dm)
                if a in V and b in V: ests.append(2 * V[a] - V[b] - 4 * 0 + (0))
            if not ests:
                for dk, dm in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                    a = (comp, kv + dk, mv + dm)
                    if a in V: ests.append(V[a] - 4 * dm)
            if not ests: return None
            V[v] = float(np.mean(ests))
        return new

    def step(self, log=print):
        """One growth round; returns the number of added tiles."""
        explained, cover = self._explained()
        cands = set()
        for key in self.fit.tiles:
            for n in _edge_neighbors(key):
                if n not in self.fit.tiles: cands.add(n)
        added = 0
        for key in sorted(cands):
            new = self._extrapolate(key)
            if new is None: continue
            self.fit.tiles[key] = [4, 4, 'main']
            for v in Fit.corner_keys(key): self.fit.vert_tiles[v].append(key)
            # Fit the new vertices, then the levels of the tile.
            for _ in range(2):
                for v in new:
                    base = self.fit.verts[v]
                    best = (self.fit.tile_score(key)[0], 0.0)
                    for d in np.arange(-4.0, 4.01, 0.5):
                        self.fit.verts[v] = base + d
                        s = self.fit.tile_score(key)[0]
                        if s > best[0]: best = (s, d)
                    self.fit.verts[v] = base + best[1]
                best = (-1e9, 4, 4, 'main')
                for sp in SPLITS:
                    for a in range(6):
                        for b in range(6):
                            s = self.fit.tile_score(key, (a, b), sp)[0]
                            if s > best[0]: best = (s, a, b, sp)
                self.fit.tiles[key] = list(best[1:])
            comp = key[0]
            c = corners_of(key[1], key[2], lambda kv, mv: self.fit.verts[(comp, kv, mv)])
            ys, xs, lev = raster_tile(c, self.fit.tiles[key][:2], self.fit.tiles[key][2])
            inb = (ys >= 0) & (ys < H) & (xs >= 0) & (xs < W)
            ys, xs, lev = ys[inb], xs[inb], lev[inb]
            free = ~explained[ys, xs]
            hit_free = int(((self.fit.ref[ys, xs] == lev) & free).sum())
            ok = len(lev) >= self.min_pixels and free.sum() > 0 and hit_free >= self.min_ratio * free.sum() and free.mean() > 0.5
            if ok:
                explained[ys[self.fit.ref[ys, xs] == lev], xs[self.fit.ref[ys, xs] == lev]] = True
                added += 1
                continue
            del self.fit.tiles[key]
            for v in Fit.corner_keys(key): self.fit.vert_tiles[v].remove(key)
            for v in new:
                if not self.fit.vert_tiles[v]:
                    del self.fit.verts[v]
                    del self.fit.vert_tiles[v]
        return added
