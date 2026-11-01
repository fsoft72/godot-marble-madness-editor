class_name LevelEnvironment
extends RefCounted
## Background and lights shared by the editor and the player (settings from js/main.js).

const AMBIENT_ENERGY := 0.72
const SUN_COLOR := Color("fffaf0")
const SUN_ENERGY := 1.15
const SUN_POSITION := Vector3(-22.0, 48.0, 12.0)
const FILL_COLOR := Color("90a8ff")
const FILL_ENERGY := 0.25
const FILL_POSITION := Vector3(25.0, 20.0, -20.0)
## Shadow range of the sun.
const SHADOW_DISTANCE := 160.0


## Adds black background, ambient light, the sun with shadows and the blue fill light to a parent.
static func add_to(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = AMBIENT_ENERGY
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	parent.add_child(world_env)
	var sun := _make_light("Sun", SUN_COLOR, SUN_ENERGY, SUN_POSITION)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	sun.shadow_bias = 0.05
	parent.add_child(sun)
	parent.add_child(_make_light("Fill", FILL_COLOR, FILL_ENERGY, FILL_POSITION))


## Creates a directional light that shines from a position toward the origin.
static func _make_light(light_name: String, color: Color, energy: float, from: Vector3) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = light_name
	light.light_color = color
	light.light_energy = energy
	light.transform = Transform3D(Basis.looking_at(-from, Vector3.UP), from)
	return light
