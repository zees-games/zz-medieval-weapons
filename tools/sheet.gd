extends Node3D
## Contact sheets of every weapon in the hands, so a person can look at the motion no
## assertion reaches. Run through tools/screenshot.sh (`--sheet` first person, `--world` a person
## seen from outside), under Xvfb: a --headless render is a black PNG.
##
## One image per weapon, eight cells (4 x 2), at a fixed 60 fps step so the same frame is the
## same picture every run. The cell order is printed with each file.

const CELL := Vector2i(400, 300)
const STEP := 1.0 / 60.0

var _world := false
var _holder: Node3D
var _held: ZzMedievalHeld
var _cam: Camera3D


func _ready() -> void:
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		if a == "--world":
			_world = true
		else:
			ids.append(StringName(a))
	if ids.is_empty():
		ids = Array(ZzMedievalConfig.IDS)
	_stage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for id in ids:
		await _sheet(id)
	get_tree().quit()


func _stage() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.45, 0.55, 0.65)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.62, 0.62, 0.66)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 25, 0)
	add_child(sun)
	# A floor and a straw target 6 m ahead, so a loosed arrow has something to land in.
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 0.2, 40)
	fs.shape = box
	floor_body.add_child(fs)
	var fm := MeshInstance3D.new()
	var plane := BoxMesh.new()
	plane.size = Vector3(40, 0.2, 40)
	var fmat := StandardMaterial3D.new()
	fmat.albedo_color = Color(0.36, 0.42, 0.28)
	plane.material = fmat
	fm.mesh = plane
	floor_body.add_child(fm)
	floor_body.position = Vector3(0, -1.7 if not _world else -0.1, 0)
	add_child(floor_body)
	var target := StaticBody3D.new()
	var ts := CollisionShape3D.new()
	var tb := BoxShape3D.new()
	tb.size = Vector3(1.2, 1.6, 0.3)
	ts.shape = tb
	target.add_child(ts)
	var tm := MeshInstance3D.new()
	var tbm := BoxMesh.new()
	tbm.size = tb.size
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color(0.72, 0.6, 0.3)
	tbm.material = tmat
	tm.mesh = tbm
	target.add_child(tm)
	target.position = Vector3(0, 0.7 if _world else -0.2, -6.0)
	add_child(target)

	_cam = Camera3D.new()
	add_child(_cam)
	_cam.current = true
	if _world:
		# A person: legs, torso, head. The chest node is where a world model's shoulders sit.
		var body := MeshInstance3D.new()
		var cap := CapsuleMesh.new()
		cap.radius = 0.2
		cap.height = 1.5
		var bmat := StandardMaterial3D.new()
		bmat.albedo_color = Color(0.25, 0.3, 0.45)
		cap.material = bmat
		body.mesh = cap
		body.position = Vector3(0, 0.85, 0)
		add_child(body)
		var head := MeshInstance3D.new()
		var hs := SphereMesh.new()
		hs.radius = 0.12
		hs.height = 0.24
		var hm := StandardMaterial3D.new()
		hm.albedo_color = ZzMedievalHeld.SKIN
		hs.material = hm
		head.mesh = hs
		head.position = Vector3(0, 1.72, 0)
		add_child(head)
		_holder = Node3D.new()
		_holder.position = Vector3(0, 1.45, 0)
		add_child(_holder)
		_cam.position = Vector3(2.4, 1.7, -1.6)
		_cam.look_at(Vector3(0, 1.1, -0.9))
		_cam.fov = 40
	else:
		_holder = _cam
		_cam.fov = 72


func _frames(id: StringName) -> Array:
	var row := ZzMedievalArtTable.row(id)
	var styles: Array = row["styles"]
	var n := styles.size()
	match id:
		&"bow":
			return [
				[], [["draw", 0.25]], [["draw", 0.55]], [["draw", 1.2]],
				[["draw", 1.2], ["wait", 0.5]], [["draw", 1.2], ["loose"], ["wait", 0.03]],
				[["draw", 1.2], ["loose"], ["wait", 0.12]], [["draw", 1.2], ["loose"], ["wait", 0.8]],
			]
		&"crossbow":
			return [
				[], [["fire"], ["wait", 0.06]], [["fire"], ["wait", 0.4]], [["fire"], ["reload", 0.5]],
				[["fire"], ["reload", 1.0]], [["fire"], ["reload", 1.35]], [["fire"], ["reload", 1.9]],
				[["fire"], ["reload", 3.0]],
			]
		&"round_shield":
			return [
				[], [["force", 0, 0.32]], [["force", 0, 0.55]], [["force", 0, 0.7]],
				[["block"]], [["block"], ["hit"], ["wait", 0.03]], [["block"], ["force", 0, 0.55]], [["force", 0, 0.9]],
			]
		_:
			return [
				[], [["force", 0, 0.32]], [["force", 0, 0.55]], [["force", mini(1, n - 1), 0.55]],
				[["force", mini(2, n - 1), 0.55]], [["block"]], [["force", 0, 0.55], ["hit"], ["wait", 0.03]], [["force", 0, 0.9]],
			]


func _sheet(id: StringName) -> void:
	if _held != null:
		_held.queue_free()
	_held = ZzMedievalWorldModel.new() if _world else ZzMedievalViewModel.new()
	_holder.add_child(_held)
	_held.set_process(false)
	_held.flight_parent = self
	var frames := _frames(id)
	var sheet := Image.create(CELL.x * 4, CELL.y * 2, false, Image.FORMAT_RGBA8)
	var labels: PackedStringArray = []
	for i in frames.size():
		for n in get_children():
			if n is ZzProjectileFlight or n is CPUParticles3D:
				n.free()
		_held.bind(id)
		_held.step(0.0)
		for op in frames[i]:
			_run(op)
		labels.append(str(frames[i]))
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(CELL.x, CELL.y, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(Vector2i.ZERO, CELL), Vector2i((i % 4) * CELL.x, (i / 4) * CELL.y))
	var out := "res://screenshots/%s_%s.png" % ["world" if _world else "view", String(id)]
	sheet.save_png(out)
	print(out, "  cells: ", " | ".join(labels))


func _run(op: Array) -> void:
	var a := _held.anim
	match String(op[0]):
		"force":
			var st: int = (a.styles() as Array)[int(op[1])]
			a.force(st, float(op[2]))
			_held.step(0.0)
		"block":
			a.set_blocking(true)
			_wait(0.3)
		"wait":
			_wait(float(op[1]))
		"draw":
			a.hold_draw(true)
			_wait(float(op[1]))
		"loose":
			a.hold_draw(false)
		"fire":
			a.start_use()
		"reload":
			a.set_reloading(true)
			_wait(float(op[1]))
		"hit":
			_held.anim.hit(&"wood")
			_held.step(0.0)


func _wait(secs: float) -> void:
	var t := 0.0
	while t < secs:
		_held.step(STEP)
		for n in get_children():
			if n is ZzProjectileFlight:
				(n as ZzProjectileFlight).step(STEP)
		t += STEP
