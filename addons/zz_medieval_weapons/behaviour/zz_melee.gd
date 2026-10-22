extends DotWeaponMelee

## The stock sweep, plus the stamina a swing costs. The stamina is an [i]event[/i] on the
## outcome, not state here: a behaviour applies nothing, and the game that owns a stamina
## pool reads the event (type "stamina", "cost").

func _use(ctx: DotWeaponContext) -> DotWeaponOutcome:
	var out := super._use(ctx)
	var cost := tune_float(&"stamina_cost", 0.0)
	if cost > 0.0 and not ctx.replayed:
		out.add_event({"type": "stamina", "cost": cost})
	return out
