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
		if art.get(&"model_path") != rows[id]["model"]:
			continue  # no model zee can load: the stand-in keeps its own carry

		var row := ZzMedievalArtTable.row(id)
		var model := ZzMedievalArtTable.model_transform(id)
		# Third person: the same upright-and-gripped correction, for a glb that was not modelled that way.
		art.set(&"world_rotation", model.basis.get_euler() * (180.0 / PI))
		art.set(&"world_offset", model.origin * float(rows[id]["world_scale"]))
		var placed := view_placement(id, art.get(&"view_offset"))
		art.set(&"view_offset", placed["offset"])
		art.set(&"view_rotation", placed["rotation"])
		art.set(&"view_scale", placed["scale"])
		art.set(&"weight", 1.4 if row.get("weight", "light") == "heavy" else 1.0)

	return out


## Where zee's rig puts the model so it sits in the hand as the pack's own view does: `rotation` (Euler degrees) is the hold turn after the
## model's `align`, `offset` is the rest place moved so the model's `grip` lands on it, `scale` the row's. Zee only knows a model's origin,
## so a glb that was not modelled upright or gripped at its origin is corrected here.
static func view_placement(id: StringName, default_offset: Vector3 = Vector3.ZERO) -> Dictionary:
	var row := ZzMedievalArtTable.row(id)
	var hold_deg: Vector3 = row.get("hold", Vector3.ZERO)
	var hold := Basis.from_euler(Vector3(deg_to_rad(hold_deg.x), deg_to_rad(hold_deg.y), deg_to_rad(hold_deg.z)))
	var model := ZzMedievalArtTable.model_transform(id)
	var scale := float(row.get("scale", 1.0))
	var grip: Vector3 = row.get("grip", Vector3.ZERO)
	var rest: Vector3 = row.get("rest", default_offset)
	return {
		"offset": rest - hold * grip * scale,
		"rotation": (hold * model.basis).get_euler() * (180.0 / PI),
		"scale": scale,
	}


## id -> {model, motion, world_scale}, the plain-data form zee's `ZeeArtDress` reads; `model` is "" while an id has no glb zee can load (none vendored, or the pack is a symlinked addon whose glbs are outside `res://`).
static func art_rows() -> Dictionary:
	var out := {}

	for id: StringName in ZzMedievalConfig.IDS:
		out[id] = {"model": ZzMedievalModels.model_path(id) if ZzMedievalModels.is_imported(id) else "", "motion": "melee", "world_scale": 1.0}

	return out


## A global class's script by name, or null when its addon is not installed.
static func _global_script(name: StringName) -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if StringName(entry.get("class", "")) == name:
			return load(str(entry["path"])) as Script

	return null
