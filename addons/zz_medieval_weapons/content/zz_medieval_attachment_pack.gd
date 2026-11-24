class_name ZzMedievalAttachmentPack
extends RefCounted

## The pack's attachments: built-in rows, overlaid by `attachment` profiles
## (`cfg/addons/zz_medieval_weapons/attachment/<id>.yml`, see [GSWeaponAttachments]). Which weapon takes
## which mount is [constant ZzMedievalPack.MOUNTS]; the models are ours, under assets/attachments/.

const CHANNEL := "zz.medieval.attachments"
const MODEL_DIR := "res://addons/zz_medieval_weapons/assets/attachments"
const IDS: Array[StringName] = [
	&"zz_aperture_sight", &"zz_barbed_heads", &"zz_leather_wrap", &"zz_counterweight", &"zz_spiked_boss",
]


## One flat profile per attachment id, in the profile schema's field names. Numbers scale the weapon's own.
static func defaults() -> Dictionary:
	return {
		&"zz_aperture_sight": {
			"name": "Aperture Sight", "description": "A peep sight on the stock: a flatter, truer flight.",
			"mount": "optic", "model": _model("aperture_sight"), "fits_tags": "crossbow",
			"scale": {"gravity_scale": 0.8},
		},
		&"zz_barbed_heads": {
			"name": "Barbed Heads", "description": "Barbed bolt heads: harder hitting, a little slower.",
			"mount": "muzzle", "model": _model("barbed_heads"), "fits_tags": "crossbow",
			"scale": {"damage": 1.15, "speed": 0.92},
		},
		&"zz_leather_wrap": {
			"name": "Leather Wrap", "description": "A bound grip: less stamina spent on each swing.",
			"mount": "underbarrel", "model": _model("leather_wrap"), "fits_tags": "melee", "excludes_tags": "shield",
			"scale": {"params.stamina_cost": 0.85},
		},
		&"zz_counterweight": {
			"name": "Counterweight", "description": "A pommel weight: a quicker recovery between swings.",
			"mount": "magazine", "model": _model("counterweight"), "fits_tags": "melee", "excludes_tags": "shield",
			"scale": {"use_interval_ticks": 0.9},
		},
		&"zz_spiked_boss": {
			"name": "Spiked Boss", "description": "An iron spike on the face: a harder bash, a longer shove.",
			"mount": "side", "model": _model("spiked_boss"), "fits_weapons": "round_shield",
			"scale": {"damage": 1.5, "params.knockback": 1.2},
		},
	}


static func _model(short: String) -> String:
	return MODEL_DIR.path_join("zz_%s.tscn" % short)


## The `attachment` profile set over [member ZzMedievalConfig.pack_cfg_root] and the default roots, like the weapons'.
static func profile_set(roots: PackedStringArray = PackedStringArray()) -> GSProfileSet:
	if roots.is_empty() and ZzMedievalConfig.pack_cfg_root != "":
		roots = PackedStringArray([ZzMedievalConfig.pack_cfg_root]) + (ZzMedievalConfig.base_roots if not ZzMedievalConfig.base_roots.is_empty() else GSProfileSet.default_roots())
	return GSWeaponAttachments.make_set(ZzMedievalConfig.ADDON, ZzMedievalConfig.game, roots)


## The built-in rows alone, with no files read.
static func builtin() -> GSWeaponAttachments:
	var out := GSWeaponAttachments.new()
	var rows := defaults()
	for id: StringName in rows:
		out.add(GSWeaponAttachment.from_flat(id, rows[id]))
	return out


## The catalogue a game hands its arsenal: the profiles when they load, else the built-in rows.
static func catalogue(roots: PackedStringArray = PackedStringArray()) -> GSWeaponAttachments:
	var set := profile_set(roots)
	if set.list_ids().is_empty():
		return builtin()
	var out := GSWeaponAttachments.new()
	var res := out.load_set(set)
	set.clear_cache()
	if not res.ok:
		GSLog.error(CHANNEL, "attachment profiles skipped; using the built-in rows", {"why": res.error.message})
		return builtin()
	return out


## The shipped yml for [param id]: the built-in row in profile form; the suite fails when a file drifts.
static func to_yaml(id: StringName) -> String:
	var row: Dictionary = defaults()[id]
	var lines: PackedStringArray = ["# Medieval attachment: %s. Scales multiply the weapon's own numbers." % String(id)]
	for key: String in row:
		var v: Variant = row[key]
		if v is Dictionary:
			lines.append("%s:" % key)
			for k: String in v:
				lines.append("  %s: %s" % [k, _yaml_value(v[k])])
		else:
			lines.append("%s: %s" % [key, _yaml_value(v)])
	return "\n".join(lines) + "\n"


static func _yaml_value(v: Variant) -> String:
	if v is String:
		return "\"%s\"" % v
	if v is bool:
		return "true" if v else "false"
	return str(v)


static func profile_path(id: StringName, root: String = "res://cfg") -> String:
	return root.path_join("addons").path_join(ZzMedievalConfig.ADDON).path_join(GSWeaponAttachments.KIND).path_join("%s.yml" % String(id))
