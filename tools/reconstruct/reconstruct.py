#!/usr/bin/env python3
"""Reconstructs data/level01.json from assets/level01_ref.png.

Usage: python3 tools/reconstruct/reconstruct.py [--out data/level01.json] [--cache fit.pkl]
"""
import argparse
import json
import os
import pickle
import sys

sys.path.insert(0, os.path.dirname(__file__))
from tiles import detect, load_logical, level_map, merge_cells  # noqa: E402
from lattice import neighbors, assign  # noqa: E402
from vertices import estimate  # noqa: E402
from optimize import Fit, Grower  # noqa: E402
from walls import votes  # noqa: E402
from assemble import reference_classes, place  # noqa: E402
from build_level import build, lattice_bounds  # noqa: E402
from bake import bake  # noqa: E402
from place_elements import place as place_elements  # noqa: E402
from vertices import height, HS  # noqa: E402

# Height of the lowest reconstructed vertex.
LOWEST_HEIGHT = 1.0
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
REF = os.path.join(ROOT, 'assets', 'level01_ref.png')


def initial_tiles(cells, verts):
    """Returns the fit tiles {(comp, k, m): [level0, level1, split]} of the detected cells."""
    out = {}
    for t in cells:
        key = (t.comp, t.k, t.m)
        if not all(v in verts for v in Fit.corner_keys(key)): continue
        out[key] = [t.level, t.level, 'main']
    return out


def fit_geometry(img):
    """Detects, links and fits the tiles. Returns (fit tiles, vertices, cells, labels)."""
    lv, _ = level_map(img)
    tiles, labels = detect(img)
    cells, cell_labels = merge_cells(tiles, labels)
    assign(cells, neighbors(cells, cell_labels))
    verts = estimate(cells)
    fit = Fit(lv, initial_tiles(cells, verts), verts)
    for _ in range(4):
        fit.refine_vertices()
        fit.refine_levels()
    hit, cov = fit.total()
    print(f'fit: {len(fit.tiles)} tiles, {hit}/{cov} tile pixels match')
    grower = Grower(fit)
    for _ in range(12):
        added = grower.step()
        print(f'grow: +{added} tiles')
        if added == 0: break
    fit.refine_vertices()
    fit.refine_levels()
    hit, cov = fit.total()
    print(f'grown fit: {len(fit.tiles)} tiles, {hit}/{cov} tile pixels match')
    return fit.tiles, fit.verts, cells, cell_labels


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--out', default=os.path.join(ROOT, 'data', 'level01.json'))
    ap.add_argument('--cache')
    ap.add_argument('--no-paint', action='store_true', help='do not bake the reference look')
    args = ap.parse_args()
    img = load_logical(REF)
    if args.cache and os.path.exists(args.cache):
        fit_tiles, verts, cells, cell_labels = pickle.load(open(args.cache, 'rb'))
    else:
        fit_tiles, verts, cells, cell_labels = fit_geometry(img)
        if args.cache: pickle.dump((fit_tiles, verts, cells, cell_labels), open(args.cache, 'wb'))
    sizes = {}
    for (c, k, m) in fit_tiles: sizes[c] = sizes.get(c, 0) + 1
    root = max(sizes, key=sizes.get)
    ref_cls = reference_classes(img, cell_labels)
    sy0 = 0.0
    offsets = place(fit_tiles, verts, ref_cls, sy0, root, votes(cells, cell_labels, img))
    if args.cache: pickle.dump(offsets, open(args.cache + '.offsets', 'wb'))
    write_level(img, fit_tiles, verts, offsets, args.out, not args.no_paint)
    return 0


def write_level(img, fit_tiles, verts, offsets, out_path, with_paint):
    """Chooses the height datum and the world origin, then writes the level JSON."""
    # Height datum: the lowest vertex sits at height LOWEST_HEIGHT.
    lowest = min(height(mv + offsets[c], sy, 0.0) for (c, kv, mv), sy in verts.items() if c in offsets)
    sy0 = (LOWEST_HEIGHT - lowest) * HS
    min_x, min_z, max_x, max_z = lattice_bounds(fit_tiles, offsets)
    # Origin: one free block row around the tiles, aligned so lattice tiles fall on whole blocks.
    origin = (3 - min_x + (min_x % 3), 3 - min_z + (min_z % 3))
    paint = bake(img, fit_tiles, verts, offsets, sy0, origin) if with_paint else None
    level = build(fit_tiles, verts, offsets, sy0, origin, paint)
    s_ = (295.0 - sy0) / 4.0
    level['arcadeFocus'] = [round((s_ + 18.0) / 2 + origin[0], 6), 0.0, round((s_ - 18.0) / 2 + origin[1], 6)]
    place_elements(level)
    # The screen center (144, 295) shows lattice point x - z = 18, x + z = (295 - sy0) / 4 at
    # height 0 (vertices.py: sy = 4 mv - HS y + sy0).
    s = (295.0 - sy0) / 4.0
    level['arcadeFocus'] = [round((s + 18.0) / 2 + origin[0], 6), 0.0, round((s - 18.0) / 2 + origin[1], 6)]
    with open(out_path, 'w') as f:
        json.dump(level, f, indent=1)
        f.write('\n')
    print(f'wrote {out_path}: {len(level["blocks"])} blocks, grid {level["cols"]}')


if __name__ == '__main__':
    sys.exit(main())
