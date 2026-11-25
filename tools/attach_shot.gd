extends Node3D
## Attachment clips for the visual judge: each fitted weapon from three cameras side by side, a slow orbit, one png
## per frame under <out>/<attachment>/<weapon>/ (attach_shot.sh turns them into <attachment>/<weapon>.mp4).
## Run under Xvfb on a GPU box: `--out=<dir> [--frames=N]`.

const CAM := Vector2i(400, 400)
const PAIRS := {
	&"zz_aperture_sight": [&"crossbow"], &"zz_barbed_heads": [&"crossbow"],
	&"zz_leather_wrap": [&"longsword", &"dagger", &"battle_axe", &"war_axe", &"double_axe", &"mace", &"spear"],
	&"zz_counterweight": [&"longsword", &"dagger", &"battle_axe", &"war_axe", &"double_axe", &"mace", &"spear"],
	&"zz_spiked_boss": [&"round_shield"],
}

var _out := "res://screenshots/attach"
var _n := 24
var _variant := 0   ## --variant=N: the judge pass number; other camera angles and light
var _cam: Camera3D


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
	sun.rotation_degrees = Vector3(-50, 25 + 55.0 * _variant, 0)
	sun.light_energy = maxf(1.0 - 0.2 * _variant, 0.4)
	add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 30
	add_child(_cam)
	_cam.current = true
	var cat := ZzMedievalAttachmentPack.catalogue(PackedStringArray(["res://cfg"]))
	for att: StringName in PAIRS:
		for w: StringName in PAIRS[att]:
			await _clip(cat, att, w)
	get_tree().quit()


func _clip(cat: GSWeaponAttachments, att: StringName, w: StringName) -> void:
	var held := ZzMedievalViewModel.new()
	held.show_arms = false
	add_child(held)
	held.set_process(false)
	held.bind(w)
	held.step(0.0)
	var f := GSWeaponFitting.make(w)
	f.fit((cat.get_attachment(att) as GSWeaponAttachment).mount, att)
	held.show_fitting(cat, f)
	held.step(0.0)
	# Frame the fitted part and a hand's width of the weapon around it, not the whole weapon.
	var mount := String((cat.get_attachment(att) as GSWeaponAttachment).mount)
	var box := _bounds(held._grip.get_node(GSWeaponAttachmentModels.SOCKET_PREFIX + mount))
	var c := box.get_center()
	var r := maxf(box.size.length() * 0.5 + 0.1, 0.2)
	var dir := ProjectSettings.globalize_path("%s/%s/%s" % [_out, att, w])
	DirAccess.make_dir_recursive_absolute(dir)
	get_viewport().size = CAM
	for i in _n:
		var t := float(i) / float(_n)
		var strip := Image.create(CAM.x * 3, CAM.y, false, Image.FORMAT_RGBA8)
		for k in 3:
			var yaw := deg_to_rad(40.0 + 30.0 * _variant + 100.0 * k + 40.0 * sin(t * TAU))
			var pitch := deg_to_rad([15.0, 5.0, 55.0][k])
			var d := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			_cam.position = c + d * r * 3.2
			_cam.look_at(c)
			await RenderingServer.frame_post_draw
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			strip.blit_rect(img, Rect2i(Vector2i.ZERO, CAM), Vector2i(k * CAM.x, 0))
		strip.save_png("%s/f%03d.png" % [dir, i])
	print("clip ", att, "/", w, " ", box)
	held.queue_free()


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
