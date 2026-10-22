class_name ZzMedievalConfig
extends RefCounted

## Every number a server owner would tune, with the built-in default, and the loader that
## layers `cfg/addons/zz_medieval_weapons/*.yml` over them.
##
## [b]Why the defaults live in code as well as in the shipped yml.[/b] A server with no cfg
## directory (a delivered pack, a unit test) must still have a complete catalogue, so the
## table here is the floor and a yml file only overrides keys it names. The shipped yml
## files are the same numbers written out, and the suite fails when they drift.
##
## [b]Durations are ticks at [constant TICK_RATE], never seconds, like the rest of the
## family; the definition's authored_tick_rate scales them to the running rate.

const CHANNEL := "zz.medieval.config"
const ADDON := "zz_medieval_weapons"
const TICK_RATE := 64

## Where the fallback reader looks when dot-core's loader is absent.
static var fallback_dir: String = "res://cfg/addons/zz_medieval_weapons"

## Weapon ids in menu order.
const IDS: Array[StringName] = [
	&"longsword", &"bow", &"round_shield", &"battle_axe",
	&"mace", &"spear", &"crossbow", &"dagger",
]


static func defaults() -> Dictionary:
	return {
		"longsword": {
			"name": "Longsword", "slot": 1, "kind": "melee", "damage_type": "slash",
			"damage": 55.0, "reach": 2.4, "arc_degrees": 60.0, "rays": 5,
			"swing_ticks": 42, "deploy_ticks": 26, "holster_ticks": 14, "stamina_cost": 12.0,
		},
		"dagger": {
			"name": "Dagger", "slot": 1, "kind": "melee", "damage_type": "pierce",
			"damage": 28.0, "reach": 1.4, "arc_degrees": 20.0, "rays": 2,
			"swing_ticks": 20, "deploy_ticks": 12, "holster_ticks": 8, "stamina_cost": 4.0,
		},
		"battle_axe": {
			"name": "Battle Axe", "slot": 1, "kind": "melee", "damage_type": "slash",
			"damage": 80.0, "reach": 2.1, "arc_degrees": 50.0, "rays": 4,
			"swing_ticks": 70, "deploy_ticks": 34, "holster_ticks": 18, "stamina_cost": 22.0,
		},
		"mace": {
			"name": "Mace", "slot": 1, "kind": "melee", "damage_type": "strike",
			"damage": 66.0, "reach": 1.9, "arc_degrees": 36.0, "rays": 3,
			"swing_ticks": 56, "deploy_ticks": 28, "holster_ticks": 16, "stamina_cost": 16.0,
		},
		"spear": {
			"name": "Spear", "slot": 1, "kind": "melee", "damage_type": "pierce",
			"damage": 60.0, "reach": 3.3, "arc_degrees": 8.0, "rays": 1,
			"swing_ticks": 52, "deploy_ticks": 30, "holster_ticks": 16, "stamina_cost": 14.0,
		},
		"round_shield": {
			"name": "Round Shield", "slot": 2, "kind": "shield", "damage_type": "strike",
			"damage": 14.0, "reach": 1.7, "arc_degrees": 44.0, "rays": 3,
			"swing_ticks": 56, "deploy_ticks": 22, "holster_ticks": 12, "stamina_cost": 10.0,
			"knockback": 7.0,
			# Share of an incoming hit a raised shield stops, inside the arc in front.
			"block_reduction": 0.8, "block_arc_degrees": 120.0,
			# Stamina a block costs per point of damage it stopped.
			"block_stamina_per_damage": 0.3,
		},
		"bow": {
			"name": "Bow", "slot": 3, "kind": "bow", "damage_type": "pierce",
			"damage": 75.0, "min_charge_damage": 0.2, "speed": 72.0, "min_speed": 22.0,
			# Arrow drop: gravity_scale 1.0 is the engine's gravity.
			"gravity_scale": 1.0, "arrow_radius": 0.05, "life_ticks": 640,
			"draw_ticks": 72, "min_charge": 0.3, "deploy_ticks": 28, "holster_ticks": 16,
			"use_interval_ticks": 24, "reserve": 30, "stamina_cost": 8.0,
			"projectile_id": "arrow",
		},
		"crossbow": {
			"name": "Crossbow", "slot": 3, "kind": "crossbow", "damage_type": "pierce",
			"damage": 90.0, "min_charge_damage": 1.0, "speed": 100.0, "min_speed": 100.0,
			"gravity_scale": 0.55, "arrow_radius": 0.05, "life_ticks": 640,
			"reload_ticks": 200, "magazine": 1, "reserve": 20, "deploy_ticks": 30,
			"holster_ticks": 16, "use_interval_ticks": 16, "stamina_cost": 6.0,
			"projectile_id": "bolt",
		},
	}


## Defaults with the cfg directory's files laid over them. Each yml file is a map of weapon id
## to keys (`longsword:` then indented `damage: 60`), so one file may tune one weapon or all of
## them, and files are read in name order with later keys winning, which is dot-core's
## [code]DotAddonConfig[/code] contract. [param dir] reads that directory with the built-in
## reader instead (the suite points it at a temp tree).
static func load_all(dir: String = "") -> Dictionary:
	var found: Dictionary = {}
	if dir == "":
		found = _from_core(defaults())
	if found.is_empty():
		found = _from_files(dir if dir != "" else fallback_dir)
	var merged := defaults()
	for id in found:
		if merged.has(id) and found[id] is Dictionary:
			merged[id].merge(found[id], true)
	return merged


## dot-core's DotAddonConfig, reached by reflection so this pack parses (and falls back)
## where dot-core predates it. It also layers environment and the command line.
static func _from_core(defs: Dictionary) -> Dictionary:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry.get("class", "") != "DotAddonConfig":
			continue
		var script: Script = load(String(entry["path"]))
		if script == null or not script.has_method("load_dir"):
			return {}
		var got: Variant = script.call("load_dir", ADDON, defs)
		if got is Object:
			if not got.get("ok"):
				DotLog.error(CHANNEL, "cfg did not load; using built-in defaults")
				return {}
			got = got.get("value")
		return got if got is Dictionary else {}
	return {}


## The fallback reader: every `*.yml` in [param dir], in name order, merged by weapon id.
static func _from_files(dir: String) -> Dictionary:
	var out: Dictionary = {}
	if not DirAccess.dir_exists_absolute(dir):
		return out
	var yaml := _yaml()
	if yaml == null:
		return out
	var names := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".yml"))
	names.sort()
	for file: String in names:
		var res: Variant = yaml.call("parse_file", dir.path_join(file))
		if not (res is Object and res.get("ok") and res.get("value") is Dictionary):
			DotLog.warn(CHANNEL, "Ignored %s: it does not parse." % file)
			continue
		for id in res.get("value"):
			if out.has(id) and out[id] is Dictionary and res.get("value")[id] is Dictionary:
				out[id].merge(res.get("value")[id], true)
			else:
				out[id] = res.get("value")[id]
	return out


static func _yaml() -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if entry.get("class", "") == "DotYaml":
			return load(String(entry["path"]))
	return null


## The yml text for [param id]'s defaults: what the shipped cfg files contain.
static func to_yaml(id: StringName) -> String:
	var row: Dictionary = defaults()[String(id)]
	var lines: PackedStringArray = [
		"# Zee's Medieval Weapons: %s. Durations are ticks at 64 Hz." % row["name"],
		"%s:" % id,
	]
	for k in row:
		var v: Variant = row[k]
		lines.append("  %s: %s" % [k, ("\"%s\"" % v) if v is String else str(v)])
	return "\n".join(lines) + "\n"
