class_name Marble
extends RigidBody3D
## The player marble: a physics sphere pushed by a steering force.

const RADIUS := ElementBuilder.MARBLE_RADIUS
const BODY_MASS := 1.0
## Steering force on the ground and fraction of it available in the air.
const STEER_FORCE := 16.0
const AIR_CONTROL := 0.3
## Above this ground speed the steering stops accelerating the marble.
const MAX_STEER_SPEED := 11.0
const LINEAR_DAMP := 0.15
const ANGULAR_DAMP := 0.6
const FRICTION := 0.9
const BOUNCE := 0.2
const MAX_CONTACTS := 4

## World direction of the steering, length at most 1.
var steer_direction := Vector3.ZERO

## Position to teleport to on the next physics step; INF when none is pending.
var _pending_position := Vector3.INF


## Builds the collision sphere, the physics settings and the visual.
func _init(color_value: Variant = null) -> void:
	name = "Marble"
	mass = BODY_MASS
	linear_damp = LINEAR_DAMP
	angular_damp = ANGULAR_DAMP
	continuous_cd = true
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = MAX_CONTACTS
	physics_material_override = PhysicsMaterial.new()
	physics_material_override.friction = FRICTION
	physics_material_override.bounce = BOUNCE
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	var collision := CollisionShape3D.new()
	collision.shape = sphere
	add_child(collision)
	add_child(ElementBuilder.make_rolling_marble(color_value))


## Applies the steering force each physics step.
func _physics_process(_delta: float) -> void:
	if steer_direction == Vector3.ZERO: return
	var speed_along := linear_velocity.dot(steer_direction.normalized())
	if speed_along >= MAX_STEER_SPEED: return
	var force := STEER_FORCE if get_contact_count() > 0 else STEER_FORCE * AIR_CONTROL
	apply_central_force(steer_direction * force)


## Applies a pending teleport inside the physics step, where it cannot be overwritten.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _pending_position == Vector3.INF: return
	state.transform = Transform3D(Basis.IDENTITY, _pending_position)
	state.linear_velocity = Vector3.ZERO
	state.angular_velocity = Vector3.ZERO
	_pending_position = Vector3.INF


## Stops the marble and moves it to a position.
func place_at(pos: Vector3) -> void:
	steer_direction = Vector3.ZERO
	_pending_position = pos
	position = pos
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
