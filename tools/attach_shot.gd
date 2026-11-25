extends Node3D
## Attachment clips for the visual judge: each fitted weapon held and used, three panels side by side per frame:
## the first-person view (camera, arms, gloves), a close camera on the fitted piece in those hands, and a person
## holding it in third person. The weapon is used in real time (a swing, or the crossbow's shot and reload), so a
## piece that lags or floats off the weapon shows. One png per frame under <out>/<attachment>/<weapon>/
## (attach_capture.sh turns them into <attachment>/<weapon>.mp4). Run under Xvfb on a GPU box: `--out=<dir>
## [--variant=N] [--frames=N]`; the variant moves the sun and the close camera.

const CAM := Vector2i(400, 400)
const STEP := 1.0 / 60.0
const FRAME := 1.0 / 12.0
const PAIRS := {
	&"zz_aperture_sight": [&"crossbow"], &"zz_barbed_heads": [&"crossbow"],
	&"zz_leather_wrap": [&"longsword", &"battle_axe", &"spear", &"dagger"],
	&"zz_counterweight": [&"longsword", &"war_axe", &"mace"],
	&"zz_spiked_boss": [&"round_shield"],
}
## The third-person rig stands well away from the first-person one, so neither shows in the other's panels.
const BODY_AT := Vector3(40, 0, 0)

var _out := "res://screenshots/attach"
var _n := 36
var _variant := 0
var _fp: Camera3D
var _detail: Camera3D
var _tp: Camera3D
var _holder: Node3D


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.substr(6)
		elif a.begins_with("--variant="):
			_variant = int(a.substr(10))
		elif a.begins_with("--frames="):
			_n = int(a.substr(9))
	var env := WorldEnvironment.new()
	env.environment = ZzMedievalReflectionSource.sky_environment()
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45 - 8 * (_variant % 3), 30 + 55.0 * _variant, 0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	_ground(Vector3.ZERO)
	_ground(BODY_AT)
	_fp = Camera3D.new()
	_fp.fov = 72
	_fp.position = Vector3(0, 1.6, 0)
	add_child(_fp)
	_detail = Camera3D.new()
	_detail.fov = 30
	_detail.near = 0.01
	add_child(_detail)
	_tp = Camera3D.new()
	_tp.fov = 40
	add_child(_tp)
	_body()
	var cat := ZzMedievalAttachmentPack.catalogue(PackedStringArray(["res://cfg"]))
	for att: StringName in PAIRS:
		for w: StringName in PAIRS[att]:
			await _clip(cat, att, w)
	get_tree().quit()


func _ground(at: Vector3) -> void:
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(12, 12)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.36, 0.33, 0.27)
	m.roughness = 0.95
	pm.material = m
	g.mesh = pm
	g.position = at
	add_child(g)


## A person (legs and torso, head) like tools/sheet.gd's; the holder at the shoulders carries the world model.
func _body() -> void:
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.2
	cap.height = 1.5
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.25, 0.3, 0.45)
	cap.material = bmat
	body.mesh = cap
	body.position = BODY_AT + Vector3(0, 0.85, 0)
	add_child(body)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.12
	hs.height = 0.24
	var hm := StandardMaterial3D.new()
	hm.albedo_color = ZzMedievalHeld.SKIN
	hs.material = hm
	head.mesh = hs
	head.position = BODY_AT + Vector3(0, 1.72, 0)
	add_child(head)
	_holder = Node3D.new()
	_holder.position = BODY_AT + Vector3(0, 1.45, 0)
	add_child(_holder)


func _clip(cat: GSWeaponAttachments, att: StringName, w: StringName) -> void:
	var a := cat.get_attachment(att) as GSWeaponAttachment
	var f := GSWeaponFitting.make(w)
	f.fit(a.mount, att)
	var fp := ZzMedievalViewModel.new()
	_fp.add_child(fp)
	var tp := ZzMedievalWorldModel.new()
	_holder.add_child(tp)
	var both: Array[ZzMedievalHeld] = [fp, tp]
	for h in both:
		h.set_process(false)
		h.flight_parent = self
		h.bind(w)
		h.show_fitting(cat, f)
		h.step(0.0)
	var dir := ProjectSettings.globalize_path("%s/%s/%s" % [_out, att, w])
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().size = CAM
	var piece := _piece(fp)
	var reach := maxf(_bounds(piece).size.length(), 0.06)
	var placed := 0
	for i in _n:
		_act(both, w, i)
		var strip := Image.create(CAM.x * 3, CAM.y, false, Image.FORMAT_RGBA8)
		var cams: Array[Camera3D] = [_fp, _detail, _tp]
		_aim_detail(piece, att, reach)
		_tp.position = BODY_AT + Vector3(1.9, 1.75, -1.5).rotated(Vector3.UP, deg_to_rad(25.0 * (_variant % 3)))
		_tp.look_at(BODY_AT + Vector3(0, 1.2, -0.4))
		for k in 3:
			cams[k].current = true
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, CAM), Vector2i(k * CAM.x, 0))
		strip.save_png("%s/f%03d.png" % [dir, i])
		placed += 1
	print("clip ", att, "/", w, " frames ", placed, " piece ", _bounds(piece).size)
	for h in both:
		h.get_parent().remove_child(h)
		h.free()
	for n in get_children():
		if n is ZzProjectileFlight or n is CPUParticles3D:
			n.free()


## The weapon in use, a frame's worth of time: a swing (or the shield's bash) at the start and again halfway; the
## crossbow aims a while (the heads ride the nocked bolt), shoots, then reloads.
func _act(both: Array[ZzMedievalHeld], w: StringName, i: int) -> void:
	for h in both:
		if w == &"crossbow":
			if i == _n * 2 / 3:
				h.anim.start_use()
			elif i == _n * 2 / 3 + 4:
				h.anim.set_reloading(true)
		elif i == 2 or i == _n / 2 + 2:
			h.anim.start_use()
	var t := 0.0
	while t < FRAME - 1e-6:
		for h in both:
			h.step(STEP)
		for n in get_children():
			if n is ZzProjectileFlight:
				(n as ZzProjectileFlight).step(STEP)
		t += STEP


## The close camera: a fixed offset in the piece's own socket frame (so it rides the weapon and the piece holds
## still in frame while the hands swing it; anything that slips on the weapon shows), from the side each piece is
## best seen: the boss from the shield's front, the counterweight and the wrap from below the hand, the rest from the side.
## The variant turns it round the weapon's long axis.
const LOOK := {
	&"zz_spiked_boss": Vector3(0.35, 0.25, 1.0), &"zz_counterweight": Vector3(0.7, -1.0, 0.4),
	&"zz_leather_wrap": Vector3(0.85, -0.6, 0.5), &"zz_aperture_sight": Vector3(0.85, -0.35, 0.6),
	&"zz_barbed_heads": Vector3(1.0, 0.1, 0.35),
}
var _last := Vector3.ZERO


func _aim_detail(piece: Node3D, att: StringName, reach: float) -> void:
	if _visible(piece):
		_last = _bounds(piece).get_center()
	var frame := (piece.get_parent() as Node3D).global_basis.orthonormalized()
	var local: Vector3 = LOOK.get(att, Vector3(1, 0.3, 0.5))
	local = local.rotated(Vector3.UP if att != &"zz_spiked_boss" else Vector3.BACK, deg_to_rad(28.0 * (_variant % 3 - 1)))
	var d := (frame * local).normalized()
	_detail.position = _last + d * clampf(reach * 3.5, 0.18, 0.9)
	var up := Vector3.UP if absf(d.y) < 0.95 else Vector3.FORWARD
	_detail.look_at(_last, up)


func _piece(h: ZzMedievalHeld) -> Node3D:
	for n in h.find_children("*", "", true, false):
		if n.has_meta(&"gs_attachment_model"):
			return n as Node3D
	return h


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
