class_name ZzMedievalArtTable
extends RefCounted

## How a weapon is HELD and MOVES, apart from the server's numbers: the one place that knows a model's grip, string and swings, so swapping in a .glb is a row edit. Aim-frame positions (-z forward); offhand and string
## are model space. Keys: align, grip, world_turn, hold, rest, side, offhand, styles, scale, heft, weight, block, string, projectile, nock_axis, surface. `align` (Euler degrees) and `grip` are for a vendored glb that was not modelled upright:
## `align` turns it so the weapon stands along +Y (head or blade up), `grip` is then the point in that aligned space that goes to the hand (the origin). Both default to none.

const S := ZzWeaponPose.Style

static func rows() -> Dictionary:
	return {
		&"longsword": {
			"hold": Vector3(-28, 0, 0), "rest": Vector3(0.30, -0.34, -0.55), "side": 1,
			"offhand": Vector3(0, -0.06, 0),
			"styles": [S.SLASH_R, S.SLASH_L, S.OVERHEAD], "heft": 1.0, "weight": "light",
			"block": {"pos": Vector3(-0.22, 0.20, -0.02), "rot": Vector3(40, 0, 52)},
			"surface": "steel",
		},
		&"dagger": {
			"hold": Vector3(-40, 0, 0), "rest": Vector3(0.26, -0.30, -0.44), "side": 1,
			"styles": [S.THRUST, S.SLASH_R, S.SLASH_L], "heft": 0.7, "scale": 1.0, "weight": "light",
			"block": {"pos": Vector3(-0.14, 0.18, -0.06), "rot": Vector3(30, 0, 40)},
			"surface": "steel",
		},
		&"battle_axe": _axe(1.15),
		&"war_axe": _axe(1.1),
		&"double_axe": _axe(1.2),
		&"mace": {
			"hold": Vector3(-30, 0, 0), "rest": Vector3(0.30, -0.34, -0.52), "side": 1,
			"styles": [S.OVERHEAD, S.SLASH_L, S.SLASH_R], "heft": 1.0, "weight": "heavy",
			"block": {"pos": Vector3(-0.20, 0.20, -0.04), "rot": Vector3(40, 0, 50)},
			"surface": "iron",
		},
		&"spear": {
			"hold": Vector3(-78, 0, 6), "rest": Vector3(0.32, -0.30, -0.42), "side": 1,
			"offhand": Vector3(0, 0.55, 0),
			"styles": [S.THRUST], "heft": 1.0, "weight": "light",
			"block": {"pos": Vector3(-0.06, 0.16, -0.05), "rot": Vector3(20, 0, 62)},
			"surface": "wood",
		},
		&"round_shield": {
			# Left hand; the front faces -Z once rotated half a turn about Y.
			"hold": Vector3(0, 180, 0), "rest": Vector3(-0.34, -0.26, -0.50), "side": -1,
			# Third person, carried like any melee weapon (+Y forward): a quarter turn about its long axis stands the disc up facing out.
			"world_turn": Vector3(0, 90, 0),
			"styles": [S.BASH], "heft": 1.0, "scale": 0.62, "weight": "heavy",
			"block": {"pos": Vector3(0.30, 0.34, -0.12), "rot": Vector3(-6, 0, 0)},
			"surface": "wood",
		},
		&"bow": _bow(),
		&"crossbow": _crossbow(),
	}


## The longbow: a rigged glb whose limbs flex with the draw.
static func _bow() -> Dictionary:
	return {
		# Bulge toward the target: model -X to world -Z is a quarter turn about Y.
		"hold": Vector3(0, -90, 0), "rest": Vector3(-0.30, -0.18, -0.58), "side": -1,
		# At full draw the grip is at arm's length just left of and below the line of sight and the nock is
		# anchored low at the jaw (0.04, -0.15, -0.12), so the drawing hand stays out of frame and the arrow
		# climbs from the bottom of the view to the rest; the stave is canted a little.
		"aim": {"pos": Vector3(0.23, 0.08, -0.187), "rot": Vector3(7, 8, -6)},
		"styles": [S.LOOSE], "heft": 1.0, "scale": 0.8, "weight": "light",
		# The glb is modelled at full draw; its rig (a root and three bones up each limb) bends it back:
		# `flex` turns limb joint i by angle * share[i] about +Z, `braced` degrees at pull 0, `drawn` at 1.
		# The tips are the glb's nocks as modelled; the string keeps its braced length, so the nock is
		# wherever that length reaches with the limbs bent (see [method string_point]).
		"string": {
			"tips": [Vector3(0.562, -0.695, -0.02), Vector3(0.562, 0.695, -0.02)],
			"axis": Vector3(1, 0, 0), "nock_height": 0.04,
			"flex": {
				"joints": [Vector2(0.039, 0.09), Vector2(0.1174, 0.29), Vector2(0.2154, 0.49)],
				"share": [0.2, 0.3, 0.5], "braced": 40.0, "drawn": 18.0, "bone": "limb_%s_%d",
			},
		},
		# The arrow lies from the nock to the rest above the bow hand, on the left of the stave.
		"projectile": "arrow", "nock_axis": Vector3(-1, 0, 0), "arrow_rest": Vector3(0.0, 0.04, 0.02),
		"surface": "wood",
	}


## The crossbow: shouldered, cocked by a reload, the bolt in the groove.
static func _crossbow() -> Dictionary:
	return {
		"hold": Vector3(-90, 0, 0), "rest": Vector3(0.20, -0.26, -0.50), "side": 1,
		"offhand": Vector3(0, 0.16, -0.012),   # under the fore-stock, behind the prod
		"styles": [S.FIRE], "heft": 1.0, "scale": 0.9, "weight": "heavy",
		"string": {
			"tips": [Vector3(-0.426, 0.25, -0.032), Vector3(0.426, 0.25, -0.032)],   # in the prod's tip hooks
			# Cocked is pull 1: the string drawn back and up over the stock into the nut (y 0.12, top of the stock z 0.017).
			"axis": Vector3(0, -0.944, 0.33), "rest": Vector3(0, 0.235, -0.02), "travel": 0.122,
		},
		"projectile": "bolt", "nock_axis": Vector3(0, 1, 0), "nock_lift": Vector3(0, 0, 0.008),
		"surface": "iron",
	}


## The three axes share one grip, rest and block and differ only in heft.
static func _axe(heft: float) -> Dictionary:
	return {
		"hold": Vector3(-20, 0, 8), "rest": Vector3(0.30, -0.36, -0.55), "side": 1,
		"offhand": Vector3(0, 0.38, 0),
		"styles": [S.OVERHEAD, S.SLASH_R], "heft": heft, "weight": "heavy",
		"block": {"pos": Vector3(-0.10, 0.20, -0.10), "rot": Vector3(5, 0, 70)},
		"surface": "steel",
	}


static func row(id: StringName) -> Dictionary:
	return rows().get(id, {})


## The transform that stands a vendored model upright with its grip at the origin: identity for a row without `align` or `grip`.
static func model_transform(id: StringName) -> Transform3D:
	var r := row(id)
	var a: Vector3 = r.get("align", Vector3.ZERO)
	var basis := Basis.from_euler(Vector3(deg_to_rad(a.x), deg_to_rad(a.y), deg_to_rad(a.z)))
	return Transform3D(basis, -(r.get("grip", Vector3.ZERO) as Vector3))


## Where each mount's attachment model sits, in the aligned grip-at-origin space the weapon stands in (+Y along it).
## Melee: the wrap just above the hand, the pommel weight at the butt. Crossbow: the sight over the nut, the head at the bolt's tip.
static func socket_points(id: StringName) -> Dictionary:
	match id:
		&"crossbow":
			return {"optic": Vector3(0, 0.10, 0.02), "muzzle": Vector3(0, 0.34, 0.0)}
		&"round_shield":
			return {"side": Vector3(0, 0, 0.03)}
		&"bow":
			return {}
	return {"underbarrel": Vector3(0, 0.08, 0), "magazine": Vector3(0, -0.18, 0)}


static func has(id: StringName) -> bool:
	return rows().has(id)


## Whether the weapon has a drawn or cocked string.
static func has_string(id: StringName) -> bool:
	return row(id).has("string")


## Where the string's centre is at [param pull] (0 = rest/fired, 1 = fully drawn/cocked), in
## model space.
static func string_point(id: StringName, pull: float) -> Vector3:
	var s: Dictionary = row(id).get("string", {})
	if s.is_empty():
		return Vector3.ZERO
	if s.has("flex"):
		# Each half of the string keeps its braced length; the nock sits where both halves reach.
		var t := string_tips(id, pull)
		var b := string_tips(id, 0.0)
		var h := float(s.get("nock_height", 0.0))
		var lo: Vector3 = t[0]
		var hi: Vector3 = t[1]
		var len_lo := absf(h - (b[0] as Vector3).y)
		var len_hi := absf((b[1] as Vector3).y - h)
		var reach := minf(sqrt(maxf(len_lo * len_lo - (h - lo.y) * (h - lo.y), 0.0)), sqrt(maxf(len_hi * len_hi - (hi.y - h) * (hi.y - h), 0.0)))
		return Vector3((lo.x + hi.x) * 0.5, h, hi.z) + (s["axis"] as Vector3) * reach
	return (s["rest"] as Vector3) + (s["axis"] as Vector3) * float(s["travel"]) * clampf(pull, 0.0, 1.0)


## How far, in degrees, each limb is bent back from the glb's pose at [param pull] (0 for a rigid row).
static func flex_angle(id: StringName, pull: float) -> float:
	var f: Dictionary = (row(id).get("string", {}) as Dictionary).get("flex", {})
	if f.is_empty():
		return 0.0
	return lerpf(float(f["braced"]), float(f["drawn"]), clampf(pull, 0.0, 1.0))


## The string's two ends at [param pull], model space: the table tips carried through the limb joints by
## [method flex_angle], the same turns [ZzMedievalHeld] gives the glb's bones.
static func string_tips(id: StringName, pull: float) -> Array:
	var s: Dictionary = row(id).get("string", {})
	if s.is_empty():
		return []
	var tips: Array = (s["tips"] as Array).duplicate()
	var f: Dictionary = s.get("flex", {})
	if f.is_empty():
		return tips
	var ang := deg_to_rad(flex_angle(id, pull))
	var joints: Array = f["joints"]
	var share: Array = f["share"]
	for k in tips.size():
		var p: Vector3 = tips[k]
		var sg := signf(p.y)
		# Outermost joint first: each turn carries what lies beyond it, as a bone chain does.
		for i in range(joints.size() - 1, -1, -1):
			var j: Vector2 = joints[i]
			var c := Vector2(j.x, j.y * sg)
			var q := (Vector2(p.x, p.y) - c).rotated(ang * float(share[i]) * sg) + c
			p = Vector3(q.x, q.y, p.z)
		tips[k] = p
	return tips


## The sounds a weapon asks for. A game connects [signal ZzWeaponAnim.cue] to its audio; these
## are the names, so a pack of recordings is a lookup, not code.
static func cue(id: StringName, event: StringName) -> StringName:
	var w := String(row(id).get("weight", "light"))
	match event:
		&"swing": return StringName("swing_" + w)
		&"hit": return StringName("hit_" + String(row(id).get("surface", "steel")))
	return event
