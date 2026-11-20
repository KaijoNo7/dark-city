# Chapter 2 — GDScript objects, nodes & scenes

🎯 **Goals**
* Work with collections: `Array`, typed arrays and `Dictionary`.
* Format strings and do vector maths with `Vector2`.
* Understand that **every script is a class**: `extends`, `class_name`, `static`, `super`.
* Find nodes in the tree (`$`, `get_node`, `@onready`) and expose settings with `@export`.
* Know the order of the node **lifecycle callbacks**.
* Create scenes from code with `preload` → `instantiate` → `add_child`, and delete them with
  `queue_free`.
* Connect to **signals** and declare your own.

Use the same `practice.tscn` from chapter 1 for the examples.

---

## Lesson 2.1 — Arrays

An **array** is an ordered list. Indices start at **0**.

```gdscript
var lines := ["Move A/D", "Jump Space"]
print(lines[0])          # "Move A/D"
print(lines.size())      # 2
lines.append("Pause Esc")
print(lines[-1])         # "Pause Esc"  (negative index counts from the end)
```

| Method | Does |
|---|---|
| `append(x)` | add to the end |
| `size()` | number of elements |
| `is_empty()` | `size() == 0` |
| `has(x)` / `x in arr` | contains? |
| `find(x)` | index of x, or −1 |
| `erase(x)` | remove first x |
| `pop_back()` | remove and return the last |
| `clear()` | remove all |
| `map(f)` / `filter(f)` | new array transformed / filtered by a function |

### Typed arrays
`Array[Type]` only accepts that type, which catches mistakes and improves autocompletion:

```gdscript
var _hearts: Array[TextureRect] = []
var _grenade_icons: Array[TextureRect] = []
```
*(from `hud.gd`)*

```gdscript
@onready var wall_shapes: Array[CollisionShape2D] = [$WallLeft/Shape, $WallRight/Shape]
```
*(from `boss_arena.gd`)*

### Arrays of arrays: data tables
The level is described by arrays of small arrays:

```gdscript
# Gaps in the ground: [first_tile, last_tile_exclusive]
const PITS := [[34, 37], [100, 103], [178, 181]]

# Enemies: [type, x_px, y_px]
const ENEMIES := [
	["gunner", 300, 176], ["brute", 470, 176], ["brute", 620, 176], ...
]
```
*(from `build_level.gd`)*

```gdscript
for e in ENEMIES:
	var n := (GUNNER if e[0] == "gunner" else BRUTE).instantiate()
	n.position = Vector2(e[1], e[2])
```

**Why:** the layout is *data*, separate from the *code* that builds it. Adding an enemy is one
line in a table, with no new logic.

> 💡 **When to prefer something else:** `e[1]` doesn't say what it means. For bigger projects,
> a small `Resource` class or a dictionary (`{"type": "gunner", "x": 300}`) is more readable. For
> a few short tables with a comment explaining the format, arrays are fine.

### `in` with arrays
```gdscript
elif not sprite.is_playing() and anim in ["idle", "walk", "shot", "walk_shot"]:
```
*(from `player.gd`)*

## Lesson 2.2 — Dictionaries

A **dictionary** maps keys to values:

```gdscript
const FPS := {
	"idle": 6.0, "walk": 10.0, "walk_shot": 12.0, "shot": 14.0, "recharge": 9.0,
	"cast": 12.0, "hurt": 14.0, "dead": 8.0, "attack": 14.0, ...
}
```
*(from `build_resources.gd`)*

| Operation | Example |
|---|---|
| read | `FPS["idle"]` → `6.0` (error if missing) |
| read with default | `FPS.get(anim, 10.0)` → 10.0 if `anim` isn't a key |
| write | `d["score"] = 100` |
| contains key | `"idle" in FPS` or `FPS.has("idle")` |
| all keys | `FPS.keys()` |
| loop | `for key in FPS: print(key, FPS[key])` |

The game uses `.get(key, default)` so that any animation not in the table still gets a sensible
speed:

```gdscript
add_strip(frames, anim, tex, 32, FPS.get(anim, 10.0), anim in LOOPING)
```

It also uses a dictionary as a **set** (only the keys matter) in the playtest bot, to remember
which boss states were seen:

```gdscript
var states := {}
states[boss.state] = true          # adding the same key twice keeps one entry
print(", ".join(states.keys()))
```
*(from `playtest.gd`)*

## Lesson 2.3 — Strings

```gdscript
var s := "DARK CITY"
s.length()                 # 9
s.to_lower()               # "dark city"
s + "!"                    # "DARK CITY!"
"Walk+Shot".replace("+", "_")   # "Walk+Shot" → "Walk_Shot"
"Idle.png".get_basename()  # "Idle"
"Idle.png".ends_with(".png")  # true
"\n"                       # newline inside a string
```

### Formatting with `%`
```gdscript
"%d/%d" % [ammo, mag]                 # "11/12"     %d = integer
"%06d" % score                         # "000150"    pad with zeros to 6 digits
"%02d:%02d" % [m, s]                   # "02:05"
"%.1fs" % 3.14159                      # "3.1s"      %.1f = float with 1 decimal
"%s defeated" % boss_name              # %s = any value as text
"BossArena%d" % 2                      # "BossArena2"
"res://asset/UI/Icons/%d.png" % n      # building a file path
```
*(all from the game)*

One value can go after `%` directly. Several values go in an array `[a, b]`.

The alternative is concatenation: `"WARNING!\n" + _boss.boss_name` *(from `boss_arena.gd`)*.
Use `+` for joining two strings and `%` when mixing in numbers.

## Lesson 2.4 — `Vector2`: positions, directions and maths

2D games are mostly vector maths. A `Vector2` has `x` and `y`.

```gdscript
var a := Vector2(3, 4)
a.x                       # 3.0
a.length()                # 5.0           (Pythagoras)
a.normalized()            # (0.6, 0.8)    same direction, length 1
a * 2                     # (6, 8)
a + Vector2(1, 1)         # (4, 5)
a.angle()                 # angle in radians from the +x axis
Vector2.from_angle(0.0)   # (1, 0)
Vector2.RIGHT, Vector2.ZERO, Vector2.UP   # (1,0), (0,0), (0,-1)
```

> 📐 **In Godot 2D, +y points DOWN.** Jumping means a *negative* y velocity, which is why
> `jump_velocity = -265.0`.

Three patterns you'll see in the game:

**1. Direction from A to B** = `B − A`. Normalise it to get a unit direction:
```gdscript
func aim_at_player() -> Vector2:
	return (player.global_position + Vector2(0, -10) - muzzle.global_position).normalized()
```
*(from `enemy_base.gd`)*. The `Vector2(0, -10)` aims at the chest, not the feet.

**2. Move along a direction**: position += direction × speed × delta:
```gdscript
position += direction * speed * delta
```
*(from `bullet.gd`)*

**3. Fan of directions** from an angle:
```gdscript
var base := aim_at_player().angle()
for i in 5:
	shoot_bullet(Vector2.from_angle(base + (i - 2) * 0.2), 1, 140.0)
```
*(from `boss_plague_doctor.gd`)*. `i − 2` gives −2, −1, 0, 1, 2, so the 5 bullets are spread
symmetrically around the aim angle, 0.2 radians (≈ 11°) apart.

## Lesson 2.5 — Every script is a class

A **class** is a blueprint for objects: it bundles data (variables) and behaviour (functions). In
GDScript, **each `.gd` file is a class**. The `extends` line says what it builds on:

```gdscript
extends CharacterBody2D          # this class IS a CharacterBody2D, plus what I add
```

That's **inheritance**. The player script can use everything a `CharacterBody2D` has
(`velocity`, `move_and_slide()`, `is_on_floor()`), and everything *it* inherits from
(`Node2D.position`, `Node.add_child()`…).

### Naming a class: `class_name`
```gdscript
class_name EnemyBase
extends CharacterBody2D
```
*(from `enemy_base.gd`)*

`class_name` registers a **global type name**. Other scripts can now write `extends EnemyBase`,
`var e: EnemyBase`, or `if node is EnemyBase`, and it appears in the "Add Node" dialog.

### Extending by path
Without `class_name`, you can extend a script by its file path:

```gdscript
extends "res://scripts/enemies/enemy_base.gd"
```
*(from `mook_gunner.gd`)*. Both forms work. This project uses the path in child scripts, which
makes the dependency explicit.

### Overriding and `super`
A child class can **replace** (override) a parent's function by defining one with the same name.
To also run the parent's version, call `super`:

```gdscript
# boss_base.gd
func _ready() -> void:
	super._ready()          # run EnemyBase._ready() first (hp, groups, layers…)
	collision_mask = 1      # then change what's different for bosses
```

```gdscript
func take_damage(amount: int, from_pos: Vector2) -> void:
	if not active or dead:
		return
	super.take_damage(amount, from_pos)       # the normal enemy damage logic
	Game.boss_hp_changed.emit(maxi(hp, 0))    # plus boss-specific extras
```
*(from `boss_base.gd`)*. Chapter 8 goes deeper.

### `static` functions and `RefCounted`
```gdscript
extends RefCounted

static func icon(n: int) -> Texture2D:
	return load("res://asset/UI/Icons/%d.png" % n)
```
*(from `ui_kit.gd`)*

* A **static** function belongs to the class, not to an object. You call it on the class itself:
  `UI.icon(33)`.
* `RefCounted` is the lightweight base for non-node objects. It is freed automatically when
  nothing references it.

### Objects that are not nodes
`Vector2` and `Color` are *values*. `Texture2D`, `SpriteFrames`, `Tween` and `RandomNumberGenerator`
are *objects* (resources or helpers). You create objects with `.new()`:

```gdscript
var rng := RandomNumberGenerator.new()
var tex := AtlasTexture.new()
var p := CPUParticles2D.new()       # nodes too
```

## Lesson 2.6 — The scene tree and finding nodes

While the game runs, all active nodes live in one big **SceneTree**. A script can reach other
nodes in several ways:

| Syntax | Meaning |
|---|---|
| `$Sprite` | child named "Sprite" (same as `get_node("Sprite")`) |
| `$WallLeft/Shape` | grandchild via a path |
| `get_parent()` | the parent node |
| `get_tree()` | the SceneTree (groups, timers, pausing, scene changes) |
| `get_tree().get_first_node_in_group("player")` | first node tagged "player" |
| `get_tree().get_nodes_in_group("summons")` | all nodes tagged "summons" |
| `find_children("*", "Button", true, false)` | search descendants by name pattern and type |

### `@onready`
Children aren't ready when the script's variables are first created. `@onready` delays the
assignment until just before `_ready()`:

```gdscript
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var camera: Camera2D = $Camera
```
*(from `player.gd`)*

**Why store them?** `$Sprite` searches the tree each time. Caching it in a variable is faster,
it's typed (so you get autocompletion), and if you rename the node you fix one line.

## Lesson 2.7 — `@export`: settings you can edit in the Inspector

```gdscript
@export var speed := 95.0
@export var jump_velocity := -265.0
@export var max_hp := 10
```
*(from `player.gd`)*

Exported variables appear in the **Inspector** when you select the node. Designers can tune them
without touching code, and each **instance** can have its own value. That's why the gunner (4 HP)
and the brute (6 HP) share `enemy_base.gd`'s `max_hp` but set different values in their scenes.

Export variants used in the game:

```gdscript
@export var boss_scene: PackedScene                     # drag a .tscn into the Inspector
@export_enum("health", "grenade") var kind := "health"  # dropdown with fixed choices
@export var spark_color := Color(1, 0.85, 0.3)          # colour picker
@export var reward := "health"  ## Pickup dropped when the boss dies.
```
*(from `boss_arena.gd`, `pickup.gd`, `bullet.gd`)*

> 💡 A `##` comment after an export becomes its **tooltip** in the Inspector.

## Lesson 2.8 — The node lifecycle

Godot calls these functions for you, in this order:

| Callback | When | Typical use in the game |
|---|---|---|
| `_init()` | object created (before it's in the tree) | `build_resources.gd` does its work here |
| `_enter_tree()` | node added to the tree | (not used) |
| `_ready()` | node **and all its children** are in the tree. Called **once**. | setup: groups, starting values, connecting signals |
| `_process(delta)` | every **rendered frame** | visuals: camera shake, HUD clock, star twinkle |
| `_physics_process(delta)` | every **physics tick** (60/s by default, steady) | movement, collisions, AI |
| `_input(event)` / `_unhandled_input(event)` | an input event arrives | pause menu toggle |
| `_draw()` | when the node must be redrawn | stars and moon |
| `_exit_tree()` | node removed | (not used) |

**`_process` vs `_physics_process`:** physics runs at a **fixed** rate, so movement and collisions
are consistent. Rendering can run faster or slower. Rule of thumb: **anything that moves bodies or
checks collisions goes in `_physics_process`**.

**`_ready` order:** children are ready **before** their parent. When `Level1._ready()` runs, the
player inside it is already ready, so `level.gd` can safely read `player.camera`.

## Lesson 2.9 — Creating and destroying scenes in code

Three steps to spawn a scene:

```gdscript
const BULLET := preload("res://scenes/projectiles/bullet.tscn")   # 1. load the PackedScene

var b := BULLET.instantiate()        # 2. create a new node tree from it
get_parent().add_child(b)            # 3. put it in the scene tree (now it runs)
```

* `preload` loads the file **when the script is loaded**. It's fast at runtime and the path is
  checked in the editor. Use it for things you'll definitely need.
* `load` loads **when that line runs**. Use it for paths decided at runtime:
  `arena.boss_scene = load(a[1])` *(from `build_level.gd`)*.
* A node does nothing until it's added to the tree.

To delete a node, use `queue_free()`. It is freed safely at the end of the frame:

```gdscript
lifetime -= delta
if lifetime <= 0.0:
	queue_free()
```
*(from `bullet.gd`)*

> ⚠️ After `queue_free()`, other scripts may still hold a reference to that node. Always check
> `is_instance_valid(node)` before using a node that might have been freed. The game does this
> with the player, bosses and overlays.

## Lesson 2.10 — Signals

A **signal** is a message an object sends when something happens. Other objects **connect**
functions to it, and those functions are called when the signal is **emitted**.

### Built-in signals
Many nodes come with signals: `Area2D.body_entered`, `Button.pressed`,
`AnimatedSprite2D.animation_finished`, `Timer.timeout`, `CPUParticles2D.finished`…

```gdscript
body_entered.connect(_on_body_entered)            # connect to my own function

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("collect") and body.collect(kind):
		queue_free()
```
*(from `pickup.gd`)*

```gdscript
$Sprite.animation_finished.connect(queue_free)    # free myself when the blast anim ends
p.finished.connect(p.queue_free)                  # particle frees itself when done
```
*(from `explosion.gd`, `bullet.gd`)*

Note: you pass the function **without parentheses** (`queue_free`, not `queue_free()`). You are
handing over the function itself (a `Callable`), not calling it.

### Custom signals
```gdscript
signal player_died
signal boss_started(boss_name: String, max_hp: int)

# somewhere:
player_died.emit()
boss_started.emit(boss_name, max_hp)
```
*(from `game.gd`, `player.gd`, `boss_base.gd`)*

You can also connect in the editor (**Node** dock → **Signals** tab). This project connects
everything in code so all the wiring is visible in the scripts.

### 🔤 Language spotlight: lambdas (anonymous functions)
A **lambda** is a function without a name, written inline:

```gdscript
Game.shake_requested.connect(func(s: float) -> void: _shake = maxf(_shake, s))
```
*(from `game_camera.gd`)*

```gdscript
Game.score_changed.connect(func(s: int) -> void: _score_label.text = "%06d" % s)
```
*(from `hud.gd`)*

Use a lambda when the handler is a single line used in one place. For anything longer, a named
function (`_on_hp_changed`) is easier to read and debug.

---

## 🏋️ Exercises

1. ★ Make an array of the three boss names. Print each with its number:
   `1: DEADEYE ROOK`… (Hint: `for i in names.size()`.)
2. ★ Make a dictionary of boss name → HP (60, 90, 120). Print the total HP of all bosses.
3. ★ Format these with `%`: score 4250 as `"004250"`, time 83 seconds as `"01:23"`, and
   `"Bosses defeated: 2/3"`.
4. ★★ Write `func direction_to(a: Vector2, b: Vector2) -> Vector2` returning the unit vector from
   a to b. Test with `(0,0)` → `(3,4)`.
5. ★★ Write a function that returns 5 directions spread around `Vector2.RIGHT`, 0.2 rad apart
   (use `Vector2.from_angle`). Print their angles in degrees (`rad_to_deg`).
6. ★★ Create a scene with a `Node2D` root and a `Sprite2D` child. Write a script that, in
   `_ready()`, creates 10 more `Sprite2D` nodes **in code** with `Sprite2D.new()`, gives them the
   `icon.svg` texture (`load("res://icon.svg")`), and places them in a row 20 px apart.
7. ★★ Add an `Area2D` with a `CollisionShape2D` to a scene and connect `body_entered` in code to
   a function that prints the body's name. (You'll need a body to enter it. Try a
   `CharacterBody2D` that you move in `_physics_process`.)
8. ★★★ Write a `Counter` class (`counter.gd`, `extends RefCounted`, `class_name Counter`) with a
   signal `reached(value: int)`, a variable `target`, and a method `increment()` that emits
   `reached` when the count reaches the target. Use it from `practice.gd` with a lambda.

## ✅ Solutions

<details><summary>Exercise 1</summary>

```gdscript
var names := ["DEADEYE ROOK", "BONECRUSHER", "THE PLAGUE DOCTOR"]
for i in names.size():
	print("%d: %s" % [i + 1, names[i]])
```
</details>

<details><summary>Exercise 2</summary>

```gdscript
var hp := {"DEADEYE ROOK": 60, "BONECRUSHER": 90, "THE PLAGUE DOCTOR": 120}
var total := 0
for boss in hp:
	total += hp[boss]
print(total)   # 270
```
</details>

<details><summary>Exercise 3</summary>

```gdscript
print("%06d" % 4250)
print("%02d:%02d" % [83 / 60, 83 % 60])
print("Bosses defeated: %d/3" % 2)
```
</details>

<details><summary>Exercise 4</summary>

```gdscript
func direction_to(a: Vector2, b: Vector2) -> Vector2:
	return (b - a).normalized()
# direction_to(Vector2.ZERO, Vector2(3, 4)) → (0.6, 0.8)
```
Godot also has this built in: `a.direction_to(b)`.
</details>

<details><summary>Exercise 5</summary>

```gdscript
func fan(base: float, count: int, gap: float) -> Array[Vector2]:
	var dirs: Array[Vector2] = []
	for i in count:
		dirs.append(Vector2.from_angle(base + (i - (count - 1) / 2.0) * gap))
	return dirs

func _ready() -> void:
	for d in fan(0.0, 5, 0.2):
		print(rad_to_deg(d.angle()))   # ≈ -22.9, -11.5, 0, 11.5, 22.9
```
`(count - 1) / 2.0` centres the fan for any count. This is the exact formula `boss_rook.gd` uses.
</details>

<details><summary>Exercise 6</summary>

```gdscript
extends Node2D

func _ready() -> void:
	var tex := load("res://icon.svg")
	for i in 10:
		var s := Sprite2D.new()
		s.texture = tex
		s.scale = Vector2(0.1, 0.1)
		s.position = Vector2(20 + i * 20, 50)
		add_child(s)
```
</details>

<details><summary>Exercise 7</summary>

```gdscript
extends Node2D

func _ready() -> void:
	$Area2D.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	print(body.name, " entered!")
```
Make sure the body's **layer** is included in the area's **mask** (chapter 3).
</details>

<details><summary>Exercise 8</summary>

```gdscript
# counter.gd
class_name Counter
extends RefCounted

signal reached(value: int)

var target := 3
var count := 0

func increment() -> void:
	count += 1
	if count == target:
		reached.emit(count)
```
```gdscript
# practice.gd
func _ready() -> void:
	var c := Counter.new()
	c.reached.connect(func(v: int) -> void: print("Reached ", v))
	for i in 5:
		c.increment()      # prints "Reached 3" once
```
</details>

---

📝 **Recap**
* `Array` / `Array[Type]` for lists, `Dictionary` for lookups. `.get(key, default)` avoids errors.
* `%` formatting: `%d`, `%06d`, `%02d`, `%.1f`, `%s`.
* `Vector2`: direction = `(B − A).normalized()`, move = `pos += dir * speed * delta`, +y is down.
* Every script is a class. `extends`, `class_name`, overriding and `super`, `static`.
* `@onready var x = $Child`, `@export var y := 1.0`.
* Lifecycle: `_init` → `_ready` (children first) → `_process` / `_physics_process`.
* Spawn: `preload` → `instantiate()` → `add_child()`. Delete: `queue_free()`. Check
  `is_instance_valid()`.
* Signals: `signal x(arg)`, `x.emit(arg)`, `x.connect(callable)`, lambdas for one-liners.

Next: **[Chapter 3 — Project setup](chapter-03-project-setup.md)**
