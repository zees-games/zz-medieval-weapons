class_name ZzMedievalArtTable
extends RefCounted

## Everything about how a weapon is HELD and MOVES that is not a number the server owns: the
## only place that knows a model's grip, where its string is, which swings it uses. Replacing
## a placeholder with a .glb is editing the row here (and dropping the file in assets/); no
## script elsewhere names a weapon.
##
## All positions are in the aim frame at the resting hand (x right, y up, -z forward) or, for
## [code]offhand[/code] and [code]string[/code], in the model's own space (origin at the grip,
## +Y along the weapon). Rotations are degrees. The convention for models is the one
## [ZzMedievalModels] states: +Y along the weapon, origin at the grip.
##
## Keys:
## [br]- [code]hold[/code]: the weapon's rotation at rest (Euler, degrees).
## [br]- [code]rest[/code]: where the hand sits at rest. [code]side[/code]: +1 right hand, -1 left.
## [br]- [code]offhand[/code]: where the other hand grips, model space; absent = a loose fist.
## [br]- [code]styles[/code]: the swings, in the order they are cycled.
## [br]- [code]scale[/code]: uniform size of the model in the hand (a 1.4 m bow is too big for a view); absent = 1.
## [br]- [code]heft[/code]: scales the swing's amplitude. [code]weight[/code]: "light" or "heavy", for the sound cue.
## [br]- [code]block[/code]: {pos, rot} overriding the guard. Absent = [constant ZzWeaponPose.GUARD_POS].
## [br]- [code]string[/code]: {tips: [a, b], axis, rest, travel}: a drawn string, redrawn by the view
##   because a model's own string cannot move (the node named "string" is hidden).
## [br]- [code]projectile[/code]: the nocked arrow or bolt; [code]nock_axis[/code] the way it points, model space.
## [br]- [code]surface[/code]: what the weapon is made of, for the impact it leaves when it hits something hard.

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
			"styles": [S.THRUST, S.SLASH_R, S.SLASH_L], "heft": 0.7, "scale": 1.3, "weight": "light",
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
