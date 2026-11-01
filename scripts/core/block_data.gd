class_name BlockData
extends RefCounted
## Helpers for block dictionaries (port of the setBlock defaults and applyShapeIdToBlock).


## Returns a new dictionary holding the default fields of a block.
static func defaults() -> Dictionary:
	return {
		"isVoid": false,
		"elevation": 14.0,
		"slope": 0.0,
		"tilt": 0.0,
		"rotation": 0,
		"shape": "flat",
		"element": "none",
		"elemRotation": 0,
		"decal": "none",
		"decalRotation": 0,
	}


## Returns a block at (bx, bz): defaults, then bx/bz, then props on top.
static func make(bx: int, bz: int, props: Dictionary = {}) -> Dictionary:
	var block := defaults()
	block["bx"] = bx
	block["bz"] = bz
	block.merge(props, true)
	return block


## Applies a palette shape id to a block, clearing the old shape-related fields first.
static func apply_shape(block: Dictionary, shape_id: String) -> void:
	block.erase("subShades")
	block.erase("cutout")
	block.erase("shadePreset")
	match shape_id:
		"chute_leg_x":
			block["shape"] = "flat"
			block["shadePreset"] = "chute_leg_x"
		"chute_leg_z":
			block["shape"] = "flat"
			block["shadePreset"] = "chute_leg_z"
		"fold_right":
			block["shape"] = "fold_right"
			block["shadePreset"] = "turn_right"
		"fold_left":
			block["shape"] = "fold_left"
			block["shadePreset"] = "turn_left_dark"
		"wing_left":
			block["shape"] = "flat"
			block["cutout"] = "wing_left"
			block["shadePreset"] = "wing_dark"
		"chute_funnel":
			block["shape"] = "chute_funnel"
			block["shadePreset"] = "funnel_center"
		_:
			block["shape"] = shape_id
