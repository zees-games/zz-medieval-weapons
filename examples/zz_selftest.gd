extends Node

## The headless suite. Counts sections entered against sections finished and a total of checks,
## so a script error that aborts a section cannot report "0 failed" with checks missing.
## What it cannot see is how the weapons look: `tools/screenshot.sh`.

const CHECKS := 423

var _entered := 0
var _finished := 0
var _checks := 0
var _failures := 0
var _section := ""


func _ready() -> void:
	print("zz-medieval-weapons self-test")
	_config()
	_profiles()
	_defs()
	_melee()
	_bow()
	_crossbow()
	_shield()
	_models()
	_spawn()
	_workshop()
	_pack_cfg()
	_packs()
	_art_table()
	_pose()
	_anim()
	_bow_anim()
	_crossbow_anim()
	_net()
	_held()
	_flight()
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
	_check(d.size() == 10, "ten weapons")
	_check(ZzMedievalConfig.IDS.size() == 10, "ten ids")
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
	# weapon_defs (what Zombie Zone's pack loader calls) must see the same override.
	f = FileAccess.open(tmp.path_join("dagger.yml"), FileAccess.WRITE)
	f.store_string("dagger:\n  damage: 41\n")
	f.close()
	var tuned := 0.0
	var untuned := 0.0
	for def in ZzMedievalSpawnProvider.weapon_defs({}, tmp):
		if def.id == &"dagger": tuned = float(def.tuning.get("damage"))
	_check(tuned > 0.0, "weapon_defs yields a dagger with a damage")
	for def in ZzMedievalSpawnProvider.weapon_defs():
		if def.id == &"dagger": untuned = float(def.tuning.get("damage"))
	_check(not is_equal_approx(tuned, untuned), "a yml override changes the dagger through weapon_defs")
	# The shipped cfg directory, read through dot-core, equals the built-in table.
	_check(str(ZzMedievalConfig.load_all()) == str(d), "shipped yml equals the defaults")
	_end()


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _root(name: String) -> String:
	return OS.get_temp_dir().path_join("zz_prof_%s_%d" % [name, Time.get_ticks_usec()])


func _profiles() -> void:
	_begin("weapon profiles")
	var d := ZzMedievalConfig.defaults()
	var res_roots := PackedStringArray(["res://cfg"])
	var set := ZzMedievalConfig.profile_set(res_roots)
	# Listing opens no profile; the order is by id, the menu order is by sort.
	var ids := Array(DotWeaponProfiles.list_ids(set))
	var want: Array = ZzMedievalConfig.IDS.map(func(i: StringName) -> String: return String(i))
	want.sort()
	_check(ids == want, "list_ids finds the ten shipped profiles (%s)" % [ids])
	var menu := ZzMedievalConfig.menu_entries(res_roots)
	_check(menu.size() == 10 and menu[0]["id"] == "longsword" and menu[7]["id"] == "dagger", "menu entries are in menu order")
	var cats := {}
	for m in menu:
		cats[m["id"]] = m["category"]
	_check(cats["round_shield"] == "shield" and cats["bow"] == "ranged" and cats["mace"] == "melee", "menu categories come from menu: keys")
	# Equivalence with the code table: every number a profile carries is the default's.
	var same := 0
	for id in ZzMedievalConfig.IDS:
		var res := set.load_profile(String(id))
		if res.ok and str(DotWeaponProfiles.flat(res.value).get("damage")) == str(d[String(id)]["damage"]):
			same += 1
	_check(same == 10, "all ten profiles carry the default damage")
	_check(str(ZzMedievalConfig.load_all("", res_roots)) == str(d), "profiles build exactly the default rows")
	_check(ZzMedievalConfig.errors.is_empty(), "no shipped profile fails")
	var def_res := DotWeaponProfiles.load_def(set, "longsword")
	set.clear_cache()
	_check(def_res.ok and def_res.value.slot == 1 and def_res.value.deploy_ticks == 26 and def_res.value.display_name == "Longsword", "load_def fills the common fields")
	_check(def_res.ok and is_equal_approx(float(def_res.value.params["damage"]), 55.0), "load_def keeps the pack keys as params")
	# Game and server tiers.
	var tmp := _root("tiers")
	_write(tmp.path_join("game/tg/weapon/longsword.yml"), "extra:\n  damage: 77.0\n")
	_write(tmp.path_join("server/weapon/mace.yml"), "slot: 2\n")
	ZzMedievalConfig.game = "tg"
	var tiered := ZzMedievalConfig.load_all("", PackedStringArray(["res://cfg", tmp]))
	ZzMedievalConfig.game = ""
	_check(is_equal_approx(float(tiered["longsword"]["damage"]), 77.0), "the game tier overrides a pack key")
	_check(is_equal_approx(float(tiered["longsword"]["reach"]), 2.4), "and leaves the others")
	_check(int(tiered["mace"]["slot"]) == 2 and is_equal_approx(float(tiered["mace"]["damage"]), 66.0), "the server tier overrides a common key")
	var no_game := ZzMedievalConfig.load_all("", PackedStringArray(["res://cfg", tmp]))
	_check(is_equal_approx(float(no_game["longsword"]["damage"]), 55.0), "another game does not see the game tier")
	# Upgrades.
	_check(Array(DotWeaponProfiles.list_upgrades(set, "longsword")) == ["balanced", "sharpened"], "longsword lists two upgrades")
	_check(DotWeaponProfiles.list_upgrades(set, "dagger").is_empty(), "dagger has none")
	_check(Array(set.child_kinds("longsword")) == ["upgrades"], "the folder form has an upgrades child")
	var up := ZzMedievalConfig.upgraded(&"longsword", ["sharpened"], res_roots)
	_check(up.ok and is_equal_approx(float(up.value["values"]["damage"]), 60.5) and is_equal_approx(float(up.value["values"]["reach"]), 2.5) and up.value["cost"] == 100, "sharpened multiplies damage, adds reach, costs 100")
	var up2 := ZzMedievalConfig.upgraded(&"longsword", ["sharpened", "balanced"], res_roots)
	_check(up2.ok and up2.value["values"]["swing_ticks"] == 38 and up2.value["values"]["rays"] == 6 and up2.value["cost"] == 250, "balanced adds ticks, sets rays, costs add up")
	_check(is_equal_approx(float(ZzMedievalConfig.load_all("", res_roots)["longsword"]["damage"]), 55.0), "applying upgrades leaves the row alone")
	_check(not ZzMedievalConfig.upgraded(&"longsword", ["balanced"], res_roots).ok, "balanced without sharpened is refused")
	_check(not ZzMedievalConfig.upgraded(&"longsword", ["balanced", "sharpened"], res_roots).ok, "a prerequisite must come first")
	_check(not ZzMedievalConfig.upgraded(&"longsword", ["sharpened", "sharpened"], res_roots).ok, "an upgrade applies once")
	_check(not ZzMedievalConfig.upgraded(&"longsword", ["nope"], res_roots).ok, "an unknown upgrade is refused")
	var bow_up := ZzMedievalConfig.upgraded(&"bow", ["heavy_limbs"], res_roots)
	_check(bow_up.ok and is_equal_approx(float(bow_up.value["values"]["speed"]), 79.2) and is_equal_approx(float(bow_up.value["values"]["damage"]), 85.0), "bow upgrade keeps the float keys floats")
	var bad_up := _root("badup")
	_write(bad_up.path_join("addons/zz_medieval_weapons/weapon/dagger/dagger.yml"), "name: \"Dagger\"\n")
	_write(bad_up.path_join("addons/zz_medieval_weapons/weapon/dagger/upgrades/ghost.yml"), "add:\n  nokey: 1\n")
	_write(bad_up.path_join("addons/zz_medieval_weapons/weapon/dagger/upgrades/wrong.yml"), "set:\n  damage: \"lots\"\n")
	_check(not ZzMedievalConfig.upgraded(&"dagger", ["ghost"], PackedStringArray([bad_up])).ok, "an upgrade naming a missing key fails")
	_check(not ZzMedievalConfig.upgraded(&"dagger", ["wrong"], PackedStringArray([bad_up])).ok, "an upgrade setting the wrong type fails")
	# Bad yml: the weapon keeps the layer below and the rest still load.
	var bad := _root("bad")
	_write(bad.path_join("addons/zz_medieval_weapons/weapon/dagger.yml"), "extra: [unclosed\n  damage: {\n")
	_write(bad.path_join("addons/zz_medieval_weapons/weapon/mace.yml"), "bogus_key: 1\n")
	_write(bad.path_join("addons/zz_medieval_weapons/weapon/spear.yml"), "slot: 0\n")
	_write(bad.path_join("addons/zz_medieval_weapons/weapon/bow.yml"), "fire_mode: \"plasma\"\n")
	_write(bad.path_join("addons/zz_medieval_weapons/weapon/longsword.yml"), "extra:\n  damage: 12.0\n")
	var broken := ZzMedievalConfig.load_all("", PackedStringArray([bad]))
	_check(ZzMedievalConfig.errors.size() == 4, "four broken profiles are reported (%d)" % ZzMedievalConfig.errors.size())
	_check(is_equal_approx(float(broken["dagger"]["damage"]), 28.0) and is_equal_approx(float(broken["mace"]["damage"]), 66.0), "a broken profile keeps its default row")
	_check(int(broken["spear"]["slot"]) == 1 and is_equal_approx(float(broken["longsword"]["damage"]), 12.0), "and a good one beside it still loads")
	# Old files still work, and sit below the profiles.
	var old := _root("old")
	_write(old.path_join("old.yml"), "longsword:\n  damage: 99.5\n  rays: 7\n  slot: 2\n")
	var mixed_root := _root("mixed")
	_write(mixed_root.path_join("addons/zz_medieval_weapons/weapon/longsword.yml"), "extra:\n  damage: 70.0\n  reach: 3.0\n")
	var mixed := ZzMedievalConfig.load_all(old, PackedStringArray([mixed_root]))
	_check(is_equal_approx(float(mixed["longsword"]["damage"]), 99.5), "an old file still beats the shipped profile")
	_check(int(mixed["longsword"]["rays"]) == 7 and int(mixed["longsword"]["slot"]) == 2, "an old file's other keys apply, common ones too")
	_check(is_equal_approx(float(mixed["longsword"]["reach"]), 3.0) and is_equal_approx(float(mixed["dagger"]["damage"]), 28.0), "and the rest comes from the profiles and defaults")
	_check(is_equal_approx(float(ZzMedievalConfig.load_all(old, PackedStringArray([tmp.path_join("none")]))["longsword"]["damage"]), 99.5), "with no profiles the old file alone retunes")
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
	for id in [&"war_axe", &"double_axe"]:
		var v := ZzMedievalModels.build(id)
		var mi := v.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var box := mi.mesh.get_aabb()
		_check(not ZzMedievalModels.is_placeholder(id), "%s is a vendored glb" % id)
		_check(box.position.y > -0.25 and box.end.y > 0.8 and box.end.y < 1.0, "%s: butt below the grip, head about a metre up (+Y along the weapon)" % id)
		_check(mi.mesh.surface_get_array_len(0) < 4000, "%s stays under the vertex budget" % id)
		v.free()
	for id in [&"longsword", &"bow", &"round_shield"]:
		var v2 := ZzMedievalModels.build(id)
		_check(not ZzMedievalModels.is_placeholder(id), "%s is a vendored glb" % id)
		var top := 0.0
		var low := 0.0
		for m in v2.find_children("*", "MeshInstance3D", true, false):
			var bb := (m as MeshInstance3D).get_aabb()
			top = maxf(top, bb.end.y)
			low = minf(low, bb.position.y)
		_check(top > 0.35 and low > -0.8 and top < 1.1, "%s: sized in metres about the grip (+Y along the weapon)" % id)
		v2.free()
	for id in [&"battle_axe", &"mace", &"spear", &"crossbow", &"dagger"]:
		_check(not ZzMedievalModels.is_placeholder(id), "%s is a vendored glb" % id)
	var env := ZzMedievalReflectionSource.sky_environment()
	_check(env.reflected_light_source == Environment.REFLECTION_SOURCE_SKY and env.sky != null, "the sky environment gives metal something to reflect")
	var host := Node3D.new()
	var probe := ZzMedievalReflectionSource.attach_probe(host)
	_check(probe.get_parent() == host and probe.update_mode == ReflectionProbe.UPDATE_ONCE, "a probe hangs on the host and captures once")
	host.free()
	var arrow := ZzMedievalModels.projectile(&"arrow")
	_check(arrow.get_child_count() == 2, "arrow has shaft and head")
	arrow.free()
	_end()


func _spawn() -> void:
	_begin("spawn provider")
	var rows := ZzMedievalSpawnProvider.spawn_entries()
	_check(rows.size() == 10, "one row per weapon")
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
	_check(json is Dictionary and json["entries"].size() == 10, "provides.json lists ten")
	_check(FileAccess.get_file_as_string("res://provides.json") == JSON.stringify(ZzDefExport.provides(defs), "\t", false) + "\n", "provides.json is not stale")
	for d in defs:
		var loaded: DotWeaponDef = load("res://weapons/%s.tres" % String(d.id))
		_check(loaded != null and loaded.describe() == d.describe() and str(loaded.tuning.describe()) == str(d.tuning.describe()) and loaded.params == d.params, "%s .tres is not stale" % d.id)
		_check(FileAccess.get_file_as_string(ZzMedievalConfig.profile_path(d.id)) == ZzMedievalConfig.to_yaml(d.id), "%s yml matches defaults" % d.id)
	_end()

func _pack_cfg() -> void:
	_begin("delivered pack cfg root")
	var src := "user://pack_cfg_src"
	var rel := "cfg/addons/zz_medieval_weapons/weapon"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://cfg/server/addons/zz_medieval_weapons/weapon"))
	var exported := ZzDefExport.export_to(src)
	_check(exported.ok, "export succeeds")
	var yml := src.path_join(rel).path_join("dagger.yml")
	var text := FileAccess.get_file_as_string(yml)
	_check(text.contains("damage:"), "the export ships the profile")
	var re := RegEx.create_from_string("(?m)^  damage: .*$")
	var f := FileAccess.open(yml, FileAccess.WRITE)
	f.store_string(re.sub(text, "  damage: 777.0"))
	f.close()
	var pck := PCKPacker.new()
	var pck_path := ProjectSettings.globalize_path("user://pack_cfg_test.pck")
	pck.pck_start(pck_path)
	var stack: Array[String] = [""]
	while not stack.is_empty():
		var sub: String = stack.pop_back()
		for d in DirAccess.get_directories_at(src.path_join(rel).path_join(sub)):
			stack.append(sub.path_join(d))
		for n in DirAccess.get_files_at(src.path_join(rel).path_join(sub)):
			pck.add_file("res://dot_cloud/zzcfg/1".path_join(rel).path_join(sub).path_join(n), ProjectSettings.globalize_path(src.path_join(rel).path_join(sub).path_join(n)))
	pck.flush()
	_check(ProjectSettings.load_resource_pack(pck_path), "pack mounts")
	ZzMedievalConfig.pack_cfg_root = "res://dot_cloud/zzcfg/1/cfg"
	ZzMedievalConfig.base_roots = PackedStringArray(["user://cfg"])
	_check(is_equal_approx(_pack_damage(), 777.0), "a delivered pack's profile numbers reach weapon_defs()")
	var srv := FileAccess.open("user://cfg/server/addons/zz_medieval_weapons/weapon/dagger.yml", FileAccess.WRITE)
	srv.store_string("extra:\n  damage: 555.0\n")
	srv.close()
	_check(is_equal_approx(_pack_damage(), 555.0), "cfg/server still overrides the pack")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cfg/server/addons/zz_medieval_weapons/weapon/dagger.yml"))
	ZzMedievalConfig.pack_cfg_root = ""
	ZzMedievalConfig.base_roots = PackedStringArray()
	_end()


func _pack_damage() -> float:
	for d in ZzMedievalSpawnProvider.weapon_defs():
		if String(d.id).ends_with("dagger"):
			return float(d.tuning.get("damage"))
	return -1.0


func _event(out: DotWeaponOutcome, type: String) -> Variant:
	for e in out.events:
		if e.get("type") == type:
			return e
	return null


## Loads the provider the way game-zombie-zone's game/zz_packs.gd does (by path, `script.new()`,
## `has_method`, `call`, then a source Callable on the script), so a change that breaks the
## contract fails here and not in a game that merely lists the weapons and refuses them.
func _packs() -> void:
	_begin("zz_packs contract")
	var path := "res://addons/zz_medieval_weapons/spawn_provider.gd"
	_check(ResourceLoader.exists(path) or FileAccess.file_exists(path), "provider file found by path")
	var script := load(path) as GDScript
	_check(script != null and script.can_instantiate(), "provider loads and instantiates")
	var provider: Object = script.new()
	_check(provider.has_method(&"spawn_entries"), "has spawn_entries")
	_check(provider.has_method(&"weapon_defs"), "has weapon_defs")
	var rows: Array = provider.call(&"spawn_entries")
	var defs: Array = provider.call(&"weapon_defs")
	var ids := PackedStringArray()
	for def: Variant in defs:
		_check(def is DotWeaponDef, "weapon_defs holds only DotWeaponDef")
		if def is DotWeaponDef:
			ids.append(String(def.id))
	_check(ids.size() == ZzMedievalConfig.IDS.size(), "one definition per weapon id")
	# Through the source Callable zee calls, with the game's damage table as `types`.
	var types := {"slash": DotDamageType.new()}
	var via: Array = Callable(provider.get_script(), &"weapon_defs").call(types)
	_check(via.size() == ids.size(), "the source Callable returns the same set")
	var slash_used := false
	for def: DotWeaponDef in via:
		if def.tuning != null and def.tuning.damage_type == types["slash"]:
			slash_used = true
	_check(slash_used, "the game's damage type replaces the pack's own")
	var kept := 0
	for row: Variant in rows:
		var r: Dictionary = row
		_check(str(r.get("kind", "")) == "weapon", "row %s is a weapon row" % r.get("id", "?"))
		var spawn: Dictionary = r.get("spawn", {})
		var wid := str(spawn.get("weapon", spawn.get("weapon_id", r.get("id", ""))))
		if ids.has(wid) or ids.has(str(r.get("id", ""))):
			kept += 1
	_check(kept == rows.size() and kept == ids.size(), "every weapon row has a definition behind it")
	_end()


## A fake replicating object: the fields [ZzMedievalNet] reads and writes.
class FakeNet extends RefCounted:
	var net_use_seq := 0
	var net_use_style := 0
	var net_blocking := false
	var net_draw := 0
	var net_reloading := false


func _art_table() -> void:
	_begin("art table")
	for id in ZzMedievalConfig.IDS:
		var r := ZzMedievalArtTable.row(id)
		_check(not r.is_empty(), "%s has an art row" % id)
		_check(r.has("hold") and r.has("rest") and not (r["styles"] as Array).is_empty(), "%s has hold, rest and styles" % id)
	_check(ZzMedievalArtTable.has_string(&"bow") and ZzMedievalArtTable.has_string(&"crossbow"), "the two missile weapons have strings")
	_check(not ZzMedievalArtTable.has_string(&"longsword"), "a sword has no string")
	_check(ZzMedievalArtTable.string_point(&"bow", 1.0).x > ZzMedievalArtTable.string_point(&"bow", 0.0).x, "a drawn bow string is back toward the archer")
	_check(ZzMedievalArtTable.cue(&"battle_axe", &"swing") == &"swing_heavy" and ZzMedievalArtTable.cue(&"dagger", &"swing") == &"swing_light", "swing cue follows the weapon's weight")
	_check(ZzMedievalArtTable.cue(&"spear", &"hit") == &"hit_wood", "hit cue follows the surface")
	_end()


func _pose() -> void:
	_begin("pose curves")
	for st in [1, 2, 3, 4, 5, 6, 7]:
		var a := ZzWeaponPose.sample(st, 0.0)
		var z := ZzWeaponPose.sample(st, 1.0)
		_check((a["pos"] as Vector3).length() < 0.001 and (z["pos"] as Vector3).length() < 0.001, "%s starts and ends at rest" % ZzWeaponPose.style_name(st))
	var hi := ZzWeaponPose.sample(ZzWeaponPose.Style.THRUST, 0.55)
	var back := ZzWeaponPose.sample(ZzWeaponPose.Style.THRUST, 0.34)
	_check((hi["pos"] as Vector3).z < -0.5 and (back["pos"] as Vector3).z > 0.2, "a thrust draws back then reaches forward")
	var r := ZzWeaponPose.sample(ZzWeaponPose.Style.SLASH_R, 0.55)
	var l := ZzWeaponPose.sample(ZzWeaponPose.Style.SLASH_L, 0.55)
	_check(is_equal_approx((r["pos"] as Vector3).x, -(l["pos"] as Vector3).x), "a left slash mirrors the right")
	var o := ZzWeaponPose.sample(ZzWeaponPose.Style.OVERHEAD, 0.34)
	_check((o["rot"] as Vector3).x > 90.0 and (o["pos"] as Vector3).y > 0.3, "an overhead raises the weapon over the shoulder")
	_check(ZzWeaponPose.sample(ZzWeaponPose.Style.SLASH_R, 0.55, 0.5)["pos"].length() < r["pos"].length(), "heft scales the swing")
	_end()


func _anim() -> void:
	_begin("melee animation")
	var a := ZzWeaponAnim.new()
	a.configure(&"longsword")
	_check(is_equal_approx(a.swing_s, 42.0 / 64.0), "swing duration is swing_ticks at 64")
	var seen := []
	a.used.connect(func(s: int) -> void: seen.append(s))
	var struck := [0]
	a.struck.connect(func(_s: int) -> void: struck[0] += 1)
	var cues := []
	a.cue.connect(func(n: StringName) -> void: cues.append(n))
	for i in 4:
		a.start_use()
		for f in 60:
			a.advance(1.0 / 60.0)
		_check(not a.is_swinging(), "swing %d finished" % i)
	_check(seen == [1, 2, 3, 1], "longsword cycles slash, slash, overhead, slash (%s)" % [seen])
	_check(struck[0] == 4, "each swing struck exactly once")
	_check(cues.count(&"swing_light") == 4, "each swing asks for its sound")
	a.start_use()
	a.advance(a.swing_s * 0.5)
	_check((a.pose()["pos"] as Vector3).length() > 0.1, "mid-swing the hand is away from rest")
	var kick := ZzWeaponAnim.new()
	kick.configure(&"mace")
	var hits := []
	kick.cue.connect(func(n: StringName) -> void: hits.append(n))
	kick.hit(&"wood")
	_check(hits == [&"hit_wood"] and (kick.pose()["pos"] as Vector3).z > 0.0, "a hit recoils the weapon and asks for its sound")
	var sh := ZzWeaponAnim.new()
	sh.configure(&"round_shield")
	var base: Vector3 = sh.pose()["pos"]
	sh.set_blocking(true)
	for f in 30:
		sh.advance(1.0 / 60.0)
	_check(is_equal_approx(sh.block, 1.0), "the guard comes fully up")
	_check((sh.pose()["pos"] as Vector3).distance_to(base) > 0.4, "a raised shield is across the body, not at the hip")
	sh.set_blocking(false)
	for f in 30:
		sh.advance(1.0 / 60.0)
	_check(is_equal_approx(sh.block, 0.0), "and goes down again")
	sh.start_use()
	_check(sh.style == ZzWeaponPose.Style.BASH, "the shield's use is a bash")
	_end()


func _bow_anim() -> void:
	_begin("bow animation")
	var b := ZzWeaponAnim.new()
	b.configure(&"bow")
	var loosed := []
	b.loosed.connect(func(c: float) -> void: loosed.append(c))
	b.hold_draw(true)
	for f in 30:
		b.advance(1.0 / 60.0)
	_check(b.draw > 0.4 and b.draw < 0.7, "half a second of a 58-tick draw is about half (%.2f)" % b.draw)
	_check(b.pose()["off_string"] > 0.9, "the other hand is on the string")
	b.hold_draw(true)
	for f in 60:
		b.advance(1.0 / 60.0)
	_check(is_equal_approx(b.draw, 1.0), "the draw stops at full")
	b.hold_draw(false)
	_check(loosed.size() == 1 and is_equal_approx(loosed[0], 1.0), "releasing a full draw looses once at full charge")
	_check(not b.nocked and b.draw == 0.0, "the arrow is gone and the string forward")
	for f in 30:
		b.advance(1.0 / 60.0)
	_check(b.nocked, "a new arrow is nocked")
	b.hold_draw(true)
	b.advance(0.1)
	b.hold_draw(false)
	_check(loosed.size() == 1, "a short draw is relaxed, not loosed")
	_end()


func _crossbow_anim() -> void:
	_begin("crossbow animation")
	var c := ZzWeaponAnim.new()
	c.configure(&"crossbow")
	_check(c.loaded and c.draw == 1.0, "starts cocked and loaded")
	var loosed := []
	c.loosed.connect(func(ch: float) -> void: loosed.append(ch))
	c.start_use()
	_check(loosed.size() == 1 and not c.loaded and c.draw == 0.0, "firing looses the bolt and lets the string go")
	c.set_reloading(true)
	for f in 45:
		c.advance(1.0 / 60.0)
	_check(c.draw > 0.3 and c.draw < 1.0 and not c.loaded, "mid-reload the string is part-way back")
	_check(c.pose()["off_string"] > 0.5, "the off hand works the string")
	c.set_reloading(false)
	_check(c.loaded and c.draw == 1.0, "the simulation ending the reload snaps to loaded")
	var profile_s := float(ZzMedievalConfig.load_all()["crossbow"]["reload_ticks"]) / float(ZzMedievalConfig.TICK_RATE)
	c.start_use()
	c.set_reloading(true)
	var t := 0.0
	while c.reloading and t < 20.0:
		c.advance(1.0 / 64.0)
		t += 1.0 / 64.0
	_check(absf(t - profile_s) < 0.05 * profile_s, "the crossbow reload animation lasts the profile's reload time (%.2f vs %.2f)" % [t, profile_s])
	var rest: Dictionary = c.pose()
	_check(c.loaded and c.draw == 1.0 and (rest["pos"] as Vector3).length() < 0.01 and (rest["rot"] as Vector3).length() < 0.5, "the crossbow reload ends at the rest pose")
	_end()


func _net() -> void:
	_begin("replication")
	var specs := ZzMedievalNet.specs()
	_check(specs.size() == 5, "five fields")
	var bits := 0
	for sp in specs:
		bits += int(sp["bits"])
		_check(sp["owner_only"] == false and sp["interpolated"] == false, "%s is public and uninterpolated" % sp["property"])
	_check(bits == 4 + 3 + 1 + 4 + 1, "thirteen bits")
	_check(ZzMedievalNet.all_specs().size() == DotWeaponNetSync.specs().size() + 5, "all_specs adds to dot-weapon's")
	_check(ZzMedievalNet.uses_between(14, 2) == 4 and ZzMedievalNet.uses_between(3, 3) == 0, "uses_between is wrap-aware")
	_check(absf(ZzMedievalNet.dequantise_draw(ZzMedievalNet.quantise_draw(0.5)) - 0.5) < 0.04, "draw survives quantising")
	# Owner swings, a watcher copies it from the fields alone.
	var owner := ZzWeaponAnim.new()
	owner.configure(&"longsword")
	var sender := ZzMedievalNet.Sender.new()
	sender.attach(owner)
	var wire := FakeNet.new()
	owner.start_use()
	owner.set_blocking(true)
	sender.pull(owner, wire)
	var watcher := ZzWeaponAnim.new()
	watcher.configure(&"longsword")
	var seq := ZzMedievalNet.apply(wire, watcher, 0)
	_check(seq == 1 and watcher.style == ZzWeaponPose.Style.SLASH_R, "a watcher plays the owner's swing")
	_check(watcher.blocking, "and sees the guard")
	_check(ZzMedievalNet.apply(wire, watcher, seq) == 1, "an unchanged counter replays nothing")
	for i in 17:
		owner.start_use()
	sender.pull(owner, wire)
	_check(ZzMedievalNet.uses_between(seq, int(wire.net_use_seq)) == 1, "seventeen swings wrap to one (the counter is four bits)")
	# A bow: draw travels as a level, the release as the counter.
	var archer := ZzWeaponAnim.new()
	archer.configure(&"bow")
	var bs := ZzMedievalNet.Sender.new()
	bs.attach(archer)
	var seen := ZzWeaponAnim.new()
	seen.configure(&"bow")
	var loosed := []
	seen.loosed.connect(func(c: float) -> void: loosed.append(c))
	archer.hold_draw(true)
	for f in 40:
		archer.advance(1.0 / 60.0)
	bs.pull(archer, wire)
	var s2 := ZzMedievalNet.apply(wire, seen, 0)
	for f in 40:
		seen.advance(1.0 / 60.0)
	_check(seen.draw > 0.5, "a watcher sees the string drawn (%.2f)" % seen.draw)
	archer.hold_draw(false)
	bs.pull(archer, wire)
	ZzMedievalNet.apply(wire, seen, s2)
	_check(loosed.size() == 1 and loosed[0] > 0.5, "and sees the arrow loosed at about the owner's draw (%s)" % [loosed])
	_check(ZzMedievalNet.describe(wire).has("draw"), "describe reports the draw")
	_end()


func _held() -> void:
	_begin("view and world models")
	var root := Node3D.new()
	add_child(root)
	for id in ZzMedievalConfig.IDS:
		for kind in 2:
			var h: ZzMedievalHeld = ZzMedievalViewModel.new() if kind == 0 else ZzMedievalWorldModel.new()
			root.add_child(h)
			h.spawn_flight = false
			h.bind(id)
			h.anim.start_use()
			h.step(0.2)
			var t := h.grip_transform()
			_check(t.origin.is_finite() and t.basis.is_finite(), "%s (%s) poses finitely" % [id, "view" if kind == 0 else "world"])
			_check(h.get_child_count() >= 7, "%s has grip and two arms" % id)
	var bow := ZzMedievalViewModel.new()
	root.add_child(bow)
	bow.spawn_flight = false
	bow.bind(&"bow")
	bow.step(0.01)
	var model := bow.find_child("bow", true, false)
	var own := model.find_child("string", true, false) as Node3D if model != null else null
	_check(model != null and (own == null or not own.visible), "the model's own string is hidden or absent")
	bow.anim.hold_draw(true)
	for f in 20:
		bow.step(1.0 / 60.0)
	var held_pull := bow.grip_transform().origin
	_check(held_pull.y > -0.1 and held_pull.x > -0.2, "a drawing bow is raised toward the aim line (%s)" % held_pull)
	var wm := ZzMedievalWorldModel.new()
	var vm := ZzMedievalViewModel.new()
	root.add_child(wm)
	root.add_child(vm)
	wm.bind(&"longsword")
	vm.bind(&"longsword")
	_check(wm.grip_transform().origin.y < vm.grip_transform().origin.y - 0.1, "a world model's hand hangs lower than the eye's")
	root.queue_free()
	_end()


func _flight() -> void:
	_begin("flight and impacts")
	var root := Node3D.new()
	add_child(root)
	var f := ZzProjectileFlight.launch(root, &"arrow", Transform3D(Basis(), Vector3(0, 2, 0)), 30.0, 1.0)
	f.mask = 0
	for i in 60:
		f.step(1.0 / 60.0)
	_check(f.global_position.z < -25.0, "an arrow flies forward (%s)" % f.global_position)
	_check(f.global_position.y < 2.0 - 4.0, "and drops under gravity (%s)" % f.global_position.y)
	var burst := ZzMedievalImpacts.burst(root, Vector3(1, 1, 1), Vector3.UP, &"steel")
	_check(burst.one_shot and burst.global_position.is_equal_approx(Vector3(1, 1, 1)), "a burst at the point")
	_check(ZzMedievalImpacts.colour(&"flesh") != ZzMedievalImpacts.colour(&"wood"), "surfaces look different")
	root.queue_free()
	_end()
