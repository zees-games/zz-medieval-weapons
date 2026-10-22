class_name ZzMedievalHeld
extends Node3D

## A weapon in somebody's hands: the model, two arms, the string, the nocked arrow, all driven
## by one [ZzWeaponAnim]. [ZzMedievalViewModel] (first person, under the camera) and
## [ZzMedievalWorldModel] (third person, at a carrier's chest) are this with different
## shoulders, so a swing is one curve in both.
##
## The node's own frame is the aim frame: x right, y up, -z forward. Parent it to the camera, or
## to a node at the carrier's shoulders that turns with their aim.
##
## [b]Art comes from one place.[/b] [method ZzMedievalModels.build] returns a vendored .glb if
## there is one and a placeholder otherwise; where the hands go, which swings exist and where
## the string is are rows of [ZzMedievalArtTable]. Nothing here names a weapon.

## The visual arrow left the string. [param xf] is its world transform, -Z the way it flies.
signal projectile_loosed(xf: Transform3D, charge: float)

const ARM_RADIUS := 0.045
const SLEEVE := Color(0.34, 0.22, 0.14)
const SKIN := Color(0.86, 0.66, 0.52)

## Shoulders in the aim frame, [code]x[/code] mirrored for a left hand. Arm bone length.
var shoulder: Vector3 = Vector3(0.22, -0.28, 0.14)
var bone: float = 0.40
var show_arms: bool = true
## Draw a flying copy of a loosed arrow (see [ZzProjectileFlight]).
var spawn_flight: bool = true
var flight_parent: Node = null

var anim := ZzWeaponAnim.new()
var weapon_id: StringName = &""

var _grip: Node3D
var _model: Node3D
var _row: Dictionary = {}
var _cfg: Dictionary = {}
var _string_a: MeshInstance3D
var _string_b: MeshInstance3D
var _missile: Node3D
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
	_skin_mat.albedo_color = SKIN
	_skin_mat.roughness = 0.8
	for i in 2:
		var a := {"upper": _limb(0.032), "fore": _limb(0.028), "hand": _hand()}
		_arms.append(a)


func _limb(r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = 1.0
	m.radial_segments = 10
	m.rings = 1
	mi.mesh = m
	mi.material_override = _arm_mat
	add_child(mi)
	return mi


func _hand() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.04
	m.height = 0.08
	mi.mesh = m
	mi.material_override = _skin_mat
	add_child(mi)
	return mi


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
	apply()


func _drop(n: Node) -> Node:
	if n != null:
		n.queue_free()
	return null


func _line() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(0.006, 0.006, 1.0)
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = ZzMedievalModels.STRING
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
		var tips: Array = s["tips"]
		_span_box(_string_a, tips[0], n)
		_span_box(_string_b, tips[1], n)
		if is_missile and _missile != null:
			_missile.visible = bool(p["nock"])
			var axis: Vector3 = _row["nock_axis"]
			var plen := ZzMedievalModels.projectile_length(StringName(_row["projectile"]))
			var up := Vector3(0, 0, 1) if absf(axis.y) > 0.9 else Vector3.UP
			var centre := n + axis * plen * 0.5 + (_row.get("nock_lift", Vector3.ZERO) as Vector3)
			_missile.transform = Transform3D(Basis.looking_at(axis, up), centre)
	_place_arms(gx, p)


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
	# The other hand: the weapon's second grip, the string, or hanging loose.
	var idle := Vector3(-0.30 * side, -0.46, -0.34)
	var off_hand := idle
	if _row.has("offhand"):
		off_hand = gx * (_row["offhand"] as Vector3)
	var w := float(p["off_string"])
	if w > 0.0 and _row.has("string"):
		off_hand = off_hand.lerp(gx * ZzMedievalArtTable.string_point(weapon_id, float(p["string_pull"])), w)
	_arm(_arms[0], main_s, main_hand, side)
	_arm(_arms[1], off_s, off_hand, -side)
	for a in _arms:
		for k in ["upper", "fore", "hand"]:
			(a[k] as Node3D).visible = show_arms


## Two-bone solve: the elbow falls below and outside the line from shoulder to hand.
func _arm(a: Dictionary, s: Vector3, h: Vector3, side: float) -> void:
	var d := h - s
	# Stretchy past full reach: a hand that cannot reach its grip leaves the weapon floating
	# beside the arm, which reads far worse than a forearm a few centimetres long.
	var reach := maxf(bone, d.length() * 0.5 + 0.01)
	var dist := clampf(d.length(), 0.05, reach * 2.0 - 0.01)
	var dn := d.normalized()
	var pole := (Vector3(0.55 * side, -1.0, 0.25)).normalized()
	var perp := (pole - dn * pole.dot(dn)).normalized()
	var x := dist * 0.5
	var hgt := sqrt(maxf(reach * reach - x * x, 0.0))
	var elbow := s + dn * x + perp * hgt
	var hand := s + dn * dist
	_span(a["upper"], s, elbow, true)
	_span(a["fore"], elbow, hand, true)
	(a["hand"] as Node3D).position = hand


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
