class_name ZzMedievalArtTable
extends RefCounted

## How a weapon is HELD and MOVES, apart from the server's numbers: the one place that knows a model's grip,
## string and swings, so swapping in a .glb is a row edit. Aim-frame positions (-z forward); offhand and string
## are model space. Keys: align, grip, hold, rest, side, offhand, styles, scale, heft, weight, block, string, projectile, nock_axis, surface.
## `align` (Euler degrees) and `grip` are for a vendored glb that was not modelled upright: `align` turns it so the weapon stands along
## +Y (head or blade up), `grip` is then the point in that aligned space that goes to the hand (the origin). Both default to none.

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
			# The glb's blade leans about 29 degrees off +Y and its guard is rolled; align stands it up, grip is its handle.
			"align": Vector3(26.9, -53.2, 11.5), "grip": Vector3(-0.043, -0.052, 0.003),
			"hold": Vector3(-40, 0, 0), "rest": Vector3(0.26, -0.30, -0.44), "side": 1,
			"styles": [S.THRUST, S.SLASH_R, S.SLASH_L], "heft": 0.7, "scale": 1.0, "weight": "light",
			"block": {"pos": Vector3(-0.14, 0.18, -0.06), "rot": Vector3(30, 0, 40)},
			"surface": "steel",
		},
		&"battle_axe": {
			"hold": Vector3(-20, 0, 8), "rest": Vector3(0.30, -0.36, -0.55), "side": 1,
			"offhand": Vector3(0, 0.38, 0),
			"styles": [S.OVERHEAD, S.SLASH_R], "heft": 1.15, "weight": "heavy",
			"block": {"pos": Vector3(-0.10, 0.20, -0.10), "rot": Vector3(5, 0, 70)},
			"surface": "steel",
		},
		&"war_axe": {
			"hold": Vector3(-20, 0, 8), "rest": Vector3(0.30, -0.36, -0.55), "side": 1,
			"offhand": Vector3(0, 0.38, 0),
			"styles": [S.OVERHEAD, S.SLASH_R], "heft": 1.1, "weight": "heavy",
			"block": {"pos": Vector3(-0.10, 0.20, -0.10), "rot": Vector3(5, 0, 70)},
			"surface": "steel",
		},
		&"double_axe": {
			"hold": Vector3(-20, 0, 8), "rest": Vector3(0.30, -0.36, -0.55), "side": 1,
			"offhand": Vector3(0, 0.38, 0),
			"styles": [S.OVERHEAD, S.SLASH_R], "heft": 1.2, "weight": "heavy",
			"block": {"pos": Vector3(-0.10, 0.20, -0.10), "rot": Vector3(5, 0, 70)},
			"surface": "steel",
		},
		&"mace": {
			# The glb's haft leans 53.6 degrees off +Y (head to the right) and is 1.07 m; align stands it up, scale makes it 0.77 m.
			"align": Vector3(0, 0, 53.6), "grip": Vector3(-0.156, -0.274, 0),
			"hold": Vector3(-30, 0, 0), "rest": Vector3(0.30, -0.34, -0.52), "side": 1,
			"styles": [S.OVERHEAD, S.SLASH_L, S.SLASH_R], "heft": 1.0, "scale": 0.72, "weight": "heavy",
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
			"styles": [S.BASH], "heft": 1.0, "scale": 0.62, "weight": "heavy",
			"block": {"pos": Vector3(0.30, 0.34, -0.12), "rot": Vector3(-6, 0, 0)},
			"surface": "wood",
		},
		&"bow": {
			# Bulge toward the target: model -X to world -Z is a quarter turn about Y.
			"hold": Vector3(0, -90, 0), "rest": Vector3(-0.30, -0.18, -0.58), "side": -1,
			"styles": [S.LOOSE], "heft": 1.0, "scale": 0.8, "weight": "light",
			"string": {
				"tips": [Vector3(0.52, -0.7, 0), Vector3(0.52, 0.7, 0)],
				"axis": Vector3(1, 0, 0), "rest": Vector3(0.52, 0, 0), "travel": 0.40,
			},
			"projectile": "arrow", "nock_axis": Vector3(-1, 0, 0),
			"surface": "wood",
		},
		&"crossbow": {
			"hold": Vector3(-90, 0, 0), "rest": Vector3(0.20, -0.26, -0.50), "side": 1,
			"offhand": Vector3(0, 0.62, -0.04),
			"styles": [S.FIRE], "heft": 1.0, "scale": 0.9, "weight": "heavy",
			"string": {
				"tips": [Vector3(-0.437, 0.255, -0.026), Vector3(0.437, 0.255, -0.026)],
				# Cocked is pull 1: the string drawn back toward the stock.
				"axis": Vector3(0, -1, 0), "rest": Vector3(0, 0.235, -0.02), "travel": 0.2,
			},
			"projectile": "bolt", "nock_axis": Vector3(0, 1, 0), "nock_lift": Vector3(0, 0, 0.06),
			"surface": "iron",
		},
	}


static func row(id: StringName) -> Dictionary:
	return rows().get(id, {})


## The transform that stands a vendored model upright with its grip at the origin: identity for a row without `align` or `grip`.
static func model_transform(id: StringName) -> Transform3D:
	var r := row(id)
	var a: Vector3 = r.get("align", Vector3.ZERO)
	var basis := Basis.from_euler(Vector3(deg_to_rad(a.x), deg_to_rad(a.y), deg_to_rad(a.z)))
	return Transform3D(basis, -(r.get("grip", Vector3.ZERO) as Vector3))


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
	return (s["rest"] as Vector3) + (s["axis"] as Vector3) * float(s["travel"]) * clampf(pull, 0.0, 1.0)


## The sounds a weapon asks for. A game connects [signal ZzWeaponAnim.cue] to its audio; these
## are the names, so a pack of recordings is a lookup, not code.
static func cue(id: StringName, event: StringName) -> StringName:
	var w := String(row(id).get("weight", "light"))
	match event:
		&"swing": return StringName("swing_" + w)
		&"hit": return StringName("hit_" + String(row(id).get("surface", "steel")))
	return event
