extends GSGameVisualQaCapture

## The visual QA capture of the medieval weapons, on gs-game's shared tool (gs-game docs/visual-qa.md): each weapon's clips from
## the first-person camera (the view model and arms), behind-right and an opponent in front (a plain person holding the same
## weapon as a [ZzMedievalWorldModel], as everybody else sees it). Run through tools/visual_qa_shot.sh.
##
## Layers: the view model draws on 1 << 17 (hidden from the outside cameras by the shared views), the person and its weapon on
## BODY_LAYER, which the first-person camera does not draw.

const BODY_LAYER := 1 << 18
const VIEW_LAYER := 1 << 17
const STEP_SWING := 1.0

var _view: ZzMedievalViewModel = null
var _world: ZzMedievalWorldModel = null
var _person: Node3D = null
var _figure: GSHumanoidFigure = null
var _arms: ZzMedievalFigureArms = null
var _holder: Node3D = null
var _id: StringName = &""
var _done: Dictionary = {}
var _primed := false


func _items() -> PackedStringArray:
	var ids := PackedStringArray()
	for id in ZzMedievalConfig.IDS:
		ids.append(String(id))
	return ids


func _clips(item: String) -> PackedStringArray:
	var main := "swing"
	match item:
		"bow":
			main = "draw_loose"
		"crossbow":
			main = "fire_reload"
	var clips := PackedStringArray([main])
	if item != "bow" and item != "crossbow":
		clips.append("block")
	clips.append("inspect")
	clips.append("holster")
	return clips


func _build() -> void:
	build_stage()
	first_person.cull_mask = 0xFFFFF & ~BODY_LAYER
	_view = ZzMedievalViewModel.new()
	_view.flight_parent = stage
	first_person.add_child(_view)
	_view.set_process(false)
	_person = Node3D.new()
	_person.name = "Person"
	stage.add_child(_person)
	# A real person (gs-player-char's figure), not a capsule; its arms reach the weapon's hands (ZzMedievalFigureArms).
	_figure = GSHumanoidFigure.new()
	_figure.name = "Figure"
	_figure.auto_animate = false
	_person.add_child(_figure)
	_figure.build(GSHumanoidLook.stock(0), 1.8)
	_arms = ZzMedievalFigureArms.new()
	_person.add_child(_arms)
	_holder = Node3D.new()
	_holder.position = Vector3(0.0, 1.45, 0.0)
	_person.add_child(_holder)


func _subject(_item: String) -> Node3D:
	return _person


func _seconds(item: String, clip: String) -> float:
	match clip:
		"swing":
			return 0.3 + STEP_SWING * float(maxi(2, ZzMedievalArtTable.row(StringName(item))["styles"].size()))
		"block":
			return 1.8
		"draw_loose":
			return 3.0
		"fire_reload":
			return 3.8
		"inspect":
			return _view.anim.inspect_s + 0.3 if _view != null else 2.7
	return 1.8


func _warmup_frames(_item: String, _clip: String) -> int:
	return 6


func _stage(item: String, _clip: String) -> GSResult:
	_id = StringName(item)
	if ZzMedievalArtTable.row(_id).is_empty():
		return GSResult.fail(GSError.CODE_UNSUPPORTED, "no art for %s" % item)
	for flight in stage.get_children():
		if flight is ZzProjectileFlight:
			flight.free()
	if _world != null:
		_world.free()
	_world = ZzMedievalWorldModel.new()
	_world.spawn_flight = false
	_world.play_builtin_sounds = false
	_holder.add_child(_world)
	_world.set_process(false)
	_view.play_builtin_sounds = false
	_world.bind(_id)
	_arms.bind(_figure, _world)
	_view.bind(_id)
	_view.step(0.0)
	_world.step(0.0)
	_done.clear()
	_primed = false
	return GSResult.success(0)


## Runs [param key] once when t passes [param at].
func _once(key: String, at: float, t: float) -> bool:
	if t >= at and not _done.has(key):
		_done[key] = true
		return true
	return false


func _both(call: Callable) -> void:
	call.call(_view.anim)
	call.call(_world.anim)


func _drive(item: String, clip: String, t: float, frame: int) -> void:
	# The capture drives frame 0 twice (once to prime the outside views); step once.
	if frame == 0 and _primed:
		return
	_primed = true
	var dt := 1.0 / float(fps)
	if frame == 0:
		dt = 0.0
	match clip:
		"swing":
			var n := maxi(2, ZzMedievalArtTable.row(StringName(item))["styles"].size())
			for k in n:
				if _once("swing%d" % k, 0.1 + STEP_SWING * float(k), t):
					_both(func(a: ZzWeaponAnim) -> void: a.start_use())
		"block":
			if _once("block", 0.1, t):
				_both(func(a: ZzWeaponAnim) -> void: a.set_blocking(true))
			if _once("hit", 0.8, t):
				_both(func(a: ZzWeaponAnim) -> void: a.hit(&"wood"))
			if _once("unblock", 1.4, t):
				_both(func(a: ZzWeaponAnim) -> void: a.set_blocking(false))
		"draw_loose":
			if _once("draw", 0.1, t):
				_both(func(a: ZzWeaponAnim) -> void: a.hold_draw(true))
			if _once("loose", 1.7, t):
				_both(func(a: ZzWeaponAnim) -> void: a.hold_draw(false))
		"fire_reload":
			if _once("fire", 0.1, t):
				_both(func(a: ZzWeaponAnim) -> void: a.start_use())
			if _once("reload", 0.7, t):
				_both(func(a: ZzWeaponAnim) -> void: a.set_reloading(true))
		"inspect":
			if _once("inspect", 0.1, t):
				_both(func(a: ZzWeaponAnim) -> void: a.inspect())
		"holster":
			if _once("holster", 0.3, t):
				_both(func(a: ZzWeaponAnim) -> void: a.holster(true))
			if _once("draw_out", 1.3, t):
				_both(func(a: ZzWeaponAnim) -> void: a.holster(false))
	_view.step(dt)
	_world.step(dt)
	for n in stage.get_children():
		if n is ZzProjectileFlight:
			(n as ZzProjectileFlight).step(dt)


func _before_draw(_item: String, _clip: String, _frame: int) -> void:
	var _a := GSGameVisualQaViews.tag_layers(_view, VIEW_LAYER)
	var _b := GSGameVisualQaViews.tag_layers(_person, BODY_LAYER)


## Eyes at 1.6 m, looking straight out: the view model hangs off this camera.
func _place_first_person(_item: String) -> void:
	first_person.global_position = _person.global_position + Vector3(0.0, 1.6, 0.0)
	first_person.global_rotation = Vector3.ZERO
