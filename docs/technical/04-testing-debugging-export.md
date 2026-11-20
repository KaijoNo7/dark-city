# 04 — Testing, debugging & export

## The automated playtest bot

`tools/playtest.gd` plays the game by itself. It fakes button presses with `Input.action_press()`
and `Input.action_release()`, the same API the real input system feeds. The game code can't tell
the difference.

```bash
# with a window (also saves screenshots to tools/screenshots/)
godot --fixed-fps 60 res://tools/playtest.tscn

# headless: logic only, fast, good for CI
godot --headless --fixed-fps 60 res://tools/playtest.tscn

# the "death" scenario: fall into a pit, check the game-over screen, press RETRY
godot --fixed-fps 60 res://tools/playtest.tscn -- death
```

### What a normal run checks

1. The level loads and the player exists (`01_start.png`).
2. **Street 1**: walk right, hold shoot, jump every second step (`02_street_fight.png`), then throw
   a grenade (`03_grenade.png`).
3. **Each of the three bosses**:
   * teleport near the arena and walk into the trigger
   * check the boss spawned and the camera limits locked to the arena (`04_bossN_intro.png`)
   * fight: approach or back off, keep shooting, jump at random, throw a grenade every 4 s
     (`05_bossN_fight.png`)
   * log which **states** the boss went through (so you can see every attack was used)
   * after the kill, check the arena walls opened and the camera limits were restored
4. **Victory**: check the overlay with buttons appeared (`06_victory.png`), then print totals.

The bot keeps the player alive by refilling HP in `_physics_process`, so a run always reaches the
end. It still counts every hit in `hits_taken`, which is a rough difficulty measure.

### Why `--fixed-fps 60`?

Normally `delta` (time since last frame) varies with machine speed. With a fixed frame rate,
timers, bullets and AI behave the same way on every computer. A slow CI machine runs the test
slower in real time, but the simulation is identical.

### Sample output (shape)

```
[playtest] street 1: walking right + shooting
[playtest]   player x=…, enemies alive=…, score=…
[playtest] boss 1 'DEADEYE ROOK' spawned (hp 60). Camera limits: 832..1216
[playtest]   active=true
[playtest]   boss 1 KILLED after …s. states seen: idle, burst, hop_fan, walk, reload
[playtest]   walls open: true, camera limits: 0..3776
…
[playtest] TOTAL: score=… time=… bosses=3 hits_taken=…
[playtest] PLAYTEST DONE
```

---

## Debugging tips for this project

| Symptom | Where to look |
|---|---|
| Editor opens on an empty scene | Godot reopens the scenes that were open last time. Double-click `scenes/level/level_1.tscn` in the FileSystem dock. |
| `title.tscn` / `hud.tscn` look empty in the editor | Normal. Their UI is **built in code** in `_ready()` (`title.gd`, `hud.gd`). Press F6 to run the scene and see it. |
| A bullet passes through an enemy | Check masks: player bullets need bit `4`. See [02 — Input & physics](02-input-and-physics.md). |
| An enemy walks off a ledge | `ground_ahead()` ray mask, or the ledge is narrower than the 12 px look-ahead. |
| HUD shows wrong values at start | The player emits its stats with `call_deferred` so the HUD is ready first. Check the HUD is in the level scene. |
| Hand edits to the level disappeared | `build_level` was re-run. See the warning in [03](03-tools-and-pipeline.md). |
| Sprites look blurry | Check `default_texture_filter = Nearest` and `snap_2d_transforms_to_pixel` ([01](01-project-settings.md)). |

### Editor tools worth knowing

* **Debug → Visible Collision Shapes**: draws every shape and ray while the game runs. This is the
  fastest way to debug hitboxes and one-way platforms.
* **Remote scene tree**: while the game runs, the Scene dock gets a *Remote* tab showing the
  **live** tree. Bullets, spawned bosses and the HUD's code-built controls all appear there.
* **`print()` and `print_debug()`**: output goes to the *Output* panel.
* **Breakpoints**: click left of a line number in the script editor, or write `breakpoint` in code.
* **Debugger → Monitors**: FPS, node count and physics objects. Useful for checking that bullets
  are freed (`queue_free()`).

---

## Exporting a build

1. **Editor → Manage Export Templates → Download and Install** (once per Godot version).
2. **Project → Export… → Add…** and pick a platform (Linux, Windows Desktop, macOS, Web…).
3. Set the export path and press **Export Project**.

Command line (after creating the preset in the editor once):

```bash
godot --headless --export-release "Linux" build/dark-city.x86_64
```

Notes:

* Exclude `tools/` from export if you want a smaller build: in the preset, **Resources →
  Filters to exclude files** → `tools/*`. The game never references those files.
* The **Web** export only supports the *Compatibility* renderer. Switch it in
  **Project Settings → Rendering → Renderer** before exporting for the web. This 2D game doesn't use
  any Forward+-only features, so it looks the same.
* Read `asset/Licens.txt` (Craftpix licence) before publishing.
