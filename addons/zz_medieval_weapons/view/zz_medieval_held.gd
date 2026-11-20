class_name ZzMedievalHeld
extends Node3D

## A weapon in somebody's hands (model, arms, string, nocked arrow) driven by one [ZzWeaponAnim]; the first and
## third person views are this with different shoulders. The node's frame is the aim frame (-z forward).
## Art comes from [ZzMedievalModels] and [ZzMedievalArtTable]; nothing here names a weapon.

## The visual arrow left the string. [param xf] is its world transform, -Z the way it flies.
signal projectile_loosed(xf: Transform3D, charge: float)

const ARM_RADIUS := 0.045
const SLEEVE := Color(0.34, 0.22, 0.14)
const SKIN := Color(0.86, 0.66, 0.52)
const GLOVE := Color(0.22, 0.14, 0.09)
## Grip centre to wrist, along the forearm.
const WRIST := 0.075

## Shoulders in the aim frame, [code]x[/code] mirrored for a left hand. Arm bone length.
var shoulder: Vector3 = Vector3(0.22, -0.28, 0.14)
var bone: float = 0.40
var show_arms: bool = true
## Draw a flying copy of a loosed arrow (see [ZzProjectileFlight]).
var spawn_flight: bool = true
var flight_parent: Node = null

## Play dot-audio's stock sound for each cue (silent when it is not linked); false when the game plays cues itself.
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
	_arm_mat = StandardMaterial3D.new()
	_arm_mat.albedo_color = SLEEVE
	_arm_mat.roughness = 0.9
	_skin_mat = StandardMaterial3D.new()
	_skin_mat.albedo_color = GLOVE
	_skin_mat.roughness = 0.62
	for i in 2:
		# Arm 0 is the main hand; its handedness is set per weapon in [method _place_arms].
		var a := {"upper": _limb(0.036, 0.031, _arm_mat), "fore": _limb(0.031, 0.026, _arm_mat), "elbow": _ball(0.031, _arm_mat),
			"cuff": _limb(0.030, 0.034, _skin_mat), "hand": _hand(), "left": false}
		_arms.append(a)


## A tapered unit-height cylinder: [param r0] at the start of a span, [param r1] at its end.
func _limb(r0: float, r1: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r1
	m.bottom_radius = r0
	m.height = 1.0
	m.radial_segments = 16
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
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


static var _gloves: Dictionary = {}

## A gloved fist closed round a grip along local +Y through the origin; the wrist is at +Z ([const WRIST]),
## the back of a right hand faces +X (a left hand is its mirror, built rather than scaled so faces stay outward).
static func glove_mesh(left: bool) -> Mesh:
	if _gloves.has(left):
		return _gloves[left]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mx := -1.0 if left else 1.0
	var at := func(phi_deg: float, y: float, r: float) -> Vector3:
		var f := deg_to_rad(phi_deg)
		return Vector3(sin(f) * r * mx, y, cos(f) * r)
	# Fingers, index (toward +Y) to little: knuckle, then round the far side of the grip back to the palm.
	var fingers := [[0.029, 0.0092, 0.025], [0.009, 0.0095, 0.0255], [-0.011, 0.009, 0.025], [-0.029, 0.008, 0.0235]]
	for fg in fingers:
		var y := float(fg[0])
		var r := float(fg[1])
		var rc := float(fg[2])
		var pts := [at.call(95.0, y, rc + 0.004), at.call(170.0, y, rc), at.call(245.0, y, rc), at.call(305.0, y * 0.97, rc - 0.002)]
		for i in pts.size() - 1:
			_capsule(st, pts[i], pts[i + 1], r * (1.0 - 0.08 * i))
	# Back of the hand: knuckles to wrist; the heel of the palm closes the inside.
	_capsule(st, Vector3(0.022 * mx, 0.026, 0.0), Vector3(0.022 * mx, -0.026, 0.0), 0.012)
	for k in 5:
		var y := lerpf(0.026, -0.026, float(k) / 4.0)
		_capsule(st, Vector3(0.022 * mx, y, 0.0), Vector3(0.012 * mx, y * 0.6, WRIST - 0.012), 0.0125)
	_capsule(st, Vector3(-0.004 * mx, 0.018, 0.028), Vector3(-0.004 * mx, -0.024, 0.03), 0.013)
	_capsule(st, Vector3(0.012 * mx, 0.0, WRIST - 0.012), Vector3(-0.004 * mx, 0.0, 0.03), 0.02)
	# Thumb: from the heel over the front of the index finger.
	var t0 := Vector3(-0.010 * mx, 0.026, 0.045)
	var t1: Vector3 = at.call(275.0, 0.036, 0.03)
	var t2: Vector3 = at.call(225.0, 0.04, 0.031)
	var t3: Vector3 = at.call(185.0, 0.037, 0.03)
	_capsule(st, t0, t1, 0.0115)
	_capsule(st, t1, t2, 0.0105)
	_capsule(st, t2, t3, 0.0095)
	st.generate_normals()
	var m := st.commit()
	_gloves[left] = m
	return m


## A capsule from [param a] to [param b] appended to [param st] (low poly; normals are generated after).
static func _capsule(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var l := d.length()
	var y := d / l if l > 0.0001 else Vector3.UP
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	const SEG := 10
	const HALF := 4
	# Rings from the bottom pole through the shaft to the top pole.
	var rings: Array = []
	for i in range(HALF + 1):
		var t := float(i) / HALF * PI * 0.5
		rings.append([a - y * r * cos(t), r * sin(t)])
	for i in range(HALF + 1):
		var t := float(i) / HALF * PI * 0.5
		rings.append([b + y * r * sin(t), r * cos(t)])
	for i in rings.size() - 1:
		var c0: Vector3 = rings[i][0]
		var r0: float = rings[i][1]
		var c1: Vector3 = rings[i + 1][0]
		var r1: float = rings[i + 1][1]
		for j in SEG:
			var a0 := TAU * j / SEG
			var a1 := TAU * (j + 1) / SEG
			var p00 := c0 + (x * cos(a0) + z * sin(a0)) * r0
			var p01 := c0 + (x * cos(a1) + z * sin(a1)) * r0
			var p10 := c1 + (x * cos(a0) + z * sin(a0)) * r1
			var p11 := c1 + (x * cos(a1) + z * sin(a1)) * r1
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p10)
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p11)


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
	if not anim.loosed.is_connected(_on_loosed):
		anim.loosed.connect(_on_loosed)
	if not anim.cue.is_connected(_on_cue):
		anim.cue.connect(_on_cue)
	apply()


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
	return Transform3D(b, rest + (p["pos"] as Vector3))


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


## Two-bone solve: the elbow falls below and outside the line from shoulder to hand.
## [param draw] 0..1 lifts the elbow from below the arm to level and behind it, as a drawing arm's is.
func _arm(a: Dictionary, s: Vector3, h: Vector3, side: float, grip_up: Vector3 = Vector3.UP, draw: float = 0.0) -> void:
	var d := h - s
	# Stretchy past full reach: a hand that cannot reach its grip leaves the weapon floating
	# beside the arm, which reads far worse than a forearm a few centimetres long.
	var reach := maxf(bone, d.length() * 0.5 + 0.01)
	var dist := clampf(d.length(), 0.05, reach * 2.0 - 0.01)
	var dn := d.normalized()
	var pole := Vector3(0.55 * side, -1.0, 0.25).normalized().lerp(Vector3(0.45 * side, -0.9, 1.0).normalized(), draw).normalized()
	var perp := (pole - dn * pole.dot(dn)).normalized()
	var x := dist * 0.5
	var hgt := sqrt(maxf(reach * reach - x * x, 0.0))
	var elbow := s + dn * x + perp * hgt
	var hand := s + dn * dist
	# The fist closes round the grip axis; the wrist sits back toward the elbow.
	var back := (elbow - hand).normalized()
	var up := grip_up - back * grip_up.dot(back)
	if up.length() < 0.05:
		up = Vector3.UP - back * back.y
	up = up.normalized()
	var wrist := hand + back * WRIST
	_span(a["upper"], s, elbow, true)
	_span(a["fore"], elbow, wrist, true)
	(a["elbow"] as Node3D).position = elbow
	_span(a["cuff"], wrist + back * 0.07, wrist - back * 0.005, true)
	var left := side < 0.0
	if a["left"] != left:
		a["left"] = left
		(a["hand"] as MeshInstance3D).mesh = glove_mesh(left)
	(a["hand"] as Node3D).transform = Transform3D(Basis(up.cross(back), up, back), hand)


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


var flight_mask: int = 1


## The weapon met something: it recoils, the sound is asked for and a burst is thrown at
## [param point] (world space).
func impact(point: Vector3, normal: Vector3, surface: StringName = &"flesh") -> void:
	anim.hit(surface)
	ZzMedievalImpacts.burst(flight_parent if flight_parent != null else get_tree().current_scene, point, normal, surface)
