extends DotWeaponProjectile

## The stock projectile, named from the row ("arrow", "bolt") so a game picks the model, plus the stamina
## a draw costs. Speed, damage and drop scale with [member DotWeaponContext.charge].

func _use(ctx: DotWeaponContext) -> DotWeaponOutcome:
	var out := super._use(ctx)
	var cost := tune_float(&"stamina_cost", 0.0)
	if cost > 0.0 and not ctx.replayed:
		out.add_event({"type": "stamina", "cost": cost * ctx.charge})
	return out
