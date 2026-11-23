class_name ZzMedievalWorldModel
extends ZzMedievalHeld

## Third person: what a watcher sees a carrier holding. Parent it to a node at the carrier's shoulders that
## turns with their aim; feed it with [method ZzMedievalNet.apply]. The resting hand is the table's
## [code]rest[/code] shifted down and in, so the weapon hangs by the hip.

## Added to every resting hand: a hand at the hip, not in front of the eye.
var hip_offset: Vector3 = Vector3(-0.02, -0.26, 0.12)
## Replaces [member hip_offset] as a bow comes up: the view model's eye anchor moved from the eye
## to these shoulders, so the nock sits at the cheek beside the head, not inside the chest.
var aim_offset: Vector3 = Vector3(0.05, 0.33, -0.03)


func _init() -> void:
	name = "WorldModel"
	shoulder = Vector3(0.20, 0.0, 0.0)
	bone = 0.36
	arm_scale = 1.6


func grip_transform() -> Transform3D:
	var t := super.grip_transform()
	# A row may carry its own hip (the shield hangs further out than a sword so it clears the body).
	var hip: Vector3 = _row.get("hip", hip_offset)
	t.origin += hip.lerp(aim_offset, anim.aim_weight())
	# A watcher sees the weapon from metres away against a person whose arms are drawn stout: the row's `world_scale` grows it about the grip.
	t.basis = t.basis.scaled_local(Vector3.ONE * float(_row.get("world_scale", 1.0)))
	# `third_turn` rolls it about its own axes for the watcher (an axe's blade shown flat, not edge-on).
	var turn: Vector3 = _row.get("third_turn", Vector3.ZERO)
	if turn != Vector3.ZERO:
		t.basis = t.basis * Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z)))
	return t
