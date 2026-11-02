"""Links components through cliff walls: scanning a screen column down, a tile of component
A, then wall pixels, then a tile of component B means that B touches the foot of A's wall.
Crimson walls face +X (B is at x_A + 1), yellow and orange walls face +Z (z_B = z_A + 1)."""
from collections import Counter, defaultdict

import numpy as np

YELLOW = (204, 204, 0)
ORANGE = (204, 102, 0)
CRIMSON = (136, 34, 34)
MAX_GAP = 3


def wall_kind(img):
    """Returns per pixel 1 for +X walls (crimson), 2 for +Z walls (yellow, orange), 0 else."""
    kind = np.zeros(img.shape[:2], int)
    kind[(img == np.array(CRIMSON)).all(2)] = 1
    kind[(img == np.array(YELLOW)).all(2) | (img == np.array(ORANGE)).all(2)] = 2
    return kind


def votes(tiles, labels, img):
    """Returns Counter {(comp_a, comp_b, delta): n} with delta = offset_b - offset_a."""
    kind = wall_kind(img)
    h, w = labels.shape
    out = Counter()
    for x in range(w):
        y = 0
        while y < h:
            a = labels[y, x]
            if a == 0:
                y += 1
                continue
            # Walk to the end of this tile in the column.
            while y < h and labels[y, x] == a: y += 1
            gap = 0
            while y < h and labels[y, x] == 0 and kind[y, x] == 0 and gap < MAX_GAP:
                y += 1
                gap += 1
            if y >= h or kind[y, x] == 0: continue
            counts = Counter()
            while y < h and labels[y, x] == 0:
                if kind[y, x]: counts[kind[y, x]] += 1
                y += 1
            if y >= h or not counts: continue
            b = labels[y, x]
            face = counts.most_common(1)[0][0]
            ta, tb = tiles[a - 1], tiles[b - 1]
            # A crimson wall hangs right of A's bottom vertex and stands left of B's top vertex;
            # a yellow wall the other way around.
            right_of_a = x >= 8 * ta.k
            right_of_b = x >= 8 * tb.k
            if face == 1 and not (right_of_a and not right_of_b): continue
            if face == 2 and not (not right_of_a and right_of_b): continue
            if face == 1:
                delta = 2 + (ta.m + ta.k) - (tb.m + tb.k)
            else:
                delta = 2 + (ta.m - ta.k) - (tb.m - tb.k)
            out[(ta.comp, tb.comp, delta)] += 1
    return out


def solve_offsets(vote_counts, root, min_votes=3):
    """Spanning tree of component offsets from the root, strongest links first.
    Returns ({comp: offset}, report lines)."""
    best = defaultdict(Counter)
    for (a, b, d), n in vote_counts.items():
        if a == b: continue
        best[(a, b)][d] += n
        best[(b, a)][-d] += n
    edges = []
    for (a, b), cnt in best.items():
        d, n = cnt.most_common(1)[0]
        if n >= min_votes: edges.append((n, a, b, d, sum(cnt.values())))
    edges.sort(reverse=True)
    offsets = {root: 0}
    report = []
    grown = True
    while grown:
        grown = False
        for n, a, b, d, total in edges:
            if a in offsets and b not in offsets:
                offsets[b] = offsets[a] + d
                report.append(f'{a}->{b} delta {d} votes {n}/{total}')
                grown = True
    return offsets, report
