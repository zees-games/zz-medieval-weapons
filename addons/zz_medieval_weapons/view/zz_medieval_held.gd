class_name ZzMedievalHeld
extends Node3D

## A weapon in somebody's hands (model, arms, string, nocked arrow) driven by one [ZzWeaponAnim]; the first and
## third person views are this with different shoulders. The node's frame is the aim frame (-z forward).
## Art comes from [ZzMedievalModels] and [ZzMedievalArtTable]; nothing here names a weapon.

## The visual arrow left the string. [param xf] is its world transform, -Z the way it flies.
signal projectile_loosed(xf: Transform3D, charge: float)

## The head stand-in's skin in the sheet tool.
const SKIN := Color(0.86, 0.66, 0.52)
## The arms' look and height (gs-player-char's stock person 3).
const ARMS_LOOK := 3
const ARMS_HEIGHT := 1.8

## Shoulders in the aim frame, [code]x[/code] mirrored for a left hand, and arm bone length: the reach a pose is kept
## within ([method _within_reach]).
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
## The family's own first-person arms (gs-player-char), posed on [member held_grip] each [method step]; null on a
## holder that draws no arms ([method _wants_arms]).
var view_arms: GSPlayerViewArms
## Where the hands close on the weapon now in hand, in the grip node's space (+Y along the haft, +Z its back).
var held_grip: GSViewGrip


func _ready() -> void:
	if _grip == null:
		_make_parts()


func _make_parts() -> void:
	_grip = Node3D.new()
	_grip.name = "Grip"
	add_child(_grip)
	held_grip = GSViewGrip.one_hand(_grip, Vector3.ZERO)
	held_grip.forward = Vector3.UP
	held_grip.up = Vector3.BACK
	if _wants_arms():
		# The arms' head sits at this node's origin: the view model hangs at the eye.
		view_arms = GSPlayerViewArms.new()
		view_arms.name = "Arms"
		add_child(view_arms)
		view_arms.build(GSHumanoidLook.stock(ARMS_LOOK), ARMS_HEIGHT)


## True where this holder draws the player's own arms (the eye's); a world model is held by a whole body instead.
func _wants_arms() -> bool:
	return true


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
	if view_arms != null:
		view_arms.tick(0.0, dt)


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


## Says which hand closes where this frame ([member held_grip], in the grip node's space). The right hand is the
## firing hand and the left the support, as gs-player-char draws them: a left-hand weapon (a shield, a bow's stave) is
## the support hand's, the right one loose beside it or drawing the string; a crossbow's left hand leaves the stock
## for the string as it spans.
func _place_arms(gx: Transform3D, p: Dictionary) -> void:
	if held_grip == null:
		return
	var to_grip := gx.affine_inverse()
	var side := float(_row.get("side", 1))
	var idle := to_grip * Vector3(-0.30 * side, -0.46, -0.34)
	var w := float(p["off_string"]) if _row.has("string") else 0.0
	var pull := float(p["string_pull"])
	if _row.has("string") and not _row.has("offhand"):
		held_grip.kind = GSViewHandPoses.BOW
		held_grip.support = Vector3.ZERO
		held_grip.grip = idle.lerp(ZzMedievalArtTable.string_point(weapon_id, pull), w)
	elif _row.has("string"):
		held_grip.kind = GSViewHandPoses.CROSSBOW
		held_grip.grip = Vector3.ZERO
		held_grip.support = (_row["offhand"] as Vector3).lerp(ZzMedievalArtTable.string_point(weapon_id, pull), w)
	elif side < 0.0:
		held_grip.kind = GSViewHandPoses.SHIELD
		held_grip.support = Vector3.ZERO
		held_grip.grip = idle
	elif _row.has("offhand"):
		held_grip.kind = GSViewHandPoses.HAFT
		held_grip.grip = Vector3.ZERO
		held_grip.support = _row["offhand"]
	else:
		held_grip.kind = GSViewHandPoses.SWORD
		held_grip.grip = Vector3.ZERO
		held_grip.support = Vector3.INF
	if view_arms != null:
		view_arms.set_held(held_grip if show_arms else null)


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
