extends SceneTree
## Renders a level JSON with the arcade 2:1 isometric camera to a PNG, for comparison
## against the reference image (tools/compare_ref.py).
## Usage:
##   godot --path . -s res://tools/render_level.gd -- --level=res://data/level01.json \
##       --out=/tmp/render.png [--ox=0 --oy=0] [--sun=azimuth,elevation]
## The image is rendered at the logical arcade resolution (288x590) and scaled 2x with
## nearest filtering, like the reference. --ox/--oy shift the camera focus in world units
## along the screen axes (used to align the framing).

const LOGICAL_SIZE := Vector2i(288, 590)
const SCALE := 2
const FRAMES_TO_WAIT := 4

var _args := {}


## Parses the arguments, builds the scene and starts the render.
func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if not arg.begins_with("--") or not "=" in arg: continue
		var kv := arg.trim_prefix("--").split("=", true, 1)
		_args[kv[0]] = kv[1]
	_render()


## Builds the level in a SubViewport, waits a few frames, saves the image and quits.
func _render() -> void:
	var path: String = _args.get("level", "res://data/level01.json")
	var out: String = _args.get("out", "user://render.png")
	var result := LevelIO.load_file(path)
	if not result["ok"]:
		push_error("render_level: cannot load %s: %s" % [path, result["error"]])
		quit(1)
		return
	var level: LevelData = result["level"]
	var vp := SubViewport.new()
	vp.size = LOGICAL_SIZE
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
	root.add_child(vp)
	var sun := LevelEnvironment.SUN_POSITION
	if _args.has("sun"):
		var ae: PackedStringArray = str(_args["sun"]).split(",")
		var az := deg_to_rad(float(ae[0]))
		var el := deg_to_rad(float(ae[1]))
		sun = Vector3(cos(el) * sin(az), sin(el), cos(el) * cos(az)) * 50.0
	LevelEnvironment.add_to(vp, sun)
	var view := LevelView.new()
	vp.add_child(view)
	view.bind(level)
	var cam := Camera3D.new()
	vp.add_child(cam)
	var focus := level.arcade_focus if level.arcade_focus != Vector3.INF else ArcadeProjection.REFERENCE_FOCUS
	ArcadeProjection.apply(cam, LOGICAL_SIZE.y, Vector2(float(_args.get("ox", "0")), float(_args.get("oy", "0"))), focus)
	cam.make_current()
	for i in FRAMES_TO_WAIT:
		await process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.resize(LOGICAL_SIZE.x * SCALE, LOGICAL_SIZE.y * SCALE, Image.INTERPOLATE_NEAREST)
	var err := img.save_png(out)
	if err != OK: push_error("render_level: cannot save %s (%d)" % [out, err])
	print("render_level: saved %s" % out)
	quit(0 if err == OK else 1)
