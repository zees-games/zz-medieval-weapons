class_name ZzMedievalPack
extends RefCounted

## The catalogue: one [DotWeaponDef] per weapon, built from [ZzMedievalConfig]. Melee and projectile use
## dot-weapon's stock shapes, wrapped by two thin behaviours for what it has no place for: stamina, knockback, block.

const BEHAVIOUR_DIR := "res://addons/zz_medieval_weapons/behaviour/"
const MELEE := BEHAVIOUR_DIR + "zz_melee.gd"
const SHIELD := BEHAVIOUR_DIR + "zz_shield.gd"
const PROJECTILE := BEHAVIOUR_DIR + "zz_projectile.gd"


static func weapons(cfg: Dictionary = {}) -> Array[DotWeaponDef]:
	if cfg.is_empty():
		cfg = ZzMedievalConfig.load_all()
	var types := damage_types()
	var out: Array[DotWeaponDef] = []
	for id in ZzMedievalConfig.IDS:
		out.append(build(id, cfg[String(id)], types))
	return out


static func damage_types() -> Dictionary:
	var out: Dictionary = {}
	for id in ["slash", "pierce", "strike"]:
		var t := DotDamageType.new()
		t.id = StringName(id)
		t.display_name = id.capitalize()
		out[id] = t
	return out


static func build(id: StringName, c: Dictionary, types: Dictionary) -> DotWeaponDef:
	var d := DotWeaponDef.new()
	d.id = id
	d.deploy_ticks = 24
	d.holster_ticks = 14
	DotWeaponProfiles.apply_common(d, c)
	d.authored_tick_rate = ZzMedievalConfig.TICK_RATE
	d.cost_per_use = 0
	d.reload_ticks = 0
	d.auto_reload = false

	var kind := String(c["kind"])
	var b := DotWeaponBallistics.new()
	b.damage = float(c["damage"])
	b.damage_type = types.get(String(c["damage_type"]))
	b.spread = 0.0
	b.spread_moving = 0.0
	b.spread_airborne = 0.0
	b.recoil_pitch = 0.0
	b.recoil_yaw = 0.0
	d.tuning = b
	d.params = {&"stamina_cost": float(c.get("stamina_cost", 0.0))}

	match kind:
		"melee", "shield":
			d.behaviour_path = SHIELD if kind == "shield" else MELEE
			d.tags = [&"melee", &"medieval"] as Array[StringName]
			d.use_interval_ticks = int(c["swing_ticks"])
			b.max_range = float(c["reach"])
			d.params[&"arc_degrees"] = float(c["arc_degrees"])
			d.params[&"rays"] = int(c["rays"])
			if kind == "shield":
				d.tags.append(&"shield")
				d.params[&"knockback"] = float(c["knockback"])
				d.params[&"block_reduction"] = float(c["block_reduction"])
				d.params[&"block_arc_degrees"] = float(c["block_arc_degrees"])
				d.params[&"block_stamina_per_damage"] = float(c["block_stamina_per_damage"])
		"bow", "crossbow":
			d.behaviour_path = PROJECTILE
			d.tags = [&"ranged", &"medieval", StringName(kind)] as Array[StringName]
			d.ammo_type = &"bolts" if kind == "crossbow" else &"arrows"
			d.reserve = int(c["reserve"])
			d.reserve_max = int(c["reserve"])
			d.use_interval_ticks = int(c.get("use_interval_ticks", 20))
			d.params[&"projectile_id"] = String(c["projectile_id"])
			b.min_charge_damage = float(c["min_charge_damage"])
			b.speed = float(c["speed"])
			b.min_speed = float(c["min_speed"])
			b.gravity_scale = float(c["gravity_scale"])
			b.radius = float(c["arrow_radius"])
			b.life_ticks = int(c["life_ticks"])
			b.max_range = 400.0
			d.cost_per_use = 1
			if kind == "bow":
				d.fire_mode = DotWeaponDef.Fire.CHARGE
				d.charge_ticks = int(c["draw_ticks"])
				d.charge_requires_min = true
				d.min_charge = float(c["min_charge"])
			else:
				d.magazine = int(c["magazine"])
				d.reload_ticks = int(c["reload_ticks"])
				d.auto_reload = true
	return d
