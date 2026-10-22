class_name ZzWeaponAnim
extends RefCounted

## One weapon's animation state: which swing is playing and how far through it, whether the
## guard is up, how far the string is drawn, whether the crossbow is cocked. Pure state and
## time: it holds no nodes, so the same object drives a first-person view model, a
## third-person world model and a test, and a watcher's copy is stepped by what
## [ZzMedievalNet] says rather than by input.
##
## [b]It animates; it does not decide.[/b] Whether a swing happened, whether a hit landed and
## how much a draw was worth are the simulation's ([DotWeaponArsenal] and the game's damage
## path). A host calls [method start_use] when the arsenal's [code]used[/code] fires,
## [method set_blocking] while the guard key is held, [method hold_draw] while the bow's
## button is, [method set_reloading] from the arsenal, and [method hit] when a swing found
## something. Nothing here reads an input device.
##
## [b]Sound is a signal, not a player.[/b] [signal cue] names what should be heard
## ([code]swing_light[/code], [code]draw[/code], [code]bow_loose[/code], [code]block[/code], ...);
## the game maps the name to a sample. No recordings ship with the pack.

signal cue(name: StringName)
## A swing began. [param style] is a [enum ZzWeaponPose.Style].
signal used(style: int)
## The swing reached [constant ZzWeaponPose.STRIKE_AT]: the blade is where the hit is.
signal struck(style: int)
## An arrow or bolt left the weapon. [param charge] is the draw (1 for a crossbow).
signal loosed(charge: float)

var id: StringName = &""
var style: int = ZzWeaponPose.Style.NONE
var style_t: float = 0.0     ## seconds into the current swing
var style_dur: float = 0.0
var blocking: bool = false
var block: float = 0.0       ## guard blend, 0..1
var draw: float = 0.0        ## bow draw / crossbow cock, 0..1
var drawing: bool = false    ## the owner is holding the draw button
var nocked: bool = true      ## a bow has an arrow on the string
var loaded: bool = true      ## a crossbow has a bolt in the groove
var reloading: bool = false
var swings: int = 0          ## uses so far; picks the next style in the cycle

var swing_s: float = 0.6
var draw_s: float = 0.9
var load_s: float = 1.5
var min_charge: float = 0.3
var heft: float = 1.0

var _row: Dictionary = {}
var _struck_sent: bool = false
var _nock_wait: float = 0.0
var _load_t: float = 0.0
var _kick: float = 0.0
var _draw_full_sent: bool = false
var _net_draw: float = -1.0   ## a watcher's target; negative = this copy is the owner's


func configure(weapon_id: StringName, cfg: Dictionary = {}) -> void:
	id = weapon_id
	_row = ZzMedievalArtTable.row(id)
	if cfg.is_empty():
		cfg = ZzMedievalConfig.defaults().get(String(id), {})
	var rate := float(ZzMedievalConfig.TICK_RATE)
	swing_s = float(cfg.get("swing_ticks", 40)) / rate
	draw_s = float(cfg.get("draw_ticks", 58)) / rate
	load_s = float(cfg.get("reload_ticks", 96)) / rate
	min_charge = float(cfg.get("min_charge", 0.3))
	heft = float(_row.get("heft", 1.0))
	reset()


func reset() -> void:
	style = ZzWeaponPose.Style.NONE
	style_t = 0.0
	blocking = false
	block = 0.0
	draw = 0.0
	drawing = false
	nocked = true
	reloading = false
	loaded = true
	swings = 0
	_nock_wait = 0.0
	_kick = 0.0
	_net_draw = -1.0
	if ZzMedievalArtTable.has_string(id) and _row.get("projectile", "") == "bolt":
		draw = 1.0   # a crossbow starts cocked and loaded


func styles() -> Array:
	return _row.get("styles", [])


func is_swinging() -> bool:
	return style != ZzWeaponPose.Style.NONE


## Begins a swing. [param which] -1 takes the next style in the weapon's cycle, so repeated
## swings alternate the way a person's do. Returns the style played. A crossbow's FIRE and a
## bow's LOOSE go through [method loose], not here.
func start_use(which: int = -1, duration_s: float = 0.0) -> int:
	var list := styles()
	if which < 0:
		if list.is_empty():
			return ZzWeaponPose.Style.NONE
		which = int(list[swings % list.size()])
	swings += 1
	if which == ZzWeaponPose.Style.LOOSE or which == ZzWeaponPose.Style.FIRE:
		loose()
		return which
	style = which
	style_t = 0.0
	style_dur = duration_s if duration_s > 0.0 else swing_s
	_struck_sent = false
	used.emit(style)
	cue.emit(ZzMedievalArtTable.cue(id, &"bash" if style == ZzWeaponPose.Style.BASH else &"swing"))
	return style


func set_blocking(on: bool) -> void:
	if on and not blocking:
		cue.emit(&"guard_up")
	blocking = on


## The bow's button. Holding draws; letting go looses if the draw reached [member min_charge]
## and relaxes it otherwise (the arsenal refuses a short draw the same way).
func hold_draw(held: bool) -> void:
	if held and not drawing and nocked:
		cue.emit(&"draw")
		_draw_full_sent = false
	if not held and drawing:
		if draw >= min_charge:
			loose()
		else:
			cue.emit(&"draw_relax")
	drawing = held and nocked


## A watcher's draw, from the replicated fraction: the copy eases to it instead of timing its
## own, since the owner's button is not on this machine.
func set_draw(fraction: float) -> void:
	_net_draw = clampf(fraction, 0.0, 1.0)


func set_reloading(on: bool, duration_s: float = 0.0) -> void:
	if on and not reloading:
		reloading = true
		loaded = false
		_load_t = 0.0
		if duration_s > 0.0:
			load_s = duration_s
		cue.emit(&"reload_start")
	elif not on and reloading:
		# The simulation says the reload is over: snap to loaded rather than leave a
		# watcher's crossbow forever half-cocked after a missed snapshot.
		_finish_load()


## Looses the arrow or bolt: the string snaps forward, the hand kicks and the missile is
## announced to whoever draws it.
func loose() -> void:
	var charge := 1.0 if _row.get("projectile", "") == "bolt" else maxf(draw, _last_draw())
	_prev_draw = 0.0
	if _net_draw >= 0.0:
		_net_draw = 0.0
	loosed.emit(charge)
	cue.emit(&"bolt_fire" if _row.get("projectile", "") == "bolt" else &"bow_loose")
	_kick = 1.0
	drawing = false
	if _row.get("projectile", "") == "bolt":
		draw = 0.0
		loaded = false
	else:
		draw = 0.0
		nocked = false
		_nock_wait = 0.32
	style = ZzWeaponPose.Style.NONE
	style_t = 0.0


## The swing found something: the weapon recoils off it and a hit is heard. [param surface]
## names what was hit (default the weapon's own cue).
func hit(surface: StringName = &"flesh") -> void:
	_kick = 0.7
	cue.emit(StringName("hit_" + String(surface)))


## Pins the animation to a swing at phase [param t], for a still image or a test; the next
## [method advance] carries on from there.
func force(which: int, t: float) -> void:
	style = which
	style_dur = swing_s
	style_t = t * style_dur
	_struck_sent = true


var _prev_draw: float = 0.0

func _last_draw() -> float:
	return _prev_draw


func advance(dt: float) -> void:
	# Guard blend. A guard is a stance, so it eases rather than snaps.
	block = move_toward(block, 1.0 if blocking else 0.0, dt * 7.0)

	if is_swinging():
		style_t += dt
		var t := style_t / maxf(style_dur, 0.001)
		if not _struck_sent and t >= ZzWeaponPose.STRIKE_AT:
			_struck_sent = true
			struck.emit(style)
		if t >= 1.0:
			style = ZzWeaponPose.Style.NONE
			style_t = 0.0

	_kick = move_toward(_kick, 0.0, dt * 4.0)

	var is_bow: bool = _row.get("projectile", "") == "arrow"
	if is_bow:
		_prev_draw = maxf(draw, 0.0) if draw > 0.0 else _prev_draw
		if _net_draw >= 0.0:
			draw = move_toward(draw, _net_draw, dt * 6.0)
		elif drawing:
			draw = minf(1.0, draw + dt / maxf(draw_s, 0.01))
			if draw >= 1.0 and not _draw_full_sent:
				_draw_full_sent = true
				cue.emit(&"draw_full")
		else:
			draw = move_toward(draw, 0.0, dt * 4.0)
		if not nocked:
			_nock_wait -= dt
			if _nock_wait <= 0.0:
				nocked = true
				cue.emit(&"nock")
	elif ZzMedievalArtTable.has_string(id):
		if reloading:
			_load_t += dt
			draw = clampf(_load_t / maxf(load_s * 0.8, 0.01), 0.0, 1.0)
			if _load_t >= load_s:
				_finish_load()
		elif loaded:
			draw = move_toward(draw, 1.0, dt * 3.0)


func _finish_load() -> void:
	reloading = false
	loaded = true
	draw = 1.0
	cue.emit(&"reload_done")


## The hand's pose now: {pos, rot, string_pull, nock, loaded, off_string, block}. Offsets from
## the rest pose in the aim frame; the host adds them to [code]rest[/code] and [code]hold[/code].
func pose() -> Dictionary:
	var pos := Vector3.ZERO
	var rot := Vector3.ZERO
	if is_swinging():
		var s := ZzWeaponPose.sample(style, style_t / maxf(style_dur, 0.001), heft)
		pos = s["pos"]
		rot = s["rot"]
	var is_bow: bool = _row.get("projectile", "") == "arrow"
	var off_string := 0.0
	if is_bow:
		# The bow is raised to the eye and the arm extended as the string comes back.
		var aim := smoothstep(0.0, 0.25, draw)
		pos += ZzWeaponPose.AIM_POS * aim
		rot += ZzWeaponPose.AIM_ROT * aim
		off_string = smoothstep(0.0, 0.12, draw)
		if not nocked:
			off_string = 0.0
	elif ZzMedievalArtTable.has_string(id):
		if reloading:
			var p := clampf(_load_t / maxf(load_s, 0.01), 0.0, 1.0)
			var lift := minf(p * 6.0, (1.0 - p) * 6.0)
			lift = clampf(lift, 0.0, 1.0)
			pos += Vector3(0.0, 0.07, 0.12) * lift
			rot += Vector3(28, 0, 0) * lift
			off_string = clampf(minf(p, 1.0 - p) * 8.0, 0.0, 1.0)
	if block > 0.0:
		var g: Dictionary = _row.get("block", {"pos": ZzWeaponPose.GUARD_POS, "rot": ZzWeaponPose.GUARD_ROT})
		var w := smoothstep(0.0, 1.0, block)
		pos = pos.lerp((g["pos"] as Vector3) + pos * 0.25, w)
		rot = rot.lerp((g["rot"] as Vector3) + rot * 0.25, w)
	if _kick > 0.0:
		# A hit or a loose: back and up, decaying.
		pos += Vector3(0.0, 0.02, 0.08) * _kick
		rot += Vector3(6.0, 0.0, 0.0) * _kick
	return {
		"pos": pos, "rot": rot, "string_pull": draw, "nock": nocked if is_bow else loaded,
		"off_string": off_string, "block": block,
	}


func describe() -> Dictionary:
	return {
		"id": String(id), "style": String(ZzWeaponPose.style_name(style)),
		"t": snappedf(style_t / maxf(style_dur, 0.001), 0.01), "blocking": blocking,
		"draw": snappedf(draw, 0.01), "nocked": nocked, "loaded": loaded,
		"reloading": reloading,
	}
