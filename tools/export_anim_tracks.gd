extends "res://addons/gs_weapon/tools/gs_weapon_anim_export.gd"

## Bakes each weapon's procedural first-person animations into <asset>.anim.json (see ZzAnimBake): the sidecar Nightly's asset viewer plays next to the model.
## The arguments and the output are the shared shell's (addons/gs_weapon/tools/gs_weapon_anim_export.gd). No ids bakes every weapon, plus the arrow and bolt.
## godot --headless --path . --script res://tools/export_anim_tracks.gd -- out_dir longsword,bow


func _bake_all(host: Node3D, wanted: PackedStringArray) -> void:
	for id in ZzMedievalConfig.IDS:
		if not wanted.is_empty() and not String(id) in wanted:
			continue
		var sidecar := ZzAnimBake.new().bake(host, id)
		if sidecar.is_empty():
			print("SKIP %s (no model)" % id)
			continue
		emit(sidecar)
		var missile := String(ZzMedievalArtTable.row(id).get("projectile", ""))
		if missile != "":
			var ps := ZzAnimBake.projectile_sidecar(StringName(missile), sidecar)
			if not ps.is_empty() and not ZzMedievalModels.is_placeholder(StringName(missile)):
				emit(ps)
