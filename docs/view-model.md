# View model, world model and replication

zee-dot-weapons has a rig, a view model and a net codec for guns. This pack has its own minimal, independent version for what a medieval weapon does, because a swing, a raised guard and a drawn string are not a recoil kick. Nothing here depends on or names zee-dot-weapons; the only hard dependency stays dot-core (dot-weapon is already this pack's).

## The pieces

| File | What |
| --- | --- |
| `art/zz_medieval_art_table.gd` | The only place that knows how a weapon is held and moves: hold rotation, resting hand, which hand, the off-hand grip, the swing styles, heft, scale, the string, the nocked missile, the surface. Swapping a placeholder for a `.glb` is editing a row and dropping the file in `assets/` (model convention: +Y along the weapon, origin at the grip) |
| `view/zz_weapon_pose.gd` | Swing curves as pure functions of phase (slash right and left, overhead, thrust, bash, loose/fire kick), the guard and the aim pose |
| `view/zz_weapon_anim.gd` | One weapon's animation state: swing, guard blend, draw, nock, cock, load. No nodes, no input. Signals: `used`, `struck` (at the blade's contact), `loosed(charge)`, `cue(name)` |
| `view/zz_medieval_held.gd` | The nodes: model, two arms (two-bone solve), the redrawn string, the nocked arrow or bolt, a flying copy of a loosed arrow. `ZzMedievalViewModel` (under the camera) and `ZzMedievalWorldModel` (at a carrier's chest) are this with different shoulders |
| `view/zz_projectile_flight.gd`, `view/zz_medieval_impacts.gd` | The arrow in the air and what a hit leaves |
| `net/zz_medieval_net.gd` | The replicated fields and the watcher's apply |

## How a game uses it

- Own player: add a `ZzMedievalViewModel` under the camera, `bind(id)`; call `anim.start_use()` when the arsenal's `used` fires, `anim.set_blocking(held)`, `anim.hold_draw(held)` for the bow, `anim.set_reloading(arsenal.is_reloading())` for the crossbow, `impact(point, normal, surface)` when a swing finds something. Nothing reads an input device.
- Sounds: connect `anim.cue` (`swing_light`, `swing_heavy`, `bash`, `guard_up`, `draw`, `draw_full`, `draw_relax`, `bow_loose`, `bolt_fire`, `nock`, `reload_start`, `reload_done`, `hit_<surface>`). No recordings ship with the pack; the names are the interface.
- Replication: concatenate `ZzMedievalNet.all_specs()` (dot-weapon's plus five public fields, 13 bits). The authority makes a `ZzMedievalNet.Sender`, `attach(anim)` once and `pull(anim, target)` per tick. A watcher keeps one integer per player and calls `seq = ZzMedievalNet.apply(source, anim, seq)`. The swing is a counter (it is worthless late); the guard, the draw and the reload are levels the watcher eases toward.
- If the game draws the real projectile itself, set `spawn_flight = false` so nothing flies twice.

## Looking at it

`tools/screenshot.sh --sheet [id ...]` (first person) and `--world [id ...]` (a person seen from outside) write `screenshots/view_<id>.png` and `world_<id>.png`: eight cells at a fixed 60 fps step, with the cell recipe printed. Swings, guard, bash, bow draw, hold and loose with the arrow landing in the target, crossbow fire and reload. Software rendering (Xvfb + llvmpipe), not the GPU boxes.

## Known gaps

- No depth lens: a first-person spear or axe can cut a wall it is pushed against.
- Arms are cylinders; no sleeve or hand art. Arms stretch a little past full reach rather than detach.
- Procedural curves are authored for the placeholders; a real model will want `hold`, `rest` and `scale` re-tuned from a sheet.
