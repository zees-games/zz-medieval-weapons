class_name ZzMedievalReflectionSource
extends RefCounted

## Something for a metal weapon to reflect. Full metal with no environment to mirror renders black,
## so a view either gives its world a sky ([method sky_environment]) or hangs a probe on the view
## model ([method attach_probe], or `ZzMedievalViewModel.provide_reflections`). See docs/lighting.md.

## A procedural sky as the background, the ambient light and the reflected light: what the pack's own
## render sheets use, and what a game with no sky of its own can assign to its WorldEnvironment.
static func sky_environment(ambient_energy: float = 1.0) -> Environment:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.32, 0.50, 0.78)
	material.sky_horizon_color = Color(0.72, 0.78, 0.86)
	material.ground_horizon_color = Color(0.55, 0.55, 0.52)
	material.ground_bottom_color = Color(0.22, 0.24, 0.20)
	var sky := Sky.new()
	sky.sky_material = material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.ambient_light_energy = ambient_energy
	return env


## A one-shot [ReflectionProbe] under [param host] that captures whatever surrounds it (sky and
## scenery) on the next frame. Call [method refresh] after the surroundings change.
static func attach_probe(host: Node3D, extents: Vector3 = Vector3(6.0, 4.0, 6.0)) -> ReflectionProbe:
	var probe := ReflectionProbe.new()
	probe.name = "ZzReflectionProbe"
	probe.size = extents
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.ambient_mode = ReflectionProbe.AMBIENT_ENVIRONMENT
	host.add_child(probe)
	return probe


static func refresh(probe: ReflectionProbe) -> void:
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
