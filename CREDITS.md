# Credits

## Art: Sketchfab models, no placeholders left

Every weapon has a vendored model; `ZzMedievalModels.build(id)` still builds a primitive placeholder for an id without one. Only CC0 and CC-BY (attribution required, credit below) are used.

## Vendored

| Weapon | Model | Author | Licence | URL | Change |
| --- | --- | --- | --- | --- | --- |
| double_axe | Decorative Double-Bladed Battle Axe | Arms Museum | CC0 1.0 | https://sketchfab.com/3d-models/decorative-double-bladed-battle-axe-f0bfbca7a2804efd9cf77fd0f5a806aa | Joined, decimated 10.3k to 3k triangles, re-UVed and baked to one 1024 px texture (JPEG), scaled to 1.1 m with the butt 0.2 m below the grip, desaturated with grime and rust (2026-10-22) |
| war_axe | Decorative Battle Axe | Arms Museum | CC0 1.0 | https://sketchfab.com/3d-models/decorative-battle-axe-97575b982f5944baa0c9062d8107a983 | Same treatment, 11.3k to 3k triangles (2026-10-22) |
| longsword | Medieval Longsword Type XVIa | leeeck | CC-BY 4.0 | https://sketchfab.com/3d-models/359b73c3e8c449d7aa5fd96e7d831abd | Four meshes joined, decimated 68k to 7k triangles, original PBR textures at 1024 px (metallic as authored; the view must give it something to reflect, docs/lighting.md), 1.15 m, grip at the origin, tip along +Y (2026-10-22) |
| bow | Medieval Bow and Arrow | ana.stakflett | CC-BY 4.0 | https://sketchfab.com/3d-models/d5680d6d851d4411941f8f40f7feab94 | Only the bow limb kept (456 triangles); the model's own string and arrows are dropped because the view draws the string and the nocked arrow. 1.4 m tall, belly toward -X, string line 0.52 m along +X (`ZzMedievalArtTable` string rows) (2026-10-22) |
| round_shield | Worn Round Shield | iedalton | CC-BY 4.0 | https://sketchfab.com/3d-models/d848db788bc041ddab8a51c7836979d2 | Decimated 4.0k to 4.0k (kept), 1024 px PBR textures, 0.8 m across, centred, boss toward +Z (2026-10-22) |
| battle_axe | Medieval Battle Axe | CaptainHC | CC-BY 4.0 | https://sketchfab.com/3d-models/79115d20afec46928ca10dd948b4ced6 | Joined, decimated to 3k triangles, original PBR textures at 1024 px, 1.0 m, grip at the origin, head toward +Y (2026-10-22) |
| mace | Medieval Mace | Kama Modeling | CC-BY 4.0 | https://sketchfab.com/3d-models/83217215a0c541b2956a8e87a4ae62fe | Joined, decimated to 6k triangles, PBR textures at 1024 px, 0.70 m, grip at the origin (2026-10-22) |
| spear | Medieval Spear | iedalton | CC-BY 4.0 | https://sketchfab.com/3d-models/f61070945153418fa11c4abae286b292 | Levelled, decimated to 2.3k triangles, 2.0 m, grip at the origin, point along +Y (2026-10-22) |
| crossbow | Medieval Crossbow | iedalton | CC-BY 4.0 | https://sketchfab.com/3d-models/cc36ed347db340d59bd2ec7b06ae0d63 | Own string mesh dropped (the view draws the string), levelled, decimated to 6.7k triangles, 0.70 m, limb tips at x +-0.437 (`ZzMedievalArtTable` string row) (2026-10-22) |
| dagger | Medieval Dagger | Whatevvs | CC-BY 4.0 | https://sketchfab.com/3d-models/519b1fc1390747038cfc9f4ea158f660 | Joined, decimated to 1.2k triangles, 0.32 m, grip at the origin (2026-10-22) |

Licence read from each download's `license.txt`. The two axes are new weapons (`war_axe`, `double_axe`); the longsword, bow and round shield are CC-BY models (licence read from the Sketchfab record and each download's `license.txt`); the other five are CC-BY too.
