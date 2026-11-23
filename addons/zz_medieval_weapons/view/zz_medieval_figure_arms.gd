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
## Per arm: the finger roots hanging off the forearm beside the hand bone (they turn with it, or the hand splays), their
## rest turns, and the finger segments with the closed pose of [constant GRIP_CLIP] (a fist, which round a haft or tiller
## reads as a grip, not the open, fanned hand the figure's walk clips leave).
var _fingers: Array = []
var _grip: Array = []
const GRIP_CLIP := &"ual_idle"


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
	_measure_fingers(sk)


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
		var hand_was := sk.get_bone_pose_rotation(chain[2])
		GSHumanoidIk.two_bone(sk, chain, target, pole.normalized(), 1.0)
		_close_hand(sk, i, chain[2], hand_was)
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


## Finds each hand's other finger roots and the closed pose of every finger segment.
func _measure_fingers(sk: Skeleton3D) -> void:
	_fingers.clear()
	_grip.clear()
	var player: AnimationPlayer = null
	var players := _figure.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		player = players.front() as AnimationPlayer
	var clip: Animation = null
	if player != null and player.get_animation_library(&"") != null and player.get_animation_library(&"").has_animation(GRIP_CLIP):
		clip = player.get_animation_library(&"").get_animation(GRIP_CLIP)
	var prefix := String(player.get_node(player.root_node).get_path_to(sk)) if clip != null else ""
	for names in [ARM_R, ARM_L]:
		var roots: Array = []
		var segments: Array = []
		var lower := sk.find_bone(names[1])
		var hand := sk.find_bone(names[2])
		if lower >= 0 and hand >= 0:
			var origin := sk.get_bone_rest(hand).origin
			for child in sk.get_bone_children(lower):
				if child != hand and sk.get_bone_rest(child).origin.distance_to(origin) < 0.01:
					roots.append([child, sk.get_bone_rest(child).basis.get_rotation_quaternion()])
			if clip != null:
				var todo: Array[int] = []
				for root in sk.get_bone_children(lower):
					todo.append_array(Array(sk.get_bone_children(root)))
				while not todo.is_empty():
					var bone: int = todo.pop_back()
					todo.append_array(Array(sk.get_bone_children(bone)))
					var track := clip.find_track(NodePath("%s:%s" % [prefix, sk.get_bone_name(bone)]), Animation.TYPE_ROTATION_3D)
					if track >= 0:
						segments.append([bone, clip.rotation_track_interpolate(track, 0.0)])
		_fingers.append(roots)
		_grip.append(segments)


## Turns the hand's other finger roots with the hand bone the solve turned and closes the finger segments.
func _close_hand(sk: Skeleton3D, arm: int, hand: int, was: Quaternion) -> void:
	if arm >= _fingers.size():
		return
	var now := sk.get_bone_pose_rotation(hand)
	var hand_rest := sk.get_bone_rest(hand).basis.get_rotation_quaternion()
	for r in _fingers[arm]:
		sk.set_bone_pose_rotation(r[0], (now * hand_rest.inverse() * (r[1] as Quaternion)).normalized())
	for g in _grip[arm]:
		sk.set_bone_pose_rotation(g[0], g[1])
