class_name ZzMedievalCarrier
extends Node3D

## A whole person holding a [ZzMedievalWorldModel], for cameras outside the holder (a third-person view, the sheet
## tool's [code]--world[/code]): gs-player-char's [GSHumanoidFigure], feet at this node's origin facing -Z, the world
## model hung at its shoulders, and each [method step] both arms reach onto the weapon's grips after the clip, as the
## eye's [GSPlayerViewArms] do (the right hand on [member ZzMedievalHeld.held_grip]'s grip, the left on its support,
## or left at its side for a one-hand weapon).

## The stock person drawn, and their height in metres.
const LOOK := 3
const HEIGHT := 1.8
## Where the elbows point, in the figure's frame (x mirrored for the left): out, down, a little back.
const POLE := Vector3(0.6, -1.0, 0.3)

var figure: GSHumanoidFigure
var held: ZzMedievalWorldModel

var _shoulders: Node3D
var _right: Array[int] = []
var _left: Array[int] = []
var _placed := false


func _init() -> void:
	name = "Carrier"


## Builds the person and the weapon they carry (once; call [method ZzMedievalHeld.bind] on [member held] after).
func build(look: GSHumanoidLook = null, height: float = HEIGHT) -> void:
	figure = GSHumanoidFigure.new()
	figure.name = "Body"
	figure.auto_animate = false
	figure.floor_mask = 0
	add_child(figure)
	figure.build(look if look != null else GSHumanoidLook.stock(LOOK), height)
	var sk := figure.skeleton()
	if sk != null:
		_right = _chain(sk, ".R")
		_left = _chain(sk, ".L")
	_shoulders = Node3D.new()
	_shoulders.name = "Shoulders"
	_shoulders.position = Vector3(0.0, height * 0.8, 0.0)
	add_child(_shoulders)
	held = ZzMedievalWorldModel.new()
	held.set_process(false)
	_shoulders.add_child(held)


static func _chain(sk: Skeleton3D, side: String) -> Array[int]:
	var out: Array[int] = []
	for b in ["UpperArm", "LowerArm", "Middle1"]:
		var i := sk.find_bone(b + side)
		if i < 0:
			return []
		out.append(i)
	return out


## Advances the weapon and the body by [param dt] and closes the hands on the grips.
func step(dt: float) -> void:
	if figure == null:
		return
	figure.animate(0.0, dt)
	if not _placed and is_inside_tree():
		_place_shoulders()
	held.step(dt)
	_reach()


## Seats the world model between the figure's shoulder joints, as posed, and sets its shoulder width from them.
func _place_shoulders() -> void:
	var sk := figure.skeleton()
	if sk == null or _right.is_empty() or _left.is_empty():
		return
	_placed = true
	var r := to_local(sk.global_transform * sk.get_bone_global_pose(_right[0]).origin)
	var l := to_local(sk.global_transform * sk.get_bone_global_pose(_left[0]).origin)
	_shoulders.position = (r + l) * 0.5
	held.shoulder = Vector3(absf(r.x - l.x) * 0.5, 0.0, 0.0)


func _reach() -> void:
	var grip := held.held_grip
	var sk := figure.skeleton()
	if sk == null or grip == null or not grip.is_valid() or _right.is_empty():
		return
	var to_sk := sk.global_transform.affine_inverse()
	var out := to_sk.basis * (global_basis * POLE)
	GSHumanoidIk.two_bone(sk, _right, to_sk * grip.grip_world(), out, 1.0)
	if grip.is_two_hand() and not _left.is_empty():
		GSHumanoidIk.two_bone(sk, _left, to_sk * grip.support_world(), to_sk.basis * (global_basis * Vector3(-POLE.x, POLE.y, POLE.z)), 1.0)
