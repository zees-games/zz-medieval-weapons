class_name ZzMedievalViewModel
extends ZzMedievalHeld

## First person: parent it to the camera. The shoulders are just below and behind the eye, so
## the arms come up into the lower corners of the frame the way a person's do.
##
## Not yet done here: a depth lens (zee-dot-weapons draws its view model in a second viewport
## so a long weapon never pokes into a wall); a spear's 3 m shaft will cut a wall it is
## pushed against. See docs/view-model.md.

func _init() -> void:
	name = "ViewModel"
	shoulder = Vector3(0.22, -0.30, 0.16)
