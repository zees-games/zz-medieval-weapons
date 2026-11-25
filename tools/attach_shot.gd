extends Node3D
## Attachment clips for the visual judge: close-ups of each fitted piece on the pack's own first-person view model,
## three panels side by side per frame: the first-person view, a close camera behind and right of the piece, and a
## close camera from its far (opponent's) side. The two close cameras ride the piece's socket frame, so the piece
## holds still in frame while the hands use the weapon, and anything that slips or floats on the weapon shows. There
## is no stand-in body: the subject is the attachment, not the person holding it. The weapon is used in real time (a
## swing, or the crossbow's shot and full reload); the crossbow's shot runs slowed down while the close cameras
## follow the bolt in flight, so the heads it carries show. One png per frame under <out>/<attachment>/<weapon>/
## (attach_capture.sh turns them into <attachment>/<weapon>.mp4). Run under Xvfb on a GPU box: `--out=<dir>
## [--variant=N] [--frames=N]`; the variant moves the sun and turns the close cameras.

const CAM := Vector2i(400, 400)
const STEP := 1.0 / 60.0
const FRAME := 1.0 / 12.0
const PAIRS := {
	&"zz_aperture_sight": [&"crossbow"], &"zz_barbed_heads": [&"crossbow"],
	&"zz_leather_wrap": [&"longsword", &"battle_axe", &"spear", &"dagger"],
	&"zz_counterweight": [&"longsword", &"war_axe", &"mace"],
	&"zz_spiked_boss": [&"round_shield"],
}
## The crossbow's timeline in frames: it aims, shoots at SHOT, runs SLOW frames at an eighth of the speed (the close
## cameras on the bolt in flight for the heads), reloads at RELOAD and shows the new bolt loaded to the end.
const SHOT := 6
const SLOW := 8
const RELOAD := SHOT + SLOW + 2

var _out := "res://screenshots/attach"
var _n := 36
var _n_set := false
var _variant := 0
var _fp: Camera3D
var _near: Camera3D
var _far: Camera3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--variant="):
			_variant = int(a.substr(10))
		elif a.begins_with("--frames="):
			_n = int(a.substr(9))
			_n_set = true
	var env := WorldEnvironment.new()
	env.environment = ZzMedievalReflectionSource.sky_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45 - 8 * (_variant % 3), 30 + 55.0 * _variant, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	# A soft fill from the other side, so a piece's shaded face still reads in a close-up.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, sun.rotation_degrees.y + 180.0, 0)
	fill.light_energy = 0.35
	add_child(fill)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.33, 0.27)
	m.roughness = 0.95
	pm.material = m
	g.mesh = pm
	add_child(g)
	_fp = Camera3D.new()
	_fp.fov = 72
	_fp.position = Vector3(0, 1.6, 0)
	add_child(_fp)
	_near = _close_camera()
	_far = _close_camera()
	var cat := ZzMedievalAttachmentPack.catalogue(PackedStringArray(["res://cfg"]))
	for att: StringName in PAIRS:
		for w: StringName in PAIRS[att]:
			await _clip(cat, att, w)
	get_tree().quit()


func _close_camera() -> Camera3D:
	var c := Camera3D.new()
	c.fov = 30
	c.near = 0.01
	add_child(c)
	return c


func _clip(cat: GSWeaponAttachments, att: StringName, w: StringName) -> void:
	var a := cat.get_attachment(att) as GSWeaponAttachment
	var f := GSWeaponFitting.make(w)
	f.fit(a.mount, att)
	var vm := ZzMedievalViewModel.new()
	_fp.add_child(vm)
	vm.set_process(false)
	vm.flight_parent = self
	vm.bind(w)
	vm.show_fitting(cat, f)
	vm.step(0.0)
	var frames := _n if _n_set or w != &"crossbow" else RELOAD + roundi(vm.anim.load_s / FRAME) + 8
	var dir := ProjectSettings.globalize_path("%s/%s/%s" % [_out, att, w])
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().size = CAM
	var held := _piece(vm)
	var reach := maxf(_bounds(held).size.length(), 0.06)
	var cams: Array[Camera3D] = [_fp, _near, _far]
	for i in frames:
		var slow := w == &"crossbow" and i >= SHOT and i < SHOT + SLOW
		_act(vm, w, i, FRAME / 8.0 if slow else FRAME)
		var piece := held
		if att == &"zz_barbed_heads" and i >= SHOT:
			# From the shot on, the close cameras ride the bolt in flight and its heads to the end of the clip.
			piece = _flight_piece(piece)
		_aim(piece, att, w, reach)
		var strip := Image.create(CAM.x * 3, CAM.y, false, Image.FORMAT_RGBA8)
		for k in 3:
			cams[k].current = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, CAM), Vector2i(k * CAM.x, 0))
		strip.save_png("%s/f%03d.png" % [dir, i])
	print("clip ", att, "/", w, " frames ", frames, " piece ", _bounds(held).size)
	vm.get_parent().remove_child(vm)
	vm.free()
	for n in get_children():
		if n is ZzProjectileFlight or n is CPUParticles3D:
			n.free()


## The weapon in use for [param dt] of time: a swing (or the shield's bash) at the start and again halfway; the
## crossbow aims a while (the heads ride the nocked bolt), shoots, then reloads.
func _act(vm: ZzMedievalHeld, w: StringName, i: int, dt: float) -> void:
	if w == &"crossbow":
		if i == SHOT:
			vm.anim.start_use()
		elif i == RELOAD:
			vm.anim.set_reloading(true)
	elif i == 2 or i == _n / 2 + 2:
		vm.anim.start_use()
	var t := 0.0
	var step := minf(STEP, dt)
	while t < dt - 1e-6:
		vm.step(step)
		for n in get_children():
			if n is ZzProjectileFlight:
				# Stepped here only: its own _process would fly it on between the cameras' renders.
				n.set_process(false)
				# Kept for the whole clip: the cameras stay on its heads, flying or stuck.
				(n as ZzProjectileFlight).life = 1e9
				(n as ZzProjectileFlight).stuck_for = 1e9
				(n as ZzProjectileFlight).step(step)
		t += step


## The heads carried onto the bolt in flight, if one is flying; else [param fallback].
func _flight_piece(fallback: Node3D) -> Node3D:
	for n in get_children():
		if n is ZzProjectileFlight:
			var p := _piece(n)
			if p != n:
				return p
	return fallback


## The close cameras: fixed offsets in the piece's own socket frame, from the side each piece is best seen (NEAR,
## behind and right of it as its holder sees it; FAR, from the opponent's side). The variant turns both round the
## weapon's long axis.
const NEAR := {
	&"zz_spiked_boss": Vector3(0.35, 0.25, 1.0), &"zz_counterweight": Vector3(0.7, -1.0, 0.4),
	&"zz_leather_wrap": Vector3(0.85, -0.6, 0.5), &"zz_aperture_sight": Vector3(0.5, -0.9, 0.35),
	&"zz_barbed_heads": Vector3(1.0, 0.1, 0.35),
}
## Per weapon, where the NEAR default would see only the fist: the dagger's short grip shows past the fist's ends.
const NEAR_ON := {&"dagger": Vector3(-0.6, -0.5, 0.7)}
const FAR := {
	&"zz_spiked_boss": Vector3(-0.9, 0.35, 0.6), &"zz_counterweight": Vector3(-0.7, -0.8, -0.6),
	&"zz_leather_wrap": Vector3(-0.85, 0.1, -0.6), &"zz_aperture_sight": Vector3(-0.7, 0.15, 0.9),
	&"zz_barbed_heads": Vector3(-0.6, 0.6, -0.7),
}


func _aim(piece: Node3D, att: StringName, w: StringName, reach: float) -> void:
	var at := _bounds(piece).get_center() if _visible(piece) else piece.global_position
	var frame := (piece.get_parent() as Node3D).global_basis.orthonormalized()
	var turn := deg_to_rad(28.0 * (_variant % 3 - 1))
	var axis := Vector3.UP if att != &"zz_spiked_boss" else Vector3.BACK
	var near: Vector3 = NEAR_ON.get(w, NEAR.get(att, Vector3(1, 0.3, 0.5)))
	var pairs := [[_near, near], [_far, FAR.get(att, Vector3(-1, 0.3, -0.5))]]
	for p in pairs:
		var cam := p[0] as Camera3D
		var local: Vector3 = p[1]
		var d := (frame * local.rotated(axis, turn)).normalized()
		cam.position = at + d * clampf(reach * 3.5, 0.18, 0.9)
		cam.look_at(at, Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD)


func _piece(h: Node) -> Node3D:
	for n in h.find_children("*", "", true, false):
		if n.has_meta(&"gs_attachment_model"):
			return n as Node3D
	return h as Node3D


func _visible(n: Node3D) -> bool:
	return n.is_visible_in_tree() and _bounds(n).size != Vector3.ZERO


func _bounds(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null:
			continue
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
