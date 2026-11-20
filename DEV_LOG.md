# DARK CITY — Development Log

A 2D pixel-art run-and-gun platformer built in **Godot 4.7** using only the
art in `asset/` (Craftpix city pack). **1 level, 3 bosses.**

Open the project in Godot and press **F5** (main scene: the title screen).

---

## 1. The finished game

| | |
|---|---|
| **Genre** | Side-scrolling run-and-gun / platformer |
| **Hero** | SWAT officer (`asset/Characters/Character_1`) |
| **Level** | "Downtown at night" — one 3776 px long street (236 tiles), rain, parallax skyline |
| **Regular enemies** | 19 placed: *Gunner* (Enimies_1, keeps distance, fires 3-round bursts) and *Brute* (Enimies_4, runs at you and swings an axe) |
| **Bosses** | 3 boss arenas — camera locks, walls close, boss drops in with a WARNING banner |
| **Win / lose** | Beat the 3rd boss → "CITY SAVED" screen (score + time). Lose all 10 hearts or fall in a pit → "YOU DIED" (Retry / Title) |

### Controls
| Action | Keyboard | Also |
|---|---|---|
| Move | A / D | Arrow keys, gamepad d-pad / left stick |
| Jump | Space | W, Up, gamepad A |
| Shoot (hold = auto-fire) | J | X, left mouse, gamepad X |
| Throw grenade | K | C, right mouse, gamepad B |
| Reload | R | gamepad Y (auto-reloads when empty) |
| Drop through platform | S + Space | |
| Pause | Esc | P, gamepad Start |

### The bosses
| # | Boss | Sprite | HP | Attacks |
|---|---|---|---|---|
| 1 | **DEADEYE ROOK** | Enimies_3 (2× size) | 60 | Aimed bursts (3 → 5 shots), hop-back + bullet fan, walks in, must **reload every 4th attack** (free-damage window) |
| 2 | **BONECRUSHER** | Enimies_5 (2× size) | 90 | Blinks red then **charges** across the arena (stunned when he hits a wall), **leaps** at you and sends **shockwaves** along the floor (jump them), close-range swipe |
| 3 | **THE PLAGUE DOCTOR** (final) | Enimies_2 (2× size) | 120 | 5-bullet **spread volleys**, **lobs grenades** around you, **dashes** to the far side of the arena, and in phase 2 **summons two gunmen** |

All bosses get **phase 2 under 50 % HP** ("… IS ENRAGED!"): shorter pauses, more bullets, faster charges, double leaps.

---

## 2. Development timeline (what I did, in order)

### Step 1 — Inventory of the assets
- Listed every file in `asset/` and measured every PNG.
- Built labeled **contact sheets** (upscaled, with a red line every 32 px) of all
  character/enemy sprite sheets to *see* each animation.
- Findings:
  - Every character animation is **one horizontal strip of 32×32 frames**
    (`Idle` 4 frames, `Walk` 4, `Shot` 4, `Recharge` 5–9, `Dead` 3, `Hurt` 2 …).
  - `Hurt.png` is a **white flash silhouette** (hit effect), not a pose.
  - Feet touch the **bottom edge** of the frame; the gun muzzle sits ≈ (+8, −6) px from the feet.
  - `Granate_Cast.png` = spinning grenade (8 × 32 px), `Granate_Explosion.png` = 8 × **64 px** blast.
  - `Charge 1/2/3.png` = bullet sprites. `Sleeve.png` = shell casings (16 px tall → skipped).
  - `asset/Tiled/Tile1.png` (480×480) is the **whole city tileset in one sheet** (16×16 grid, 30 columns):
    full building facades, pavement/asphalt, roof ledges, dumpsters, crates, signs, posters, and the UI.
  - `asset/UI/Icons/*.png` — white 16 px icons (heart = 33, grenade = 1, bullet = 26, skull = 25).
  - `asset/UI/UI.png` — panel graphics (used as a 9-slice frame).
  - `asset/__MACOSX/` = macOS junk (`._*` files that are not real PNGs).
- Rendered the tilesheet with a **coordinate grid** to note exact tile positions
  (ground tiles at rows 22–28, building 1 = cols 1–8 × rows 9–20, building 2 = cols 12–22 × rows 12–20,
  roof-ledge platform pieces on row 15, props at cols 24–29).

### Step 2 — Game design (based on what the art supports)
- 3 hero characters + 6 enemy types → hero = Character_1, 2 enemy types as regular mooks,
  3 distinctive enemy types scaled 2× as bosses.
- Shoot / Recharge / Cast animations → gun with a 12-round magazine + reload + grenades.
- One-screen boss arenas that lock the camera (classic run-and-gun structure).

### Step 3 — Project setup (`project.godot`)
- Base resolution **384×216** (a 16:9 pixel canvas), window **1152×648** (×3), `canvas_items`
  stretch + **integer scaling** + **pixel snapping** + **nearest** texture filter → crisp pixels, sharp text.
- Input map: `move_left/right/down`, `jump`, `shoot`, `grenade`, `reload`, `pause` (keyboard, mouse, gamepad).
- Named physics layers: 1 world, 2 player, 3 enemies, 4 pickups, 5 platforms.
- Autoload `Game` (`scripts/autoload/game.gd`).
- Added `asset/__MACOSX/.gdignore` so Godot doesn't try to import the macOS junk files.

### Step 4 — Asset pipeline tool (`tools/build_resources.gd`)
Instead of slicing ~300 frames by hand in the editor, a script converts the sheets automatically:
- For each character folder: every PNG → one animation in a **SpriteFrames** resource,
  name in snake_case (`Walk+Shot.png` → `walk_shot`), frame count = width / 32, per-animation FPS and loop flags.
- Output: `resources/frames/player.tres`, `mook_gunner.tres`, `mook_brute.tres`,
  `boss_rook.tres`, `boss_bonecrusher.tres`, `boss_plague_doctor.tres`, `grenade.tres`, `explosion.tres`.
- Builds `resources/city_tileset.tres` from `Tile1.png` with two physics layers:
  **solid** (ground tiles, full square) and **one-way** (roof-ledge platform tiles, thin top strip).

### Step 5 — Core gameplay scripts
- **`game.gd` (autoload)** — score, timer, scene switching, and an **event bus** of signals
  (`player_hp_changed`, `boss_started`, `boss_defeated`, `show_message`, `shake_requested`…).
  Gameplay objects emit signals; the HUD and camera just listen. Also `hit_stop()` (tiny freeze on big hits).
- **Player** (`player.gd`): acceleration-based movement, **coyote time** (jump just after leaving a ledge),
  **jump buffering**, **variable jump height**, auto-fire with spread + recoil, magazine & reload,
  grenade throw, drop-through platforms, knockback + 1 s invulnerability flicker, pit death.
- **Camera** (`game_camera.gd`): smoothed follow + screen shake.
- **Projectiles**: one `bullet.gd` used for player bullets, enemy bullets *and* the boss shockwave
  (`from_player` decides who it hurts, `hits_world` lets shockwaves pass through walls); spark particles on impact.
  `grenade.gd` (arc, bounce, fuse) → `explosion.gd` (8-frame blast, area damage, shake).
- **Pickups** (`pickup.gd`): health (+3, soda-can sprite) and grenade (+1); enemies drop them 35 % of the time.

### Step 6 — Enemies and bosses
- **`enemy_base.gd`** — shared by everything hostile: HP, gravity, white hit-flash, contact damage,
  ledge detection (raycast), aiming helpers, death + fade + loot.
- **`mook_gunner.gd`** — aggro range, keeps 60–150 px away, 3-shot bursts (bullets slow enough to jump).
- **`mook_brute.gd`** — walks, then sprints with the `run_attack` animation, axe swing hits ~0.2 s in.
- **`boss_base.gd`** — waits for `activate()`, simple **state machine** (`state` + `state_time`),
  phase 2 at 50 % HP, boss HP bar signals, explosion chain on death, kills leftover summons.
- **`boss_rook.gd`, `boss_bonecrusher.gd`, `boss_plague_doctor.gd`** — the attack patterns in the table above.
- **`boss_arena.gd`** — trigger zone, closes walls, locks camera limits to the arena, spawns the boss,
  2 s intro, unlocks everything and drops a health pickup on death.

### Step 7 — UI
- **`ui_kit.gd`** — helpers: 9-slice panel cut from `asset/UI/UI.png`, icons from `asset/UI/Icons`, styled buttons, dialogs.
- **HUD** (`hud.gd`): 10 heart icons, ammo counter / "RELOAD…", 3 grenade icons, score, timer,
  boss name + animated HP bar with skull icon, big center messages, **pause menu**, **game-over** and **victory** screens
  (keyboard/gamepad focus on the first button).
- **Title screen** (`title.gd`): night-street diorama built from the tileset, the hero facing the 3 bosses, START / QUIT, controls.

### Step 8 — Level builder tool (`tools/build_level.gd` + `.tscn`)
The level layout is data (arrays of pits, platforms, arenas, enemies, pickups in tile units). The tool:
- paints the **TileMapLayers** (`Ground`: pavement row + asphalt; `Platforms`: roof-ledge pieces with end caps; 3 pits),
- places street **buildings** (both facades from the tilesheet), **signs** ("VIDEO RENTAL", "BURGERS"), **posters**, and
  **props** (dumpsters, crates, tires, cones, barrels, trash),
- adds a **sky** (gradient + script-drawn twinkling stars and moon), two **Parallax2D** skyline layers,
  **CPUParticles2D rain**, a night **CanvasModulate**, invisible level bounds,
- instances the player, 3 boss arenas, 19 enemies, 5 pickups and the HUD,
- saves it all as a normal scene: **`scenes/level/level_1.tscn`** (open it in the editor and edit freely).

### Step 9 — Automated testing
- **`tools/playtest.gd`** — a bot that plays the game with simulated input: walks and fights through the street,
  throws a grenade, enters each arena, fights each boss until it dies, and checks that walls open and the camera unlocks,
  then checks the victory screen. Run with `-- death` to test falling in a pit → game over → Retry.
- **`tools/snap.gd`** — opens any scene and saves a screenshot.
- Screenshots are in `tools/screenshots/`.

Last test report:
```
boss 1 KILLED after 11.1s. states seen: idle, walk, burst, hop_fan, reload
boss 2 KILLED after 26.0s. states seen: idle, windup, charge, stunned, leap, swipe
boss 3 KILLED after 23.7s. states seen: idle, grenades, dash, spread, summon
walls open: true, camera limits: 0..3776   (after each boss)
victory overlay shown: true
death test: player dead after falling in pit: true / game over buttons: RETRY, TITLE
```
(The bot has infinite health and stands still shooting, so a human will take longer.)

### Step 10 — Problems found and fixed
| Problem | Cause | Fix |
|---|---|---|
| Level builder: `Identifier not found: Game` | Godot does not load autoloads when running `--script` | Run the builder as a scene (`tools/build_level.tscn`) instead |
| `Cannot infer the type of "b"` | `:=` can't infer from `instantiate().setup()` | Explicit types (`var b: Area2D = …`) |
| `Member "root" redefined` | `root` is a SceneTree property | Renamed to `level_root` |
| Message text off-screen | Anchor preset + manual position conflict | Plain position/size |
| Street looked like one flat wall | Street buildings (z −5) were drawn *behind* the parallax skyline (z 0) | Skyline z −10 / −9, darker blue tints, wider gaps between buildings |
| Sidewalk too tall / bright | 2 pavement rows + camera showed 48 px of ground | 1 pavement row + asphalt, camera bottom 224 → 210, ground tint |
| Plague Doctor unkillable from the ground | Bosses landed on one-way platforms above bullet height | Bosses ignore platforms (`collision_mask = 1`) |
| Gunmen still alive on victory screen | Summoned gunmen outlived the final boss | Boss death kills all `summons` |
| An axe brute followed the player into arena 3 | Spawned too close to the arena | Moved it back 100 px |
| Bosses died too fast (7–25 s vs the bot) | HP too low | HP 40/60/80 → 60/90/120 |
| Title controls text cut off | Line too long for 384 px | Split into two short lines |

---

## 3. Project structure

```
project.godot            settings, input map, autoload
DEV_LOG.md               this file
asset/                   original art (unchanged; + __MACOSX/.gdignore)
resources/
  frames/*.tres          generated SpriteFrames (one per character + grenade + explosion)
  city_tileset.tres      generated TileSet with collisions
scenes/
  ui/title.tscn          main scene
  ui/hud.tscn
  level/level_1.tscn     the level (generated, editable)
  level/boss_arena.tscn
  player/player.tscn
  enemies/mook_gunner.tscn, mook_brute.tscn
  bosses/boss_rook.tscn, boss_bonecrusher.tscn, boss_plague_doctor.tscn
  projectiles/bullet.tscn, shockwave.tscn, grenade.tscn, explosion.tscn
  pickups/pickup.tscn
scripts/                 one folder per area (autoload, player, enemies, bosses, level, ui, ...)
tools/                   build_resources, build_level, playtest, snap (+ screenshots/)
```
About 2,350 lines of GDScript in 24 files, 15 game scenes.

## 4. How to change things
- **Tune numbers** (speed, jump, HP, damage): select the node in its scene → Inspector (they are `@export` variables).
- **Edit the level by hand**: open `scenes/level/level_1.tscn`, select `Ground` / `Platforms` and paint with the TileMap panel;
  drag enemies, pickups and arenas around. *Note:* re-running `build_level` would overwrite hand edits.
- **Edit the level as data**: change the arrays at the top of `tools/build_level.gd`, then run
  `godot --headless res://tools/build_level.tscn`.
- **Re-import sprites** after changing PNGs: `godot --headless --import` then
  `godot --headless --script res://tools/build_resources.gd`.
- **Add a boss**: copy a boss scene, attach a new script that `extends "res://scripts/bosses/boss_base.gd"`,
  write `_boss_ai()`, and put a new entry in `ARENAS`.
- **Run the bot**: `godot --fixed-fps 60 res://tools/playtest.tscn` (add `--headless` for no window).

## 5. Known limits / next ideas
- **No sound**: the pack has no audio. Adding shots, explosions and music would help the game feel a lot more.
- **No pixel font**: `Font.txt` names "DigitalDisco" (dafont link), but the font file isn't included. Godot's default font is used.
  Drop a `.ttf` in and set it in a Theme to change it.
- Unused assets: Character_2 / Character_3 (could be selectable heroes; Character_2 has a **shield** animation),
  Enimies_6, the melee `Attack` animation, UI bars/buttons, PSD files.
- Licence: Craftpix licence, see `asset/Licens.txt` — check it before publishing commercially.
