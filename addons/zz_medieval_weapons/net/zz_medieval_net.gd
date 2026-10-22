class_name ZzMedievalNet
extends RefCounted

## What has to travel so a watcher sees somebody else's sword swing, shield come up and string
## draw. [DotWeaponNetSync] carries the slot, the magazine and the reserve; none of that says
## "that player just swung", so this adds the picture's fields and a game concatenates the two
## spec lists ([method all_specs]), exactly as zee-dot-weapons does for guns. This is an
## independent minimal version: it duck-types the rig (reads `fire_seq`-style properties by
## name) and never names zee-dot-weapons, which this pack does not depend on.
##
## [b]A counter for the swing, levels for the stances.[/b] A swing is an event that is worthless
## late, so it is a four-bit counter inside the snapshot (a watcher who missed one sees it jump
## by two and plays one swing, the correct amount of wrong; [method uses_between] is wrap-aware
## because subtraction goes negative every sixteen swings). A raised guard, the draw and a
## crossbow mid-reload are held states, so they are levels the watcher eases toward.
##
## The draw is four bits (sixteen steps) because a watcher cannot read a finer string, and it
## is public: a drawn bow is visible to the room. Ammunition stays [DotWeaponNetSync]'s
## owner-only business.

const SEQ_BITS := 4
const SEQ_WRAP := 1 << SEQ_BITS
const DRAW_BITS := 4
const DRAW_MAX := (1 << DRAW_BITS) - 1


static func specs() -> Array[Dictionary]:
	return [
		{"property": &"net_use_seq", "type": "UINT", "bits": SEQ_BITS, "owner_only": false, "interpolated": false},
		{"property": &"net_use_style", "type": "UINT", "bits": ZzWeaponPose.STYLE_BITS, "owner_only": false, "interpolated": false},
		{"property": &"net_blocking", "type": "BOOL", "bits": 1, "owner_only": false, "interpolated": false},
		{"property": &"net_draw", "type": "UINT", "bits": DRAW_BITS, "owner_only": false, "interpolated": false},
		{"property": &"net_reloading", "type": "BOOL", "bits": 1, "owner_only": false, "interpolated": false},
	]


## dot-weapon's specs, then these. A game makes this one call.
static func all_specs() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append_array(DotWeaponNetSync.specs())
	out.append_array(specs())
	return out


static func estimated_bits() -> int:
	return DotWeaponNetSync.estimated_bits() + SEQ_BITS + ZzWeaponPose.STYLE_BITS + 1 + DRAW_BITS + 1


static func quantise_draw(fraction: float) -> int:
	return clampi(roundi(clampf(fraction, 0.0, 1.0) * DRAW_MAX), 0, DRAW_MAX)


static func dequantise_draw(bits: int) -> float:
	return float(clampi(bits, 0, DRAW_MAX)) / float(DRAW_MAX)


static func uses_between(previous: int, now: int) -> int:
	var d := (now - previous) % SEQ_WRAP
	return d + SEQ_WRAP if d < 0 else d


## The sending side's bookkeeping: counts uses off an animation so the host does not need a
## counter of its own. Hook [member ZzWeaponAnim.used] and [member ZzWeaponAnim.loosed] to
## [method note_use] and every swing and loose is counted, with the style that played.
class Sender extends RefCounted:
	var seq: int = 0
	var style: int = 0

	func attach(anim: ZzWeaponAnim) -> void:
		anim.used.connect(func(s: int) -> void: note_use(s))
		# Capture the style, not the animation: a lambda holding [param anim] would make the
		# animation own a callable that owns the animation, and neither would ever be freed.
		var loose_style: int = ZzWeaponPose.Style.FIRE if anim.id == &"crossbow" else ZzWeaponPose.Style.LOOSE
		anim.loosed.connect(func(_c: float) -> void: note_use(loose_style))

	func note_use(s: int) -> void:
		seq = (seq + 1) % ZzMedievalNet.SEQ_WRAP
		style = s

	## Writes the fields onto the replicating object, once a tick on the authority.
	func pull(anim: ZzWeaponAnim, target: Object) -> void:
		target.set(&"net_use_seq", seq)
		target.set(&"net_use_style", style)
		target.set(&"net_blocking", anim.blocking)
		target.set(&"net_draw", ZzMedievalNet.quantise_draw(anim.draw))
		target.set(&"net_reloading", anim.reloading)


## Plays what a snapshot says on a watcher's [param anim]. [param previous_seq] is the last
## counter this watcher saw; returns the new one, so this keeps no state and one function
## serves every player. A burst of uses between snapshots plays once, with the last style.
static func apply(source: Object, anim: ZzWeaponAnim, previous_seq: int) -> int:
	if source == null or anim == null:
		return previous_seq
	var seq := int(source.get(&"net_use_seq"))
	var n := uses_between(previous_seq, seq)
	anim.set_blocking(bool(source.get(&"net_blocking")))
	anim.set_draw(dequantise_draw(int(source.get(&"net_draw"))))
	var reloading := bool(source.get(&"net_reloading"))
	if reloading != anim.reloading:
		anim.set_reloading(reloading)
	if n > 0:
		var st := int(source.get(&"net_use_style"))
		if st == ZzWeaponPose.Style.LOOSE or st == ZzWeaponPose.Style.FIRE:
			anim.loose()
		else:
			anim.start_use(st)
	return seq


static func describe(source: Object) -> Dictionary:
	if source == null:
		return {}
	return {
		"use_seq": int(source.get(&"net_use_seq")),
		"style": String(ZzWeaponPose.style_name(int(source.get(&"net_use_style")))),
		"blocking": bool(source.get(&"net_blocking")),
		"draw": dequantise_draw(int(source.get(&"net_draw"))),
		"reloading": bool(source.get(&"net_reloading")),
	}
