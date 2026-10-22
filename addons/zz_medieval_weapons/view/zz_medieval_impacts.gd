class_name ZzMedievalImpacts
extends RefCounted

## What a hit leaves: a short burst of chips or sparks at the point, coloured by what was
## hit. Nodes only on a client; a server never calls it. No decals or recordings ship with the
## pack: the burst is built in code and the sound is a [signal ZzWeaponAnim.cue] name.

const COLOURS := {
	&"flesh": Color(0.62, 0.05, 0.05),
	&"wood": Color(0.55, 0.38, 0.2),
	&"stone": Color(0.7, 0.7, 0.68),
	&"steel": Color(1.0, 0.85, 0.5),
	&"iron": Color(1.0, 0.8, 0.45),
	&"dirt": Color(0.4, 0.3, 0.2),
}
## Sparks fly off hard surfaces and fall quickly off soft ones.
const HARD := [&"stone", &"steel", &"iron"]


static func colour(surface: StringName) -> Color:
	return COLOURS.get(surface, COLOURS[&"dirt"])


## Spawns a one-shot burst under [param parent] at [param point], thrown along [param normal].
## Frees itself. Returns the node.
static func burst(parent: Node, point: Vector3, normal: Vector3, surface: StringName = &"dirt") -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = 14 if surface in HARD else 10
	p.lifetime = 0.35
	p.direction = normal if normal.length() > 0.01 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 1.5
	p.initial_velocity_max = 4.0 if surface in HARD else 3.0
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.0
	var m := BoxMesh.new()
	m.size = Vector3(0.02, 0.02, 0.02) if surface in HARD else Vector3(0.035, 0.035, 0.035)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = colour(surface)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material = mat
	p.mesh = m
	parent.add_child(p)
	p.global_position = point
	p.finished.connect(p.queue_free)
	p.emitting = true
	return p
