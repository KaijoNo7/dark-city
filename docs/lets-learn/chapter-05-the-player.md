# Chapter 5 — The player

🎯 **Goals**
* Build the player scene: `CharacterBody2D`, sprite, collision shape, muzzle, camera.
* Understand **velocity**, **delta time**, **gravity** and `move_and_slide()`.
* Implement responsive platformer movement: acceleration, variable jump height, coyote time,
  jump buffering, dropping through one-way platforms.
* Organise per-frame code into small, ordered functions driven by **countdown timers**.
* Choose animations from state with a **priority list**.

This is the most important chapter of the course. Every action game starts with a character that
feels good to control.

---

## Lesson 5.1 — A test room

You need floor to stand on. Make a quick test scene:

1. **New Scene → 2D Scene**, rename the root `TestRoom`, save as `scenes/test_room.tscn`.
2. Add a child **TileMapLayer**. In the Inspector set **Tile Set** = `resources/city_tileset.tres`.
3. With the TileMapLayer selected, open the **TileMap** panel at the bottom. Pick a pavement tile
   (row 22, the grey stones) and paint a floor across the screen at y ≈ 176. Paint a short row of
   roof-ledge tiles (row 15) higher up as a platform.

> If the tiles have no collision, check that you used tiles listed in `GROUND_TILES` /
> `PLATFORM_TILES`. Only those were created with shapes in chapter 4.

## Lesson 5.2 — The player scene

**New Scene → Other Node → `CharacterBody2D`**, rename it `Player`, and build this tree:

```
Player            CharacterBody2D
├── Sprite        AnimatedSprite2D
├── Shape         CollisionShape2D
├── Muzzle        Marker2D
└── Camera        Camera2D
```

Set these properties in the Inspector:

| Node | Property | Value | Why |
|---|---|---|---|
| Player | Collision → Layer | 2 (player) only | "I am the player" |
| Player | Collision → Mask | 1 (world) + 5 (platforms) | "I stand on these" |
| Player | Floor → Snap Length | 4 | stay glued to the floor on small bumps |
| Player | Groups (Node dock) | `player` | so enemies can find us |
| Sprite | Sprite Frames | `resources/frames/player.tres` | |
| Sprite | Animation / Autoplay | `idle` / `idle` | |
| Sprite | Position | (0, −16) | feet at the origin (frames are 32 tall, feet at the bottom) |
| Shape | Shape | New RectangleShape2D, size (10, 18) | the character's body, not the empty frame around it |
| Shape | Position | (0, −9) | bottom of the box at y = 0 |
| Muzzle | Position | (9, −7) | in front of the gun barrel |
| Camera | Position | (0, −28) | frame slightly above the feet |
| Camera | Position Smoothing → Enabled / Speed | on / 7 | the camera eases after the player |
| Camera | Limit → Smoothed | on | eases into limits instead of snapping |

Save as `scenes/player/player.tscn`.

### Why `CharacterBody2D`?

Godot has three kinds of physics bodies:

| Body | Moved by | Use for |
|---|---|---|
| `StaticBody2D` | nothing (doesn't move) | walls, floors |
| `RigidBody2D` | the physics engine (forces, gravity, bounces) | crates, ragdolls, balls |
| `CharacterBody2D` | **your code** (set `velocity`, call `move_and_slide()`) | players, enemies |

Platformer characters need precise, non-realistic control: instant turns, hanging in the air, no
tumbling. With a `CharacterBody2D` you decide every movement, and the engine resolves collisions.

### Why is the origin at the feet?

Placing a character "on the ground" becomes `position.y = ground_y`, whatever the character's
size. Bosses at 2× size use the same rule. It also makes ground checks and spawn points trivial.

## Lesson 5.3 — Velocity, delta and `move_and_slide`

Attach a new script to `Player`: `scripts/player/player.gd`.

Three ideas run everything:

1. **`velocity`** (a `Vector2` built into `CharacterBody2D`) is the speed in **pixels per second**:
   `velocity.x = 95` means "95 px to the right every second".
2. **`delta`** is the seconds since the last physics frame (≈ 0.0167 at 60 Hz). To change something
   *per second*, multiply by `delta`.
3. **`move_and_slide()`** moves the body by `velocity × delta`, **slides along** walls and floors
   instead of stopping dead, updates `velocity` after collisions (landing sets `velocity.y` to 0),
   and updates `is_on_floor()`, `is_on_wall()` and `is_on_ceiling()`.

The smallest platformer controller looks like this *(example)*:

```gdscript
extends CharacterBody2D

func _physics_process(delta: float) -> void:
	velocity.y += 720.0 * delta                       # gravity
	velocity.x = Input.get_axis("move_left", "move_right") * 95.0
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -265.0
	move_and_slide()
```

Put the player in the test room and press F6. It works, but it feels stiff: instant starts and
stops, a fixed jump height, and jumps lost at ledges. The rest of the chapter fixes each problem,
one technique at a time.

## Lesson 5.4 — Constants, exports and state

The real script begins:

```gdscript
extends CharacterBody2D
## The player (SWAT officer, asset/Characters/Character_1).
## Controls: move, jump, shoot (hold for auto-fire), throw grenade, reload.

const BULLET := preload("res://scenes/projectiles/bullet.tscn")
const GRENADE := preload("res://scenes/projectiles/grenade.tscn")
```
*(from the game)*

> ✋ The bullet and grenade scenes don't exist yet (chapter 7). For now, **leave these two lines
> out**. You'll add them in chapter 7.

```gdscript
@export var speed := 95.0
@export var acceleration := 900.0
@export var jump_velocity := -265.0
@export var gravity := 720.0
@export var max_fall_speed := 380.0
@export var max_hp := 10
@export var mag_size := 12
@export var fire_cooldown := 0.14
@export var reload_time := 0.9
@export var max_grenades := 3
```
*(from the game)*

Every "feel" number is exported, so you can tune it in the Inspector **while the game runs**:
change a value in the remote inspector and see the effect immediately.

**How the numbers were chosen:**
* `speed 95`: crossing the 384 px screen takes about 4 s. That's deliberate pace, room to aim.
* `acceleration 900`: full speed in 95/900 ≈ 0.1 s. Snappy but not robotic.
* `jump_velocity −265`, `gravity 720`: jump height = v²/2g ≈ **49 px ≈ 3 tiles**. The level's
  platforms (2 and 4 tiles up) are designed around this.
* `max_fall_speed 380`: long falls stay readable.

```gdscript
var hp := 0
var ammo := 0
var grenades := 0
var facing := 1
var dead := false

var _fire_timer := 0.0
var _shoot_anim_timer := 0.0
var _reload_timer := 0.0
var _cast_timer := 0.0
var _hurt_timer := 0.0
var _invuln_timer := 0.0
var _coyote_timer := 0.0
var _jump_buffer := 0.0
var _drop_timer := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var camera: Camera2D = $Camera
```
*(from the game)*

* **Public state** (`hp`, `facing`, `dead`) is read by enemies, the HUD and the playtest bot.
* **Private timers** (`_`) are all **countdowns in seconds**. This is the key pattern of the
  whole script.
* `facing` is `1` (right) or `-1` (left). Using ±1 instead of a bool means you can **multiply**
  by it: `Vector2(150 * facing, -190)` throws a grenade the correct way with no `if`.
* `camera` is public because the level and boss arenas need to set its limits.

### 🔤 Language spotlight: the countdown-timer pattern

Instead of creating `Timer` nodes for every cooldown, keep a float and subtract `delta` each frame:

```gdscript
_fire_timer -= delta          # counts down forever; we only care whether it's > 0
...
if _fire_timer <= 0.0:        # ready to fire?
	_fire_timer = fire_cooldown   # start the cooldown
```

| Approach | Pros | Cons |
|---|---|---|
| Float countdown | one line, no nodes, easy to read/reset, testable | you must remember to subtract delta |
| `Timer` node | visible in the editor, emits `timeout` | extra nodes, signal wiring, harder to reset or inspect |
| `get_tree().create_timer()` + `await` | great for one-off sequences | can't be cancelled or queried easily |

For many short, frequently reset cooldowns, floats are the cleanest choice. The game uses `await`
timers for one-off sequences (boss intro, game-over delay). Chapter 6 covers those.

## Lesson 5.5 — `_ready`: starting values

```gdscript
func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	ammo = mag_size
	grenades = max_grenades
	# Let the HUD draw the starting values once it is ready.
	_emit_stats.call_deferred()
```
*(from the game)*

* `add_to_group("player")` duplicates the group set in the editor. It's harmless, and it makes
  the script work even if someone forgets the editor setting.
* `hp = max_hp` is done here, not at declaration, because `max_hp` may be changed **per instance**
  in the Inspector. Exported values are applied *after* declarations run, but before `_ready`.
* **`call_deferred()`**: in the level, the HUD comes *after* the player in the tree, so its
  `_ready` (where it connects to `Game` signals) runs later. If we emitted the stats right now,
  nobody would be listening yet. `call_deferred` postpones the call to the end of the frame, after
  every `_ready` has run.

## Lesson 5.6 — `_physics_process`: the frame, in order

```gdscript
func _physics_process(delta: float) -> void:
	if dead:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return

	_tick_timers(delta)
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_combat()
	move_and_slide()
	_update_animation()

	# Fell into a pit.
	if global_position.y > 320.0:
		hp = 0
		_die()
```
*(from the game)*

> ✋ For now, comment out `_handle_combat()` (`# _handle_combat()`). It arrives in chapter 7.

**Why split into small functions?** `_physics_process` now reads like a table of contents. Each
step is short enough to understand on its own, and the **order** is explicit:

1. **Timers first**, so everything below sees up-to-date cooldowns.
2. **Forces and intentions** (gravity, run input, jump) change `velocity`.
3. **`move_and_slide()`** applies velocity **once**, after all decisions.
4. **Animation last**, so it reflects the final state of this frame (on floor? moving?).

**The dead branch:** a dead player still falls and slides to a stop (so the corpse lands on the
ground), but ignores input. The early `return` skips everything else.

**Pit death:** the ground is at y = 176. Below 320 you've clearly fallen into a pit. A simple
height check is cheaper and more reliable than placing "kill zones" in every pit.

## Lesson 5.7 — Ticking the timers

```gdscript
func _tick_timers(delta: float) -> void:
	_fire_timer -= delta
	_shoot_anim_timer -= delta
	_cast_timer -= delta
	_hurt_timer -= delta
	_jump_buffer -= delta
	_coyote_timer = 0.1 if is_on_floor() else _coyote_timer - delta
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		sprite.visible = fmod(_invuln_timer, 0.12) > 0.05  # flicker while invulnerable
		if _invuln_timer <= 0.0:
			sprite.visible = true
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			ammo = mag_size
			_emit_stats()
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(5, true)
```
*(from the game)*

* **Simple timers** just count down. Going negative is fine, because everything checks `> 0.0`.
* **Coyote timer:** while on the floor it's constantly refilled to 0.1. In the air it drains. So
  for 0.1 s after walking off a ledge it's still positive and you can still jump (Lesson 5.9).
* **Timers with an end event** (`_invuln`, `_reload`, `_drop`) are wrapped in `if timer > 0.0`, so
  the "on finished" code runs **exactly once**, on the frame it crosses zero.
* **Flicker:** `fmod(t, 0.12)` cycles 0 → 0.12 over and over. Visible when the cycle is > 0.05 is
  roughly 58 % on, 42 % off, flipping about 8 times a second. That's the classic "I'm
  invulnerable" blink, with no extra node or shader.
* **Reload finishes** → refill `ammo` and tell the HUD.
* **Drop-through finishes** → see platforms again (Lesson 5.10).

## Lesson 5.8 — Gravity with variable jump height

```gdscript
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g := gravity
		# Releasing jump early = shorter hop (variable jump height).
		if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
			g *= 2.2
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)
```
*(from the game)*

* **Gravity is acceleration:** each second, downward speed grows by `gravity` px/s. So we add
  `gravity * delta` every frame.
* **Variable jump height:** while **rising** (`velocity.y < 0`, since up is negative) *and* the
  jump button is **not held**, gravity is 2.2× stronger. Tap = short hop, hold = full jump. The
  player gets fine control over height with one button.
* **Terminal velocity:** `minf(..., max_fall_speed)` caps the fall speed.

## Lesson 5.9 — Horizontal movement with acceleration

```gdscript
func _handle_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if _hurt_timer > 0.0:
		dir = 0.0  # knocked back, no control for a moment
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target, acceleration * delta)
	if dir != 0.0:
		facing = int(signf(dir))
	sprite.flip_h = facing < 0
	muzzle.position.x = absf(muzzle.position.x) * facing
```
*(from the game)*

* **Target velocity:** where we *want* to be (−95, 0 or +95, or partial for a stick).
* **`move_toward(current, target, acceleration * delta)`:** approach the target by at most 15 px/s
  per frame (900 × 1/60). This one line handles speeding up, slowing down (target 0) **and**
  turning around.
* **Hurt lock:** while knocked back, input is ignored so the knockback velocity (set in
  `take_damage`) can play out.
* **Facing** only changes when there's input, so you keep facing where you last moved.
  `signf` gives ±1.0, and `int()` makes it ±1.
* **Flip** the sprite, and **mirror the muzzle**: `absf(x) * facing` is always +9 or −9, whatever
  it was before. Writing `-muzzle.position.x` instead would flip it *every frame*. `absf` makes
  the operation **idempotent**: doing it twice gives the same result as doing it once.

## Lesson 5.10 — Jumping: buffer, coyote time and drop-through

```gdscript
func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12
	if _jump_buffer > 0.0 and _coyote_timer > 0.0 and _hurt_timer <= 0.0:
		_jump_buffer = 0.0
		_coyote_timer = 0.0
		if Input.is_action_pressed("move_down") and is_on_floor():
			# Down + jump drops through one-way platforms.
			set_collision_mask_value(5, false)
			_drop_timer = 0.25
		else:
			velocity.y = jump_velocity
```
*(from the game)*

This short function holds two classic tricks:

**Jump buffering.** Pressing jump doesn't jump directly. It sets `_jump_buffer = 0.12`, meaning
"the player wants to jump, remember it for 0.12 s". If you press jump 5 frames *before* landing,
the buffer is still positive when you touch down, and you jump. Without it, those presses are
silently lost and the game feels unresponsive.

**Coyote time.** The jump condition is `_coyote_timer > 0.0`, not `is_on_floor()`. You can jump for
0.1 s after running off a ledge, just as a cartoon coyote hangs in the air before falling. Players
don't notice it, but they do notice when it's missing.

Both timers are **consumed** (set to 0) when the jump happens, so one press equals one jump.

**Drop-through:** on the floor + holding down + jump → turn off mask layer 5 (platforms) for 0.25 s.
The body falls through the one-way tile, then `_tick_timers` turns the layer back on. If you were
standing on the *ground* (layer 1), nothing happens, because ground stays solid.

### 🧪 Try it
* Set the coyote time `0.1` to `0.5`. You can now "air-jump" off ledges, which is clearly too
  generous. Set it to `0.0` and try jumping at platform edges. Notice how often you miss.
* Set `2.2` to `1.0` and compare short taps. The short hop disappears.

## Lesson 5.11 — Choosing the animation

```gdscript
func _update_animation() -> void:
	var anim := "idle"
	var moving := absf(velocity.x) > 10.0
	if _hurt_timer > 0.0:
		anim = "hurt"
	elif _cast_timer > 0.0:
		anim = "cast"
	elif _reload_timer > 0.0:
		anim = "recharge"
	elif _shoot_anim_timer > 0.0:
		anim = "walk_shot" if moving else "shot"
	elif not is_on_floor():
		anim = "walk"
	elif moving:
		anim = "walk"
	if sprite.animation != anim:
		sprite.play(anim)
	# In the air: freeze on a "legs apart" walk frame.
	if anim == "walk" and not is_on_floor():
		sprite.pause()
		sprite.frame = 1
	elif not sprite.is_playing() and anim in ["idle", "walk", "shot", "walk_shot"]:
		sprite.play(anim)
```
*(from the game)*

* **Priority list:** the first true condition wins. Hurt beats everything, then actions with
  timers, then movement. The animation is *derived* from state every frame, so it can never get
  stuck. That makes this sturdier than switching animations inside each action.
* `moving` uses a threshold of 10 px/s, so tiny leftover speeds while decelerating don't flicker
  between walk and idle.
* **Only call `play` on change** (`if sprite.animation != anim`).
* **No jump animation in the pack?** We fake one by pausing on walk frame 1 (legs apart) while
  airborne. It's a cheap and convincing improvisation.
* **Resume looping animations:** after the in-air pause, landing must restart walk or idle. The
  last branch restarts any looping animation that isn't playing.

## Lesson 5.12 — Dying and reporting stats

```gdscript
func _die() -> void:
	if dead:
		return
	dead = true
	sprite.visible = true
	sprite.play("dead")
	collision_layer = 0
	velocity = Vector2(-facing * 60.0, -160.0)
	_emit_stats()
	Game.player_died.emit()


func _emit_stats() -> void:
	Game.player_hp_changed.emit(hp, max_hp)
	Game.player_ammo_changed.emit(ammo, mag_size, grenades, _reload_timer > 0.0)
```
*(from the game)*

* **Guard** `if dead: return`: `_die` can be reached from several places (pit, damage). It must
  only run once, or `player_died` would fire twice and show two game-over screens.
* `sprite.visible = true`: if you died mid-flicker, make sure the body is visible.
* `collision_layer = 0`: enemies and bullets stop seeing the corpse.
* **Death hop:** a small backward and upward velocity is a classic, readable "defeated" motion.
* `Game.player_died.emit()`: the player doesn't know about the HUD. It just announces the event.
* `_emit_stats` is the **single place** where the player reports its numbers. Whenever HP, ammo or
  grenades change, call it. The HUD listens (chapter 11).

## Lesson 5.13 — Run it

Instance the player into the test room (drag `player.tscn` into the scene), place it above the
floor, and press F6. You should be able to run, jump, short-hop, coyote-jump, buffer jumps and
drop through the platform.

---

## 🏋️ Exercises

1. ★ Tune the feel: make the hero floatier (gravity 500, jump −230). Then heavier (gravity 1000,
   jump −310). Compute both jump heights with v²/2g. Which matches 3 tiles?
2. ★ Make the hero face left at the start of the level, using only one line in `_ready`.
3. ★★ Add **air control**: use a lower acceleration (e.g. 40 %) while in the air. One line
   changes in `_handle_movement`.
4. ★★ Add a **double jump**: allow one extra jump in the air. You'll need `var _air_jumps := 0`,
   refilled when on the floor.
5. ★★ The pit death height `320.0` is a magic number. Turn it into an `@export var
   death_y := 320.0` with a `##` tooltip.
6. ★★★ Add a **dash**: on `dash` just pressed (action from chapter 3), set `velocity.x = facing *
   300` for 0.15 s, ignore gravity during the dash, and allow it again after a 0.6 s cooldown. Use
   the countdown-timer pattern.
7. ★★★ Add **wall sliding**: when in the air, pushing into a wall (`is_on_wall()`) and falling,
   cap the fall speed at 60.

## ✅ Solutions

<details><summary>Exercise 1</summary>

Floaty: 230² / 1000 ≈ 53 px. Heavy: 310² / 2000 ≈ 48 px. Both are about 3 tiles. Different
gravity/velocity pairs give the **same height** with a different **duration** (floaty ≈ 0.92 s,
heavy ≈ 0.62 s). That's how designers tune "weight" without breaking level geometry.
</details>

<details><summary>Exercise 2</summary>

```gdscript
facing = -1
```
`_handle_movement` sets `flip_h` and the muzzle from `facing` on the first physics frame.
</details>

<details><summary>Exercise 3</summary>

```gdscript
var accel := acceleration if is_on_floor() else acceleration * 0.4
velocity.x = move_toward(velocity.x, target, accel * delta)
```
</details>

<details><summary>Exercise 4</summary>

```gdscript
var _air_jumps := 0

# in _tick_timers:
if is_on_floor():
	_air_jumps = 1

# in _handle_jump, after the coyote branch:
elif _jump_buffer > 0.0 and _air_jumps > 0 and _hurt_timer <= 0.0:
	_jump_buffer = 0.0
	_air_jumps -= 1
	velocity.y = jump_velocity * 0.85
```
Restructure the existing `if` into `if … elif …` so the ground jump takes priority.
</details>

<details><summary>Exercise 5</summary>

```gdscript
@export var death_y := 320.0  ## Falling below this y kills the player (pits).
...
if global_position.y > death_y:
```
</details>

<details><summary>Exercise 6</summary>

```gdscript
var _dash_timer := 0.0
var _dash_cooldown := 0.0

# _tick_timers:
_dash_timer -= delta
_dash_cooldown -= delta

# new function, called after _handle_jump():
func _handle_dash() -> void:
	if Input.is_action_just_pressed("dash") and _dash_cooldown <= 0.0:
		_dash_timer = 0.15
		_dash_cooldown = 0.6
	if _dash_timer > 0.0:
		velocity = Vector2(facing * 300.0, 0.0)

# in _apply_gravity, at the top:
if _dash_timer > 0.0:
	return
```
</details>

<details><summary>Exercise 7</summary>

```gdscript
# at the end of _apply_gravity:
var pushing := Input.get_axis("move_left", "move_right") != 0.0
if is_on_wall() and pushing and velocity.y > 60.0:
	velocity.y = 60.0
```
</details>

---

## The player script so far

<details><summary>Click to see the full chapter-5 version of player.gd</summary>

This is the game's `player.gd` **without** the parts added later: the `BULLET`/`GRENADE` constants
and `_handle_combat`, `_shoot`, `_start_reload`, `_throw_grenade` and `take_damage` (chapter 7),
and `collect` (chapter 8). Everything shown here is identical to the final file.

```gdscript
extends CharacterBody2D
## The player (SWAT officer, asset/Characters/Character_1).
## Controls: move, jump, shoot (hold for auto-fire), throw grenade, reload.

@export var speed := 95.0
@export var acceleration := 900.0
@export var jump_velocity := -265.0
@export var gravity := 720.0
@export var max_fall_speed := 380.0
@export var max_hp := 10
@export var mag_size := 12
@export var fire_cooldown := 0.14
@export var reload_time := 0.9
@export var max_grenades := 3

var hp := 0
var ammo := 0
var grenades := 0
var facing := 1
var dead := false

var _fire_timer := 0.0
var _shoot_anim_timer := 0.0
var _reload_timer := 0.0
var _cast_timer := 0.0
var _hurt_timer := 0.0
var _invuln_timer := 0.0
var _coyote_timer := 0.0
var _jump_buffer := 0.0
var _drop_timer := 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	ammo = mag_size
	grenades = max_grenades
	_emit_stats.call_deferred()


func _physics_process(delta: float) -> void:
	if dead:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return

	_tick_timers(delta)
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	# _handle_combat()   ← chapter 7
	move_and_slide()
	_update_animation()

	if global_position.y > 320.0:
		hp = 0
		_die()

# … _tick_timers, _apply_gravity, _handle_movement, _handle_jump,
#   _update_animation, _die, _emit_stats exactly as in the lessons above …
```
</details>

📝 **Recap**
* `CharacterBody2D` + `velocity` + `move_and_slide()` = character controller. Multiply rates by
  `delta`.
* Order each frame: timers → forces/input → move → animate.
* Float countdown timers are a simple, powerful pattern.
* Feel techniques: acceleration (`move_toward`), variable jump height, coyote time, jump
  buffering, drop-through by toggling a mask bit.
* Derive animation from state with a priority list.
* Report state through `Game` signals. Never reach into the UI.

Next: **[Chapter 6 — Camera, game state & the event bus](chapter-06-camera-and-event-bus.md)**
