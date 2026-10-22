extends Node3D
## Renders every weapon (or the ones named after `--`) to screenshots/<id>.png and quits. Run
## through tools/screenshot.sh (Xvfb); a --headless render is a black PNG.

func _ready() -> void:
	var ids: Array = []
	for a in OS.get_cmdline_user_args():
		ids.append(StringName(a))
	if ids.is_empty():
		ids = Array(ZzMedievalConfig.IDS)

	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.18, 0.22)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.65)
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	add_child(sun)
	var cam := Camera3D.new()
	add_child(cam)
	cam.current = true

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://screenshots"))
	for id in ids:
		var m := ZzMedievalModels.build(id)
		add_child(m)
		# Three-quarter turn so the width and the length both read.
		m.rotation_degrees = Vector3(0, 35, 0)
		if id == &"bow" or id == &"round_shield":
			m.rotation_degrees = Vector3(0, 60, 0)
		var box := _bounds(m)
		var c := box.get_center()
		var r := maxf(box.size.length() * 0.5, 0.2)
		cam.position = c + Vector3(0, r * 0.2, r * 2.4)
		cam.look_at(c)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://screenshots/%s.png" % String(id))
		m.queue_free()
		await get_tree().process_frame
	get_tree().quit()


func _bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out
