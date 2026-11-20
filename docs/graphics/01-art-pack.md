# 01 — The art pack

All art is from a **Craftpix** city pixel-art pack, stored unmodified in `asset/`.
The licence is in `asset/Licens.txt` (it links to <https://craftpix.net/file-licenses/>).
**Read it before publishing the game commercially.**

## Inventory

```
asset/
├── Characters/
│   ├── Character_1/   ← THE HERO (SWAT officer)
│   ├── Character_2/   unused (has a Shield animation)
│   ├── Character_3/   unused
│   ├── Other/         Charge 1–3.png (bullets), Granate_Cast.png, Granate_Explosion.png
│   └── PSD/           layered source files (not imported for gameplay)
├── Enimies/           (spelling as in the pack)
│   ├── Enimies_1/     ← Gunner mook
│   ├── Enimies_2/     ← BOSS 3: The Plague Doctor
│   ├── Enimies_3/     ← BOSS 1: Deadeye Rook
│   ├── Enimies_4/     ← Brute mook
│   ├── Enimies_5/     ← BOSS 2: Bonecrusher
│   ├── Enimies_6/     unused
│   └── PSD/
├── City_Tileset/      the tileset as separate pieces (Building 1/2, Road, Objects, Signage…)
├── Tiled/
│   ├── Tile1.png      ← THE WHOLE CITY IN ONE 480×480 SHEET (used for everything)
│   └── Tile.tsx       a Tiled-editor tileset definition (not used by Godot)
├── UI/
│   ├── UI.png         ← panel art (9-slice frame source), 256×200
│   ├── Icons/1..N.png ← 16 px white icons (heart 33, grenade 1, bullet 26, skull 25)
│   ├── Bars/, Buttons/, Interface/, Scrolling/   unused
│   └── PSD.psd
├── Font.txt           names the font "DigitalDisco" (font file NOT included)
├── Licens.txt
└── __MACOSX/          macOS junk (._* files), ignored via .gdignore
```

## What is used where

| Asset | Used for | Via |
|---|---|---|
| `Characters/Character_1/*.png` | Player animations | `resources/frames/player.tres` |
| `Enimies/Enimies_1, _4` | Gunner, Brute | `mook_gunner.tres`, `mook_brute.tres` |
| `Enimies/Enimies_3, _5, _2` | The three bosses (shown 2×) | `boss_*.tres` |
| `Characters/Other/Charge 1.png` | Bullet sprite | `bullet.tscn` |
| `Characters/Other/Granate_Cast.png` | Spinning grenade, grenade pickup icon | `grenade.tres`, `pickup.gd` |
| `Characters/Other/Granate_Explosion.png` | 8-frame explosion; one frame reused as the shockwave | `explosion.tres`, `shockwave.tscn` |
| `Tiled/Tile1.png` | Ground and platform tiles, buildings, signs, posters, props, health pickup, title-screen diorama | `city_tileset.tres`, `build_level.gd`, `pickup.gd`, `title.gd` |
| `UI/UI.png` | Beige panel for the HUD and dialogs | `ui_kit.gd → panel()` |
| `UI/Icons/*.png` | Hearts, bullet, grenades, boss skull | `ui_kit.gd → icon()` |

## Why `Tile1.png` instead of `City_Tileset/`?

`City_Tileset/` has the same art as many separate PNGs. `Tile1.png` packs everything into one
16 px grid (30 × 30 cells). A single texture means:

* one `TileSetAtlasSource` covers every tile,
* any building, prop or sign can be cut out with a `Rect2` region,
* fewer texture switches when drawing (better batching).

## Unused art: ideas for extensions

* **Character_2 / Character_3**: selectable heroes. Character_2 has a **Shield** animation, which
  could become a blocking move.
* **Enimies_6**: a third mook type (it has `Walk+Attack`, so it could be a charger).
* **Player `Attack` animation**: a melee strike.
* **UI Bars / Buttons**: replace the code-drawn boss bar and the `StyleBoxFlat` buttons with art.
* **The DigitalDisco font**: download it from the link in `Font.txt` (check its licence), add the
  `.ttf`, and set it in a `Theme` to replace Godot's default font.

## Facts measured from the sheets

These were worked out by viewing the sheets on a pixel grid during development. All the
character code depends on them:

* Every character animation is **one horizontal strip of 32 × 32 frames**, so
  frame count = `width / 32`.
* **Feet touch the bottom edge** of the frame, which is why sprites are offset by −16 (or −32 at 2×).
* The gun muzzle is roughly **(+8, −6)** px from the feet when facing right.
* `Hurt.png` is a **white flash silhouette**, a hit effect rather than a pose.
* `Sleeve.png` (shell casings) is **16 px tall**, so the pipeline skips it automatically.
* `Granate_Explosion.png` uses **64 px** frames. The grenade uses 32 px frames.
