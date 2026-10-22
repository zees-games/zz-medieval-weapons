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
	for sub in ["weapons", "cfg/addons/zz_medieval_weapons"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root.path_join(sub)))
	for def in defs:
		var path := root.path_join("weapons/%s.tres" % String(def.id))
		var saved := ResourceSaver.save(def, path)
		if saved != OK:
			return DotResult.fail(DotError.CODE_IO, "Cannot save %s (error %d)." % [path, saved])
		var y := FileAccess.open(root.path_join("cfg/addons/zz_medieval_weapons/%s.yml" % String(def.id)), FileAccess.WRITE)
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
