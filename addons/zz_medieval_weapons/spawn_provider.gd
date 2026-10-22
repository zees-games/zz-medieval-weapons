class_name ZzMedievalSpawnProvider
extends RefCounted

## Entries for a game's spawn menu (game-playground's, and any other that lists providers).
## A row is {category, id, name, icon, kind, spawn, cfg_hint}: [code]spawn[/code] is what the
## menu hands to its spawner for a weapon (the weapon id, the definition's path and the model
## builder), [code]cfg_hint[/code] where a server owner tunes it.

const ROOT := "res://addons/zz_medieval_weapons/"


## The contract game-zombie-zone's zz_packs.gd reads (it loads this file by path and calls it by
## name, so nothing there names this pack): [code]weapon_defs(types := {})[/code] returns every
## definition, and a "weapon" row is handed out only if its [code]spawn.weapon_id[/code] (or
## [code]spawn.weapon[/code], or the row id) is one of those ids. [param types] is the game's
## damage table (id -> DotDamageType); an entry there replaces this pack's own of that id, so
## damage resolves against the game's resistances. Called with no argument it uses the pack's.
## Numbers come from [method ZzMedievalConfig.load_all] (defaults under cfg/addons/zz_medieval_weapons/*.yml), so a server owner's yml retunes a weapon; with no cfg directory that is the built-in defaults. [param cfg_dir] reads that directory instead (the suite's temp tree).
static func weapon_defs(types: Dictionary = {}, cfg_dir: String = "") -> Array[DotWeaponDef]:
	var table := ZzMedievalPack.damage_types()
	for key in types:
		table[String(key)] = types[key]
	var cfg := ZzMedievalConfig.load_all(cfg_dir)
	var out: Array[DotWeaponDef] = []
	for id in ZzMedievalConfig.IDS:
		out.append(ZzMedievalPack.build(id, cfg[String(id)], table))
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
			"cfg_hint": "cfg/addons/zz_medieval_weapons/%s.yml" % key,
		})
	return out
