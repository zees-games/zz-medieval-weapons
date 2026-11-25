# Credits

## Art: Sketchfab models, no placeholders left

Every weapon has a vendored model; `ZzMedievalModels.build(id)` still builds a primitive placeholder for an id without one. Only CC0 is used.

## Vendored

| Weapon | Model | Author | Licence | URL | Change |
| --- | --- | --- | --- | --- | --- |
| double_axe | Decorative Double-Bladed Battle Axe | Arms Museum | CC0 1.0 | https://sketchfab.com/3d-models/decorative-double-bladed-battle-axe-f0bfbca7a2804efd9cf77fd0f5a806aa | Joined, decimated 10.3k to 3k triangles, re-UVed and baked to one 1024 px texture (JPEG), scaled to 1.1 m with the butt 0.2 m below the grip, desaturated with grime and rust (2026-10-22) |
| war_axe | Decorative Battle Axe | Arms Museum | CC0 1.0 | https://sketchfab.com/3d-models/decorative-battle-axe-97575b982f5944baa0c9062d8107a983 | Same treatment, 11.3k to 3k triangles (2026-10-22) |
| longsword | Longsword | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (3.0k triangles at most: revolved pommel and grip with leather wrap, curved iron cross, fullered tapering blade; 1.15 m, grip at the origin, tip along +Y; ambientCG Metal009/Metal038 (CC0), own leather) |
| bow | Bow | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (2.8k triangles): D-section limbs, leather grip wrap and horn nocks on the original rig (`tools/bow_rig.json`, three bones per limb), yew from ambientCG Wood049, own leather and horn textures; 1.4 m, nocks at (0.562, +-0.695) (`ZzMedievalArtTable` string row) |
| round_shield | Round shield | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (3.2k triangles: dished plank face, iron rim, steel boss with rivets, leather grip bar; 0.8 m across, centred, boss toward +Z; ambientCG Wood049, Metal009/Metal038 (CC0), own leather) |
| battle_axe | Battle axe | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (2.1k triangles): oval haft, leather grip, langets, crescent single-bit head with a back spike; ambientCG Wood049 and Metal009/Metal038 (CC0), own leather; 1024 px albedo, normal and ORM |
| mace | Flanged mace | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (3.1k triangles: ash haft, leather grip, socket collar, six-flanged steel head with spike; upright, 0.77 m, grip at the origin; ambientCG Wood049, Metal009/Metal038 (CC0), own leather) |
| spear | Spear | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (2.2k triangles): ash shaft, iron butt ferrule, socketed leaf blade with midrib and langets, leather binding; ambientCG Wood049 and Metal009/Metal038 (CC0) |
| crossbow | Crossbow | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (2.5k triangles): wooden stock, steel prod, iron tip caps and stirrup, bone nut, lashings; ambientCG Wood077, Metal009/Metal038 (CC0), own leather and bone; string nocks at x +-0.426 (`ZzMedievalArtTable` string row) |
| arrow, bolt | Arrow and crossbow bolt | own work (zz-medieval-weapons) | CC0 1.0 | - | Built for the pack: shaft (ambientCG Wood049, CC0), bodkin head, horn nock, thread whipping, three curved fletching vanes (own procedural feather textures); rebuilt 2026-11-22 by `tools/gen_projectiles.py` at 2000 triangles each with 1024 px albedo, normal and ORM maps (shaft wood from the 1k Wood049 set) |
| dagger | Dagger | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (1.3k triangles): wire-wrapped leather grip, curved quillon, fullered blade, upright with the hand at the origin; ambientCG Metal009/Metal038 (CC0), own leather |
| attachments (zz_aperture_sight, zz_barbed_heads, zz_leather_wrap, zz_counterweight, zz_spiked_boss) | Attachment meshes and materials | own work (zz-medieval-weapons) | CC0 1.0 | - | Built in code at load (`ZzAttachmentPiece`, `ZzAttachmentArt`): lofted and lathed meshes with bevels, fitted to each weapon's measured grip, butt, stock or boss (`ZzAttachmentFit`); procedural albedo, roughness and normal textures (stitched spiral leather, twisted rope whipping, pitted iron); no vendored assets (2026-11-24) |

Licence read from each download's `license.txt`. The two axes are new weapons (`war_axe`, `double_axe`); every other weapon, arrow and bolt is own work (CC0), so the pack is CC0-clean.
