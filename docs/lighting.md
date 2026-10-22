# What a game must give the weapon view model

The weapon models keep their authored PBR values, metal included (blades, heads and rims are `metallic` near 1). **A fully metallic surface has no diffuse colour: it shows only what it reflects.** With nothing to reflect it renders black, which is why the first conversions scaled metal down (0.6 on the axes, 0.35 on the longsword). The longsword's scaling is gone; the view must provide the reflection instead.

A game does one of these, and needs only one:

1. **A sky in the world's Environment** (the usual case): `background_mode = BG_SKY` with a `Sky`, and `reflected_light_source` left at `REFLECTION_SOURCE_SKY` or background. The view model sits in the same world, so its metal reflects that sky. Most games here already have one.
2. **`ZzMedievalReflectionSource.sky_environment()`** for a world that has none: a procedural sky that is the background, the ambient and the reflected light. `tools/rack.gd` and `tools/sheet.gd` use it.
3. **`ZzMedievalViewModel.provide_reflections = true`** (or `ZzMedievalReflectionSource.attach_probe(node)`): a one-shot `ReflectionProbe` hung on the view model, for a world with a flat-colour background and no sky. It captures the surroundings at the next frame; call `ZzMedievalReflectionSource.refresh(probe)` after a big lighting change. It is flatter than a sky.

Also needed, as for any lit mesh: a `DirectionalLight3D`, and no `Environment` with reflections disabled.

The helper is a small copy of the one in zz-modern-weapons, on purpose: a pack may not require another pack. Check by eye with `tools/screenshot.sh` and `tools/screenshot.sh --sheet`; a black blade with bright glints is this problem.
