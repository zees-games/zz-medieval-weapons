class_name ZzAnimBake
extends RefCounted

## Samples a weapon's procedural first-person motion into keyframed tracks, from the code the game runs: a real [ZzMedievalHeld] is driven
## through each clip the weapon has (its swing styles, block, idle; a bow's draw and loose; a crossbow's fire and reload) at 60 fps and the
## weapon's transform is read back each frame; no number is copied. A bow's or crossbow's nocked arrow or bolt is baked as the `magazine`
## track (transform in the weapon's grip frame, plus `magazine.visible`), so its travel is the clip's mag_displacement.
## Used by tools/export_anim_tracks.gd (Nightly's asset viewer plays the sidecar next to the model) and the suite.
## Space: the held node's aim frame (the camera's, no hands lens), metres, -Z forward. The sidecar format is Nightly's version 1 (lib/anim-sample.mjs).

const Sidecar := preload("res://addons/gs_weapon/view/gs_weapon_anim_sidecar.gd")
const FPS := Sidecar.FPS
const STEP := Sidecar.STEP
const PACK := "zz-medieval-weapons"

var _held: ZzMedievalHeld = null
var _w: Array = []
var _m: Array = []
var _vis: Array = []
var _frames := 0


## The clips weapon [param id] has, in play order, each {name, loop}.
static func clip_names(id: StringName) -> Array[Dictionary]:
	var row := ZzMedievalArtTable.row(id)
	var out: Array[Dictionary] = []
	for style: int in row.get("styles", []):
		if style == ZzWeaponPose.Style.LOOSE:
			out.append({"name": "draw", "loop": false})
			out.append({"name": "loose", "loop": false})
		else:
			out.append({"name": String(ZzWeaponPose.style_name(style)), "loop": false})
	if String(row.get("projectile", "")) == "bolt":
		out.append({"name": "reload", "loop": false})
	if not row.has("string"):
		out.append({"name": "block", "loop": false})
	out.append({"name": "idle", "loop": true})
	return out


## Bakes every clip of weapon [param id] under [param host] (a node in the tree). {} for an unknown id or one with only a placeholder model.
func bake(host: Node, id: StringName) -> Dictionary:
	if not ZzMedievalArtTable.has(id) or ZzMedievalModels.is_placeholder(id):
		return {}
	var clips: Array = []
	for c in clip_names(id):
		_held = ZzMedievalHeld.new()
		_held.show_arms = false
		_held.spawn_flight = false
		_held.play_builtin_sounds = false
		_held.set_process(false)
		host.add_child(_held)
		_held.bind(id)
		clips.append(_clip(String(c.name), bool(c.loop)))
		host.remove_child(_held)
		_held.free()
	return _sidecar(String(id), clips)


## The arrow's or bolt's own sidecar: its track is the missile the bow's or crossbow's clips carry (grip frame), so the projectile model
## previews the nock and loose it is made for. [param carrier] is the sidecar [method bake] returned for the weapon that looses it.
static func projectile_sidecar(projectile_id: StringName, carrier: Dictionary) -> Dictionary:
	var clips: Array = []
	for c: Dictionary in carrier.get("clips", []):
		for t: Dictionary in c.tracks:
			if t.target == "magazine" and t.path == "transform":
				clips.append({"name": c.name, "length": c.length, "frames": c.frames, "loop": c.loop,
					"tracks": [{"target": "weapon", "path": "transform", "values": t.values}]})
	if clips.is_empty():
		return {}
	return _sidecar(String(projectile_id), clips)


static func _sidecar(id: String, clips: Array) -> Dictionary:
	return Sidecar.sidecar(id, id, Sidecar.asset_of(PACK, "res://assets/" + id), Sidecar.lens_identity(), "", "", clips)


func _clip(name: String, loop: bool) -> Dictionary:
	_reset()
	var anim := _held.anim
	_held.step(0.0)
	_snap()
	match name:
		"draw":
			anim.hold_draw(true)
			_run(anim.draw_s + 0.2)
		"loose":
			anim.hold_draw(true)
			_run(anim.draw_s)
			_reset()
			anim.hold_draw(false)
			_snap()
			_run(1.0)
		"fire":
			anim.start_use(ZzWeaponPose.Style.FIRE)
			_snap()
			_run(0.8)
		"reload":
			anim.loose()
			_run(0.4)
			_reset()
			anim.set_reloading(true)
			_snap()
			_run(anim.load_s + 0.25)
		"block":
			anim.set_blocking(true)
			_run(0.6)
		"idle":
			_run(2.0)
		_:
			anim.start_use(_style_of(name))
			_run(anim.swing_s + 0.15)
	var tracks: Array = [Sidecar.track("weapon", "transform", _w)]
	if _held.has_missile():
		tracks.append(Sidecar.track("magazine", "transform", _m))
		tracks.append({"target": "magazine.visible", "path": "visible", "values": _vis.duplicate()})
	return Sidecar.clip(name, loop, _frames, tracks)


static func _style_of(name: String) -> int:
	for s: int in ZzWeaponPose.Style.values():
		if String(ZzWeaponPose.style_name(s)) == name:
			return s
	return ZzWeaponPose.Style.NONE


func _reset() -> void:
	_w = []
	_m = []
	_vis = []
	_frames = 0


func _run(seconds: float) -> void:
	for _i in int(ceil(seconds * FPS)):
		_held.step(STEP)
		_snap()


func _snap() -> void:
	_append(_w, _held.weapon_transform())
	if _held.has_missile():
		_append(_m, _held.missile_transform())
		_vis.append(1.0 if _held.missile_visible() else 0.0)
	_frames += 1


static func _append(into: Array, t: Transform3D) -> void:
	into.append_array(Sidecar.t7(t))
