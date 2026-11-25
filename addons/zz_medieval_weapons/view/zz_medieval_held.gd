class_name ZzMedievalHeld
extends Node3D

## A weapon in somebody's hands (model, arms, string, nocked arrow) driven by one [ZzWeaponAnim]; the first and
## third person views are this with different shoulders. The node's frame is the aim frame (-z forward).
## Art comes from [ZzMedievalModels] and [ZzMedievalArtTable]; nothing here names a weapon.

## The visual arrow left the string. [param xf] is its world transform, -Z the way it flies.
signal projectile_loosed(xf: Transform3D, charge: float)

const ARM_RADIUS := 0.045
const SKIN := Color(0.86, 0.66, 0.52)
## Grip centre to wrist, along the forearm.
const WRIST := 0.075

## Shoulders in the aim frame, [code]x[/code] mirrored for a left hand. Arm bone length.
var shoulder: Vector3 = Vector3(0.22, -0.28, 0.14)
var bone: float = 0.40
var show_arms: bool = true
## Draw a flying copy of a loosed arrow (see [ZzProjectileFlight]).
var spawn_flight: bool = true
var flight_parent: Node = null

## Play gs-audio's stock sound for each cue (silent when it is not linked); false when the game plays cues itself.
var play_builtin_sounds: bool = true

var anim := ZzWeaponAnim.new()
var weapon_id: StringName = &""

var _grip: Node3D
var _voice: AudioStreamPlayer3D
var _model: Node3D
var _row: Dictionary = {}
var _cfg: Dictionary = {}
var _string_a: MeshInstance3D
var _string_b: MeshInstance3D
var _missile: Node3D
var _skel: Skeleton3D
var _catalogue: GSWeaponAttachments
var _fitting: GSWeaponFitting
var _arms: Array = []     # [{upper, fore, hand}] main then off
var _arm_mat: StandardMaterial3D
var _skin_mat: StandardMaterial3D


func _ready() -> void:
	if _grip == null:
		_make_parts()


func _make_parts() -> void:
	_grip = Node3D.new()
	_grip.name = "Grip"
	add_child(_grip)
	_arm_mat = ZzArmArt.sleeve()
	_skin_mat = ZzArmArt.glove()
	for i in 2:
		# Arm 0 is the main hand; its handedness is set per weapon in [method _place_arms]. The cuff is the glove's
		# gauntlet, flaring from the wrist over the sleeve, closed at both ends.
		var a := {"upper": _limb(0.036, 0.031, _arm_mat), "fore": _limb(0.031, 0.027, _arm_mat), "elbow": _ball(0.031, _arm_mat),
			"cuff": _limb(0.025, 0.036, _skin_mat, 24), "hand": _hand(), "left": false}
		_arms.append(a)


## A tapered unit-height cylinder, capped: [param r0] at the start of a span, [param r1] at its end.
func _limb(r0: float, r1: float, mat: Material, segs: int = 20) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r1
	m.bottom_radius = r0
	m.height = 1.0
	m.radial_segments = segs
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)
	return mi


func _ball(r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 16
	m.rings = 8
	mi.mesh = m
	mi.material_override = mat
	add_child(mi)
	return mi


func _hand() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = glove_mesh(false)
	mi.material_override = _skin_mat
	add_child(mi)
	return mi


## A gloved fist closed round a grip along local +Y (see [ZzGloveMesh]).
static func glove_mesh(left: bool) -> Mesh:
	return ZzGloveMesh.fist(left)


## Puts [param id] in the hands, from the art table and [param cfg] (default the shipped
## tuning). Safe to call again to switch weapon.
func bind(id: StringName, cfg: Dictionary = {}) -> void:
	if _grip == null:
		_make_parts()
	if _model != null:
		_model.queue_free()
		_model = null
	_string_a = _drop(_string_a)
	_string_b = _drop(_string_b)
	_missile = _drop(_missile) as Node3D
	weapon_id = id
	_row = ZzMedievalArtTable.row(id)
	_cfg = cfg if not cfg.is_empty() else ZzMedievalConfig.load_all().get(String(id), {})
	anim.configure(id, cfg)
	_model = ZzMedievalModels.build(id)
	_grip.add_child(_model)
	_skel = null
	var sk := _model.find_children("*", "Skeleton3D", true, false)
	if not sk.is_empty():
		_skel = sk[0] as Skeleton3D
	if _row.has("string"):
		# The model's own string cannot move, so it is hidden and redrawn each frame.
		for n in ["string", "string2"]:
			var s := _model.find_child(n, true, false)
			if s != null:
				(s as Node3D).visible = false
		_string_a = _line()
		_string_b = _line()
	if _row.has("projectile"):
		_missile = ZzMedievalModels.projectile(StringName(_row["projectile"]))
		_grip.add_child(_missile)
	ZzMedievalAttachmentDress.dress(_grip, _model, id, _catalogue, _fitting, _missile)
	if not anim.loosed.is_connected(_on_loosed):
		anim.loosed.connect(_on_loosed)
	if not anim.cue.is_connected(_on_cue):
		anim.cue.connect(_on_cue)
	apply()


## Shows [param with]'s attachment models on the weapon now in hand and on each one bound after; null clears them.
func show_fitting(catalogue: GSWeaponAttachments, with: GSWeaponFitting) -> void:
	_catalogue = catalogue
	_fitting = with
	if _grip != null:
		ZzMedievalAttachmentDress.dress(_grip, _model, weapon_id, _catalogue, _fitting, _missile)


func _drop(n: Node) -> Node:
	if n != null:
		n.queue_free()
	return null


func _line() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.0045, 0.0045, 1.0)
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ZzMedievalModels.STRING
	mat.roughness = 0.75
	mi.material_override = mat
	_grip.add_child(mi)
	return mi


func _process(delta: float) -> void:
	step(delta)


## Advances the animation and re-poses everything. The host calls it from its own tick if it
## would rather not rely on [method Node._process] (the sheet tool steps at a fixed rate).
func step(dt: float) -> void:
	anim.advance(dt)
	apply()


func grip_transform() -> Transform3D:
	var p := anim.pose()
	var hold: Vector3 = _row.get("hold", Vector3.ZERO)
	var rest: Vector3 = _row.get("rest", Vector3(0.3, -0.3, -0.5))
	var b := (Basis.from_euler(_rad(p["rot"])) * Basis.from_euler(_rad(hold))).scaled(Vector3.ONE * float(_row.get("scale", 1.0)))
	return _within_reach(Transform3D(b, rest + (p["pos"] as Vector3) + _hand_offset()))


## Where this holder carries the hand beyond the pose (a world model's hip and aim offsets); none for the eye's.
func _hand_offset() -> Vector3:
	return Vector3.ZERO


## Arms are [member bone] + [member bone] long: past [constant REACH_SOFT] of that a pose's reach is eased toward the
## shoulder (never past [constant REACH_MAX]), for the main hand and the second grip alike, so a thrust or a pole arm
## held far out moves the whole weapon back instead of stretching the arm into a pole.
const REACH_SOFT := 0.86
const REACH_MAX := 1.04


func _within_reach(t: Transform3D) -> Transform3D:
	var side := float(_row.get("side", 1))
	var grips: Array = [[Vector3(shoulder.x * side, shoulder.y, shoulder.z), Vector3.ZERO]]
	if _row.has("offhand"):
		grips.append([Vector3(-shoulder.x * side, shoulder.y, shoulder.z), _row["offhand"]])
	var full := bone * 2.0
	var soft := full * REACH_SOFT
	var knee := full * (REACH_MAX - REACH_SOFT)
	for g in grips:
		var d: Vector3 = t * (g[1] as Vector3) - (g[0] as Vector3)
		var l := d.length()
		if l > soft:
			t.origin -= d / l * (l - (soft + knee * tanh((l - soft) / knee)))
	return t


static func _rad(v: Vector3) -> Vector3:
	return Vector3(deg_to_rad(v.x), deg_to_rad(v.y), deg_to_rad(v.z))


## Lays every part out for the current animation state.
func apply() -> void:
	if _grip == null or weapon_id == &"":
		return
	var p := anim.pose()
	var gx := grip_transform()
	_grip.transform = gx
	var pull := float(p["string_pull"])
	var is_missile := _row.has("projectile")
	if _row.has("string"):
		var s: Dictionary = _row["string"]
		var n := ZzMedievalArtTable.string_point(weapon_id, pull)
		var tips := ZzMedievalArtTable.string_tips(weapon_id, pull)
		_flex(pull)
		_span_box(_string_a, tips[0], n)
		_span_box(_string_b, tips[1], n)
		if is_missile and _missile != null:
			_missile.visible = bool(p["nock"])
			var axis: Vector3 = _row["nock_axis"]
			var plen := ZzMedievalModels.projectile_length(StringName(_row["projectile"]))
			var centre := n + axis * plen * 0.5 + (_row.get("nock_lift", Vector3.ZERO) as Vector3)
			if _row.has("arrow_rest"):
				# Nock on the string, shaft over the rest beside the stave rather than through it.
				axis = ((_row["arrow_rest"] as Vector3) - n).normalized()
				centre = n + axis * plen * 0.5
			var up := Vector3(0, 0, 1) if absf(axis.y) > 0.9 else Vector3.UP
			_missile.transform = Transform3D(Basis.looking_at(axis, up), centre)
	_place_arms(gx, p)


## Bends a rigged bow's limbs to [param pull]: each limb bone turns its share of
## [method ZzMedievalArtTable.flex_angle] about the bow's plane normal (+Z), matching [method ZzMedievalArtTable.string_tips].
func _flex(pull: float) -> void:
	flex_skeleton(_skel, weapon_id, pull)


static func flex_skeleton(skel: Skeleton3D, id: StringName, pull: float) -> void:
	var f: Dictionary = (ZzMedievalArtTable.row(id).get("string", {}) as Dictionary).get("flex", {})
	if f.is_empty() or skel == null:
		return
	var ang := deg_to_rad(ZzMedievalArtTable.flex_angle(id, pull))
	var share: Array = f["share"]
	for side in ["top", "bot"]:
		var sg := 1.0 if side == "top" else -1.0
		for i in share.size():
			var b := skel.find_bone(String(f["bone"]) % [side, i])
			if b < 0:
				continue
			var axis := (skel.get_bone_global_rest(b).basis.inverse() * Vector3(0, 0, 1)).normalized()
			skel.set_bone_pose_rotation(b, skel.get_bone_rest(b).basis.get_rotation_quaternion() * Quaternion(axis, ang * float(share[i]) * sg))


func _span_box(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	_span(mi, a, b, false)


## Stretches [param mi] (a unit-length mesh) between two points. [param along_y] true for the
## cylinders (axis Y), false for the box line (axis Z).
static func _span(mi: Node3D, a: Vector3, b: Vector3, along_y: bool) -> void:
	var d := b - a
	var l := maxf(d.length(), 0.001)
	var dn := d / l
	if along_y:
		var ref := Vector3.RIGHT if absf(dn.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
		var x := ref.cross(dn).normalized()
		var z := x.cross(dn)
		mi.transform = Transform3D(Basis(x, dn * l, z), (a + b) * 0.5)
	else:
		mi.transform = Transform3D(Basis.looking_at(dn, Vector3.UP if absf(dn.y) < 0.99 else Vector3.RIGHT).scaled_local(Vector3(1, 1, l)), (a + b) * 0.5)


func _place_arms(gx: Transform3D, p: Dictionary) -> void:
	var side := float(_row.get("side", 1))
	var main_s := Vector3(shoulder.x * side, shoulder.y, shoulder.z)
	var off_s := Vector3(-shoulder.x * side, shoulder.y, shoulder.z)
	var main_hand := gx.origin
	var weapon_up := gx.basis.y.normalized()
	# The other hand: the weapon's second grip, the string, or hanging loose.
	var idle := Vector3(-0.30 * side, -0.46, -0.34)
	var off_hand := idle
	if _row.has("offhand"):
		off_hand = gx * (_row["offhand"] as Vector3)
	var off_up := weapon_up if _row.has("offhand") else Vector3(0, 0, -1)
	var w := float(p["off_string"])
	if w > 0.0 and _row.has("string"):
		off_hand = off_hand.lerp(gx * ZzMedievalArtTable.string_point(weapon_id, float(p["string_pull"])), w)
		off_up = off_up.slerp(weapon_up, w) if off_up.dot(weapon_up) > -0.99 else weapon_up
	_arm(_arms[0], main_s, main_hand, side, weapon_up)
	_arm(_arms[1], off_s, off_hand, -side, off_up, w * smoothstep(0.25, 0.85, float(p["string_pull"])) if _row.has("string") and not _row.has("offhand") else 0.0)
	for a in _arms:
		for k in ["upper", "fore", "elbow", "cuff", "hand"]:
			(a[k] as Node3D).visible = show_arms


## Places one arm so its fist closes on the grip at [param h]. The fist is set first, from the grip alone: its axis
## is [param grip_up] exactly (so it wraps the haft whatever the arm does) and its wrist sits off the haft toward the
## shoulder, a little from below. The arm then reaches the wrist with a two-bone solve whose elbow falls below,
## outside, and away from the eye (so a hand brought close never drives the forearm through the camera).
## [param draw] 0..1 lifts the elbow from below the arm to level and behind it, as a drawing arm's is.
func _arm(a: Dictionary, s: Vector3, h: Vector3, side: float, grip_up: Vector3 = Vector3.UP, draw: float = 0.0) -> void:
	var up := grip_up.normalized() if grip_up.length() > 0.001 else Vector3.UP
	var toward := (s - h).normalized() + Vector3(0.0, -0.5, 0.0)
	var back := toward - up * toward.dot(up)
	if back.length() < 0.05:
		back = Vector3(side, 0.0, 0.0).cross(up)
	back = back.normalized()
	var wrist := h + back * WRIST
	var d := wrist - s
	# Stretchy past full reach: a hand that cannot reach its grip leaves the weapon floating
	# beside the arm, which reads far worse than a forearm a few centimetres long.
	var reach := maxf(bone - WRIST * 0.5, d.length() * 0.5 + 0.01)
	var dist := clampf(d.length(), 0.05, reach * 2.0 - 0.01)
	var dn := d.normalized()
	var mid := s + d * 0.5
	var pole := Vector3(0.55 * side, -1.0, 0.25).normalized().lerp(Vector3(0.45 * side, -0.9, 1.0).normalized(), draw).normalized()
	pole = (pole + mid.normalized() * 0.8).normalized()
	var perp := pole - dn * pole.dot(dn)
	perp = perp.normalized() if perp.length() > 0.01 else Vector3(side, -1.0, 0.0).normalized()
	var x := dist * 0.5
	var hgt := sqrt(maxf(reach * reach - x * x, 0.0))
	var elbow := s + dn * x + perp * hgt
	var fore := (elbow - wrist).normalized()
	_span(a["upper"], s, elbow, true)
	_span(a["fore"], elbow, wrist + fore * 0.03, true)
	(a["elbow"] as Node3D).position = elbow
	# Gauntlet: narrow at the wrist, flaring back over the sleeve.
	_span(a["cuff"], wrist - fore * 0.006, wrist + fore * 0.075, true)
	var left := side < 0.0
	if a["left"] != left:
		a["left"] = left
		(a["hand"] as MeshInstance3D).mesh = glove_mesh(left)
	(a["hand"] as Node3D).transform = Transform3D(Basis(up.cross(back), up, back), h)


func _on_cue(cue: StringName) -> void:
	if not play_builtin_sounds or not is_inside_tree():
		return
	var stream := ZzMedievalSound.stream_for(cue, weapon_id)
	if stream == null:
		return
	if _voice == null:
		_voice = AudioStreamPlayer3D.new()
		_voice.unit_size = 6.0
		_voice.max_distance = 60.0
		add_child(_voice)
	_voice.stream = stream
	_voice.pitch_scale = randf_range(0.95, 1.05)
	_voice.play()


func _on_loosed(charge: float) -> void:
	var xf := global_transform
	if _missile != null and is_inside_tree():
		xf = _missile.global_transform
		xf.basis = global_transform.basis   # flies where the carrier looks, from the string
	projectile_loosed.emit(xf, charge)
	if spawn_flight and is_inside_tree() and _row.has("projectile"):
		var speed_hi := float(_cfg.get("speed", 60.0))
		var speed_lo := float(_cfg.get("min_speed", 20.0))
		var parent := flight_parent if flight_parent != null else get_tree().current_scene
		if parent != null:
			var f := ZzProjectileFlight.launch(parent, StringName(_row["projectile"]), xf, lerpf(speed_lo, speed_hi, charge), float(_cfg.get("gravity_scale", 1.0)))
			f.mask = flight_mask
			ZzMedievalAttachmentDress.dress_flight(_missile, f.model)


var flight_mask: int = 1


## The weapon met something: it recoils, the sound is asked for and a burst is thrown at
## [param point] (world space).
func impact(point: Vector3, normal: Vector3, surface: StringName = &"flesh") -> void:
	anim.hit(surface)
	ZzMedievalImpacts.burst(flight_parent if flight_parent != null else get_tree().current_scene, point, normal, surface)
