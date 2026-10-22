extends "res://addons/zz_medieval_weapons/behaviour/zz_melee.gd"

## A shield's bash: a short, wide, weak sweep with a knockback event. The block is not a use
## (a use is an edge; blocking is a held stance) so it is [ZzMedievalBlock], a pure function
## the game's damage path calls with its own "is blocking" input.

func _use(ctx: DotWeaponContext) -> DotWeaponOutcome:
	var out := super._use(ctx)
	if not ctx.replayed:
		out.add_event({
			"type": "knockback",
			"impulse": tune_float(&"knockback", 6.0),
			"direction": ctx.direction,
		})
	return out
