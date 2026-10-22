extends DotWeaponProjectile

## The stock projectile, with the projectile's name from the row ("arrow", "bolt") so a game
## picks the model, and the stamina a draw costs. Speed, damage and drop come from the
## ballistics through the draw ([member DotWeaponContext.charge]); an arrow loosed at half draw
## is slower, weaker and drops sooner, which is what a drawn bow is.

func _use(ctx: DotWeaponContext) -> DotWeaponOutcome:
	var out := super._use(ctx)
	var cost := tune_float(&"stamina_cost", 0.0)
	if cost > 0.0 and not ctx.replayed:
		out.add_event({"type": "stamina", "cost": cost * ctx.charge})
	return out
