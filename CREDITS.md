# Credits

## Art: Sketchfab models, no placeholders left

Every weapon has a vendored model; `ZzMedievalModels.build(id)` still builds a primitive placeholder for an id without one. Only CC0 and CC-BY (attribution required, credit below) are used.

## Vendored

| Weapon | Model | Author | Licence | URL | Change |
| --- | --- | --- | --- | --- | --- |
| double_axe | Decorative Double-Bladed Battle Axe | Arms Museum | CC0 1.0 | https://sketchfab.com/3d-models/decorative-double-bladed-battle-axe-f0bfbca7a2804efd9cf77fd0f5a806aa | Joined, decimated 10.3k to 3k triangles, re-UVed and baked to one 1024 px texture (JPEG), scaled to 1.1 m with the butt 0.2 m below the grip, desaturated with grime and rust (2026-10-22) |
| war_axe | Decorative Battle Axe | Arms Museum | CC0 1.0 | https://sketchfab.com/3d-models/decorative-battle-axe-97575b982f5944baa0c9062d8107a983 | Same treatment, 11.3k to 3k triangles (2026-10-22) |
| longsword | Medieval Longsword Type XVIa | leeeck | CC-BY 4.0 | https://sketchfab.com/3d-models/359b73c3e8c449d7aa5fd96e7d831abd | Four meshes joined, decimated 68k to 7k triangles, original PBR textures at 1024 px (JPEG q92, restored 2026-11-22 after the 512 px shrink; metallic as authored; the view must give it something to reflect, docs/lighting.md), 1.15 m, grip at the origin, tip along +Y (2026-10-22) |
| bow | Bow | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (2.8k triangles): D-section limbs, leather grip wrap and horn nocks on the original rig (`tools/bow_rig.json`, three bones per limb), yew from ambientCG Wood049, own leather and horn textures; 1.4 m, nocks at (0.562, +-0.695) (`ZzMedievalArtTable` string row) |
| round_shield | Worn Round Shield | iedalton | CC-BY 4.0 | https://sketchfab.com/3d-models/d848db788bc041ddab8a51c7836979d2 | Decimated 4.0k to 4.0k (kept), 1024 px PBR textures, 0.8 m across, centred, boss toward +Z (2026-10-22) |
| battle_axe | Battle axe | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (2.1k triangles): oval haft, leather grip, langets, crescent single-bit head with a back spike; ambientCG Wood049 and Metal009/Metal038 (CC0), own leather; 1024 px albedo, normal and ORM |
| mace | Medieval Mace | Kama Modeling | CC-BY 4.0 | https://sketchfab.com/3d-models/83217215a0c541b2956a8e87a4ae62fe | Joined, decimated to 6k triangles, PBR textures at 1024 px, 0.70 m, grip at the origin (2026-10-22) |
| spear | Spear | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (2.2k triangles): ash shaft, iron butt ferrule, socketed leaf blade with midrib and langets, leather binding; ambientCG Wood049 and Metal009/Metal038 (CC0) |
| crossbow | Crossbow | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (2.5k triangles): wooden stock, steel prod, iron tip caps and stirrup, bone nut, lashings; ambientCG Wood077, Metal009/Metal038 (CC0), own leather and bone; string nocks at x +-0.426 (`ZzMedievalArtTable` string row) |
| arrow, bolt | Arrow and crossbow bolt | own work (zz-medieval-weapons) | CC0 1.0 | - | Built for the pack: shaft (ambientCG Wood049, CC0), bodkin head, horn nock, thread whipping, three curved fletching vanes (own procedural feather textures); rebuilt 2026-11-22 by `tools/gen_projectiles.py` at 2000 triangles each with 1024 px albedo, normal and ORM maps (shaft wood from the 1k Wood049 set) |
| dagger | Dagger | own work (zz-medieval-weapons) | CC0 1.0 | - | Rebuilt 2026-11-22 by `tools/gen_weapons.py` (1.3k triangles): wire-wrapped leather grip, curved quillon, fullered blade, upright with the hand at the origin; ambientCG Metal009/Metal038 (CC0), own leather |

Licence read from each download's `license.txt` (and the Sketchfab record for the CC-BY models). The two axes are new weapons (`war_axe`, `double_axe`); the longsword, round shield and mace are CC-BY models; the dagger, spear, battle axe, crossbow, bow, arrow and bolt are own work (CC0).
