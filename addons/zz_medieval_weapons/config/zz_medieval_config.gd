class_name ZzMedievalConfig
extends RefCounted

## Every number a server owner would tune, with the built-in default, and the loader that
## layers weapon profiles (`weapon/<id>.yml`, see [DotWeaponProfiles]) over them.
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

## Where the old one-file-per-pack ymls (`<id>: key: v`) are read; they sit below the profiles.
static var fallback_dir: String = "res://cfg/addons/zz_medieval_weapons"
## The game id for the game tier (`cfg/game/<game>/weapon`); empty skips it.
static var game: String = ""
## Profiles that failed to load in the last [method load_all]; their weapons keep the layer below.
static var errors: PackedStringArray = PackedStringArray()

## Weapon ids in menu order.
const IDS: Array[StringName] = [
	&"longsword", &"bow", &"round_shield", &"battle_axe",
	&"mace", &"spear", &"crossbow", &"dagger",
	&"war_axe", &"double_axe",
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
		"war_axe": {
			"name": "War Axe", "slot": 1, "kind": "melee", "damage_type": "slash",
			"damage": 72.0, "reach": 2.0, "arc_degrees": 46.0, "rays": 4,
			"swing_ticks": 62, "deploy_ticks": 32, "holster_ticks": 16, "stamina_cost": 20.0,
		},
		"double_axe": {
			"name": "Double Axe", "slot": 1, "kind": "melee", "damage_type": "slash",
			"damage": 90.0, "reach": 2.2, "arc_degrees": 70.0, "rays": 5,
			"swing_ticks": 78, "deploy_ticks": 38, "holster_ticks": 20, "stamina_cost": 26.0,
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


## Defaults, then the `weapon` profiles of every tier, then any old-style ymls, environment and
## command line on top (an old file is an operator's own tuning, so it still wins; delete it once
## migrated). [param dir] reads that directory as the old-style yml (a map of weapon id to keys,
## name order, later wins) instead of the cfg tree; [param roots] replaces the profile config roots (tests); [param layer] is a runtime layer (id -> {path: value}) over the files.
static func load_all(dir: String = "", roots: PackedStringArray = PackedStringArray(), layer: Variant = null) -> Dictionary:
	errors = PackedStringArray()
	var merged := defaults()
	var set := profile_set(roots, layer)
	for id in set.list_ids():
		if not merged.has(id):
			continue
		var res := set.load_profile(id)
		if not res.ok:
			errors.append(res.error.message)
			DotLog.error(CHANNEL, "weapon profile skipped", {"id": id, "why": res.error.message})
			continue
		_overlay(merged[id], res.value)
	set.clear_cache()
	var found: Dictionary = {}
	if dir == "":
		found = _from_core(merged)
	if found.is_empty():
		found = _from_files(dir if dir != "" else fallback_dir)
	for id in found:
		if merged.has(id) and found[id] is Dictionary:
			merged[id].merge(found[id], true)
	return merged


## The profile set the weapons load from. A set caches its profiles, which point back at it: call [method DotProfileSet.clear_cache] when done or it leaks.
static func profile_set(roots: PackedStringArray = PackedStringArray(), layer: Variant = null) -> DotProfileSet:
	return DotWeaponProfiles.make_set(ADDON, game, roots, layer)


## Weapon menu entries (id, category, icon, sort) in menu order, from the profiles' `menu:` keys.
static func menu_entries(roots: PackedStringArray = PackedStringArray()) -> Array:
	var set := profile_set(roots)
	var out := DotWeaponProfiles.menu_entries(set)
	set.clear_cache()
	return out


## Weapon [param id] with the upgrades [param ids] applied to its tuned row; value `{values, cost}`.
static func upgraded(id: StringName, ids: Array, roots: PackedStringArray = PackedStringArray()) -> DotResult:
	var base: Dictionary = load_all("", roots).get(String(id), {})
	if base.is_empty():
		return DotResult.fail(DotError.CODE_INVALID, "no weapon %s" % id)
	var ups := DotWeaponProfiles.upgrade_set(profile_set(roots), String(id))
	var res := DotWeaponProfiles.apply_upgrades(base, ups, ids)
	ups.clear_cache()
	return res


static func _overlay(row: Dictionary, p: DotProfile) -> void:
	for k in p.values:
		if row.has(k):
			row[k] = p.values[k]
	for k in p.extra:
		row[k] = p.extra[k]


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


## The yml text for [param id]'s defaults: what the shipped `weapon/<id>.yml` contains.
## The common keys sit at the top, the pack's own under `extra:`.
static func to_yaml(id: StringName) -> String:
	var row: Dictionary = defaults()[String(id)]
	var common := PackedStringArray()
	for f: Dictionary in DotWeaponProfiles.schema():
		common.append(f["name"])
	var top: PackedStringArray = ["# Zee's Medieval Weapons: %s. Durations are ticks at 64 Hz." % row["name"]]
	var extra: PackedStringArray = ["extra:"]
	for k in row:
		var line := "%s: %s" % [k, _scalar(row[k])]
		if common.has(k):
			top.append(line)
		else:
			extra.append("  " + line)
	top.append("menu:")
	top.append("  category: %s" % _category(row["kind"]))
	top.append("  sort: %d" % IDS.find(id))
	return "\n".join(top + extra) + "\n"


static func _category(kind: String) -> String:
	return "shield" if kind == "shield" else ("melee" if kind == "melee" else "ranged")


static func _scalar(v: Variant) -> String:
	return ("\"%s\"" % v) if v is String else str(v)


## Where the shipped yml for [param id] lives under [param root]: the folder form when the
## weapon has a folder (for its upgrades), else the flat file.
static func profile_path(id: StringName, root: String = "res://cfg") -> String:
	var base := root.path_join("addons").path_join(ADDON).path_join("weapon")
	if DirAccess.dir_exists_absolute(base.path_join(String(id))):
		return base.path_join(String(id)).path_join("%s.yml" % id)
	return base.path_join("%s.yml" % id)
