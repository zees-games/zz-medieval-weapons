# zz-medieval-weapons

Zee's Medieval Weapons: eight historical weapons on dot-weapon, as a Workshop pack (`provides.json`, games `*`). Read the family [CLAUDE.md](../../CLAUDE.md), [dot-weapon's](../dot-weapon/CLAUDE.md) and [README.md](README.md). Modelled on zee-dot-weapons, without its rig and view model: this pack is catalogue rows, behaviours, config, models and a spawn provider.

- Tuning is in `cfg/addons/zz_medieval_weapons/*.yml` through `DotAddonConfig`; `ZzMedievalConfig.defaults()` is the source of truth and the shipped yml and `weapons/*.tres` are **generated** by `tools/export-defs.sh`. Change a default, re-run it, commit all of it.
- Behaviours apply nothing: stamina and knockback are outcome events the game applies; blocking is `ZzMedievalBlock`, a pure function.
- Durations are ticks at 64 (`authored_tick_rate`).
- Models: `assets/<id>.glb` if present, else a primitive placeholder (all eight are placeholders; see CREDITS.md). Credit every vendored model there and in the README.
- A spawn menu consumes `spawn_provider.gd`; do not copy it into a game.
- Check: `./game.sh test`; render with `tools/screenshot.sh` and look.
