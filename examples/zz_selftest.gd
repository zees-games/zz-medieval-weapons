extends Node

## The headless suite. Counts sections entered against sections finished and a total of checks,
## so a script error that aborts a section cannot report "0 failed" with checks missing.
## What it cannot see is how the weapons look: `tools/screenshot.sh`.

const CHECKS := 177

var _entered := 0
var _finished := 0
var _checks := 0
var _failures := 0
var _section := ""


func _ready() -> void:
	print("zz-medieval-weapons self-test")
	_config()
	_defs()
	_melee()
	_bow()
	_crossbow()
	_shield()
	_models()
	_spawn()
	_workshop()
	print("%d sections entered, %d finished, %d checks (expected %d), %d failed" % [_entered, _finished, _checks, CHECKS, _failures])
	if _entered != _finished or _checks != CHECKS:
		_failures += 1
		print("FAIL: sections or check count do not match")
	get_tree().quit(1 if _failures > 0 else 0)


func _begin(name: String) -> void:
	_entered += 1
	_section = name
	print("-- ", name)


func _end() -> void:
	_finished += 1


func _check(ok: bool, what: String) -> void:
	_checks += 1
	if not ok:
		_failures += 1
		print("  FAIL [%s] %s" % [_section, what])


func _catalogue(cfg: Dictionary = {}) -> DotWeaponCatalogue:
	var cat := DotWeaponCatalogue.new()
	for d in ZzMedievalPack.weapons(cfg):
		cat.add(d)
	return cat


func _use(cat: DotWeaponCatalogue, id: StringName, charge: float = 1.0) -> DotWeaponOutcome:
	var made := cat.instantiate(id)
	var beh: DotWeaponBehaviour = made.value
	beh.setup(cat.get_def(id))
	var ctx := DotWeaponContext.make(1, 100, Vector3(0, 1.6, 0), Vector3.FORWARD)
	ctx.charge = charge
	return beh.use(ctx)


func _config() -> void:
	_begin("config")
	var d := ZzMedievalConfig.defaults()
	_check(d.size() == 8, "eight weapons")
	_check(ZzMedievalConfig.IDS.size() == 8, "eight ids")
	for id in ZzMedievalConfig.IDS:
		_check(d.has(String(id)), "default row for %s" % id)
	# Overrides: the fallback reader lays a yml over the defaults.
	var tmp := OS.get_temp_dir().path_join("zz_cfg_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(tmp)
	var f := FileAccess.open(tmp.path_join("longsword.yml"), FileAccess.WRITE)
	f.store_string("longsword:\n  damage: 99.5\n  rays: 7\n")
	f.close()
	var merged := ZzMedievalConfig.load_all(tmp)
	_check(is_equal_approx(float(merged["longsword"]["damage"]), 99.5), "yml overrides damage")
	_check(int(merged["longsword"]["rays"]) == 7, "yml overrides rays")
	_check(is_equal_approx(float(merged["longsword"]["reach"]), 2.4), "untouched key keeps its default")
	_check(is_equal_approx(float(merged["dagger"]["damage"]), 28.0), "other weapons keep defaults")
	# The shipped cfg directory, read through dot-core, equals the built-in table.
	_check(str(ZzMedievalConfig.load_all()) == str(d), "shipped yml equals the defaults")
	_end()


func _defs() -> void:
	_begin("definitions")
	var cat := _catalogue()
	for id in ZzMedievalConfig.IDS:
		var def := cat.get_def(id)
		_check(def != null, "%s in catalogue" % id)
		_check(def.validate().ok, "%s validates" % id)
		_check(def.authored_tick_rate == 64, "%s authored at 64" % id)
		_check(cat.instantiate(id).ok, "%s behaviour resolves" % id)
	_check(cat.get_def(&"bow").fire_mode == DotWeaponDef.Fire.CHARGE, "bow is a drawn shot")
	_check(cat.get_def(&"crossbow").fire_mode == DotWeaponDef.Fire.SEMI, "crossbow is one use per press")
	_end()


func _melee() -> void:
	_begin("melee")
	var cat := _catalogue()
	var sword := _use(cat, &"longsword")
	_check(sword.shots.size() == 1, "sword emits one shot")
	var shot := sword.shots[0]
	_check(is_equal_approx(shot.damage, 55.0), "sword damage from cfg")
	_check(is_equal_approx(shot.max_range, 2.4), "sword reach from cfg")
	_check(shot.pellet_count == 5, "sword sweeps five rays")
	_check(_event(sword, "stamina") != null and is_equal_approx(float(_event(sword, "stamina")["cost"]), 12.0), "swing costs stamina")
	var spear := _use(cat, &"spear")
	_check(spear.shots[0].max_range > sword.shots[0].max_range, "spear outreaches the sword")
	_check(_use(cat, &"battle_axe").shots[0].damage > _use(cat, &"mace").shots[0].damage, "axe hits harder than mace")
	_check(_use(cat, &"dagger").shots[0].damage < sword.shots[0].damage, "dagger is lighter")
	_check(cat.get_def(&"dagger").use_interval_ticks < cat.get_def(&"battle_axe").use_interval_ticks, "dagger is faster than the axe")
	# A tuned value reaches the shot.
	var cfg := ZzMedievalConfig.defaults()
	cfg["mace"]["damage"] = 123.0
	_check(is_equal_approx(_use(_catalogue(cfg), &"mace").shots[0].damage, 123.0), "cfg change reaches the shot")
	_end()


func _bow() -> void:
	_begin("bow")
	var cat := _catalogue()
	var full := _use(cat, &"bow", 1.0)
	var half := _use(cat, &"bow", 0.5)
	_check(full.spawns.size() == 1, "a draw looses one arrow")
	var a := full.spawns[0]
	var h := half.spawns[0]
	_check(is_equal_approx(a.velocity.length(), 72.0), "full draw arrow speed from cfg")
	_check(h.velocity.length() < a.velocity.length(), "half draw is slower")
	_check(h.damage < a.damage, "half draw is weaker")
	_check(is_equal_approx(a.damage, 75.0), "full draw damage from cfg")
	_check(is_equal_approx(a.gravity_scale, 1.0), "arrow drops")
	_check(a.id == &"arrow", "projectile is an arrow")
	_check(a.velocity.z < 0.0, "arrow flies forward")
	_check(is_equal_approx(a.life_ticks, 640.0), "arrow life from cfg")
	var def := cat.get_def(&"bow")
	_check(def.charge_ticks == 72 and def.charge_requires_min, "draw time and minimum draw")
	_check(is_equal_approx(float(_event(half, "stamina")["cost"]), 4.0), "stamina scales with the draw")
	_end()


func _crossbow() -> void:
	_begin("crossbow")
	var cat := _catalogue()
	var out := _use(cat, &"crossbow")
	var def := cat.get_def(&"crossbow")
	_check(out.spawns.size() == 1 and out.spawns[0].id == &"bolt", "crossbow looses a bolt")
	_check(out.spawns[0].velocity.length() > 72.0, "bolt is faster than an arrow")
	_check(out.spawns[0].gravity_scale < 1.0, "bolt drops less")
	_check(def.magazine == 1 and def.reload_ticks == 200, "one bolt, a slow reload")
	_check(def.ammo_type == &"bolts" and cat.get_def(&"bow").ammo_type == &"arrows", "separate ammunition pools")
	_end()


func _shield() -> void:
	_begin("shield")
	var cat := _catalogue()
	var def := cat.get_def(&"round_shield")
	var bash := _use(cat, &"round_shield")
	_check(bash.shots.size() == 1 and bash.shots[0].damage < 20.0, "bash is a weak sweep")
	_check(_event(bash, "knockback") != null and is_equal_approx(float(_event(bash, "knockback")["impulse"]), 7.0), "bash knocks back")
	var f := Vector3.FORWARD
	_check(is_equal_approx(ZzMedievalBlock.reduced(def, 100.0, f, Vector3.FORWARD, true), 20.0), "front hit reduced by 80%")
	_check(is_equal_approx(ZzMedievalBlock.reduced(def, 100.0, f, Vector3.BACK, true), 100.0), "hit from behind not blocked")
	_check(is_equal_approx(ZzMedievalBlock.reduced(def, 100.0, f, Vector3.FORWARD, false), 100.0), "not blocking: full damage")
	_check(is_equal_approx(ZzMedievalBlock.reduced(def, 100.0, f, Vector3(1, 0, -1), true), 20.0), "45 degrees off is inside the arc")
	_check(is_equal_approx(ZzMedievalBlock.reduced(def, 100.0, f, Vector3.RIGHT, true), 100.0), "90 degrees off is outside the 120 degree arc")
	_check(is_equal_approx(ZzMedievalBlock.stamina_cost(def, 80.0), 24.0), "block stamina per damage stopped")
	_end()


func _models() -> void:
	_begin("models")
	for id in ZzMedievalConfig.IDS:
		var n := ZzMedievalModels.build(id)
		_check(n != null and n.get_child_count() > 0, "%s model builds" % id)
		n.free()
	var arrow := ZzMedievalModels.projectile(&"arrow")
	_check(arrow.get_child_count() == 2, "arrow has shaft and head")
	arrow.free()
	_end()


func _spawn() -> void:
	_begin("spawn provider")
	var rows := ZzMedievalSpawnProvider.spawn_entries()
	_check(rows.size() == 8, "one row per weapon")
	for r in rows:
		for k in ["category", "id", "name", "icon", "kind", "spawn", "cfg_hint"]:
			_check(r.has(k), "%s has %s" % [r.get("id"), k])
		_check(ResourceLoader.exists(r["icon"]), "%s icon exists" % r["id"])
	_check(rows[0]["category"] == "Weapons" and rows[0]["kind"] == "weapon", "category and kind")
	_end()


func _workshop() -> void:
	_begin("workshop form")
	var defs := ZzMedievalPack.weapons()
	var json: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://provides.json"))
	_check(json is Dictionary and json["games"] == "*", "provides.json games *")
	_check(json is Dictionary and json["entries"].size() == 8, "provides.json lists eight")
	_check(FileAccess.get_file_as_string("res://provides.json") == JSON.stringify(ZzDefExport.provides(defs), "\t", false) + "\n", "provides.json is not stale")
	for d in defs:
		var loaded: DotWeaponDef = load("res://weapons/%s.tres" % String(d.id))
		_check(loaded != null and loaded.describe() == d.describe() and str(loaded.tuning.describe()) == str(d.tuning.describe()) and loaded.params == d.params, "%s .tres is not stale" % d.id)
		_check(FileAccess.get_file_as_string("res://cfg/addons/zz_medieval_weapons/%s.yml" % String(d.id)) == ZzMedievalConfig.to_yaml(d.id), "%s yml matches defaults" % d.id)
	_end()


func _event(out: DotWeaponOutcome, type: String) -> Variant:
	for e in out.events:
		if e.get("type") == type:
			return e
	return null
