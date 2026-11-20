# Let's learn: build *Dark City* from scratch

A complete course in **Godot 4** and **GDScript**, taught by building a real, finished game: a
pixel-art run-and-gun with a player, enemies, three bosses, a level, a HUD, menus, settings,
controller support, save games, sound and an intro cinematic.

You will start with an empty folder and end with the game in this repository. Every line of code
is explained: **what** it does, **why** it is written that way, and **what else** you could have
done. The GDScript language is taught alongside, so by the end you will know the language and the
engine well enough to make your own games.

---

## Who this course is for

* **Complete beginners to Godot.** You've never opened the editor.
* **Beginners to programming.** Chapters 1 and 2 teach GDScript from zero: variables, functions,
  loops, classes.
* **Programmers from other languages** (Python, C#, JavaScript…). Skim chapters 1–2 using the
  "Coming from another language?" notes, then dive into the game.

You need a computer that runs Godot 4.7, and patience. Budget about **30–50 hours** for chapters
0–12 with exercises, and another **10–15 hours** for the bonus chapters 13–15.

## How each chapter is built

| Part | Purpose |
|---|---|
| 🎯 **Goals** | What you'll be able to do by the end |
| 📖 **Lessons** | Numbered lessons (3.1, 3.2…). Concept, then code from the game, then why it's done that way |
| 🔤 **Language spotlight** | A GDScript feature explained in depth, with standalone examples |
| 🧪 **Try it** | Small experiments to run right away: change a number, see what happens |
| 🏋️ **Exercises** | Practice problems, graded ★ (easy) to ★★★ (challenging) |
| ✅ **Solutions** | At the end of each chapter, hidden in collapsible blocks. Try first! |
| 📝 **Recap** | What to remember |

## Syllabus

| # | Chapter | You will learn | Game code built |
|---|---|---|---|
| 0 | [Before you start](chapter-00-before-you-start.md) | Installing Godot, the editor, nodes and scenes, how to study | an empty project |
| 1 | [GDScript basics](chapter-01-gdscript-basics.md) | Variables, types, operators, `if`/`match`, loops, functions | practice scripts |
| 2 | [GDScript objects, nodes & scenes](chapter-02-gdscript-objects-and-nodes.md) | Arrays, dictionaries, strings, classes, inheritance, the scene tree, lifecycle callbacks, signals | practice scripts |
| 3 | [Project setup](chapter-03-project-setup.md) | Pixel-perfect settings, input map, physics layers and bitmasks, autoloads | `project.godot`, `game.gd` (first version) |
| 4 | [The asset pipeline](chapter-04-asset-pipeline.md) | Resources, `SpriteFrames`, `AtlasTexture`, `TileSet`, tool scripts, `DirAccess`, `ResourceSaver` | `tools/build_resources.gd` |
| 5 | [The player](chapter-05-the-player.md) | `CharacterBody2D`, `_physics_process`, delta time, gravity, input, coyote time, jump buffering, animation | `player.tscn`, `player.gd` |
| 6 | [Camera, game state & the event bus](chapter-06-camera-and-event-bus.md) | `Camera2D`, signals in depth, lambdas, `await`, screen shake, hit-stop | `game_camera.gd`, full `game.gd` |
| 7 | [Projectiles & combat](chapter-07-projectiles-and-combat.md) | `Area2D`, `preload`/`instantiate`, method chaining, duck typing, particles, `call_deferred`, bouncing physics | bullet, grenade, explosion, player combat |
| 8 | [Enemies & inheritance](chapter-08-enemies-and-inheritance.md) | Base classes, `class_name`, virtual methods, `super`, raycasts, tweens, loot, pickups | `enemy_base.gd`, gunner, brute, pickup |
| 9 | [Bosses & state machines](chapter-09-bosses-and-state-machines.md) | Finite state machines with `match`, phases, attack patterns, trigonometry, ballistics | `boss_base.gd` + 3 bosses |
| 10 | [Building the level](chapter-10-building-the-level.md) | `TileMapLayer`, procedural decoration, seeded RNG, `PackedScene.pack`, parallax, custom `_draw`, particles, boss arenas | `build_level.gd`, `level.gd`, `stars.gd`, `boss_arena.gd` |
| 11 | [User interface](chapter-11-user-interface.md) | `Control` nodes, `CanvasLayer`, building UI in code, static helper libraries, `Callable`, styles, focus, pause | `ui_kit.gd`, `hud.gd`, `title.gd` |
| 12 | [Game flow, testing & shipping](chapter-12-game-flow-testing-shipping.md) | Scene changes, pausing, automated playtests, screenshots, exporting, where to go next | `playtest.gd`, `snap.gd`, an exported build |
| 13 | [Menus, settings, controllers & save games](chapter-13-menus-settings-and-saves.md) | A settings system with `ConfigFile`, debouncing, window/resolution/V-Sync in code, a post-processing shader, runtime `InputMap` rebinding, gamepad brand detection (Xbox, PS2–PS5), a reusable settings-row widget, input order (`_input` / `_gui_input` / `_unhandled_input`), JSON save games across scene changes, character customisation | `settings.gd`, `pad_info.gd`, `setting_row.gd`, `options_menu.gd`, `save_game.gd`, `customize_menu.gd`, pause menu |
| 14 | [Audio](chapter-14-audio.md) | Licences, scripted asset import with ffmpeg, buses and decibels, an `Audio` autoload (pools, cross-fades, positional sound, ambience, pause muffle), and synthesising music with numpy (additive synthesis, envelopes, drums, seamless loops, reverb) | `import_sfx.sh`, `audio.gd`, `compose_music.py` |
| 15 | [The intro, a living title screen & the stage card](chapter-15-the-intro.md) | Directing a cutscene with `await`, tweens in depth (parallel, chain, loops, `tween_method`, easing, kill), letterbox, typewriter, silhouettes, parallax, logo slam, clean skipping, lightning | `intro.gd`, `city_backdrop.gd`, `weather.gd`, `title.gd`, stage card |
| A | [Appendix: GDScript cheat sheet & glossary](appendix-gdscript-cheatsheet.md) | Quick reference for everything above | |

## How to study

1. **Type the code, don't paste it.** Typing builds muscle memory and makes you notice details.
2. **Run often.** After every lesson, press F5 or F6 and see the change.
3. **Break things on purpose.** Change a number to something silly (gravity = 50, speed = 2000).
   Seeing what breaks teaches you what each line does.
4. **Do the exercises before reading solutions.** Struggling for 10 minutes is where learning
   happens.
5. **Keep the reference docs open.** The [architecture](../architecture/README.md) and
   [graphics](../graphics/README.md) sections are the "map". This course is the "journey".
6. **Use version control.** Commit after each chapter (`git commit -am "chapter 5 done"`), so you
   can always go back.

## Two ways to follow along

* **From scratch (recommended).** Create a new empty project in chapter 0, copy the `asset/`
  folder into it, and build everything yourself.
* **Read with the finished project.** Open this repository and read each script as the lesson
  explains it. Faster, but you'll learn less.

Ready? Start with **[Chapter 0 — Before you start](chapter-00-before-you-start.md)**.
