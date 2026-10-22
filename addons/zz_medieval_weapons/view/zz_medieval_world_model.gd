class_name ZzMedievalWorldModel
extends ZzMedievalHeld

## Third person: what a watcher sees a carrier holding. Parent it to a node at the carrier's
## shoulders that turns with their aim (the pose curves are the same ones the owner's view
## uses, so a swing reads the same from outside). Feed it with [method ZzMedievalNet.apply]
## from the replicated fields.
##
## Shoulders sit on the node's origin and the resting hand is the table's [code]rest[/code]
## shifted down and in, so the weapon hangs by the hip instead of in front of a camera.

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
