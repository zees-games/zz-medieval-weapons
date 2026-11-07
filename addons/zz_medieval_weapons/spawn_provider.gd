class_name ZzMedievalSpawnProvider
extends RefCounted

## Entries for a game's spawn menu: rows of {category, id, name, icon, kind, spawn, cfg_hint}.
## [code]spawn[/code] is what the menu hands its spawner; [code]cfg_hint[/code] says where to tune it.

const ROOT := "res://addons/zz_medieval_weapons/"


## The contract game-zombie-zone's zz_packs.gd reads by path and name: [code]weapon_defs(types := {})[/code]
## returns every definition. [param types] (id -> DotDamageType) replaces this pack's own entry of that id.
## Numbers come from [method ZzMedievalConfig.load_all]; [param cfg_dir] reads another directory (tests).
static func weapon_defs(types: Dictionary = {}, cfg_dir: String = "") -> Array[DotWeaponDef]:
	var table := ZzMedievalPack.damage_types()
	for key in types:
		table[String(key)] = types[key]
	var cfg := ZzMedievalConfig.load_all(cfg_dir)
	var out: Array[DotWeaponDef] = []
	for id in ZzMedievalConfig.IDS:
		out.append(ZzMedievalPack.build(id, cfg[String(id)], table))
	return out


## [method weapon_defs] rebuilt over a host's live profile edits ([param layer]: id -> {path: value}).
static func weapon_defs_with(layer: Dictionary, types: Dictionary = {}) -> Array[DotWeaponDef]:
	var table := ZzMedievalPack.damage_types()
	for key in types:
		table[String(key)] = types[key]
	var cfg := ZzMedievalConfig.load_all("", PackedStringArray(), layer)
	var out: Array[DotWeaponDef] = []
	for id in ZzMedievalConfig.IDS:
		out.append(ZzMedievalPack.build(id, cfg[String(id)], table))
	return out


## The pack's own models as zee's art resources, one per weapon id (the optional hook zz_packs.gd and zee's `ZeePackSource` call).
## Empty when zee-dot-weapons is not installed: this pack names none of its classes, see [ZzMedievalZeeArt].
static func weapon_art() -> Array:
	return ZzMedievalZeeArt.build()


## Every weapon id's model scene as a path, for a host or a test that wants the glb without a rig.
static func model_paths() -> Dictionary:
	var out := {}
	for id in ZzMedievalConfig.IDS:
		out[id] = ZzMedievalModels.model_path(id)
	return out


static func spawn_entries() -> Array[Dictionary]:
	var cfg := ZzMedievalConfig.load_all()
	var out: Array[Dictionary] = []
	for id in ZzMedievalConfig.IDS:
		var key := String(id)
		out.append({
			"category": "Weapons",
			"id": "zz_medieval_" + key,
			"name": String(cfg[key]["name"]),
			"icon": ROOT + "icons/%s.svg" % key,
			"kind": "weapon",
			"spawn": {
				"weapon_id": key,
				"def": "res://weapons/%s.tres" % key,
				"model": ROOT + "art/zz_medieval_models.gd",
			},
			"cfg_hint": "cfg/addons/zz_medieval_weapons/weapon/%s.yml" % key,
		})
	return out
