extends SceneTree
## `godot --headless --path . --script res://tools/export_defs.gd` rewrites weapons/*.tres,
## provides.json, the default cfg yml and the attachment yml from the code table.

func _initialize() -> void:
	var res := ZzDefExport.export_to("res://")
	if not res.ok:
		printerr("export failed: %s" % res.error.message)
		quit(1)
		return
	for id: StringName in ZzMedievalAttachmentPack.IDS:
		var path := ZzMedievalAttachmentPack.profile_path(id, "res://cfg")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(ZzMedievalAttachmentPack.to_yaml(id))
		f.close()
	print("wrote %d weapon definitions, provides.json and cfg" % int(res.value))
	quit(0)
