# Appendix — GDScript cheat sheet & glossary

A compact reference for everything used in this course. Each item links back to where it appears
in Dark City.

---

## Script structure (recommended order)

```gdscript
class_name MyThing            # optional global name
extends CharacterBody2D       # base class
## Doc comment describing the script.

signal something_happened(value: int)

enum Mode { A, B }
const SPEED := 100.0
const SCENE := preload("res://x.tscn")

@export var health := 10
var state := "idle"
var _private_timer := 0.0
@onready var sprite: Sprite2D = $Sprite

func _ready() -> void: ...
func _process(delta: float) -> void: ...
func _physics_process(delta: float) -> void: ...
func public_method() -> void: ...
func _private_helper() -> void: ...
```

## Variables & types

```gdscript
var a = 1               # dynamic
var b: int = 1          # explicit
var c := 1              # inferred (int)
var d := 1.0            # float. Use 0.0 for timers!
const MAX := 10
var arr: Array[int] = [1, 2]
var dict := {"key": 1}
var node: Node2D        # null until assigned
```

| Type | Literal | Notes |
|---|---|---|
| `bool` | `true`, `false` | |
| `int` | `42`, `-3`, `1_000`, `0xFF` | `7 / 2 == 3` |
| `float` | `3.14`, `1e3`, `INF` | |
| `String` | `"a"`, `'a'`, `"""multi"""` | |
| `Vector2` / `Vector2i` | `Vector2(1, 2)` | `+y` is down |
| `Color` | `Color(1, 0, 0)`, `Color.WHITE` | channels 0–1. Over 1 brightens via `modulate`. |
| `Rect2` | `Rect2(x, y, w, h)` | |
| `Array`, `Dictionary` | `[]`, `{}` | |
| `Callable` | `my_method`, `func(): ...` | functions as values |

## Operators

```
+ - * / % **            arithmetic (int / int truncates)
+= -= *= /=             compound assignment
== != < > <= >=         comparison
and or not   && || !    logic (short-circuit)
| & ^ ~ << >>           bitwise (collision masks)
x if cond else y        ternary
a in collection         membership
obj is Type             type check
obj as Type             cast (null if it fails)
```

## Control flow

```gdscript
if a: ...
elif b: ...
else: ...

match value:
	"x": ...
	"y", "z": ...
	var v when v > 10: ...   # guard (Godot 4.4+)
	_: ...                    # wildcard

for i in 10: ...                 # 0..9
for i in range(2, 10, 2): ...    # 2,4,6,8
for item in array: ...
for key in dict: ...
while cond: ...
break / continue / pass / return
```

## Functions

```gdscript
func f(a: int, b: float = 1.0) -> String:
	return str(a + b)

static func helper() -> void: ...        # call as ClassName.helper()
func _unused(_param: int) -> void: ...   # leading _ = intentionally unused

var lam := func(x: int) -> int: return x * 2
lam.call(3)                              # 6
method.bind(1, 2)                        # pre-fill arguments
node.method.call_deferred(arg)           # call at end of frame
```

## Classes & inheritance

```gdscript
extends "res://scripts/enemies/enemy_base.gd"   # by path
extends EnemyBase                                # by class_name

func _ready() -> void:
	super._ready()          # call parent's version

func take_damage(a: int, p: Vector2) -> void:
	super.take_damage(a, p) # extend, don't replace
```

## Annotations

```gdscript
@export var speed := 95.0
@export var scene: PackedScene
@export_enum("health", "grenade") var kind := "health"
@export_range(0, 100) var volume := 50
@onready var sprite := $Sprite
@tool                       # (top of file) run the script in the editor
```

## Node essentials

```gdscript
$Child / $Path/To/Node / get_node("Child")
get_parent()
get_tree()
add_child(node)  ·  node.queue_free()  ·  is_instance_valid(node)
add_to_group("enemies")  ·  is_in_group("player")
get_tree().get_first_node_in_group("player")
get_tree().get_nodes_in_group("enemies")
find_children("*", "Button", true, false)
node.set_deferred("prop", value)
```

## Scenes & resources

```gdscript
const S := preload("res://a.tscn")    # at load time
var s = load("res://a.tscn")          # at run time
var n := S.instantiate()
parent.add_child(n)
ResourceSaver.save(resource, "res://x.tres")
get_tree().change_scene_to_file("res://level.tscn")
```

## Signals

```gdscript
signal hit(amount: int)
hit.emit(3)
hit.connect(_on_hit)
hit.connect(func(a: int) -> void: print(a))
hit.disconnect(_on_hit)
await hit                              # wait for it
```

## Timing

```gdscript
await get_tree().create_timer(1.0).timeout
await get_tree().create_timer(t, true, false, true).timeout   # ignores time_scale
await get_tree().physics_frame
await RenderingServer.frame_post_draw
Engine.time_scale = 0.05
get_tree().paused = true
process_mode = Node.PROCESS_MODE_ALWAYS
```

## Tweens

```gdscript
var t := create_tween()
t.tween_property(node, "modulate:a", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
t.tween_interval(1.0)
t.tween_callback(queue_free)
t.parallel().tween_property(...)
t.set_loops()        # forever
t.kill()
```

## Physics (2D)

```gdscript
# CharacterBody2D
velocity.y += gravity * delta
move_and_slide()
is_on_floor() · is_on_wall() · is_on_ceiling()
var hit := move_and_collide(velocity * delta)
if hit: velocity = velocity.bounce(hit.get_normal()) * 0.45

# Layers / masks
collision_layer = 2
collision_mask = 1 | 16
set_collision_mask_value(5, false)    # layer NUMBER

# Area2D
body_entered.connect(_on_body_entered)
get_overlapping_bodies()

# Raycast
var q := PhysicsRayQueryParameters2D.create(from, to, mask)
var r := get_world_2d().direct_space_state.intersect_ray(q)   # {} if nothing
```

## Input

```gdscript
Input.get_axis("move_left", "move_right")
Input.is_action_pressed("shoot")
Input.is_action_just_pressed("jump")
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"): ...
get_viewport().set_input_as_handled()
Input.action_press("jump")      # simulate (tests)
```

## Maths helpers

```gdscript
absf  signf  minf  maxf  mini  maxi  clampf  move_toward  lerp  fmod
sin  cos  TAU  PI  deg_to_rad  rad_to_deg
randf()  randf_range(a, b)  randi() % n
var rng := RandomNumberGenerator.new(); rng.seed = 7
v.length()  v.normalized()  v.angle()  Vector2.from_angle(a)  a.distance_to(b)
```

## String formatting

```gdscript
"%d" % 5         "%06d" % 42 → "000042"     "%02d:%02d" % [m, s]
"%.1f" % 3.14159 → "3.1"     "%s" % anything     "a" + "b"
"\n".join(array)  s.to_lower()  s.replace("+", "_")  s.get_basename()  s.ends_with(".png")
```

---

## Glossary

| Term | Meaning |
|---|---|
| **Autoload** | A script or scene loaded at startup, kept for the whole run, accessible by name (`Game`). |
| **Callable** | A value that refers to a function, so it can be stored, passed and called later. |
| **CanvasLayer** | A separate 2D drawing layer unaffected by the camera (HUD, sky, rain). |
| **Coyote time** | A grace period to jump after leaving a ledge. |
| **Coroutine** | A function using `await`. It pauses and resumes later. |
| **Delta** | Seconds since the last frame. Multiply rates by it. |
| **Duck typing** | Calling a method if the object has it, regardless of its class. |
| **Event bus** | A central object with signals that decouples emitters from listeners. |
| **Export** | A variable shown and editable in the Inspector. |
| **FSM** | Finite state machine: one state at a time, with transitions. |
| **Group** | A tag on nodes, used to find them. |
| **Hit-stop** | A brief slow-down on impact to sell its power. |
| **I-frames** | Invulnerability frames after being hit. |
| **Instancing** | Placing a copy of a scene inside another scene. |
| **Jump buffer** | Remembering an early jump press for a short time. |
| **Layer / mask** | What a physics object *is* / what it *looks for*. |
| **Node** | The basic building block, arranged in a tree. |
| **One-way collision** | A shape that only blocks from one side (platforms). |
| **Owner** | The node a child "belongs to" for saving. Required by `PackedScene.pack`. |
| **Parallax** | Layers scrolling at different speeds to fake depth. |
| **Resource** | Shareable data saved to disk (`.tres`): textures, SpriteFrames, TileSets… |
| **Scene** | A saved tree of nodes (`.tscn`). |
| **Signal** | A message an object emits. Connected functions are called. |
| **Tell** | A visual or audio warning before an attack. |
| **Template method** | A base class runs a fixed skeleton and calls hooks that subclasses override. |
| **Tween** | An object that animates a property over time. |
