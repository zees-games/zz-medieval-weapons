# zz-medieval-weapons

Zee's Medieval Weapons: ten historical weapons on dot-weapon, as a Workshop pack (`provides.json`, games `*`). Read the family [CLAUDE.md](../../CLAUDE.md), [dot-weapon's](../dot-weapon/CLAUDE.md) and [README.md](README.md). Modelled on zee-dot-weapons, with its own minimal view model, world model and replication (it does not depend on zee-dot-weapons): catalogue rows, behaviours, config, models, a spawn provider and `view/`, `net/`; the detail is in [docs/view-model.md](docs/view-model.md).

- Tuning is in weapon profiles `cfg/addons/zz_medieval_weapons/weapon/<id>.yml` (`DotWeaponProfiles` in dot-weapon over dot-core's `DotProfileSet`; pack keys under `extra:`, `upgrades/` children in the folder form), with the old `*.yml` files kept as a top layer; `ZzMedievalConfig.defaults()` is the source of truth and the shipped yml and `weapons/*.tres` are **generated** by `tools/export-defs.sh`. Change a default, re-run it, commit all of it.
- Behaviours apply nothing: stamina and knockback are outcome events the game applies; blocking is `ZzMedievalBlock`, a pure function.
- Durations are ticks at 64 (`authored_tick_rate`).
- Models: `assets/<id>.glb` if present, else a primitive placeholder (every weapon has a vendored model; `view/zz_medieval_reflection_source.gd` and docs/lighting.md say what a view gives metal to reflect; see CREDITS.md). Credit every vendored model there and in the README.
- A spawn menu consumes `spawn_provider.gd`; do not copy it into a game.
- `ZzMedievalArtTable` is the only file that knows how a weapon is held and moves; `ZzWeaponAnim` holds no nodes and reads no input. A lambda connected to an anim must not capture the anim (a reference cycle, caught by the suite's leak check).
- Check: `./game.sh test`; render with `tools/screenshot.sh` (`--sheet`, `--world`) and look at the frames.
- A delivered pack ships its profiles: `export_to` writes the `cfg/addons/<addon>/weapon` tree (upgrades included) under the export root. After mounting, set `ZzMedievalConfig.pack_cfg_root` to `DotCloudMounter.cfg_root_of(key)`; it is the weakest config root, so `cfg/addons`, `cfg/game` and `cfg/server` still override it. No dot-core change was needed (`DotProfileSet.roots` is weakest first).
