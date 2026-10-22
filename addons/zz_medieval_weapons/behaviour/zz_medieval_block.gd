class_name ZzMedievalBlock
extends RefCounted

## What a raised shield does to a hit. Pure: the game's damage path asks, applies the answer,
## and charges the stamina itself.

## Damage left after the shield. [param def] is the shield's [DotWeaponDef]; [param facing] the
## way the carrier looks and [param hit_from] the direction the blow arrives FROM (attacker
## minus carrier), both horizontal enough that only yaw matters.
static func reduced(def: DotWeaponDef, damage: float, facing: Vector3, hit_from: Vector3, blocking: bool) -> float:
	if not blocking or def == null or not covers(def, facing, hit_from):
		return damage
	var keep := 1.0 - clampf(def.param_float(&"block_reduction", 0.0), 0.0, 1.0)
	return damage * keep


## Whether [param hit_from] is inside the shield's arc in front of [param facing].
static func covers(def: DotWeaponDef, facing: Vector3, hit_from: Vector3) -> bool:
	var f := Vector3(facing.x, 0.0, facing.z)
	var h := Vector3(hit_from.x, 0.0, hit_from.z)
	if f.length_squared() < 0.0001 or h.length_squared() < 0.0001:
		return false
	var half := def.param_float(&"block_arc_degrees", 120.0) * 0.5
	return rad_to_deg(f.angle_to(h)) <= half


## Stamina the block costs for [param stopped] points of damage.
static func stamina_cost(def: DotWeaponDef, stopped: float) -> float:
	return stopped * def.param_float(&"block_stamina_per_damage", 0.0)
