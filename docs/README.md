# Dark City — Documentation

Welcome to the documentation for **Dark City**, a 2D pixel-art run-and-gun platformer built with
**Godot 4.7** and **GDScript**: one night, one street, three bosses.

This folder is organised so you can read it in two ways:

* **As a reference.** Jump straight to the section you need: settings, scenes, a script's API,
  how the sprites were cut.
* **As a course.** [Let's learn](lets-learn/README.md) rebuilds the whole game from an empty
  folder, one lesson at a time, and teaches the GDScript language along the way.

---

## Map of the documentation

| Section | What it covers | Start here |
|---|---|---|
| **Technical** | Engine version, project settings, rendering, input map, physics layers, tool scripts, command-line usage, testing, exporting | [technical/README.md](technical/README.md) |
| **Architecture** | Folder layout, scene trees, the `Game` event bus, the damage/collect contracts, inheritance, a reference for every script | [architecture/README.md](architecture/README.md) |
| **Graphics** | The Craftpix art pack, sprite sheets and animations, the tileset, level art, parallax, particles, the UI kit, colour palette | [graphics/README.md](graphics/README.md) |
| **Gameplay** | Game design, controls, customisation, saving, enemies, bosses, scoring, and every number you can tune | [gameplay/README.md](gameplay/README.md) |
| **Audio** | Music, sound effects, buses, the `Audio` autoload, and how the soundtrack is synthesised | [audio/README.md](audio/README.md) |
| **Let's learn** | A complete step-by-step course (16 chapters) that builds this game from scratch and teaches GDScript | [lets-learn/README.md](lets-learn/README.md) |

### Full file list

```
docs/
├── README.md                          ← you are here
├── technical/
│   ├── README.md
│   ├── 01-project-settings.md         display, rendering, pixel-perfect setup
│   ├── 02-input-and-physics.md        input map, physics layers & masks (bit maths)
│   ├── 03-tools-and-pipeline.md       build_resources, build_level, snap, menu_shots, audio tools, CLI
│   ├── 04-testing-debugging-export.md playtest bot (incl. save test), debugging tips, exporting
│   └── 05-settings-saves-controllers.md every option, save format, gamepad detection, rebinding
├── architecture/
│   ├── README.md
│   ├── 01-overview.md                 folder layout, big picture, design principles
│   ├── 02-scenes.md                   every scene's node tree, explained
│   ├── 03-communication.md            event bus, groups, duck-typed contracts
│   ├── 04-script-reference.md         every script: purpose, exports, methods
│   └── 05-menus-and-services.md       Settings/Audio/SaveGame autoloads, menus, intro
├── graphics/
│   ├── README.md
│   ├── 01-art-pack.md                 what is in asset/ and what is used
│   ├── 02-sprites-and-animation.md    SpriteFrames, frame sizes, anchoring, flipping
│   ├── 03-tiles-and-level-art.md      TileSet, collision polygons, parallax, decor
│   └── 04-ui-effects-palette.md       UI kit, HUD, intro, title, menus, post-process, weather, colours
├── gameplay/
│   ├── README.md
│   ├── 01-game-design.md              loop, controls, level, enemies, bosses
│   └── 02-tuning-reference.md         every @export number and where it lives
├── audio/
│   └── README.md                      music, sound effects, Audio autoload, the synthesiser
└── lets-learn/
    ├── README.md                                syllabus & how to study
    ├── chapter-00-before-you-start.md           install, editor, nodes & scenes
    ├── chapter-01-gdscript-basics.md            variables, types, operators, control flow, functions
    ├── chapter-02-gdscript-objects-and-nodes.md collections, classes, scene tree, lifecycle, signals
    ├── chapter-03-project-setup.md              pixel-perfect settings, input map, bitmasks, autoload
    ├── chapter-04-asset-pipeline.md             SpriteFrames, TileSet, tool scripts
    ├── chapter-05-the-player.md                 CharacterBody2D, platformer feel, animation
    ├── chapter-06-camera-and-event-bus.md       camera, shake, signals, await, hit-stop
    ├── chapter-07-projectiles-and-combat.md     bullets, grenades, explosions, duck typing
    ├── chapter-08-enemies-and-inheritance.md    base classes, AI, raycasts, tweens, pickups
    ├── chapter-09-bosses-and-state-machines.md  FSMs, phases, ballistics, boss design
    ├── chapter-10-building-the-level.md         tilemaps from code, parallax, _draw, arenas
    ├── chapter-11-user-interface.md             Controls, UI kit, HUD, pause, title screen
    ├── chapter-12-game-flow-testing-shipping.md playtest bot, debugging, export, next steps
    ├── chapter-13-menus-settings-and-saves.md   settings, rebinding, controllers, save/load, customisation
    ├── chapter-14-audio.md                      sourcing SFX, synthesising music, the Audio autoload
    ├── chapter-15-the-intro.md                  the intro cinematic, animated title, stage card
    └── appendix-gdscript-cheatsheet.md          quick reference & glossary
```

---

## Quick facts

| | |
|---|---|
| Engine | Godot **4.7** (Forward+ renderer) |
| Language | GDScript (about 4,300 lines across 30 game scripts), plus a Python music generator |
| Base resolution | 384 × 216 px, shown at ×3 (1152 × 648) with integer scaling |
| Main scene | `res://scenes/ui/intro.tscn` (then the title) |
| Autoloads | `Settings`, `Audio`, `SaveGame`, `Game` (in `res://scripts/autoload/`) |
| Level | 1 street, 3,776 px long (236 tiles of 16 px), with 3 boss arenas |
| Enemies | 2 regular types (Gunner, Brute) and 3 bosses (Deadeye Rook, Bonecrusher, The Plague Doctor) |
| Art | Craftpix city pack in `asset/` (see `asset/Licens.txt`) |
| Audio | Original synthesised music; CC0 sound effects by Juhani Junkala |
| Controllers | Xbox, PlayStation 2 (USB adapter) / 3 / 4 / 5, Switch, generic, all rebindable |

## Conventions used in these docs

* `res://…` paths are Godot project paths. `res://` is the folder that contains `project.godot`.
* `file.gd:42` points to line 42 of a file.
* **Layer** numbers (1–5) are the names shown in the editor. **Bit values** (1, 2, 4, 8, 16) are
  what the code writes. The difference is explained in
  [technical/02-input-and-physics.md](technical/02-input-and-physics.md).
* Code blocks marked `gdscript` are real code from the project unless the text says they are an example.
