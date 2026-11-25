class_name ZzWeaponAnim
extends RefCounted

## One weapon's animation state (swing, guard, string draw, crossbow cocked): pure state and time, no nodes,
## so one object drives a view model, a world model and a test. [b]It animates; it does not decide[/b]: the
## simulation owns hits. Sound is a signal, not a player: [signal cue] names what to hear for [ZzMedievalHeld].

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

var inspecting: bool = false ## the owner is looking the weapon over (a look pose, no net state)
var holstered: float = 0.0   ## 0 = in hand, 1 = stowed (eased toward [member _holster_to])
var inspect_s: float = 2.4
var holster_s: float = 0.45

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
var _inspect_t: float = 0.0
var _holster_to: float = 0.0
var _bolt_laid: bool = false

## Every keyed style holds its strike to [constant RECOVER_FROM] and returns to rest by 1.0. A quick weapon's swing
## (a dagger's is 0.31 s) would make that return a one-frame snap, so on screen it takes at least [constant RECOVER_S]:
## the pose runs on after the swing itself has ended (the swing's timing, strike and next use are unchanged).
const RECOVER_FROM := 0.70
const RECOVER_S := 0.45
var _settle_style: int = ZzWeaponPose.Style.NONE
var _settle_t: float = 0.0
var _settle_dur: float = 0.0


func configure(weapon_id: StringName, cfg: Dictionary = {}) -> void:
	id = weapon_id
	_row = ZzMedievalArtTable.row(id)
	if cfg.is_empty():
		cfg = ZzMedievalConfig.load_all().get(String(id), {})
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
	_settle_style = ZzWeaponPose.Style.NONE
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
	inspecting = false
	_inspect_t = 0.0
	holstered = 0.0
	_holster_to = 0.0
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
	if _holster_to > 0.0:
		return ZzWeaponPose.Style.NONE   # a stowed weapon is not swung
	inspecting = false
	swings += 1
	if which == ZzWeaponPose.Style.LOOSE or which == ZzWeaponPose.Style.FIRE:
		loose()
		return which
	style = which
	style_t = 0.0
	_settle_style = ZzWeaponPose.Style.NONE
	style_dur = duration_s if duration_s > 0.0 else swing_s
	_struck_sent = false
	used.emit(style)
	cue.emit(ZzMedievalArtTable.cue(id, &"bash" if style == ZzWeaponPose.Style.BASH else &"swing"))
	return style


## Starts the look-over: the weapon is raised and turned in the hand. Refused while swinging, guarding, drawing, reloading or stowed;
## returns whether it started. Any use, guard or holster cancels it.
func inspect() -> bool:
	if inspecting or is_swinging() or blocking or drawing or reloading or _holster_to > 0.0:
		return false
	inspecting = true
	_inspect_t = 0.0
	cue.emit(ZzMedievalArtTable.cue(id, &"inspect"))
	return true


## Fraction through the look-over, 0..1 (0 when not inspecting).
func inspect_phase() -> float:
	return clampf(_inspect_t / maxf(inspect_s, 0.01), 0.0, 1.0) if inspecting else 0.0


## Puts the weapon away (true) or brings it out (false). Stowing cancels a look-over and a draw.
func holster(on: bool) -> void:
	if on == (_holster_to > 0.0):
		return
	_holster_to = 1.0 if on else 0.0
	if on:
		inspecting = false
		_inspect_t = 0.0
		drawing = false
		blocking = false
	cue.emit(ZzMedievalArtTable.cue(id, &"holster" if on else &"unholster"))


func set_blocking(on: bool) -> void:
	if on and not blocking:
		cue.emit(&"guard_up")
		inspecting = false
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
		_bolt_laid = false
		inspecting = false
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
		_follow = 0.28
	style = ZzWeaponPose.Style.NONE
	style_t = 0.0
	_settle_style = ZzWeaponPose.Style.NONE


## The swing found something: the weapon recoils off it and a hit is heard. [param surface]
## names what was hit (default the weapon's own cue).
func hit(surface: StringName = &"flesh") -> void:
	_kick = 0.7
	cue.emit(StringName("hit_" + String(surface)))


## Pins the animation to a swing at phase [param t], for a still image or a test; the next
## [method advance] carries on from there.
func force(which: int, t: float) -> void:
	style = which
	_settle_style = ZzWeaponPose.Style.NONE
	style_dur = swing_s
	style_t = t * style_dur
	_struck_sent = true


var _prev_draw: float = 0.0
var _aim: float = 0.0        ## how far the bow is raised to the eye, eased so a loose follows through
var _off: float = 0.0        ## the draw hand's pull toward the string, eased so it leaves the string, not teleports
var _follow: float = 0.0     ## seconds the bow stays up after a loose

## How far a bow is raised to the eye, 0..1 (0 for anything else).
func aim_weight() -> float:
	return _aim


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
			_settle_style = style
			_settle_t = style_t
			_settle_dur = style_dur
			style = ZzWeaponPose.Style.NONE
			style_t = 0.0
	elif _settle_style != ZzWeaponPose.Style.NONE:
		_settle_t += dt
		if _visual_phase(_settle_t, _settle_dur) >= 1.0:
			_settle_style = ZzWeaponPose.Style.NONE

	_kick = move_toward(_kick, 0.0, dt * 4.0)
	holstered = move_toward(holstered, _holster_to, dt / maxf(holster_s, 0.01))
	if inspecting:
		_inspect_t += dt
		if _inspect_t >= inspect_s:
			inspecting = false
			_inspect_t = 0.0

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
		# The bow comes up with the draw at once, holds through the loose, then settles.
		var aim_to := smoothstep(0.0, 0.25, draw)
		_follow = maxf(_follow - dt, 0.0)
		if aim_to >= _aim:
			_aim = aim_to
		elif _follow <= 0.0:
			_aim = move_toward(_aim, aim_to, dt * 2.2)
		var off_to := smoothstep(0.0, 0.12, draw) if nocked else 0.0
		_off = off_to if off_to >= _off else move_toward(_off, off_to, dt * 3.0)
		if not nocked:
			_nock_wait -= dt
			if _nock_wait <= 0.0:
				nocked = true
				cue.emit(&"nock")
	elif ZzMedievalArtTable.has_string(id):
		if reloading:
			_load_t += dt
			if not _bolt_laid and _load_t >= load_s * 0.82:
				_bolt_laid = true
				cue.emit(&"bolt_laid")
			draw = clampf(_load_t / maxf(load_s * 0.8, 0.01), 0.0, 1.0)
			if _load_t >= load_s:
				_finish_load()
		elif loaded:
			draw = move_toward(draw, 1.0, dt * 3.0)


## The pose's phase [param t] seconds into a swing of [param dur]: the swing's own phase up to [constant RECOVER_FROM],
## then the return to rest spread over at least [constant RECOVER_S].
func _visual_phase(t: float, dur: float) -> float:
	dur = maxf(dur, 0.001)
	var hold := RECOVER_FROM * dur
	if t <= hold:
		return t / dur
	var back := maxf((1.0 - RECOVER_FROM) * dur, RECOVER_S)
	return minf(RECOVER_FROM + (1.0 - RECOVER_FROM) * (t - hold) / back, 1.0)


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
	if is_swinging() or _settle_style != ZzWeaponPose.Style.NONE:
		var swinging := is_swinging()
		var s := ZzWeaponPose.sample(style if swinging else _settle_style,
				_visual_phase(style_t if swinging else _settle_t, style_dur if swinging else _settle_dur), heft)
		pos = s["pos"]
		rot = s["rot"]
	var is_bow: bool = _row.get("projectile", "") == "arrow"
	var off_string := 0.0
	if is_bow:
		# The bow is raised to the eye and the arm extended as the string comes back.
		# The row's `aim` puts the nock at the cheek under the eye at full draw.
		var a: Dictionary = _row.get("aim", {})
		pos += (a.get("pos", ZzWeaponPose.AIM_POS) as Vector3) * _aim
		rot += (a.get("rot", ZzWeaponPose.AIM_ROT) as Vector3) * _aim
		off_string = _off
	elif ZzMedievalArtTable.has_string(id):
		if reloading:
			# Foot in the stirrup (the stock tips up and toward the body), the string worked back in the middle with a small rock
			# for each pull of the hand, then the stock levels while the bolt is laid in the groove.
			var p := clampf(_load_t / maxf(load_s, 0.01), 0.0, 1.0)
			var up := smoothstep(0.0, 0.14, p) * (1.0 - smoothstep(0.84, 1.0, p))
			var crank := sin(p * TAU * 3.0) * smoothstep(0.14, 0.3, p) * (1.0 - smoothstep(0.62, 0.8, p))
			pos += Vector3(0.0, 0.07, 0.12) * up + Vector3(0.0, 0.0, 0.025) * crank
			rot += Vector3(34, 0, 0) * up + Vector3(0, 0, 5) * crank
			if p > 0.62:
				rot += Vector3(-16, 0, 8) * smoothstep(0.62, 0.8, p) * (1.0 - smoothstep(0.84, 1.0, p))   # tilt to lay the bolt
			off_string = clampf(minf(p, 1.0 - p) * 8.0, 0.0, 1.0)
	if block > 0.0:
		var g: Dictionary = _row.get("block", {"pos": ZzWeaponPose.GUARD_POS, "rot": ZzWeaponPose.GUARD_ROT})
		var w := smoothstep(0.0, 1.0, block)
		pos = pos.lerp((g["pos"] as Vector3) + pos * 0.25, w)
		rot = rot.lerp((g["rot"] as Vector3) + rot * 0.25, w)
	if inspecting:
		# Raised toward the eye, turned over one way and back (both faces seen), and tipped to show the head, then lowered.
		var ph := inspect_phase()
		var env := smoothstep(0.0, 0.18, ph) * (1.0 - smoothstep(0.82, 1.0, ph))
		pos += Vector3(-0.10, 0.12, 0.10) * env
		rot += Vector3(-24.0 * env + 10.0 * sin(ph * TAU * 2.0) * env, 90.0 * sin(ph * TAU) * env, 14.0 * sin(ph * TAU * 2.0) * env)
	if holstered > 0.0:
		var h := smoothstep(0.0, 1.0, holstered)
		pos += Vector3(0.12, -0.42, 0.10) * h
		rot += Vector3(-55.0, 0.0, 25.0) * h
	if _kick > 0.0:
		# A hit or a loose: back and up, decaying.
		pos += Vector3(0.0, 0.02, 0.08) * _kick
		rot += Vector3(6.0, 0.0, 0.0) * _kick
	return {
		# A crossbow's bolt shows from the moment it is laid in the groove, before the reload finishes.
		"pos": pos, "rot": rot, "string_pull": draw, "nock": nocked if is_bow else (loaded or (reloading and _bolt_laid)),
		"off_string": off_string, "block": block, "inspect": inspect_phase(), "holstered": holstered,
	}


func describe() -> Dictionary:
	return {
		"id": String(id), "style": String(ZzWeaponPose.style_name(style)),
		"t": snappedf(style_t / maxf(style_dur, 0.001), 0.01), "blocking": blocking,
		"draw": snappedf(draw, 0.01), "nocked": nocked, "loaded": loaded,
		"reloading": reloading, "inspecting": inspecting, "holstered": snappedf(holstered, 0.01),
	}
