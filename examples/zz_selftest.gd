extends "res://examples/selftest/zz_motion_checks.gd"

## The headless suite. Counts sections entered against sections finished and a total of checks,
## so a script error that aborts a section cannot report "0 failed" with checks missing.
## What it cannot see is how the weapons look: `tools/screenshot.sh`.

const CHECKS := 464


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
	_weapon_art_hook()
	_model_lookup()
	_model_upright()
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
	_sound()
	print("%d sections entered, %d finished, %d checks (expected %d), %d failed" % [_entered, _finished, _checks, CHECKS, _failures])
	if _entered != _finished or _checks != CHECKS:
		_failures += 1
		print("FAIL: sections or check count do not match")
	get_tree().quit(1 if _failures > 0 else 0)


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


func _weapon_art_hook() -> void:
	_begin("weapon_art hook")
	var paths := ZzMedievalSpawnProvider.model_paths()
	_check(paths.size() == ZzMedievalConfig.IDS.size(), "model_paths names every weapon id")
	for id in ZzMedievalConfig.IDS:
		var scene := load(String(paths.get(id, ""))) as PackedScene
		var node := scene.instantiate() if scene != null else null
		_check(node != null and not node.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s: its model path loads as a scene with a mesh" % id)
		if node != null:
			node.free()
	var art := ZzMedievalSpawnProvider.weapon_art()
	# zee-dot-weapons is not a dependency: without it the hook answers nothing, with it one art per id on this pack's models.
	var zee := ProjectSettings.get_global_class_list().any(func(e: Dictionary) -> bool: return e.get("class", "") == "ZeeWeaponArt")
	_check(art.size() == (ZzMedievalConfig.IDS.size() if zee else 0), "without zee the hook is empty, with it one art per weapon id")
	var ids_ok := true
	for a: Resource in art:
		ids_ok = ids_ok and paths.get(a.get(&"id"), "") == a.get(&"model_path")
	_check(ids_ok, "every art carries the pack's model for its id")
	_end()


## Every melee model stands along +Y with its grip at the origin once built (the dagger and mace glbs are modelled leaning).
func _model_upright() -> void:
	_begin("models stand upright in the hand")
	for id in [&"longsword", &"dagger", &"mace", &"battle_axe", &"war_axe", &"double_axe", &"spear"]:
		var n := ZzMedievalModels.build(id)
		var lo := Vector3(INF, INF, INF)
		var hi := -lo
		for m in n.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			var xf := n.transform * mi.transform
			for s in mi.mesh.get_surface_count():
				for v: Vector3 in mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
					var p := xf * v
					lo = lo.min(p)
					hi = hi.max(p)
		var size := hi - lo
		var wide := maxf(size.x, size.z)
		_check(size.y > 2.0 * wide, "%s: more than twice as long along +Y as across (%s)" % [id, size])
		_check(lo.y < 0.0 and hi.y > 0.3, "%s: the grip (origin) lies between its butt and its head" % id)
		if id == &"mace" or id == &"dagger":
			var row := ZzMedievalArtTable.row(id)
			var s := float(row.get("scale", 1.0))
			_check(size.y * s > 0.3 and size.y * s < 0.9, "%s: %.2f m long in the hand" % [id, size.y * s])
		n.free()
	_end()


## The model lookup finds the glbs for a project, a mounted pack and an addon that is only symlinked into a game.
func _model_lookup() -> void:
	_begin("model lookup")
	var mounted := ZzMedievalModels.asset_dirs("res://game/addons/zz_medieval_weapons/art/zz_medieval_models.gd", func(_d: String) -> String: return "")
	_check(mounted == ["res://game/assets/", "res://assets/"], "a mounted pack: <prefix>/assets/, then res://assets/ (%s)" % [mounted])
	var linked := ZzMedievalModels.asset_dirs("res://addons/zz_medieval_weapons/art/zz_medieval_models.gd", func(d: String) -> String:
		return "/opt/packs/zz-medieval-weapons/addons/zz_medieval_weapons" if d == "res://addons/zz_medieval_weapons" else "")
	_check(linked == ["res://assets/", "/opt/packs/zz-medieval-weapons/assets/"], "a linked addon: also the assets beside the link target (%s)" % [linked])
	var plain := ZzMedievalModels.asset_dirs("res://addons/zz_medieval_weapons/art/zz_medieval_models.gd", func(_d: String) -> String: return "")
	_check(plain == ["res://assets/"], "an addon in the project itself: just res://assets/ (%s)" % [plain])

	# A real symlink: user://<tmp>/addons/zz_medieval_weapons -> this project's addon dir; the link is followed, and a glb that is
	# only reachable through it (an absolute path outside res://) is read at run time.
	var tmp := ProjectSettings.globalize_path("user://link_check")
	DirAccess.make_dir_recursive_absolute(tmp.path_join("addons"))
	var link := tmp.path_join("addons/zz_medieval_weapons")
	var target := ProjectSettings.globalize_path("res://addons/zz_medieval_weapons")
	if not FileAccess.file_exists(link) and not DirAccess.dir_exists_absolute(link):
		OS.execute("ln", ["-s", target, link])
	if DirAccess.dir_exists_absolute(link):
		_check(ZzMedievalModels._resolve_link("res://addons/zz_medieval_weapons") == "", "a real directory is not a link")
		var real := ZzMedievalModels.asset_dirs("res://addons/zz_medieval_weapons/art/zz_medieval_models.gd", func(_d: String) -> String: return _link_target(link))
		_check(real.back() == ProjectSettings.globalize_path("res://assets/"), "a symlink resolves to the checkout's assets/ (%s)" % [real])
		var read := ZzMedievalModels._read_glb(real.back() + "mace.glb")
		_check(read != null and not read.find_children("*", "MeshInstance3D", true, false).is_empty(), "a glb outside res:// reads as a scene with a mesh")
		if read != null:
			read.free()
		OS.execute("rm", [link])
	else:
		print("  (no symlink support here: the real-link checks are skipped)")
	_end()


static func _link_target(link: String) -> String:
	var dir := DirAccess.open(link.get_base_dir())
	return dir.read_link(link) if dir != null and dir.is_link(link) else ""


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


