extends SceneTree
## Renders a close-up of the glass marble on a small level, to look at the glass shader.
## Usage: godot --path . -s res://tools/render_marble.gd -- --out=/tmp/marble.png [--ortho=1]

const SIZE := Vector2i(640, 480)
const FRAMES_TO_WAIT := 6

var _args := {}


## Parses the arguments and starts the render.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not "=" in arg: continue
		var kv := arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1]
	_render()


## Builds a 3x3 block floor with a step and a tube, a marble on it, renders and saves.
func _render() -> void:
	var level := LevelData.new()
	level.cols = 3
	level.rows = 3
	for bx in 3:
		for bz in 3:
			level.set_block(bx, bz, BlockData.make(bx, bz, {"elevation": 2.0 if bx == 0 else 1.0, "decal": "arrow_wide_ortho" if bx == 2 and bz == 1 else "none"}))
	level.get_block(1, 0)["element"] = "tube_straight"
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_4X
	root.add_child(vp)
	LevelEnvironment.add_to(vp)
	var view := LevelView.new()
	vp.add_child(view)
	view.bind(level)
	var marble := Marble.new()
	vp.add_child(marble)
	marble.freeze = true
	marble.global_position = Vector3(4.5, 1.0 + Marble.RADIUS, 4.5)
	marble.rotation = Vector3(0.4, 0.8, 0.2)
	for i in 3:
		await physics_frame
	var cam := Camera3D.new()
	vp.add_child(cam)
	if _args.get("ortho", "0") == "1":
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.size = 3.0
	else:
		cam.fov = 30.0
	var eye := Vector3(4.5, 1.5, 4.5) + ArcadeProjection.view_dir() * 4.0
	cam.transform = Transform3D(Basis.looking_at(Vector3(4.5, 1.4, 4.5) - eye, Vector3.UP), eye)
	cam.make_current()
	for i in FRAMES_TO_WAIT:
		await process_frame
	await RenderingServer.frame_post_draw
	var out: String = _args.get("out", "user://marble.png")
	var err := vp.get_texture().get_image().save_png(out)
	print("render_marble: saved %s" % out)
	quit(0 if err == OK else 1)
