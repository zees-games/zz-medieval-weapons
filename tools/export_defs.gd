extends SceneTree
## `godot --headless --path . --script res://tools/export_defs.gd` rewrites weapons/*.tres,
## provides.json and the default cfg yml from the code table.

func _initialize() -> void:
	var res := ZzDefExport.export_to("res://")
	if not res.ok:
		printerr("export failed: %s" % res.error.message)
		quit(1)
		return
	print("wrote %d weapon definitions, provides.json and cfg" % int(res.value))
	quit(0)
