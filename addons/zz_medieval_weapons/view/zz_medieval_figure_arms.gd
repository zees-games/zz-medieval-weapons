class_name ZzMedievalFigureArms
extends Node

## Puts a [GSHumanoidFigure]'s own arms on a [ZzMedievalHeld]'s hands: after the figure has posed, a two-bone solve turns
## each arm's bones so the wrist reaches the grip, the elbow falling down and outside. The held model's own cylinder arms
## are hidden; the person's skinned arms replace them. Add it as a child of anything; call [method bind] once.

const ARM_R: Array[String] = ["UpperArm.R", "LowerArm.R", "Middle1.R"]
const ARM_L: Array[String] = ["UpperArm.L", "LowerArm.L", "Middle1.L"]

var _figure: GSHumanoidFigure = null
var _held: ZzMedievalHeld = null
var _chains: Array = []
## Fastest an arm bone may turn, degrees a second: a shield bash or a flipped elbow solve is eased, not popped.
var max_turn_dps: float = 700.0
var _last: Dictionary = {}


## [param held] is the world model whose hands the arms follow; [param figure] the person drawn.
func bind(figure: GSHumanoidFigure, held: ZzMedievalHeld) -> void:
	_figure = figure
	_held = held
	held.show_arms = false
	# After the figure's own pose, so this frame's solve is what the skin is drawn from.
	process_priority = 1000
	_chains.clear()
	var sk := figure.skeleton()
	if sk == null:
		return
	for names in [ARM_R, ARM_L]:
		var chain: Array[int] = []
		for n in names:
			chain.append(sk.find_bone(n))
		_chains.append(chain)


func _process(delta: float) -> void:
	if _figure == null or _held == null or not is_instance_valid(_held):
		return
	var sk := _figure.skeleton()
	if sk == null:
		return
	var to_skel := sk.global_transform.affine_inverse()
	var side := float(_held.arm_side())
	for i in _chains.size():
		var chain: Array[int] = _chains[i]
		if chain.has(-1):
			continue
		# The held model's main hand is the right one for side +1; its off hand the other.
		var held_index := i if side > 0.0 else 1 - i
		var target := to_skel * _held.hand_world(held_index).origin
		var out := 1.0 if i == 0 else -1.0
		var pole := to_skel.basis * (_figure.global_basis * Vector3(0.55 * out, -1.0, 0.25))
		GSHumanoidIk.two_bone(sk, chain, target, pole.normalized(), 1.0)
		for bone in [chain[0], chain[1]]:
			var want := sk.get_bone_pose_rotation(bone)
			if _last.has(bone) and delta > 0.0:
				var before: Quaternion = _last[bone]
				var angle := before.angle_to(want)
				var limit := deg_to_rad(max_turn_dps) * delta
				if angle > limit:
					want = before.slerp(want, limit / angle)
					sk.set_bone_pose_rotation(bone, want)
			_last[bone] = want
