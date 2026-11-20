# Chapter 1 — GDScript basics

🎯 **Goals**
* Store data in variables and constants, and understand GDScript's type system.
* Compute with operators, including the integer and float traps.
* Make decisions with `if`, `elif`, `else` and `match`.
* Repeat work with `for` and `while`.
* Write functions with parameters, default values and return types.
* Recognise each of these in Dark City's code.

> **How to practise in this chapter:** create a scene `practice.tscn` with a single `Node` root
> and a script `practice.gd`. Put example code inside `_ready()` and press **F6**. Output appears
> in the **Output** panel.

```gdscript
extends Node

func _ready() -> void:
	# your experiments go here
	pass
```

`pass` means "do nothing". You need it when a block must exist but has no code yet.

---

## Lesson 1.1 — Comments

```gdscript
# A single-line comment. Godot ignores everything after # on a line.

## A DOC comment (two #). Placed above a script, variable or function,
## it appears in the editor's built-in help and in tooltips.
```

Dark City uses `##` doc comments at the top of every script to say what it's for:

```gdscript
extends CharacterBody2D
## The player (SWAT officer, asset/Characters/Character_1).
## Controls: move, jump, shoot (hold for auto-fire), throw grenade, reload.
```
*(from the game: `player.gd`)*

**Why:** a good comment explains *why*, not *what*. `hp -= 1  # subtract one` is useless.
`# Releasing jump early = shorter hop (variable jump height).` tells you the reason the code exists.

## Lesson 1.2 — Variables

A **variable** is a named box holding a value that can change.

```gdscript
var hp = 10
var player_name = "Ada"
var speed = 95.5
var dead = false

hp = hp - 3          # now 7
print(hp)            # 7
```

### The built-in types you'll use most

| Type | Example values | Used in the game for |
|---|---|---|
| `int` | `0`, `10`, `-3`, `1_000_000` | HP, ammo, score, frame indices |
| `float` | `0.5`, `95.0`, `-265.0`, `1e3` | speeds, timers, positions |
| `bool` | `true`, `false` | `dead`, `active`, `expires` |
| `String` | `"idle"`, `'BOSS'` | animation names, messages |
| `Vector2` | `Vector2(10, -16)` | positions, velocities, directions |
| `Vector2i` | `Vector2i(3, 22)` | tile coordinates (integers only) |
| `Color` | `Color(1, 0.72, 0.2)` | tints, UI colours (r, g, b, alpha from 0 to 1) |
| `Rect2` | `Rect2(16, 144, 128, 192)` | regions of a sprite sheet (x, y, width, height) |
| `Array` | `[1, 2, 3]` | lists (chapter 2) |
| `Dictionary` | `{"idle": 6.0}` | lookup tables (chapter 2) |
| `null` | `null` | "no value / no object" |

## Lesson 1.3 — Static typing: three ways to declare

GDScript is **dynamically typed** by default: a variable can hold anything. But you can, and in
this project always do, give variables **types**:

```gdscript
var a = 10            # dynamic: could later hold "hello"
var b: int = 10       # explicit type: can only ever hold an int
var c := 10           # inferred type: ":=" means "type = whatever the value is" → int
```

Dark City uses `:=` almost everywhere:

```gdscript
var hp := 0
var facing := 1
var dead := false
var _fire_timer := 0.0
```
*(from the game: `player.gd`)*

**Why use types?**
1. **Errors at write time.** `var hp := 0` then `hp = "lots"` is underlined red immediately
   instead of crashing mid-game.
2. **Autocompletion.** The editor knows `hp` is an `int` and suggests the right methods.
3. **Speed.** Typed code runs faster: Godot can use optimised instructions.

> ⚠️ **The `0` vs `0.0` trap.** `var t := 0` makes an **int**. If you later do `t += delta`
> (a float), you get an error. That's why timers are written `0.0`:
> `var _fire_timer := 0.0`.

When the value doesn't tell the type (for example a node that doesn't exist yet), use an
explicit type:

```gdscript
var player: Node2D                    # starts as null, will hold a Node2D
var _message_tween: Tween
```
*(from the game: `enemy_base.gd`, `hud.gd`)*

### 🔤 Language spotlight: naming conventions

| Thing | Style | Examples from the game |
|---|---|---|
| variables, functions | `snake_case` | `max_hp`, `take_damage()` |
| private (internal) members | leading `_` | `_fire_timer`, `_shoot()` |
| constants | `UPPER_SNAKE_CASE` | `BULLET`, `TITLE_SCENE` |
| classes, node types | `PascalCase` | `EnemyBase`, `CharacterBody2D` |
| signals | past tense, `snake_case` | `player_died`, `boss_defeated` |
| files | `snake_case.gd` | `boss_plague_doctor.gd` |

The leading underscore is only a **convention**. GDScript doesn't enforce privacy. It tells
readers "don't touch this from outside". Godot's own callbacks (`_ready`, `_process`) also start
with `_` because *you* don't call them. The engine does.

## Lesson 1.4 — Constants

A **constant** never changes. Use `const`:

```gdscript
const TITLE_SCENE := "res://scenes/ui/title.tscn"
const LEVEL_SCENE := "res://scenes/level/level_1.tscn"
```
*(from the game: `game.gd`)*

```gdscript
const T := 16                   # tile size in pixels
const GROUND_ROW := 11          # top of the ground = y 176
const LEVEL_TILES := 236        # 236 * 16 = 3776 px
```
*(from the game: `build_level.gd`)*

**Why constants?**
* **No magic numbers.** `GROUND_ROW * T` explains itself, while `176` doesn't.
* **One place to change.** Want a longer level? Change `LEVEL_TILES` once.
* **Safety.** Assigning to a constant is an error.

## Lesson 1.5 — Operators

### Arithmetic
| Operator | Meaning | Example | Result |
|---|---|---|---|
| `+ - *` | add, subtract, multiply | `3 + 4 * 2` | `11` |
| `/` | divide | `7 / 2` → **`3`** (ints!), `7 / 2.0` → `3.5` | |
| `%` | remainder (ints) | `125 % 60` | `5` |
| `-x` | negate | `-facing` | |
| `**` | power | `2 ** 4` | `16` |

> ⚠️ **Integer division.** If both sides are `int`, `/` throws away the fraction: `7 / 2 == 3`.
> The game uses this on purpose to turn seconds into minutes:
>
> ```gdscript
> func format_time(t: float) -> String:
> 	var m := int(t) / 60
> 	var s := int(t) % 60
> 	return "%02d:%02d" % [m, s]
> ```
> *(from the game: `game.gd`)*. `t = 125.7` → `int(t) = 125` → `m = 2`, `s = 5` → `"02:05"`.
> Godot shows a warning ("integer division") to make sure you meant it.
>
> And here's a case where the game *avoids* integer division:
> `BOSS_BAR_W * hp / float(_boss_max)`. Converting with `float()` keeps the fraction
> *(from `hud.gd`)*.

### Compound assignment
```gdscript
hp -= amount        # same as hp = hp - amount
score += 100
velocity.x *= 0.7   # ground friction on a bouncing grenade
```

### Comparison (result is `bool`)
`==` equal, `!=` not equal, `<`, `>`, `<=`, `>=`

### Logic
| Operator | Also written | Meaning |
|---|---|---|
| `and` | `&&` | both true |
| `or` | `\|\|` | at least one true |
| `not` | `!` | invert |

```gdscript
if dead or _invuln_timer > 0.0:
	return
```
*(from the game: `player.gd → take_damage`)*

`and` / `or` **short-circuit**: if the left side already decides the answer, the right side
isn't evaluated. The game relies on it:

```gdscript
return is_instance_valid(player) and not player.dead
```
*(from `enemy_base.gd`)*. If `player` was freed, `is_instance_valid` is false and
`player.dead` is never touched, so there is no crash.

### Bitwise (used for collision masks, chapter 3)
`|` OR, `&` AND, `<<` shift left: `1 | 16 == 17`, `1 << 4 == 16`.

### Type conversion
```gdscript
int(3.9)        # 3   (truncates toward zero)
float(7)        # 7.0
str(42)         # "42"
int("12")       # 12
```

## Lesson 1.6 — Decisions: `if`, `elif`, `else`

```gdscript
if condition:
	# runs when condition is true
elif other_condition:
	# runs when the first was false and this is true
else:
	# runs when everything above was false
```

Real example, choosing the player's animation by priority:

```gdscript
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
```
*(from the game: `player.gd → _update_animation`)*

**Why this shape?** Exactly one branch runs, and the order is the priority. Being hurt beats
everything, then throwing, then reloading, and so on. Reordering the branches changes the game's
behaviour.

### The conditional (ternary) expression
`value_if_true if condition else value_if_false`. It's an *expression*, so it produces a value:

```gdscript
anim = "walk_shot" if moving else "shot"
_coyote_timer = 0.1 if is_on_floor() else _coyote_timer - delta
collision_mask = (1 if hits_world else 0) | (4 if from_player else 2)
```
*(from `player.gd` and `bullet.gd`)*

### Early return ("guard clause")
Instead of nesting everything in `if`, leave the function early:

```gdscript
func take_damage(amount: int, from_pos: Vector2) -> void:
	if dead or _invuln_timer > 0.0:
		return
	hp = maxi(hp - amount, 0)
	...
```
*(from `player.gd`)*

**Why:** the "normal" path stays flat and readable. You'll see guard clauses at the start of most
functions in this project.

## Lesson 1.7 — `match`: choosing between many values

`match` compares one value against several patterns, like `switch` in other languages:

```gdscript
func collect(kind: String) -> bool:
	match kind:
		"health":
			if hp >= max_hp:
				return false
			hp = mini(hp + 3, max_hp)
		"grenade":
			if grenades >= max_grenades:
				return false
			grenades += 1
	_emit_stats()
	return true
```
*(from the game: `player.gd`)*

* No `break` is needed. Only the first matching branch runs.
* `_` is the wildcard ("anything else"):

```gdscript
match state:            # (example)
	"idle":
		print("waiting")
	"charge", "leap":   # several values for one branch
		print("attacking")
	_:
		print("unknown state")
```

`match` is the backbone of the boss **state machines** in chapter 9.

## Lesson 1.8 — Loops

### `for` over a range of numbers
```gdscript
for i in 5:              # 0, 1, 2, 3, 4
	print(i)

for i in range(2, 5):    # 2, 3, 4
	print(i)

for i in range(10, 0, -2):   # 10, 8, 6, 4, 2
	print(i)
```

From the game, ten hearts in a row, 9 px apart:

```gdscript
for i in 10:
	var h := TextureRect.new()
	h.texture = UI.icon(HEART_ICON)
	h.scale = Vector2(0.5, 0.5)
	h.position = Vector2(9 + i * 9, 8)
	add_child(h)
	_hearts.append(h)
```
*(from `hud.gd`)*

**The `9 + i * 9` pattern**, `start + index * spacing`, is how you lay things out in a row.
You'll use it constantly.

### `for` over a collection
```gdscript
for dir in [-1, 1]:                       # left and right shockwave
	var w: Area2D = SHOCKWAVE.instantiate().setup(...)
```
*(from `boss_bonecrusher.gd`)*

```gdscript
for body in get_overlapping_bodies():
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
```
*(from `explosion.gd`)*

### `while`
Repeats as long as a condition is true. Use it when you don't know the count in advance:

```gdscript
var x := -20.0
while x < LEVEL_TILES * T:
	# ...place a building at x...
	x += region.size.x + rng.randf_range(50.0, 130.0)
```
*(from `build_level.gd`)*. Buildings have random widths and gaps, so we keep placing until we
reach the end of the level.

> ⚠️ Make sure a `while` loop's condition eventually becomes false, or the game freezes.

### `break` and `continue`
* `break` leaves the loop immediately.
* `continue` skips to the next iteration.

```gdscript
for file in dir.get_files():
	if not file.ends_with(".png"):
		continue          # skip .import files etc.
	...
```
*(from `build_resources.gd`)*

## Lesson 1.9 — Functions

A **function** is a named, reusable block of code.

```gdscript
func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)
```
*(from `game.gd`)*

Anatomy:
```
func  add_score  (amount: int)  -> void  :
 │       │            │             │
 │       name         parameter     return type ("void" = returns nothing)
 keyword              with type
```

### Return values
```gdscript
func to_player() -> Vector2:
	return player.global_position - global_position

func player_alive() -> bool:
	return is_instance_valid(player) and not player.dead
```
*(from `enemy_base.gd`)*

Small functions with good names make calling code read like English:
`if not player_alive(): ...`

### Default parameter values
```gdscript
func shake(strength: float = 3.0) -> void:
	shake_requested.emit(strength)

func message(text: String, seconds: float = 2.0) -> void:
	show_message.emit(text, seconds)
```
*(from `game.gd`)*

`Game.shake()` uses 3.0, and `Game.shake(8.0)` overrides it. Parameters with defaults must come
**after** parameters without.

### Unused parameters
Prefix with `_` to tell Godot (and readers) it's intentionally unused, which silences the warning:

```gdscript
func _ai(_delta: float) -> void:
	pass
```
*(from `enemy_base.gd`)*

### Useful built-in maths functions
| Function | Does | Game example |
|---|---|---|
| `absf(x)` / `absi(x)` / `abs(x)` | absolute value | `absf(velocity.x) > 10.0` |
| `signf(x)` | −1, 0 or +1 | `facing = int(signf(dir))` |
| `minf/maxf`, `mini/maxi` | smaller / larger | `hp = maxi(hp - amount, 0)` |
| `clampf(x, lo, hi)` | limit to a range | `clampf(to_player().x, -160.0, 160.0)` |
| `move_toward(from, to, step)` | move toward a target by at most `step` | `velocity.x = move_toward(velocity.x, target, acceleration * delta)` |
| `lerp(a, b, t)` | blend between a and b | |
| `fmod(a, b)` | float remainder | `fmod(_invuln_timer, 0.12) > 0.05` (blinking) |
| `sin`, `cos`, `TAU`, `PI` | trigonometry | twinkling stars, wobble |
| `randf()` | random 0..1 | loot rolls |
| `randf_range(a, b)` | random float in range | bullet spread |
| `randi() % n` | random int 0..n−1 | random tile variant |

The `f` / `i` suffixed versions (`absf`, `maxi`…) are **typed**: they take and return a specific
type. They are faster and avoid surprises, so the project prefers them.

### 🔤 Language spotlight: `move_toward`, the most useful function in this game

```gdscript
move_toward(from: float, to: float, delta: float) -> float
```
It returns `from` moved toward `to` by **at most** `delta`, and never overshoots.

```gdscript
move_toward(0.0, 95.0, 15.0)   # 15.0
move_toward(90.0, 95.0, 15.0)  # 95.0  (would overshoot, so it stops at 95)
move_toward(5.0, 0.0, 15.0)    # 0.0
```

Used for acceleration (`player.gd`), friction (`enemy_base.gd`) and decaying shake
(`game_camera.gd`). Any time something should *approach* a value at a fixed rate, think
`move_toward`.

---

## 🏋️ Exercises

1. ★ Declare typed variables for a character: name, HP (int), speed (float), alive (bool). Print
   them in one line using `print(a, " ", b)`.
2. ★ What do these print? Work it out first, then run them.
   `print(7 / 2)`, `print(7 / 2.0)`, `print(7 % 3)`, `print(int(-3.7))`, `print(2 ** 10)`.
3. ★ Write `func format_time(t: float) -> String` yourself without looking. Test it with
   `0`, `59.9`, `60`, `3599`.
4. ★★ Write `func grade(score: int) -> String` that returns `"S"` for ≥ 10,000, `"A"` for
   ≥ 7,000, `"B"` for ≥ 4,000, else `"C"`. Then write the same with `match` and a wildcard. Which
   is clearer?
5. ★★ Print a row of 8 tile x-positions for 16 px tiles starting at x = 32:
   `32, 48, 64, …`
6. ★★ Simulate the player accelerating: start `vx = 0.0`, target `95.0`,
   `acceleration = 900.0`, `delta = 1.0 / 60.0`. Loop with `move_toward` until `vx == 95.0`
   and count the frames. How many seconds is that?
7. ★★★ Simulate a jump with `vy = -265.0`, `gravity = 720.0`, `delta = 1/60`. Each frame:
   `y += vy * delta`, `vy += gravity * delta`. Stop when `vy >= 0` (top of the jump). Print the
   height reached and the frame count. Compare with the formula `v² / (2g)`.

## ✅ Solutions

<details><summary>Exercise 1</summary>

```gdscript
var hero_name := "Officer K"
var hp := 10
var speed := 95.0
var alive := true
print(hero_name, " ", hp, " ", speed, " ", alive)
```
</details>

<details><summary>Exercise 2</summary>

`3`, `3.5`, `1`, `-3` (truncates toward zero), `1024`.
</details>

<details><summary>Exercise 3</summary>

```gdscript
func format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]
# 0 → "00:00", 59.9 → "00:59", 60 → "01:00", 3599 → "59:59"
```
</details>

<details><summary>Exercise 4</summary>

```gdscript
func grade(score: int) -> String:
	if score >= 10000:
		return "S"
	elif score >= 7000:
		return "A"
	elif score >= 4000:
		return "B"
	return "C"
```
`match` compares exact values (or patterns), not ranges, so a range check needs `when` guards
(Godot 4.4+):
```gdscript
func grade_match(score: int) -> String:
	match score:
		var s when s >= 10000: return "S"
		var s when s >= 7000: return "A"
		var s when s >= 4000: return "B"
	return "C"
```
For ranges, `if/elif` is clearer. Use `match` for distinct values like state names.
</details>

<details><summary>Exercise 5</summary>

```gdscript
for i in 8:
	print(32 + i * 16)
```
</details>

<details><summary>Exercise 6</summary>

```gdscript
var vx := 0.0
var frames := 0
while vx < 95.0:
	vx = move_toward(vx, 95.0, 900.0 / 60.0)
	frames += 1
print(frames, " frames = ", frames / 60.0, " s")   # 7 frames ≈ 0.117 s
```
The player reaches full speed in about a tenth of a second: responsive, but not instant.
</details>

<details><summary>Exercise 7</summary>

```gdscript
var y := 0.0
var vy := -265.0
var frames := 0
while vy < 0.0:
	y += vy / 60.0
	vy += 720.0 / 60.0
	frames += 1
print("height ", -y, " px in ", frames, " frames")
print("formula ", 265.0 * 265.0 / (2 * 720.0))     # ≈ 48.8
```
The simulation gives about 50 px in 23 frames (≈ 0.37 s). The small difference from the formula
comes from stepping in whole frames. That height is just over 3 tiles, which is why the game's
platforms are 2 and 4 tiles high.
</details>

---

📝 **Recap**
* Prefer typed variables: `var x := 0.0`. Mind `0` vs `0.0`.
* Use `const` for fixed values. Name things in `snake_case`, constants in `UPPER_CASE`.
* `/` between ints truncates. `%` gives the remainder.
* `if/elif/else` for ranges and priorities, `match` for distinct values, ternary for short
  choices, guard clauses to return early.
* `for i in n`, `for item in list`, `while condition`.
* Functions have typed parameters, defaults and return types. `move_toward` is your friend.

Next: **[Chapter 2 — GDScript objects, nodes & scenes](chapter-02-gdscript-objects-and-nodes.md)**
