extends Node

## The first half of zz_selftest: the section counters and helpers every section shares, and
## the checks on how a weapon is held and moves: the art table, poses, swings, bow and crossbow
## draws, the held model, arrows in flight and sound. The scene script has the rest.

var _entered := 0
var _finished := 0
var _checks := 0
var _failures := 0
var _section := ""


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


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()


func _root(name: String) -> String:
	return OS.get_temp_dir().path_join("zz_prof_%s_%d" % [name, Time.get_ticks_usec()])


func _event(out: DotWeaponOutcome, type: String) -> Variant:
	for e in out.events:
		if e.get("type") == type:
			return e
	return null


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
	# Low anchor: the grip comes up to just under the eye line, about -0.10.
	_check(held_pull.y > -0.13 and held_pull.x > -0.2, "a drawing bow is raised toward the aim line (%s)" % held_pull)
	var wm := ZzMedievalWorldModel.new()
	var vm := ZzMedievalViewModel.new()
	root.add_child(wm)
	root.add_child(vm)
	wm.bind(&"longsword")
	vm.bind(&"longsword")
	_check(wm.grip_transform().origin.y < vm.grip_transform().origin.y - 0.1, "a world model's hand hangs lower than the eye's")
	root.free()
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
	root.free()
	_end()


func _sound() -> void:
	_begin("sound cues")
	var missing: PackedStringArray = []
	for cue in ZzMedievalSound.CUES:
		if DotWeaponSound.count(ZzMedievalSound.CUES[cue]) == 0:
			missing.append(String(cue))
	_check(missing.is_empty(), "every cue has stock files: %s" % ", ".join(missing))
	var silent_ok := true
	for id: StringName in ZzMedievalArtTable.rows():
		var heard: Array[StringName] = [ZzMedievalArtTable.cue(id, &"swing"), ZzMedievalArtTable.cue(id, &"bash"), ZzMedievalArtTable.cue(id, &"hit")]
		for c in heard:
			if ZzMedievalSound.stream_for(c, id) == null:
				silent_ok = false
				print("  silent cue %s for %s" % [c, id])
	for c: StringName in [&"draw", &"draw_full", &"bow_loose", &"bolt_fire", &"reload_start", &"reload_done", &"hit_flesh", &"hit_wood", &"hit_steel", &"hit_stone"]:
		if ZzMedievalSound.stream_for(c) == null:
			silent_ok = false
			print("  silent cue %s" % c)
	_check(silent_ok, "every swing, bash, hit and draw cue of every weapon plays a stock sound")
	for c in ZzMedievalSound.SILENT:
		_check(not ZzMedievalSound.CUES.has(c), "%s is declared silent and has no sound" % c)
	var shared := DotWeaponSound.check_unique()
	_check(shared.is_empty(), "no two sound classes share a recording: %s" % "; ".join(shared))
	_end()
