# Chapter 12 — Game flow, testing & shipping

🎯 **Goals**
* Trace the full game flow: title → level → bosses → end screens → restart.
* Write an **automated playtest bot** that plays the game with simulated input.
* Capture **screenshots** from code.
* Debug with Godot's tools.
* **Export** the game for other people to play.
* Know where to go next.

---

## Lesson 12.1 — The complete game flow

You've built every piece. Here's how they hand control to each other:

```
[Godot starts] → autoload Game created
      │
      ▼
title.tscn  (Game.running = false)
      │ START → Game.start_game(): reset score/time, running = true, unpause, change scene
      ▼
level_1.tscn
  level.gd: camera limits + "DARK CITY" message
  Player ⇄ Enemies (bullets, take_damage, score via Game.add_score)
  BossArena trigger → walls, camera lock, boss spawn, activate after 2 s
      boss_defeated → arena opens walls, gives reward; HUD shows "DEFEATED!"
  …×3…
      │
      ├── player_died → HUD: clock stops, 1.6 s, "YOU DIED" [RETRY][TITLE]
      └── boss_defeated(is_final) → HUD: clock stops, 3 s, "CITY SAVED" [PLAY AGAIN][TITLE]
                │                                  │
     Game.restart_level() ──► start_game()   Game.go_to_title()
```

**Checklist of "flow bugs" this design avoids:**

| Bug | Prevented by |
|---|---|
| Restarting from pause loads a frozen level | `get_tree().paused = false` in `start_game` / `go_to_title` |
| Clock keeps running on the end screen | `Game.running = false` in the HUD handlers |
| Two game-over screens | `if dead: return` guard in `_die()` |
| Pause menu over the victory screen | `_game_over` flag in the HUD |
| Old enemies or bullets survive a restart | `change_scene_to_file` frees the entire level |
| Boss killed during its intro | `active` flag + `take_damage` guard |

## Lesson 12.2 — Why automated playtests?

Every change risks breaking something far away. Tweak bullet masks and the Plague Doctor's
grenades may stop hurting you. Playing all three boss fights by hand after every change takes ten
minutes, so you stop doing it, and bugs creep in.

A **bot** that plays the game and reports what happened takes 2 minutes of machine time and
nothing of yours. Dark City's bot lives in `tools/playtest.gd` / `playtest.tscn`.

### The key idea: simulated input
```gdscript
Input.action_press("move_right")
Input.action_release("move_right")
```
These feed the **same** action system the player script reads with `Input.is_action_pressed`.
The game can't tell a bot from a human, so the bot tests the real code paths.

## Lesson 12.3 — `playtest.gd`, walkthrough

```gdscript
extends Node
## Automated playtest bot (developer tool, not part of the game).
##   godot --fixed-fps 60 res://tools/playtest.tscn            (with screenshots)
##   godot --headless --fixed-fps 60 res://tools/playtest.tscn (logic only)
## It plays the level with simulated input, fights all three bosses and
## prints a report. The player is kept alive (hp refilled) so the run
## always reaches the end, but damage taken is still counted.

const LEVEL := preload("res://scenes/level/level_1.tscn")
const SHOT_DIR := "res://tools/screenshots/"
const ARENA_X := [832.0, 2080.0, 3360.0]

var level: Node
var player: CharacterBody2D
var hits_taken := 0
var log_lines: PackedStringArray = []
var _keep_alive := true
var _headless := DisplayServer.get_name() == "headless"
```
*(from the game)*

* `ARENA_X` = arena tiles 52, 130, 210 × 16. (If you move arenas in `build_level.gd`, update these.)
* `DisplayServer.get_name() == "headless"` detects `--headless`, where there's nothing to screenshot.

```gdscript
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	Game.running = true
	level = LEVEL.instantiate()
	add_child(level)
	player = get_tree().get_first_node_in_group("player")
	Game.player_hp_changed.connect(func(hp: int, max_hp: int) -> void:
		if hp < max_hp: hits_taken += 1)
	Game.boss_defeated.connect(func(n: String, f: bool) -> void: _log("signal boss_defeated: %s final=%s" % [n, f]))
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if _keep_alive and is_instance_valid(player) and not player.dead and player.hp < player.max_hp:
		player.hp = player.max_hp
```
*(from the game)*

* The bot **instances the level as its own child**, so it stays in control of the run.
* **It listens to the same bus** as the HUD, to count hits and log boss kills. The event bus pays
  off again: tests observe the game without hooks inside the game code.
* **A multi-line lambda:** the body continues on the next, indented line.
* **God mode for testing:** HP is refilled every frame so the run always reaches the end, but every
  hit is still **counted** as a difficulty metric.
* `_run.call_deferred()` starts the script once everything is ready.

```gdscript
func _run() -> void:
	if "death" in OS.get_cmdline_user_args():
		await _death_test()
		return
	await _wait(0.5)
	await _shot("01_start")

	# --- Street section: walk right and shoot for a while.
	_log("street 1: walking right + shooting")
	Input.action_press("move_right")
	Input.action_press("shoot")
	for i in 8:
		await _wait(0.5)
		if i % 2 == 0:
			_tap("jump")
		if i == 3:
			await _shot("02_street_fight")
	Input.action_release("move_right")
	Input.action_release("shoot")
	_log("  player x=%d, enemies alive=%d, score=%d" % [player.global_position.x, _alive_enemies(), Game.score])

	_tap("grenade")
	await _wait(0.15)
	await _shot("03_grenade")
	await _wait(1.0)

	# --- Three boss fights.
	for b in 3:
		await _boss_fight(b)

	# --- Victory screen.
	await _wait(4.0)
	await _shot("06_victory")
	var overlay_found := not level.find_children("*", "Button", true, false).is_empty()
	_log("victory overlay shown: %s" % overlay_found)
	_log("TOTAL: score=%d time=%s bosses=%d hits_taken=%d" % [Game.score, Game.format_time(Game.run_time), Game.bosses_defeated, hits_taken])
	...
	_log("PLAYTEST DONE")
	print("\n".join(log_lines))
	get_tree().quit()
```
*(from the game)*

**The whole test is a coroutine.** `await` makes a test **read like a script of actions**: press
right, wait half a second, jump, take a screenshot. Without `await` you'd need a state machine
with timers.

* **Scenarios via command-line arguments:** `-- death` runs a different test.
* **Assertions as log lines:** "victory overlay shown: true". A failing run shows `false` or
  `NOT KILLED`. (Exercise 3 turns these into real pass/fail exit codes.)

```gdscript
func _boss_fight(index: int) -> void:
	var ax: float = ARENA_X[index]
	player.global_position = Vector2(ax + 60.0, 160.0)
	player.velocity = Vector2.ZERO
	await _wait(0.3)
	Input.action_press("move_right")
	await _wait(0.6)
	Input.action_release("move_right")
	await _wait(0.4)
	var boss: Node2D = _find_boss()
	if boss == null:
		_log("BOSS %d: FAILED TO SPAWN" % (index + 1))
		return
	_log("boss %d '%s' spawned (hp %d). Camera limits: %d..%d" % [index + 1, boss.boss_name, boss.max_hp, player.camera.limit_left, player.camera.limit_right])
	...
	while is_instance_valid(boss) and not boss.dead and t < 90.0:
		states[boss.state] = true
		var dx: float = boss.global_position.x - player.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 150.0:
			Input.action_press("move_right" if dx > 0 else "move_left")
		elif absf(dx) < 70.0 and player.global_position.x > ax + 30 and player.global_position.x < ax + 354:
			Input.action_press("move_left" if dx > 0 else "move_right")
		elif signi(int(dx)) != player.facing:
			Input.action_press("move_right" if dx > 0 else "move_left")
		Input.action_press("shoot")
		...
		await _wait(0.1)
		t += 0.1
	...
	_log("  boss %d %s after %.1fs. states seen: %s" % [index + 1, "KILLED" if killed else "NOT KILLED", t, ", ".join(states.keys())])
	...
	_log("  walls open: %s, camera limits: %d..%d" % [arena.get_node("WallRight/Shape").disabled, player.camera.limit_left, player.camera.limit_right])
```
*(from the game, shortened)*

* **Teleport** next to each arena, which skips the street and isolates the boss test.
* **The bot is itself a little AI:** keep 70–150 px from the boss, turn to face it, always shoot,
  jump at random, and throw a grenade every 4 s.
* **It checks the integration points:** the camera limits locked to the arena, which states the
  boss used (proving every attack happens), whether it died within 90 s, and whether the walls
  re-opened and the camera was released.

```gdscript
func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


func _shot(shot_name: String) -> void:
	if _headless:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + shot_name + ".png")
```
*(from the game)*

* **`_tap`** holds a button for **two physics frames**, long enough for
  `is_action_just_pressed` to register in `_physics_process`.
* **`_wait`** respects time scale (last argument `false`), so hit-stops slow the bot exactly like
  they slow the game.
* **Screenshots:** wait until the frame has finished drawing, then grab the viewport's texture as
  an `Image` and save a PNG. These are the images in `tools/screenshots/` and in the README.

### Running it

```bash
godot --fixed-fps 60 res://tools/playtest.tscn          # watch it play + screenshots
godot --headless --fixed-fps 60 res://tools/playtest.tscn   # fast, logic only
godot --fixed-fps 60 res://tools/playtest.tscn -- death  # the death scenario
```

**`--fixed-fps 60`** makes every frame exactly 1/60 s of game time, however fast the machine is.
Runs become **repeatable**, so a test that passes once passes every time (apart from the random
numbers in AI and loot).

## Lesson 12.4 — A screenshot tool: `snap.gd`

```gdscript
extends Node
## Developer tool: opens a scene, waits a moment and saves a screenshot.
##   godot res://tools/snap.tscn -- res://scenes/ui/title.tscn out_name
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	add_child(load(args[0]).instantiate())
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tools/screenshots")
	get_viewport().get_texture().get_image().save_png("res://tools/screenshots/%s.png" % args[1])
	get_tree().quit()
```
*(from the game)*

Eleven lines, and you can screenshot any scene for documentation or a store page. Everything after
`--` on the command line ends up in `OS.get_cmdline_user_args()`.

## Lesson 12.5 — Debugging toolbox

| Tool | How | Use it for |
|---|---|---|
| `print()` / `print_debug()` | in code | quick values. `print_debug` adds file:line |
| `push_warning()` / `push_error()` | in code | problems that should stand out in the debugger |
| `assert(cond, "msg")` | in code | invariants that must hold (only checked in debug builds) |
| `breakpoint` keyword or clicking the gutter | script editor | pause and inspect variables |
| **Remote** scene tree | Scene dock, while running | see live nodes: spawned bullets, code-built UI, bosses |
| **Debug → Visible Collision Shapes** | menu | see hitboxes, triggers, one-way platforms |
| **Debugger → Monitors** | bottom panel | FPS, object count. Spot bullets that never free. |
| **Debugger → Profiler** | bottom panel | which functions eat frame time |

**A debugging habit:** when something breaks, make it **reproducible** first (a playtest scenario,
or a tiny test scene), then fix it, then keep the scenario so it never breaks again.

## Lesson 12.6 — Exporting

1. **Editor → Manage Export Templates → Download and Install.** Templates are the pre-built engine
   binaries your game is packed with, and they must match your Godot version exactly.
2. **Project → Export… → Add…** → *Linux*, *Windows Desktop*, *macOS* or *Web*.
3. **Resources → Filters to exclude:** `tools/*, docs/*`. The game never uses them, so the build
   is smaller.
4. Choose an export path → **Export Project**.

From the command line (after creating presets once in the editor):

```bash
godot --headless --export-release "Linux" build/linux/dark-city.x86_64
godot --headless --export-release "Windows Desktop" build/windows/dark-city.exe
```

**Web builds** need the **Compatibility** renderer (Project Settings → Rendering → Renderer).
This game uses nothing Forward+-specific, so it looks the same.

**Before publishing:** read `asset/Licens.txt` (Craftpix) to make sure your use of the art is
allowed, and credit the artists.

## Lesson 12.7 — Where to go next

You now know enough GDScript and Godot to make your own 2D games. Ideas to grow this one, roughly
in order of difficulty:

| Idea | Skills it practises |
|---|---|
| Sound effects and music (`AudioStreamPlayer` listening to `Game` signals) | signals, audio buses |
| A real pixel font via a `Theme` | resources, theming |
| Character select (Character_2 has a shield) | scenes, inheritance, UI |
| Save best scores and settings (`ConfigFile`) | file I/O |
| A second level with a new tileset section | the level builder, data design |
| Checkpoints before boss arenas | game state, scene flow |
| A fourth enemy and a fourth boss (Enimies_6) | AI, state machines |
| Controller rumble on hits (`Input.start_joy_vibration`) | input API |
| Local co-op (two players, split input) | input devices, camera framing |
| Replace code-built UI with editor scenes + a Theme | editor workflow |
| Port the bot's checks to a unit-test framework (e.g. GUT) | testing |

**Learning resources:**
* The official docs: <https://docs.godotengine.org/en/stable/>. Read *Getting Started*, *2D*, and
  the *GDScript reference*. In the editor, **F1** opens the class reference offline.
* The **class reference** pages for every node used here (`CharacterBody2D`, `Area2D`,
  `TileMapLayer`, `Tween`, `Control`) list every property, method and signal.
* Godot's demo projects: <https://github.com/godotengine/godot-demo-projects>.

---

## 🏋️ Exercises

1. ★ Run the playtest bot with a window and watch it. Then run it headless and compare the time.
2. ★ Use `snap.tscn` to screenshot `scenes/ui/title.tscn` as `my_title.png`.
3. ★★ Turn the bot's log into real **pass/fail**: collect failures in an array (boss not killed,
   walls not open, overlay missing) and quit with `get_tree().quit(1)` if any failed, `quit(0)`
   otherwise. Check the exit code with `echo $?`.
4. ★★ Add a playtest scenario `-- pickups` that teleports the player onto each placed pickup and
   checks that HP or grenades increased.
5. ★★ Export a Linux or Windows build and run it outside the editor. Does the window open at
   1152 × 648?
6. ★★★ Write a GitHub Actions workflow that downloads Godot 4.7 headless and runs the playtest on
   every push (look up the `godot-ci` Docker images or install Godot in the workflow).
7. ★★★ **Capstone:** design and add one complete feature from the "Where to go next" table, from
   design notes to code, a playtest check and updated docs.

## ✅ Solutions

<details><summary>Exercise 1</summary>

Headless is much faster because nothing is rendered. With `--fixed-fps` the in-game results are
the same, only real time differs.
</details>

<details><summary>Exercise 2</summary>

```bash
godot res://tools/snap.tscn -- res://scenes/ui/title.tscn my_title
```
The image appears in `tools/screenshots/my_title.png`.
</details>

<details><summary>Exercise 3</summary>

```gdscript
var failures: PackedStringArray = []

func _check(cond: bool, what: String) -> void:
	if not cond:
		failures.append(what)
		_log("FAIL: " + what)

# in _boss_fight:
_check(killed, "boss %d not killed" % (index + 1))
_check(arena.get_node("WallRight/Shape").disabled, "boss %d walls still closed" % (index + 1))

# in _run, at the end:
_check(overlay_found, "victory overlay missing")
print("\n".join(log_lines))
get_tree().quit(1 if failures.size() > 0 else 0)
```
CI systems treat a non-zero exit code as a failed job.
</details>

<details><summary>Exercise 4</summary>

```gdscript
func _pickup_test() -> void:
	_keep_alive = false
	player.hp = 2
	player.grenades = 0
	await _wait(0.3)
	for p in level.get_node("Pickups").get_children():
		var before := [player.hp, player.grenades]
		player.global_position = p.global_position + Vector2(0, -2)
		await _wait(0.2)
		_log("%s at %s: hp %d→%d, grenades %d→%d" % [p.kind, p.global_position, before[0], player.hp, before[1], player.grenades])
	get_tree().quit()

# in _run():
if "pickups" in OS.get_cmdline_user_args():
	await _pickup_test()
	return
```
(Enemies may interfere. Teleporting is quick, but for a cleaner test you could free
`level.get_node("Enemies")` first.)
</details>

<details><summary>Exercise 5</summary>

Yes. The window size comes from `project.godot`, which is packed into the build. If it's tiny or
huge, check `window_width_override` / `window_height_override`.
</details>

<details><summary>Exercise 6</summary>

A minimal outline (adapt names and versions to what's available when you do it):

```yaml
name: playtest
on: [push]
jobs:
  playtest:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Godot
        run: |
          wget -q https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
          unzip -q Godot_v4.7-stable_linux.x86_64.zip
          mv Godot_v4.7-stable_linux.x86_64 godot
      - run: ./godot --headless --import
      - run: ./godot --headless --fixed-fps 60 res://tools/playtest.tscn
```
Check the exact release file name on Godot's GitHub releases page for the version you use.
</details>

<details><summary>Exercise 7</summary>

Your own design. Use what you've learnt: write it down first (what, why, how it feels), find the
right place in the architecture (a new scene? a new signal on `Game`? a new hook in a base
class?), keep it data-driven, add feedback, and test it automatically.
</details>

---

## 🎓 Course complete

You've rebuilt **Dark City** from an empty folder:

* **GDScript:** types, control flow, functions, collections, classes, inheritance, signals,
  lambdas, `await`, static helpers.
* **Godot:** nodes and scenes, the scene tree, resources, physics bodies and areas, layers and
  masks, tilemaps, cameras, parallax, particles, tweens, UI controls, autoloads, pausing, scene
  changes, tool scripts, exporting.
* **Game development:** feel (coyote time, buffering, hit-stop, shake), readable combat (tells,
  i-frames, colours), AI and state machines, boss design, level design from data, event-driven
  architecture, automated playtesting.

Keep the [cheat sheet](appendix-gdscript-cheatsheet.md) handy, and go make something of your own.
