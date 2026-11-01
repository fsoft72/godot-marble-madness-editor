class_name PlayerInput
extends RefCounted
## Player input actions, registered from code so the player needs no editor setup.
## Physical keys keep WASD in the same place on every keyboard layout.

const LEFT := &"player_left"
const RIGHT := &"player_right"
const UP := &"player_up"
const DOWN := &"player_down"
const RESTART := &"player_restart"
const EXIT := &"player_exit"
## Physical keys of each action.
const BINDINGS := {
	LEFT: [KEY_A, KEY_LEFT],
	RIGHT: [KEY_D, KEY_RIGHT],
	UP: [KEY_W, KEY_UP],
	DOWN: [KEY_S, KEY_DOWN],
	RESTART: [KEY_R],
	EXIT: [KEY_ESCAPE],
}


## Registers the actions that are still missing from the InputMap.
static func ensure_actions() -> void:
	for action in BINDINGS:
		if InputMap.has_action(action): continue
		InputMap.add_action(action)
		for keycode in BINDINGS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action, event)


## Returns the steering input: x is right, y is forward (screen up), length at most 1.
static func steer_vector() -> Vector2:
	var raw := Vector2(
		Input.get_action_strength(RIGHT) - Input.get_action_strength(LEFT),
		Input.get_action_strength(UP) - Input.get_action_strength(DOWN))
	return raw.limit_length(1.0)


## Converts a steering input to a world direction on the ground, relative to the camera.
static func world_direction(steer: Vector2, camera_basis: Basis) -> Vector3:
	var forward := Vector3(-camera_basis.z.x, 0.0, -camera_basis.z.z).normalized()
	var right := Vector3(camera_basis.x.x, 0.0, camera_basis.x.z).normalized()
	return right * steer.x + forward * steer.y
