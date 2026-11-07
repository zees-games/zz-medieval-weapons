extends Node3D

## Contact sheet for the weapon_art() hook: each weapon is a pair, the bare zee stand-in on the left and the pack's own model on the right.
## Needs zee-dot-weapons beside the pack (the hook is empty without it); without it only the pack's models are drawn.
## `-- --pack zz_modern_weapons --shot out.png`; run under Xvfb (tools/art_sheet.sh), a headless frame is black.

const PIXELS_PER_METRE := 90.0
const CELL := Vector2(2.6, 1.6)

var _pack := "zz_modern_weapons"
var _shot := ""
var _columns := 4
var _vp: SubViewport


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "--pack" and i + 1 < args.size():
			_pack = args[i + 1]
		elif args[i] == "--shot" and i + 1 < args.size():
			_shot = args[i + 1]

	var provider := load("res://addons/%s/spawn_provider.gd" % _pack) as Script
	var after: Array = provider.call(&"weapon_art")
	var before: Array = _before(provider)
	_columns = 4 if after.size() > 10 else 5
	var rows := ceili(float(maxi(after.size(), 1)) / _columns)
	_vp = SubViewport.new()
	_vp.size = Vector2i(int(_columns * CELL.x * PIXELS_PER_METRE), int((rows * CELL.y + 0.4) * PIXELS_PER_METRE))
	_vp.own_world_3d = true
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)

	for i in after.size():
		var cell := Vector3((i % _columns) * CELL.x, -(i / _columns) * CELL.y, 0.0)
		_label(str((after[i] as Resource).get(&"id")), cell + Vector3(0.0, -0.62, 0.0))
		if i < before.size():
			_model(before[i], cell + Vector3(-0.62, 0.0, 0.0))
		_model(after[i], cell + Vector3(0.62, 0.0, 0.0))

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.17, 0.2)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, -30.0, 0.0)
	_vp.add_child(sun)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rows * CELL.y + 0.4
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.position = Vector3((_columns - 1) * CELL.x * 0.5, -(rows - 1) * CELL.y * 0.5, 10.0)
	_vp.add_child(cam)

	await get_tree().create_timer(1.0).timeout
	if _shot != "":
		_vp.get_texture().get_image().save_png(_shot)
		print("wrote ", _shot)
	get_tree().quit()


## The bare stand-in: the same build with no dressing, via the pack's own builder class.
func _before(provider: Script) -> Array:
	var builder := load(ProjectSettings.get_global_class_list().filter(
		func(e: Dictionary) -> bool: return str(e["class"]).ends_with("ZeeArt") and str(e["path"]).contains(_pack))[0]["path"]) as Script
	return builder.call(&"build", false)


## Draws [param art]'s model lying along +X, scaled to fit the cell, with its zee carry scale kept relative to the others by length.
func _model(art: Resource, at: Vector3) -> void:
	var path := str(art.get(&"model_path"))
	var scene := load(path) as PackedScene if path != "" else null
	if scene == null:
		return

	var node := scene.instantiate() as Node3D
	var holder := Node3D.new()
	holder.add_child(node)
	var forward: Vector3 = art.get(&"model_forward")
	# Turn the model's own front to screen-right (+X).
	if forward.is_equal_approx(Vector3.UP):
		holder.rotation_degrees.z = -90.0
	elif forward.is_equal_approx(Vector3.FORWARD):
		holder.rotation_degrees.y = -90.0
	elif forward.is_equal_approx(Vector3.BACK):
		holder.rotation_degrees.y = 90.0
	_vp.add_child(holder)

	var box := AABB()
	var first := true
	for m: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		var part := m.global_transform * m.get_aabb()
		box = part if first else box.merge(part)
		first = false

	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var fit := 1.0 if longest <= 0.0001 else 1.0 / longest
	holder.scale = Vector3.ONE * fit
	holder.position = at - box.get_center() * fit


func _label(text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.pixel_size = 0.004
	l.position = at
	_vp.add_child(l)
