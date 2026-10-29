class_name ZzMedievalViewModel
extends ZzMedievalHeld

## First person: parent it to the camera. The shoulders sit below and behind the eye so the arms come up
## into the lower corners of the frame. No depth lens yet, so a spear can cut a wall (docs/view-model.md).

## Hang a reflection probe on the view model, for a world whose environment has no sky to mirror.
## A game with a sky leaves it off; docs/lighting.md says why.
@export var provide_reflections: bool = false


func _ready() -> void:
	super._ready()
	if provide_reflections:
		ZzMedievalReflectionSource.attach_probe(self)


func _init() -> void:
	name = "ViewModel"
	shoulder = Vector3(0.22, -0.30, 0.16)
