extends SceneTree

## Run inside a throwaway game project that only symlinks this addon (tools/linked_check.sh): every model must be found and built
## from the pack's own checkout, though the project has no assets/ of its own.

func _init() -> void:
	var bad := 0
	for id in ZzMedievalConfig.IDS:
		var path := ZzMedievalModels.model_path(id)
		var node := ZzMedievalModels.build(id)
		var ok := not ZzMedievalModels.is_placeholder(id) and not path.begins_with("res://") and node != null \
			and not node.find_children("*", "MeshInstance3D", true, false).is_empty()
		print("  %s  %s -> %s" % ["ok  " if ok else "FAIL", id, path])
		bad += 0 if ok else 1
		if node != null:
			node.free()
	print("linked addon: %s" % ("all ten models found" if bad == 0 else "%d model(s) not found" % bad))
	quit(1 if bad > 0 else 0)
