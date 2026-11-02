"""Detection of the top surface tiles in the arcade reference image.

Coordinates: logical pixels (the reference is 2x pixel art). A tile (x, z) has its column
k = x - z: its top and bottom corners lie on the pixel boundary sx = 8k, its left and right
corners on sx = 8k -+ 8. Its depth index m = x + z grows by one per neighbor toward the viewer.
"""
from dataclasses import dataclass, field

import numpy as np
from PIL import Image
from scipy import ndimage

# Gray ladder of the arcade palette: level 0 (darkest) .. 5 (white).
GRAY_LEVELS = {51: 0, 68: 1, 102: 2, 153: 3, 187: 4, 221: 5}
# Red decal ladder, same offsets as the gray ladder.
RED_LEVELS = {(102, 0, 0): 0, (102, 34, 34): 1, (136, 34, 34): 2, (170, 34, 34): 3, (221, 51, 51): 4, (255, 136, 136): 5}
MIN_FILL = 14
MAX_FILL = 90
MIN_W = 4
MIN_H = 3
# Largest screen box of one tile cell (steep slopes make tiles taller than 8 pixels).
CELL_MAX_W = 17
CELL_MAX_H = 16


@dataclass
class Tile:
    """One detected tile fill (or half tile) component."""
    id: int
    level: int
    ramp: int
    pixels: np.ndarray  # (n, 2) rows, cols
    cx: float
    cy: float
    k: int = 0
    comp: int = -1
    m: int | None = None
    parts: list = field(default_factory=list)


def load_logical(path):
    """Returns the logical (every second) pixels of a 2x image as an int RGB array."""
    img = np.array(Image.open(path).convert('RGB')).astype(int)
    return img[::2, ::2]


def level_map(img):
    """Returns (level, ramp) per pixel: ramp 0 gray, 1 red, -1 other colors."""
    lv = np.full(img.shape[:2], -1, int)
    ramp = np.full(img.shape[:2], -1, int)
    gray = (img[:, :, 0] == img[:, :, 1]) & (img[:, :, 1] == img[:, :, 2])
    for v, i in GRAY_LEVELS.items():
        sel = gray & (img[:, :, 0] == v)
        lv[sel] = i
        ramp[sel] = 0
    for c, i in RED_LEVELS.items():
        sel = (img == np.array(c)).all(axis=2)
        lv[sel] = i
        ramp[sel] = 1
    return lv, ramp


def detect(img):
    """Returns the list of tile fill components and the label image (id + 1, 0 = none)."""
    lv, ramp = level_map(img)
    labels = np.zeros(lv.shape, int)
    tiles = []
    for r in (0, 1):
        for lev in range(6):
            lab, _ = ndimage.label((lv == lev) & (ramp == r))
            for i, sl in enumerate(ndimage.find_objects(lab)):
                mask = lab[sl] == i + 1
                n = int(mask.sum())
                h = sl[0].stop - sl[0].start
                w = sl[1].stop - sl[1].start
                if n < MIN_FILL or n > MAX_FILL or w < MIN_W or h < MIN_H: continue
                ys, xs = np.nonzero(mask)
                ys = ys + sl[0].start
                xs = xs + sl[1].start
                t = Tile(len(tiles), lev, r, np.stack([ys, xs], 1), xs.mean() + 0.5, ys.mean() + 0.5)
                t.k = int(round(t.cx / 8.0))
                labels[ys, xs] = t.id + 1
                tiles.append(t)
    return tiles, labels


def merge_cells(tiles, labels):
    """Merges fill components that touch directly (no line pixel between them: split shading,
    a shadow edge or decal paint crossing one tile) into one cell, while the union still fits
    a tile box. Returns (cells, cell label image); each cell keeps its parts in `parts`."""
    parent = list(range(len(tiles)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    boxes = {t.id: [t.pixels[:, 0].min(), t.pixels[:, 1].min(), t.pixels[:, 0].max(), t.pixels[:, 1].max()] for t in tiles}
    pairs = set()
    for dy, dx in ((0, 1), (1, 0)):
        a = labels[:labels.shape[0] - dy, :labels.shape[1] - dx]
        b = labels[dy:, dx:]
        sel = (a > 0) & (b > 0) & (a != b)
        for p, q in zip(a[sel], b[sel]): pairs.add((min(p, q) - 1, max(p, q) - 1))
    # Merge smallest unions first so that two tiles are not glued by a big shadow sliver.
    def union_box(i, j):
        bi, bj = boxes[find(i)], boxes[find(j)]
        return [min(bi[0], bj[0]), min(bi[1], bj[1]), max(bi[2], bj[2]), max(bi[3], bj[3])]
    for i, j in sorted(pairs, key=lambda pq: len(tiles[pq[0]].pixels) + len(tiles[pq[1]].pixels)):
        ri, rj = find(i), find(j)
        if ri == rj: continue
        box = union_box(i, j)
        if box[3] - box[1] + 1 > CELL_MAX_W or box[2] - box[0] + 1 > CELL_MAX_H: continue
        parent[rj] = ri
        boxes[ri] = box
    groups = {}
    for t in tiles: groups.setdefault(find(t.id), []).append(t)
    cells = []
    cell_labels = np.zeros(labels.shape, int)
    for members in groups.values():
        pix = np.concatenate([t.pixels for t in members])
        main = max(members, key=lambda t: len(t.pixels))
        cell = Tile(len(cells), main.level, main.ramp, pix, pix[:, 1].mean() + 0.5, pix[:, 0].mean() + 0.5)
        cell.k = int(round(cell.cx / 8.0))
        cell.parts = members
        cell_labels[pix[:, 0], pix[:, 1]] = cell.id + 1
        cells.append(cell)
    return cells, cell_labels
