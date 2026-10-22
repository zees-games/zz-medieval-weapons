class_name ZzMedievalSpawnProvider
extends RefCounted

## Entries for a game's spawn menu (game-playground's, and any other that lists providers).
## A row is {category, id, name, icon, kind, spawn, cfg_hint}: [code]spawn[/code] is what the
## menu hands to its spawner for a weapon (the weapon id, the definition's path and the model
## builder), [code]cfg_hint[/code] where a server owner tunes it.

const ROOT := "res://addons/zz_medieval_weapons/"


static func spawn_entries() -> Array[Dictionary]:
	var cfg := ZzMedievalConfig.defaults()
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
