// Generates golden data for the Godot port from the original Three.js sources.
// Usage: node tools/gen_golden.mjs
// Output: tests/golden/surface_y.json as [{block, u, v, y}]
import { register } from 'node:module';
import { writeFileSync, mkdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import { homedir } from 'node:os';
import path from 'node:path';

const JS_DIR = process.env.MM_JS_DIR || path.join(homedir(), 'dev/games/marble-madness/js');
const OUT_DIR = 'tests/golden';

// Resolve hook that replaces `three` and `./textures.js` with stub modules
// (textures.js exports the names geometry.js imports; they are only used at mesh build time).
const HOOK_SOURCE = `
export async function resolve(specifier, context, next) {
  if (specifier === 'three' || specifier.endsWith('/textures.js')) {
    return { url: 'stub:' + specifier, shortCircuit: true };
  }
  return next(specifier, context);
}
export async function load(url, context, next) {
  if (url.startsWith('stub:')) {
    const source = url.endsWith('/textures.js')
      ? 'export const getTopSurfaceMaterial = null, getCliffWallMaterials = null, getFlagMaterial = null;'
      : 'export {};';
    return { format: 'module', source, shortCircuit: true };
  }
  return next(url, context);
}
`;
register('data:text/javascript,' + encodeURIComponent(HOOK_SOURCE), import.meta.url);

const geometry = await import(pathToFileURL(path.join(JS_DIR, 'geometry.js')).href);
const { getBlockSurfaceY } = geometry;

const SAMPLES = [0, 0.5, 1.5, 2.5, 3];
const SHAPES = [
  'flat', 'chute_leg_x', 'chute_leg_z', 'fold_right', 'fold_left', 'wing_left',
  'chute_funnel', 'pit_stepped', 'goal_bevel', 'pit', 'subtiles_custom',
];
const ROTATIONS = [0, 90, 180, 270];

const VGRID = [
  [0, 0.5, 1, 0],
  [0.25, 1, 2, 0.5],
  [0, 1.5, 0.75, 0],
  [0.5, 0, 0, 1],
];

/** Builds the list of blocks, covering every branch of getBlockSurfaceY. */
function buildBlocks() {
  const blocks = [];
  // Every shape, every rotation, with slope and tilt set.
  for (const shape of SHAPES) {
    for (const rotation of ROTATIONS) {
      blocks.push({ shape, rotation, elevation: 14, slope: 1.5, tilt: -0.75 });
    }
  }
  // subtiles_custom with subHeights: getBlockSurfaceY ignores it, keep as evidence.
  blocks.push({ shape: 'subtiles_custom', elevation: 3, slope: 0.5, subHeights: [[1, 2, 3], [0, 0, 0], [4, 5, 6]] });
  // Flat block, no slope and no tilt.
  blocks.push({ shape: 'flat', rotation: 0, elevation: 7, slope: 0, tilt: 0 });
  // Rotations outside [0, 360): wrapped by rotateUV. Non-multiples of 90 fall back to identity.
  blocks.push({ shape: 'flat', rotation: 360, elevation: 2, slope: 1, tilt: 0.5 });
  blocks.push({ shape: 'flat', rotation: 450, elevation: 2, slope: 1, tilt: 0.5 });
  blocks.push({ shape: 'flat', rotation: -90, elevation: 2, slope: 1, tilt: 0.5 });
  blocks.push({ shape: 'flat', rotation: 45, elevation: 2, slope: 1, tilt: 0.5 });
  blocks.push({ shape: 'fold_right', rotation: -270, elevation: 5, slope: 2, tilt: 1 });
  // Missing fields: elevation, slope, tilt, rotation default to 0, shape to flat.
  blocks.push({});
  blocks.push({ slope: 1, tilt: 2 });
  blocks.push({ elevation: 9 });
  blocks.push({ shape: '', elevation: 4, slope: 1 });
  blocks.push({ shape: 'fold_left', elevation: 4, slope: 2, tilt: 1 });
  // Numeric strings are converted by Number().
  blocks.push({ elevation: '6', slope: '1', tilt: '0.5', rotation: '90' });
  // vGrid, default split (anti-diagonal) and 'main' split, with and without rotation set.
  blocks.push({ shape: 'flat', elevation: 14, vGrid: VGRID });
  blocks.push({ shape: 'flat', elevation: 14, vGrid: VGRID, diagSplit: 'main' });
  blocks.push({ shape: 'flat', elevation: 14, vGrid: VGRID, diagSplit: 'anti', rotation: 90 });
  blocks.push({ vGrid: VGRID });
  // vGrid of the wrong length is ignored and falls through to the parametric branch.
  blocks.push({ elevation: 3, slope: 1, vGrid: [[0, 0, 0, 0]] });
  // corners [c00, c10, c01, c11], main (default) and anti split.
  blocks.push({ shape: 'flat', elevation: 14, corners: [0, 1, 2, 4] });
  blocks.push({ shape: 'flat', elevation: 14, corners: [0, 1, 2, 4], diagSplit: 'main' });
  blocks.push({ shape: 'flat', elevation: 14, corners: [0, 1, 2, 4], diagSplit: 'anti' });
  blocks.push({ shape: 'flat', elevation: 14, corners: [-1, 3, 0.5, 2], diagSplit: 'anti', rotation: 180 });
  blocks.push({ corners: [1, 2, 3, 4] });
  // corners of the wrong length is ignored.
  blocks.push({ elevation: 3, slope: 1, corners: [1, 2, 3] });
  // vGrid wins over corners when both are present.
  blocks.push({ elevation: 1, vGrid: VGRID, corners: [9, 9, 9, 9] });
  return blocks;
}

/** Evaluates every block at every (u, v) sample and returns the golden entries. */
function buildEntries() {
  const entries = [];
  for (const block of buildBlocks()) {
    for (const u of SAMPLES) {
      for (const v of SAMPLES) {
        entries.push({ block, u, v, y: getBlockSurfaceY(block, u, v) });
      }
    }
  }
  return entries;
}

const entries = buildEntries();
mkdirSync(OUT_DIR, { recursive: true });
writeFileSync(path.join(OUT_DIR, 'surface_y.json'), JSON.stringify(entries, null, 1) + '\n');
console.log(`Wrote ${entries.length} entries to ${OUT_DIR}/surface_y.json`);
