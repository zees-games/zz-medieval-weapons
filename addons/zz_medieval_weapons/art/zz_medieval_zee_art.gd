class_name ZzMedievalZeeArt
extends RefCounted

## The pack's own models as zee-dot-weapons' `ZeeWeaponArt` resources, for a host (game-zombie-zone) that draws weapons with zee's rig:
## [method build] backs `ZzMedievalSpawnProvider.weapon_art()`. This pack does not require zee, so no zee class is named: each is looked
## up by its global name when called, and without zee the answer is empty (the pack draws itself with [ZzMedievalViewModel]).
## Every weapon is a melee-style carry (the model stands along +Y, origin at the grip); zee's knife lends the arm pose, and the hip place
## and size come from [ZzMedievalArtTable] (`rest`, `hold`, `scale`), the rows the pack's own view uses.


## One art per weapon id ([param dressed] false leaves zee's own knife under the id, which is what a bare stand-in shows), typed `Array[ZeeWeaponArt]` (zee's art source is typed), or an empty untyped array without zee.
static func build(dressed: bool = true) -> Array:
	var art_script := _global_script(&"ZeeWeaponArt")
	var table := _global_script(&"ZeeWeaponArtTable")
	var dress := _global_script(&"ZeeArtDress")
	var out: Array = []

	if art_script == null or table == null or dress == null:
		return out

	out = Array([], TYPE_OBJECT, &"Resource", art_script)
	var rows := art_rows()

	for id: StringName in ZzMedievalConfig.IDS:
		var art: Resource = table.call(&"knife")
		art.set(&"id", id)
		out.append(art)

		if not dressed:
			continue

		dress.call(&"apply", art, rows[id])
		var row := ZzMedievalArtTable.row(id)
		art.set(&"view_offset", row.get("rest", art.get(&"view_offset")))
		art.set(&"view_rotation", row.get("hold", Vector3.ZERO))
		art.set(&"view_scale", float(row.get("scale", 1.0)))
		art.set(&"weight", 1.4 if row.get("weight", "light") == "heavy" else 1.0)

	return out


## id -> {model, motion, world_scale}, the plain-data form zee's `ZeeArtDress` reads; `model` is "" while an id has no vendored glb.
static func art_rows() -> Dictionary:
	var out := {}

	for id: StringName in ZzMedievalConfig.IDS:
		out[id] = {"model": "" if ZzMedievalModels.is_placeholder(id) else ZzMedievalModels.model_path(id), "motion": "melee", "world_scale": 1.0}

	return out


## A global class's script by name, or null when its addon is not installed.
static func _global_script(name: StringName) -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(entry.get("class", "")) == name:
			return load(str(entry["path"])) as Script

	return null
