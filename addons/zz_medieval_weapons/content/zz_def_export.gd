class_name ZzDefExport
extends RefCounted

## Writes the Workshop form (the contract is dot-cloud's docs/workshop.md): a `.tres` per
## weapon, `provides.json` (games "*", kind weapon) and the default cfg yml. The code table
## stays the source of truth; the suite fails when the files are stale.

const CATEGORIES: Array[Dictionary] = [
	{"id": "melee", "name": "Melee"},
	{"id": "shield", "name": "Shields"},
	{"id": "ranged", "name": "Ranged"},
]


static func category_for(def: DotWeaponDef) -> String:
	if def.has_tag(&"shield"):
		return "shield"
	return "ranged" if def.has_tag(&"ranged") else "melee"


static func provides(defs: Array[DotWeaponDef]) -> Dictionary:
	var entries: Array = []
	for def in defs:
		entries.append({
			"kind": "weapon", "id": String(def.id), "name": def.name_or_id(),
			"def": "weapons/%s.tres" % String(def.id), "slot": def.slot,
			"category": category_for(def),
			"tags": Array(def.tags).map(func(t: StringName) -> String: return String(t)),
			"meta": {"asset_root": "."},
		})
	return {
		"schema": 1, "title": "Zee's Medieval Weapons", "kinds": ["weapon"], "games": "*",
		"categories": CATEGORIES, "entries": entries,
	}


static func export_to(root: String) -> DotResult:
	var defs := ZzMedievalPack.weapons()
	for sub in ["weapons", "cfg/addons/zz_medieval_weapons/weapon"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root.path_join(sub)))
	var cfg := _copy_cfg(root, "addons/zz_medieval_weapons/weapon")
	if not cfg.ok:
		return cfg
	for def in defs:
		var path := root.path_join("weapons/%s.tres" % String(def.id))
		var saved := ResourceSaver.save(def, path)
		if saved != OK:
			return DotResult.fail(DotError.CODE_IO, "Cannot save %s (error %d)." % [path, saved])
		var y := FileAccess.open(ZzMedievalConfig.profile_path(def.id, root.path_join("cfg")), FileAccess.WRITE)
		if y == null:
			return DotResult.fail(DotError.CODE_IO, "Cannot write cfg for %s." % String(def.id))
		y.store_string(ZzMedievalConfig.to_yaml(def.id))
		y.close()
	var f := FileAccess.open(root.path_join("provides.json"), FileAccess.WRITE)
	if f == null:
		return DotResult.fail(DotError.CODE_IO, "Cannot write provides.json.")
	f.store_string(JSON.stringify(provides(defs), "\t", false) + "\n")
	f.close()
	return DotResult.success(defs.size())


## Copies the shipped `cfg/addons/<addon>/weapon` tree (upgrades included) under [param root] when it is not the project's own.
static func _copy_cfg(root: String, rel: String) -> DotResult:
	var from := "res://cfg".path_join(rel)
	var to := root.path_join("cfg").path_join(rel)
	if root.trim_suffix("/") == "res:/" or to == from or not DirAccess.dir_exists_absolute(from):
		return DotResult.success(0)
	var n := 0
	var stack: Array[String] = [""]
	while not stack.is_empty():
		var sub: String = stack.pop_back()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(to.path_join(sub)))
		for d in DirAccess.get_directories_at(from.path_join(sub)):
			stack.append(sub.path_join(d))
		for f in DirAccess.get_files_at(from.path_join(sub)):
			if f.get_extension() != "yml":
				continue
			var text := FileAccess.get_file_as_string(from.path_join(sub).path_join(f))
			var o := FileAccess.open(to.path_join(sub).path_join(f), FileAccess.WRITE)
			if o == null:
				return DotResult.fail(DotError.CODE_IO, "Cannot write cfg %s." % f)
			o.store_string(text)
			o.close()
			n += 1
	return DotResult.success(n)
