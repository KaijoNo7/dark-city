# Chapter 6 — Camera, game state & the event bus

🎯 **Goals**
* Configure a following `Camera2D` with smoothing and **limits**.
* Add **screen shake** driven by a signal.
* Finish the `Game` autoload: scene changes, scoring, messages, shake, **hit-stop**.
* Master **signals** as an architecture tool (the *event bus* / observer pattern).
* Learn **`await`**, coroutines and `Engine.time_scale`.

---

## Lesson 6.1 — The camera as a child of the player

In chapter 5 you added `Camera` as a child of `Player`. Because children move with their parent,
the camera follows the player for free. The settings:

| Property | Value | Effect |
|---|---|---|
| Position | (0, −28) | centres the view a little above the feet, so more sky than ground |
| Position Smoothing | on, speed 7 | the camera *catches up* instead of being glued. Bigger = snappier. |
| Limit Left/Right/Top/Bottom | set in code | the camera never shows outside the level |
| Limit → Smoothed | on | when limits change (boss arena), the camera glides to the new bounds |

### Camera limits
Limits are world coordinates the camera's **view edges** may not cross. The level sets them when
it starts *(from `level.gd`, chapter 10)*:

```gdscript
cam.limit_left = 0
cam.limit_right = level_width     # 3776
cam.limit_top = -400
cam.limit_bottom = ground_bottom  # 210
cam.reset_smoothing()
```

* `limit_bottom = 210` keeps the view's bottom edge at y 210, so you never see below the street
  tiles.
* `reset_smoothing()` jumps the camera straight to its target. Otherwise, on the first frame it
  would glide over from (0, 0).
* Boss arenas temporarily set `limit_left/right` to the arena's edges, which locks the screen
  during the fight (chapter 10).

## Lesson 6.2 — Screen shake

Create `scripts/player/game_camera.gd` and attach it to the `Camera` node:

```gdscript
extends Camera2D
## Follows the player (it is a child of the player) and adds screen shake.
## Boss arenas change the limit_* values to lock the view to the arena.

var _shake := 0.0


func _ready() -> void:
	Game.shake_requested.connect(func(s: float) -> void: _shake = maxf(_shake, s))


func _process(delta: float) -> void:
	if _shake > 0.0:
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
		_shake = move_toward(_shake, 0.0, 20.0 * delta)
	else:
		offset = Vector2.ZERO
```
*(from the game)*

* **`offset`** shifts the *view* without moving the camera node, so smoothing and limits are
  unaffected.
* **Random offset** up to ±`_shake` px each frame, rounded to **whole pixels** with `.round()`.
  In pixel art, sub-pixel shake looks like blur.
* **Decay:** `move_toward(_shake, 0, 20 * delta)` shrinks the shake linearly by 20 px per second.
  A strength-8 shake lasts 0.4 s, and a strength-0.8 shot shake lasts 0.04 s.
* **`maxf`:** if a big explosion (5) and a small shot (0.8) arrive together, keep the bigger one.
  Adding them up would let rapid fire build into an earthquake.
* **`_process` not `_physics_process`:** shake is purely visual, so it runs every *rendered*
  frame for smoothness.
* **It listens to a signal.** The camera doesn't know who shakes it. Anyone calls
  `Game.shake(4.0)` and the camera responds.

## Lesson 6.3 — The event bus pattern

You've now seen both sides: the player **emits** `Game.player_hp_changed` and the camera
**listens** to `Game.shake_requested`. This is the **observer pattern**, centralised in one
**event bus** (the autoload).

```
 Without a bus (tight coupling)          With a bus (loose coupling)

  Boss ──► HUD                             Boss ──emit──►┐
  Boss ──► Arena                           Player ─emit─►│  Game  │──► HUD
  Player ─► HUD                            Arena ──emit─►│ (bus)  │──► Camera
  Player ─► Camera                                       └────────┘──► Arena
  Bullet ─► Camera                         Nobody knows anybody except Game.
```

**Benefits:**
* **No null crashes.** If the HUD isn't in a test scene, the boss still works. Emitting a signal
  that nobody listens to is fine.
* **Easy to extend.** Want sound effects? Add an `Audio` node that listens to `boss_defeated` and
  `player_died`. You don't touch the boss or the player.
* **Readable.** `game.gd` lists every important event in the game in nine lines.

**Costs:**
* Signal flow is less obvious than a direct call. Use the table in
  [architecture/03-communication.md](../architecture/03-communication.md) as a map.
* A bus can grow into a dumping ground. Only put **game-wide** events on it. Events between a
  node and its own children use local signals or direct calls.

## Lesson 6.4 — Finishing `game.gd`

Add the remaining functions to `scripts/autoload/game.gd`:

```gdscript
func start_game() -> void:
	score = 0
	bosses_defeated = 0
	run_time = 0.0
	running = true
	get_tree().paused = false
	get_tree().change_scene_to_file(LEVEL_SCENE)


func restart_level() -> void:
	start_game()


func go_to_title() -> void:
	running = false
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
```
*(from the game)*

* **`change_scene_to_file(path)`** frees the current scene (every node in it) and loads the new
  one. Autoloads survive, and that's exactly why the run state lives here.
* **`get_tree().paused = false`**: if the player restarts from the **pause** menu, the tree is
  still paused. Without this line the new level would load frozen.
* **`restart_level()` just calls `start_game()`.** Why have both? The **names** document intent at
  the call site (`UI.button("RETRY", Game.restart_level)`). If restarting ever needs to differ
  (keep the score, start at a checkpoint), only this function changes.

```gdscript
func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


func shake(strength: float = 3.0) -> void:
	shake_requested.emit(strength)


func message(text: String, seconds: float = 2.0) -> void:
	show_message.emit(text, seconds)
```
*(from the game)*

These **wrappers** make call sites short and safe: `Game.shake(5.0)` instead of
`Game.shake_requested.emit(5.0)`, with a sensible default. `add_score` also makes sure the score
and its signal can never get out of sync.

```gdscript
func format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]
```
*(from the game; explained in chapter 1)*

## Lesson 6.5 — Hit-stop with `await`

```gdscript
## Short "hit-stop" freeze that makes big hits feel heavy.
func hit_stop(seconds: float = 0.05) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0
```
*(from the game)*

**Hit-stop** (also called *hit-pause* or *freeze frame*) is a tiny slow-motion moment when
something big happens. Fighting games use it on every punch. It sells impact like nothing else.

### `Engine.time_scale`
A global multiplier on game time. At 0.05, `delta` becomes 5 % of normal: physics, animations and
timers all crawl. Rendering continues, so the frozen moment is visible.

### 🔤 Language spotlight: `await`
`await` **pauses the current function** until a signal is emitted. The rest of the game keeps
running, and the function resumes where it left off.

```gdscript
print("A")
await get_tree().create_timer(1.0).timeout    # wait 1 second
print("B")                                     # runs 1 second later
```

A function that contains `await` is a **coroutine**. Calling it starts it, and it returns at the
first `await`. The caller does **not** wait unless it also writes `await`:

```gdscript
Game.hit_stop(0.06)      # fire and forget: we don't wait for it
do_more_stuff()          # runs immediately
```

That's exactly what `player.gd → take_damage` does: it starts the freeze and carries on.

### `create_timer(time, process_always, process_in_physics, ignore_time_scale)`
`SceneTree.create_timer` makes a one-shot timer with no node needed, and returns a `SceneTreeTimer`
with a `timeout` signal. The arguments matter here:

| Argument | Value | Why |
|---|---|---|
| `time_sec` | `seconds` | duration |
| `process_always` | `true` | keep counting even if the tree is paused |
| `process_in_physics` | `false` | count in idle frames |
| `ignore_time_scale` | **`true`** | **count real seconds.** At time scale 0.05, a normal 0.06 s timer would last 1.2 s! |

### 🧪 Try it
Temporarily change `0.05` to `0.0` (a full freeze) and `seconds` to `0.5`. Get hit in-game: half a
second of total stillness. Too much, but it shows the effect. Restore the values.

## Lesson 6.6 — Await patterns you'll see later

```gdscript
# 1. Delay, then act (boss intro, game over screen):
await get_tree().create_timer(2.0).timeout
if is_instance_valid(_boss):
	_boss.activate()
```
*(from `boss_arena.gd`)*

> ⚠️ After any `await`, the world may have changed: the boss may have died, or the scene may have
> been replaced. **Re-check** with `is_instance_valid` before using objects.

```gdscript
# 2. Wait for physics to update (overlap lists are filled during the physics step):
await get_tree().physics_frame
await get_tree().physics_frame
```
*(from `explosion.gd`)*

```gdscript
# 3. Wait for the frame to finish drawing (screenshots):
await RenderingServer.frame_post_draw
```
*(from `snap.gd`)*

```gdscript
# 4. Wait for any signal:
await $Sprite.animation_finished
```

## Lesson 6.7 — Lambdas and `bind`

You connected the shake with a lambda:

```gdscript
Game.shake_requested.connect(func(s: float) -> void: _shake = maxf(_shake, s))
```

Lambdas **capture** the variables around them. Here it uses `_shake`, a member of the camera, so
it modifies the camera's own field.

Another tool you'll meet is **`bind`**, which pre-fills arguments of a callable:

```gdscript
get_tree().scene_changed.connect(Game.message.bind("retry ok", 1.0))
```
*(from `playtest.gd`)*. When the scene changes, `Game.message("retry ok", 1.0)` is called.

| Tool | Use when |
|---|---|
| Named method `_on_x` | the handler is more than a line, or reused |
| Lambda `func(...): ...` | one short line, used once |
| `method.bind(args)` | the handler exists but needs extra fixed arguments |

---

## 🏋️ Exercises

1. ★ In the test room, add a script that calls `Game.shake(8.0)` when you press **R**. Compare
   strengths 1, 3 and 8.
2. ★ Change the shake decay from 20 to 60, then to 5. Describe the difference in feel.
3. ★★ Make the shake **directional**: add `Game.shake_dir(strength, dir: Vector2)` and a new
   signal, and make the camera offset mostly along `dir`. (A gun's recoil kicks backwards.)
4. ★★ Write a coroutine `count_down()` in a test script that prints 3, 2, 1, "GO!" one second
   apart, using `await`. Call it from `_ready`.
5. ★★ Write `Game.slow_motion(scale, seconds)`, a general version of `hit_stop`. Then make
   `hit_stop` call it.
6. ★★★ Add a `paused_changed(paused: bool)` signal to `Game` and a `set_paused(value)` function
   that sets `get_tree().paused` and emits it. Why might the HUD and an audio manager both want
   this signal?
7. ★★★ **Spot the bug:** a student writes `hit_stop` with `create_timer(seconds)` (no other
   arguments). What happens in game, and why?

## ✅ Solutions

<details><summary>Exercise 1</summary>

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reload"):
		Game.shake(8.0)
```
</details>

<details><summary>Exercise 2</summary>

60: very short, sharp jolts, a "snappy" feel. 5: long, wobbly shaking that quickly becomes
nauseating. 20 is a middle ground.
</details>

<details><summary>Exercise 3</summary>

```gdscript
# game.gd
signal shake_dir_requested(strength: float, dir: Vector2)
func shake_dir(strength: float, dir: Vector2) -> void:
	shake_dir_requested.emit(strength, dir.normalized())

# game_camera.gd
var _dir := Vector2.ZERO
func _ready() -> void:
	Game.shake_requested.connect(func(s: float) -> void: _shake = maxf(_shake, s); _dir = Vector2.ZERO)
	Game.shake_dir_requested.connect(func(s: float, d: Vector2) -> void: _shake = maxf(_shake, s); _dir = d)

func _process(delta: float) -> void:
	if _shake > 0.0:
		var rnd := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		if _dir != Vector2.ZERO:
			rnd = _dir * randf_range(0.0, _shake) + rnd * 0.3
		offset = rnd.round()
		_shake = move_toward(_shake, 0.0, 20.0 * delta)
	else:
		offset = Vector2.ZERO
```
(A semicolon joins two statements on one line inside a lambda.)
</details>

<details><summary>Exercise 4</summary>

```gdscript
func _ready() -> void:
	count_down()

func count_down() -> void:
	for n in [3, 2, 1]:
		print(n)
		await get_tree().create_timer(1.0).timeout
	print("GO!")
```
</details>

<details><summary>Exercise 5</summary>

```gdscript
func slow_motion(scale: float, seconds: float) -> void:
	Engine.time_scale = scale
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0

func hit_stop(seconds: float = 0.05) -> void:
	slow_motion(0.05, seconds)
```
</details>

<details><summary>Exercise 6</summary>

```gdscript
signal paused_changed(paused: bool)

func set_paused(value: bool) -> void:
	get_tree().paused = value
	paused_changed.emit(value)
```
The HUD shows or hides the pause dialog, and an audio manager could lower the music volume. Both
react to the same event without knowing about each other.
</details>

<details><summary>Exercise 7</summary>

The timer would respect `Engine.time_scale`, which is 0.05. A 0.06 s hit-stop would last
0.06 / 0.05 = **1.2 seconds** of real time, and the game would feel like it lags every time you're
hit. `ignore_time_scale = true` is essential.
</details>

---

📝 **Recap**
* A camera as a child follows for free. Use smoothing, limits and `reset_smoothing()`.
* Shake = random rounded `offset`, keep the max, decay with `move_toward`.
* Event bus = one autoload with signals. Emitters and listeners never reference each other.
* `change_scene_to_file` frees the scene. Only autoloads persist. Unpause before switching.
* `await signal` pauses a function. Re-check objects afterwards. A coroutine's caller doesn't
  wait unless it awaits too.
* `Engine.time_scale` + a real-time timer = hit-stop.

Next: **[Chapter 7 — Projectiles & combat](chapter-07-projectiles-and-combat.md)**
