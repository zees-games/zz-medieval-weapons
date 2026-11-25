class_name ZzWeaponPose
extends RefCounted

## The hand's motion for each use, as pure functions of time: offsets from the rest pose in the aim frame
## (x right, y up, -z forward; metres, degrees). A pose never names a weapon; [member ZzMedievalArtTable]
## scales it. Phases are fractions of the swing because duration is the weapon's; the strike lands at [constant STRIKE_AT].

enum Style { NONE, SLASH_R, SLASH_L, OVERHEAD, THRUST, BASH, LOOSE, FIRE }

## Four bits would do; three carry every style and are what [ZzMedievalNet] sends.
const STYLE_BITS := 3

const STRIKE_AT := 0.45

## Keyframes: [t, pos, rot_degrees], joined by a monotone cubic ([method _hermite]).
const _SLASH_R := [
	[0.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[0.32, Vector3(0.20, 0.12, 0.10), Vector3(42, 0, -58)],
	[0.45, Vector3(-0.02, 0.02, -0.12), Vector3(5, 0, 0)],
	[0.55, Vector3(-0.32, -0.14, -0.30), Vector3(-45, 0, 62)],
	[0.70, Vector3(-0.36, -0.16, -0.30), Vector3(-50, 0, 68)],
	[1.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
]
const _OVERHEAD := [
	[0.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[0.34, Vector3(0.02, 0.30, 0.14), Vector3(92, 0, -4)],
	[0.45, Vector3(0.0, 0.20, -0.05), Vector3(30, 0, 0)],
	[0.55, Vector3(0, -0.24, -0.38), Vector3(-72, 0, 0)],
	[0.70, Vector3(0, -0.26, -0.38), Vector3(-76, 0, 0)],
	[1.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
]
const _THRUST := [
	[0.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[0.34, Vector3(0.04, -0.02, 0.28), Vector3(12, 0, -4)],
	[0.45, Vector3(0.02, 0.0, -0.20), Vector3(-6, 0, 0)],
	[0.55, Vector3(0, 0.03, -0.62), Vector3(-14, 0, 2)],
	[0.70, Vector3(0, 0.03, -0.64), Vector3(-14, 0, 2)],
	[1.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
]
## A shield bash: the whole shield shoved at the target.
const _BASH := [
	[0.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[0.32, Vector3(0.10, -0.04, 0.22), Vector3(8, 18, 0)],
	[0.45, Vector3(0.0, 0.0, -0.18), Vector3(-4, 4, 0)],
	[0.55, Vector3(-0.10, 0.08, -0.52), Vector3(-10, -16, 0)],
	[0.70, Vector3(-0.10, 0.08, -0.54), Vector3(-10, -16, 0)],
	[1.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
]
## Loosing a bow and firing a crossbow are a kick, not a swing: the carrier already holds the
## aim, so the hand only jumps back and settles.
const _KICK := [
	[0.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
	[0.12, Vector3(0.0, 0.01, 0.06), Vector3(5, 0, 0)],
	[0.35, Vector3(0.0, 0.0, 0.02), Vector3(1.5, 0, 0)],
	[1.00, Vector3(0, 0, 0), Vector3(0, 0, 0)],
]

## The guard: the weapon is brought across the body and held there. Per weapon it is
## overridden by the art table's [code]block[/code] entry (a shield covers the face; a sword
## parries).
const GUARD_POS := Vector3(-0.20, 0.22, -0.05)
const GUARD_ROT := Vector3(35, 0, 30)

## The hand's pose while drawing a bow: the weapon rises to the eye line and the arm extends.
const AIM_POS := Vector3(0.18, 0.22, -0.16)
const AIM_ROT := Vector3(0, 0, 0)


static func keys(style: int) -> Array:
	match style:
		Style.SLASH_R: return _SLASH_R
		Style.SLASH_L: return _SLASH_R
		Style.OVERHEAD: return _OVERHEAD
		Style.THRUST: return _THRUST
		Style.BASH: return _BASH
		Style.LOOSE, Style.FIRE: return _KICK
	return []


## The swing's offset at phase [param t] (0..1) as {pos: Vector3, rot: Vector3}. A left slash
## is the right one mirrored: x position flips, and the roll (Z) and yaw (Y) flip with it.
static func sample(style: int, t: float, heft: float = 1.0) -> Dictionary:
	var k := keys(style)
	if k.is_empty():
		return {"pos": Vector3.ZERO, "rot": Vector3.ZERO}
	t = clampf(t, 0.0, 1.0)
	var i := 0
	while i < k.size() - 2 and t > float(k[i + 1][0]):
		i += 1
	var pos: Vector3 = _hermite(k, i, 1, t) * heft
	var rot: Vector3 = _hermite(k, i, 2, t) * heft
	if style == Style.SLASH_L:
		pos.x = -pos.x
		rot.z = -rot.z
		rot.y = -rot.y
	return {"pos": pos, "rot": rot}


## Key column [param col] at [param t] in segment [param i]: a monotone cubic through the keys, so the hand flows
## through each key at speed (no stop at every key, no overshoot past one) and is still at the first and last.
static func _hermite(k: Array, i: int, col: int, t: float) -> Vector3:
	var t0 := float(k[i][0])
	var t1 := float(k[i + 1][0])
	var h := maxf(t1 - t0, 0.0001)
	var s := clampf((t - t0) / h, 0.0, 1.0)
	var p0: Vector3 = k[i][col]
	var p1: Vector3 = k[i + 1][col]
	var m0 := _tangent(k, i, col) * h
	var m1 := _tangent(k, i + 1, col) * h
	var s2 := s * s
	var s3 := s2 * s
	return p0 * (2.0 * s3 - 3.0 * s2 + 1.0) + m0 * (s3 - 2.0 * s2 + s) + p1 * (-2.0 * s3 + 3.0 * s2) + m1 * (s3 - s2)


## The slope at key [param j] per component: zero at the ends and where the motion turns, else the harmonic mean
## of the two secants (Fritsch-Butland), which never overshoots.
static func _tangent(k: Array, j: int, col: int) -> Vector3:
	if j <= 0 or j >= k.size() - 1:
		return Vector3.ZERO
	var da := ((k[j][col] as Vector3) - (k[j - 1][col] as Vector3)) / maxf(float(k[j][0]) - float(k[j - 1][0]), 0.0001)
	var db := ((k[j + 1][col] as Vector3) - (k[j][col] as Vector3)) / maxf(float(k[j + 1][0]) - float(k[j][0]), 0.0001)
	var out := Vector3.ZERO
	for c in 3:
		if da[c] * db[c] > 0.0:
			out[c] = 2.0 * da[c] * db[c] / (da[c] + db[c])
	return out


## Where the blade is, as a signed number: 0 before the wind-up, 1 at the strike. For
## deciding when a swing "connects" without caring which style it was.
static func strike_progress(t: float) -> float:
	return clampf(t / STRIKE_AT, 0.0, 1.0)


static func style_name(style: int) -> StringName:
	match style:
		Style.SLASH_R: return &"slash_r"
		Style.SLASH_L: return &"slash_l"
		Style.OVERHEAD: return &"overhead"
		Style.THRUST: return &"thrust"
		Style.BASH: return &"bash"
		Style.LOOSE: return &"loose"
		Style.FIRE: return &"fire"
	return &"none"
