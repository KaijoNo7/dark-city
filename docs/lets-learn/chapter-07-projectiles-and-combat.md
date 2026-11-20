# Chapter 7 — Projectiles & combat

🎯 **Goals**
* Build a reusable **bullet** with `Area2D` and configure it with a chainable `setup()`.
* Understand **duck typing** and the `take_damage` contract.
* Spawn **particles** from code and clean them up automatically.
* Build a bouncing **grenade** with `move_and_collide` and `Vector2.bounce`.
* Build an **explosion** that damages an area once.
* Learn why and when to use **`call_deferred`** / **`set_deferred`**.
* Give the player shooting, reloading, grenades and taking damage.

---

## Lesson 7.1 — `Area2D` vs bodies for projectiles

A bullet needs to know **when it touches something**, then disappear. It never needs to *be
blocked* or to *push* anything. That's exactly what `Area2D` does: it detects overlaps and emits
signals (`body_entered`, `area_entered`), with no physical response.

> Fast bullets can **tunnel**: in one frame they jump past a thin target. At 260 px/s and 60 FPS,
> a bullet moves about 4.3 px per frame, and our smallest shape is 10 px wide, so it's safe. For
> very fast projectiles, use a `RayCast2D` or `ShapeCast2D` instead.

### The bullet scene
`scenes/projectiles/bullet.tscn`:

```
Bullet    Area2D          script bullet.gd
├── Sprite  Sprite2D      texture: asset/Characters/Other/Charge 1.png
└── Shape   CollisionShape2D   RectangleShape2D 6×3
```

## Lesson 7.2 — `bullet.gd`

```gdscript
extends Area2D
## A projectile that flies in a straight line and damages the first thing it hits.
## The same script is used for the player's bullets, enemy bullets and the
## boss shockwave. `from_player` decides who it is allowed to hurt.

@export var speed := 260.0
@export var damage := 1
@export var lifetime := 1.6
@export var hits_world := true      ## false = passes through walls/ground (shockwave)
@export var spark_color := Color(1, 0.85, 0.3)

var direction := Vector2.RIGHT
var from_player := true
```
*(from the game)*

**One script, three projectiles.** Player bullets, enemy bullets and the Bonecrusher's shockwave
all use this script with different values. The shockwave scene sets `speed = 140`,
`lifetime = 2.2`, `hits_world = false` and an orange spark in the Inspector. Exported variables
turn one script into a family of behaviours.

* `lifetime 1.6` s × 260 px/s ≈ 416 px, just over one screen. Missed bullets are removed once
  they're off-screen, so they don't pile up and slow the game.

### `setup()`, a chainable initialiser

```gdscript
## Call before add_child(). Returns self so calls can be chained.
func setup(pos: Vector2, dir: Vector2, is_player: bool, dmg: int = 1, spd: float = -1.0) -> Area2D:
	global_position = pos
	direction = dir.normalized()
	from_player = is_player
	damage = dmg
	if spd > 0.0:
		speed = spd
	return self
```
*(from the game)*

**Why a `setup()` method?** Scenes can't take constructor arguments (`instantiate()` has none).
Setting five properties one by one at every call site is verbose and easy to get wrong. One
method sets them all, and **returning `self`** lets you chain:

```gdscript
var b: Area2D = BULLET.instantiate().setup(muzzle.global_position, Vector2(facing, spread), true, 1)
get_parent().add_child(b)
```

* `dir.normalized()` guarantees a length of 1, so callers can pass `Vector2(1, 0.03)` without
  changing the speed.
* `spd = -1.0` is a **sentinel** meaning "keep the scene's speed". Negative speeds make no sense,
  so −1 can safely mean "not given".
* **Call before `add_child`.** `_ready()` runs during `add_child` and uses `direction` and
  `from_player` to set rotation and masks. They must already be correct by then.

### `_ready`: masks and orientation

```gdscript
func _ready() -> void:
	collision_layer = 0
	# Layer bits: 1 = world, 2 = player, 4 = enemies.
	collision_mask = (1 if hits_world else 0) | (4 if from_player else 2)
	rotation = direction.angle()
	if direction.x < 0.0 and abs(direction.y) < 0.01:
		# Keep sprites upright when flying left (rotation would flip them upside down).
		rotation = 0.0
		scale.x = -absf(scale.x)
	body_entered.connect(_on_body_entered)
```
*(from the game)*

* `collision_layer = 0`: nothing needs to detect bullets.
* The mask is built from flags (chapter 3's table). **Who a bullet can hurt is decided by
  physics masks.** Player bullets can't even *see* the player, so there's no friendly fire and no
  `if` checks.
* `rotation = direction.angle()` points the sprite where it flies (diagonal fan bullets are
  tilted).
* **Flying straight left:** an angle of π would turn the sprite **upside down**. Mirroring with a
  negative `scale.x` keeps it upright.

### Moving and expiring

```gdscript
func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
```
*(from the game)*

An `Area2D` has no `velocity` or `move_and_slide`. We move it directly, using the standard formula
**position += direction × speed × delta**.

### Hitting something

```gdscript
func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	elif not hits_world:
		return
	_spawn_spark()
	queue_free()
```
*(from the game)*

* **Duck typing:** we don't ask "is it an enemy?" We ask "can it take damage?" (see below).
* If it **can't** take damage, it's a wall or the floor. Normal bullets spark and vanish. A
  shockwave (`hits_world = false`) just `return`s and keeps going. (Its mask doesn't include
  world anyway, but the check makes the intent explicit.)

## Lesson 7.3 — 🔤 Duck typing and the damage contract

> *"If it walks like a duck and quacks like a duck, it's a duck."*

GDScript can check whether an object has a method at runtime with `has_method("name")`, and then
call it. The game defines a **contract**: an informal promise that some objects keep.

```gdscript
func take_damage(amount: int, from_pos: Vector2) -> void
```

| Who keeps the promise | What it does |
|---|---|
| Player | loses HP, knockback, i-frames |
| Every enemy (via `EnemyBase`) | loses HP, flashes, may stagger or die |
| Every boss (via `BossBase`) | the same, plus updates the boss bar and phase 2 |

| Who relies on it | |
|---|---|
| Bullet, shockwave | on `body_entered` |
| Explosion | on everything overlapping |
| Enemy contact damage, brute swing, Bonecrusher swipe | on the player |

**Alternatives and why this was chosen:**

| Option | Example | Trade-off |
|---|---|---|
| Duck typing | `if body.has_method("take_damage")` | flexible: crates, barrels, anything can opt in. No shared base class needed. Typos aren't caught by the editor. |
| Class check | `if body is EnemyBase` | type-safe, but the player isn't an `EnemyBase`, so you'd need two checks. Adding a destructible crate means another check. |
| Groups | `if body.is_in_group("damageable")` | also flexible, but you still need the method to call |
| Component node | a `Health` child node | scales best in big projects, but is more structure than this game needs |

For a small game with a clear contract, duck typing keeps things simple.

`from_pos` is the attacker's position. The victim uses it to decide which way to fly when knocked
back.

## Lesson 7.4 — Sparks: particles from code

```gdscript
func _spawn_spark() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 6
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 200)
	p.color = spark_color
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	get_parent().add_child.call_deferred(p)
```
*(from the game)*

| Property | Meaning |
|---|---|
| `one_shot` + `emitting` | emit one batch, then stop |
| `amount 6`, `lifetime 0.25` | six sparks that live a quarter second |
| `explosiveness 1.0` | all six at the same instant (a burst), not spread out over time |
| `spread 180` | in every direction (±180° around the default direction) |
| `initial_velocity_*`, `gravity` | fly out, then fall a little |
| `finished.connect(p.queue_free)` | **self-cleaning**: when done, delete the node |

**Why add the spark to the parent, not the bullet?** The bullet calls `queue_free()` right after.
Children die with their parent, so the sparks would vanish instantly. Adding to the parent (the
level) lets them outlive the bullet.

**Why `call_deferred`?** See the next lesson.

## Lesson 7.5 — 🔤 `call_deferred` and `set_deferred`

Godot runs physics in steps. While it's **processing collisions** (for example while calling your
`body_entered` handler), the physics world is "locked". Adding or removing physics objects, or
enabling shapes, at that moment can cause errors such as *"Can't change this state while flushing
queries"*.

The fix is to **postpone** the change to a safe moment at the end of the frame:

```gdscript
get_parent().add_child.call_deferred(p)       # call this method later
s.set_deferred("disabled", not closed)        # set this property later
hitbox.set_deferred("monitoring", false)
```

**Rule of thumb:** inside physics callbacks (`body_entered`, `area_entered`…), and whenever you
add physics nodes or toggle collision shapes in response to a collision, **defer** it.

`add_child.call_deferred(x)` uses the fact that methods are values (`Callable`s) with a
`call_deferred` method. The older form, `call_deferred("add_child", x)`, still works but isn't
type-checked.

## Lesson 7.6 — The grenade: bouncing physics

`scenes/projectiles/grenade.tscn`:

```
Grenade   CharacterBody2D   script grenade.gd
├── Sprite  AnimatedSprite2D   frames: resources/frames/grenade.tres
├── Shape   CollisionShape2D   circle r=3     ← to bounce on the world
└── Hitbox  Area2D                            ← to notice enemies
    └── Shape CollisionShape2D circle r=5
```

A **body** to bounce, and an **area** to detect targets. Each node does one job.

```gdscript
extends CharacterBody2D
## A thrown grenade: flies in an arc, bounces, then explodes after its fuse
## runs out (or immediately if it touches a target).

const EXPLOSION := preload("res://scenes/projectiles/explosion.tscn")

@export var fuse := 1.1
@export var gravity := 600.0
@export var damage := 6

var from_player := true
var _exploded := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 16  # world + platforms, so it can bounce on them
	$Hitbox.collision_layer = 0
	$Hitbox.collision_mask = 4 if from_player else 2
	$Hitbox.body_entered.connect(func(_b: Node2D) -> void: explode())
	$Sprite.play()
```
*(from the game)*

* The same scene serves the player (hits enemies, mask 4) and the Plague Doctor (hits the player,
  mask 2).
* The lambda ignores its argument (`_b`). Any target touching the hitbox means boom.

```gdscript
func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	var hit := move_and_collide(velocity * delta)
	if hit:
		velocity = velocity.bounce(hit.get_normal()) * 0.45
		if hit.get_normal().y < -0.5:
			velocity.x *= 0.7  # ground friction
	fuse -= delta
	if fuse <= 0.0:
		explode()
```
*(from the game)*

### `move_and_collide` vs `move_and_slide`

| | `move_and_slide()` | `move_and_collide(motion)` |
|---|---|---|
| Input | uses `velocity` (px/s), applies delta itself | a **motion vector for this frame** (so you multiply by delta) |
| On collision | slides along the surface | **stops** and returns a `KinematicCollision2D` |
| Use for | walking characters | bouncing, custom responses |

### Bouncing with vectors
`hit.get_normal()` is the unit vector pointing **out of** the surface we hit: `(0, −1)` for a
floor, `(±1, 0)` for a wall. `velocity.bounce(normal)` reflects the velocity like a mirror.
Multiplying by `0.45` keeps 45 % of the speed, so each bounce is lower until it settles.

```
     velocity ↘         ↗ bounced velocity × 0.45
                ╲     ╱
   ──────────────╲───╱──────────  floor, normal ↑ (0, -1)
```

`normal.y < -0.5` means "mostly a floor" (not a wall or ceiling). Only floors apply friction to x,
so the grenade rolls to a stop.

### Exploding exactly once

```gdscript
func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var e := EXPLOSION.instantiate()
	e.global_position = global_position
	e.from_player = from_player
	e.damage = damage
	get_parent().add_child.call_deferred(e)
	queue_free()
```
*(from the game)*

The fuse and the hitbox could both trigger in the same frame. The `_exploded` **guard** stops a
double explosion. `queue_free()` doesn't remove the node instantly, so without the guard a second
call could still happen in the same frame.

## Lesson 7.7 — The explosion: area damage, once

`scenes/projectiles/explosion.tscn`: an `Area2D` with an `AnimatedSprite2D` (8 frames of 64 px)
and a 28 px radius circle.

```gdscript
extends Area2D
## Grenade explosion: plays the 8-frame blast animation and damages
## everything inside the circle once.

var from_player := true
var damage := 6


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 if from_player else 2
	$Sprite.play("default")
	$Sprite.animation_finished.connect(queue_free)
	Game.shake(5.0)
	# Wait two physics frames so the Area2D knows what overlaps it.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
```
*(from the game)*

* **The lifetime is tied to the animation:** `animation_finished → queue_free`. When the visual
  ends, the node is gone.
* **Why wait two physics frames?** A brand-new `Area2D` hasn't been through a physics step yet,
  so `get_overlapping_bodies()` would return an empty list. After the physics server updates, the
  list is filled. Waiting two frames is a safe margin.
* **Damage once:** we query overlaps one time instead of using `body_entered` (which could fire
  again if someone walks in later). Each body is hit exactly once.
* Bosses reuse this scene with `damage = 0` for purely visual death explosions.

## Lesson 7.8 — Giving the player a gun

Now return to `player.gd` and add what you left out in chapter 5. At the top:

```gdscript
const BULLET := preload("res://scenes/projectiles/bullet.tscn")
const GRENADE := preload("res://scenes/projectiles/grenade.tscn")
```

Uncomment `_handle_combat()` in `_physics_process`, then add:

```gdscript
func _handle_combat() -> void:
	if _hurt_timer > 0.0:
		return
	if Input.is_action_just_pressed("reload") and ammo < mag_size:
		_start_reload()
	if Input.is_action_just_pressed("grenade") and grenades > 0 and _cast_timer <= 0.0 and _reload_timer <= 0.0:
		_throw_grenade()
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0 and _reload_timer <= 0.0 and _cast_timer <= 0.0:
		if ammo > 0:
			_shoot()
		else:
			_start_reload()
```
*(from the game)*

* No combat while hurt (knockback).
* **Reload** only if the magazine isn't full.
* **Grenade** needs stock, and you can't throw mid-throw or mid-reload.
* **Shoot uses `is_action_pressed`** (held), so holding the button gives **auto-fire**, limited
  by `_fire_timer`. Pulling the trigger on an empty gun starts a reload. That's friendlier than
  a dead click.

```gdscript
func _shoot() -> void:
	_fire_timer = fire_cooldown
	_shoot_anim_timer = 0.25
	ammo -= 1
	var spread := randf_range(-0.04, 0.04)
	var b: Area2D = BULLET.instantiate().setup(muzzle.global_position, Vector2(facing, spread), true, 1)
	get_parent().add_child(b)
	velocity.x -= facing * 8.0  # tiny recoil
	Game.shake(0.8)
	_emit_stats()
	if ammo == 0:
		_start_reload()
```
*(from the game)*

* **Spread:** a small random vertical component (±0.04 → about ±2.3°) makes streams of bullets look
  alive rather than laser-straight.
* **`get_parent().add_child(b)`:** the bullet is a **sibling** of the player, so it flies on its
  own. As a child, it would move with the player.
* **Recoil + micro-shake** make every shot feel physical.
* **Auto-reload** on the last bullet.

```gdscript
func _start_reload() -> void:
	if _reload_timer > 0.0:
		return
	_reload_timer = reload_time
	sprite.play("recharge")
	_emit_stats()


func _throw_grenade() -> void:
	grenades -= 1
	_cast_timer = 0.3
	sprite.play("cast")
	var g := GRENADE.instantiate()
	g.global_position = global_position + Vector2(6 * facing, -16)
	g.velocity = Vector2(150 * facing + velocity.x * 0.5, -190)
	g.from_player = true
	get_parent().add_child(g)
	_emit_stats()
```
*(from the game)*

* `_start_reload` is guarded so pressing R mid-reload doesn't restart the timer.
* **Grenade velocity inherits half the player's velocity** (`velocity.x * 0.5`). Throwing while
  running throws further, which feels natural.
* It spawns at chest height (`-16`), slightly in front.

## Lesson 7.9 — Taking damage

```gdscript
## Called by bullets, explosions and enemy attacks.
func take_damage(amount: int, from_pos: Vector2) -> void:
	if dead or _invuln_timer > 0.0:
		return
	hp = maxi(hp - amount, 0)
	_invuln_timer = 1.0
	_hurt_timer = 0.25
	var push := signf(global_position.x - from_pos.x)
	if push == 0.0:
		push = -facing
	velocity = Vector2(push * 140.0, -140.0)
	Game.shake(4.0)
	Game.hit_stop(0.06)
	_emit_stats()
	if hp <= 0:
		_die()
```
*(from the game)*

* **Invulnerability frames:** for 1 s after a hit, further damage is ignored (and the sprite
  flickers, from `_tick_timers`). Without i-frames, standing in a 5-bullet fan would cost 5 hearts
  instantly.
* `maxi(hp - amount, 0)`: HP never goes negative (the HUD would draw strangely).
* **Knockback direction:** `signf(my_x − attacker_x)` is +1 if the attacker is to the left, so
  we're pushed right, away from it. If exactly aligned (0), push backwards from where we face.
* `_hurt_timer = 0.25`: no control and no shooting for a quarter second, so the knockback reads.
* **Feedback stack:** shake 4 + hit-stop 0.06 s + `hurt` animation + flicker. Getting hit must
  never go unnoticed.

---

## 🏋️ Exercises

1. ★ Make bullets twice as fast and half as long-lived. Does the effective range change?
2. ★ Change the spark colour of player bullets to cyan. Where's the best place to do it: the
   scene or the script?
3. ★★ Add a **shotgun**: on a new `shotgun` action, fire 5 bullets in a fan of ±0.3 rad. Reuse
   `setup()`.
4. ★★ Make grenades **sticky**: on the first collision, set `velocity = Vector2.ZERO` and stop
   moving.
5. ★★ Add **piercing** bullets: an exported `pierce := 0`. When a bullet damages something and
   `pierce > 0`, decrement it and keep flying instead of freeing.
6. ★★★ Create a destructible **barrel** scene (`StaticBody2D` on layer 1, with a sprite from
   `Tile1.png` region `(448, 240, 16, 16)`) with `take_damage` that counts 3 hits, then spawns an
   explosion (`from_player = true`) and frees itself. Notice that bullets and grenades work on it
   with **zero changes**, thanks to duck typing.
7. ★★★ The explosion damages everyone in range equally. Make damage **fall off** with distance:
   full damage at the centre, half at the edge (28 px).

## ✅ Solutions

<details><summary>Exercise 1</summary>

Range = speed × lifetime. 520 × 0.8 = 416 px, the **same range** as 260 × 1.6. Faster bullets
are harder for enemies to dodge and feel snappier.
</details>

<details><summary>Exercise 2</summary>

Set `spark_color` on the bullet **scene** root in the Inspector. Enemy bullets override it in
`shoot_bullet()` anyway. Changing the script default would also change any other scene using
`bullet.gd` that doesn't override it, such as the shockwave if it didn't set its own colour.
</details>

<details><summary>Exercise 3</summary>

```gdscript
if Input.is_action_just_pressed("shotgun") and ammo >= 5:
	ammo -= 5
	for i in 5:
		var a := (i - 2) * 0.15                    # -0.3 … +0.3 rad
		var dir := Vector2.from_angle(a)
		dir.x *= facing
		var b: Area2D = BULLET.instantiate().setup(muzzle.global_position, dir, true, 1)
		get_parent().add_child(b)
	Game.shake(3.0)
	_emit_stats()
```
</details>

<details><summary>Exercise 4</summary>

```gdscript
var _stuck := false

func _physics_process(delta: float) -> void:
	if not _stuck:
		velocity.y += gravity * delta
		var hit := move_and_collide(velocity * delta)
		if hit:
			_stuck = true
			velocity = Vector2.ZERO
	fuse -= delta
	if fuse <= 0.0:
		explode()
```
</details>

<details><summary>Exercise 5</summary>

```gdscript
@export var pierce := 0

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
		if pierce > 0:
			pierce -= 1
			return              # keep flying
	elif not hits_world:
		return
	_spawn_spark()
	queue_free()
```
</details>

<details><summary>Exercise 6</summary>

```gdscript
extends StaticBody2D

const EXPLOSION := preload("res://scenes/projectiles/explosion.tscn")
var hits := 3

func take_damage(_amount: int, _from_pos: Vector2) -> void:
	hits -= 1
	if hits <= 0:
		var e := EXPLOSION.instantiate()
		e.global_position = global_position
		e.from_player = true
		get_parent().add_child.call_deferred(e)
		queue_free()
```
Player bullets have mask `1 | 4`. The barrel is on layer 1 (world), so they hit it, find
`take_damage`, and call it. No bullet code changes.
</details>

<details><summary>Exercise 7</summary>

```gdscript
for body in get_overlapping_bodies():
	if body.has_method("take_damage"):
		var d := body.global_position.distance_to(global_position)
		var t := clampf(d / 28.0, 0.0, 1.0)          # 0 at centre, 1 at edge
		var dmg := int(round(lerp(float(damage), damage * 0.5, t)))
		body.take_damage(maxi(dmg, 1), global_position)
```
</details>

---

📝 **Recap**
* Projectiles: `Area2D`, move with `position += dir * speed * delta`, free on hit or timeout.
* `setup()` returning `self` → configure before `add_child`, and chain the calls.
* Masks decide who can be hurt. Duck typing (`has_method`) decides how.
* Spawn effects into the **parent**, and make them self-cleaning (`finished → queue_free`).
* Defer physics changes made inside physics callbacks.
* Bounce = `move_and_collide` + `velocity.bounce(normal) * damping`.
* Area damage = wait for physics, then query overlaps once.
* The player now shoots, reloads, throws and takes hits with i-frames and knockback.

Next: **[Chapter 8 — Enemies & inheritance](chapter-08-enemies-and-inheritance.md)**
