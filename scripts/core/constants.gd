class_name Constants
extends RefCounted
## Shared constants ported from the Three.js editor (js/main.js).

## Edge length of one block in world units.
const BLOCK_SIZE := 3.0
## Y coordinate of the bottom of pillars.
const PILLAR_BOTTOM := -75.0
## Default trim height.
const DEFAULT_TRIM_HEIGHT := 0.78
## Default grid size (tiles per side).
const DEFAULT_GRID := 14

## Face shade multipliers.
const SHADE := {"WHITE": 0.99, "LIGHT": 0.86, "FLAT": 0.75, "MID": 0.52, "DARK": 0.35}

## Available tile shape ids.
const SHAPE_IDS: Array[String] = [
	"flat", "chute_leg_x", "chute_leg_z", "fold_right", "fold_left", "wing_left",
	"chute_funnel", "pit_stepped", "goal_bevel", "pit", "subtiles_custom",
]

## Available element ids.
const ELEMENT_IDS: Array[String] = [
	"none", "tube_straight", "tube_corner", "tube_u", "cone_small", "cone_large",
	"goal_flags", "marble_start",
]

## Available decal ids.
const DECAL_IDS: Array[String] = [
	"none", "arrow_wide_diag", "arrow_wide_ortho", "arrow_long_chevrons",
	"arrow_shaft_only", "pad_456", "goal_banner",
]
