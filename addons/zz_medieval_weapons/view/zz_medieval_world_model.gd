class_name ZzMedievalWorldModel
extends ZzMedievalHeld

## Third person: what a watcher sees a carrier holding. Parent it to a node at the carrier's shoulders that
## turns with their aim; feed it with [method ZzMedievalNet.apply]. The resting hand is the table's
## [code]rest[/code] shifted down and in, so the weapon hangs by the hip.

## Added to every resting hand: a hand at the hip, not in front of the eye.
var hip_offset: Vector3 = Vector3(-0.02, -0.26, 0.12)


func _init() -> void:
	name = "WorldModel"
	shoulder = Vector3(0.20, 0.0, 0.0)
	bone = 0.36


func grip_transform() -> Transform3D:
	var t := super.grip_transform()
	t.origin += hip_offset
	return t
