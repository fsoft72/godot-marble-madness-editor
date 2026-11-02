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

## Height above the floor below which the contact shadow and caustic are shown.
const CONTACT_RANGE := 3.0
const CAUSTIC_SHADER_PATH := "res://shaders/marble_caustic.gdshader"

## World direction of the steering, length at most 1.
var steer_direction := Vector3.ZERO

## Position to teleport to on the next physics step; INF when none is pending.
var _pending_position := Vector3.INF
## Floor decals that do not turn with the marble: contact shadow and caustic.
var _contact: Node3D


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
	_contact = _make_contact(ElementBuilder._parse_marble_color(color_value))
	add_child(_contact)


## Builds the top level node with the contact shadow disc and the caustic quad.
func _make_contact(color: Color) -> Node3D:
	var node := Node3D.new()
	node.name = "Contact"
	node.top_level = true
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = RADIUS * 0.8
	shadow_mesh.bottom_radius = RADIUS * 0.8
	shadow_mesh.height = 0.001
	shadow_mesh.radial_segments = 24
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.05, 0.05, 0.05, 0.45)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.mesh = shadow_mesh
	shadow.material_override = shadow_mat
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(shadow)
	var quad := QuadMesh.new()
	quad.size = Vector2(RADIUS * 2.2, RADIUS * 2.2)
	quad.orientation = PlaneMesh.FACE_Y
	var caustic_mat := ShaderMaterial.new()
	caustic_mat.shader = load(CAUSTIC_SHADER_PATH)
	caustic_mat.set_shader_parameter("tint", Color(color.r, color.g, color.b))
	var caustic := MeshInstance3D.new()
	caustic.name = "Caustic"
	caustic.mesh = quad
	caustic.material_override = caustic_mat
	caustic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(caustic)
	return node


## Puts the contact shadow under the marble and the caustic on the side away from the sun,
## on the floor found by a ray cast; hides both in the air.
func _place_contact() -> void:
	if not is_inside_tree(): return
	var from := global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * CONTACT_RANGE)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	_contact.visible = not hit.is_empty()
	if hit.is_empty(): return
	var normal: Vector3 = hit["normal"]
	var floor_point: Vector3 = hit["position"] + normal * 0.01
	# Basis with Y on the floor normal (floors are never vertical, so X stays well defined).
	var x_axis := (Vector3.RIGHT - normal * normal.dot(Vector3.RIGHT)).normalized()
	_contact.global_transform = Transform3D(Basis(x_axis, normal, x_axis.cross(normal)), floor_point)
	var sun := LevelEnvironment.sun_direction()
	var height := from.y - floor_point.y
	var away := Vector3(sun.x, 0.0, sun.z) / maxf(-sun.y, 0.2) * height * 0.6
	var caustic := _contact.get_node("Caustic") as Node3D
	caustic.global_position = floor_point + away + normal * 0.005


## Applies the steering force each physics step.
func _physics_process(_delta: float) -> void:
	_place_contact()
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
