# Chapter 8 — Enemies & inheritance

🎯 **Goals**
* Design a **base class** that holds everything enemies share, and let child classes fill in
  behaviour through **virtual methods** (the *template method* pattern).
* Use `class_name`, path-based `extends`, overriding and `super`.
* Write simple, readable AI: aggro ranges, keeping distance, bursts, wind-up attacks, stagger.
* Cast **rays** with `PhysicsRayQueryParameters2D` to detect ledges.
* Animate properties with **Tweens** (hit flash, fade-out, bobbing).
* Build **pickups** and the `collect` contract.

---

## Lesson 8.1 — What do all enemies have in common?

Before writing a gunner and a brute, list what they share:

| Shared by all enemies (and bosses) | Different per enemy |
|---|---|
| HP, taking damage, dying, score | how they move |
| gravity, falling into pits | when and how they attack |
| facing and flipping | how they react to a hit (stagger, cancel) |
| contact damage on touch | |
| white hit flash, fade out on death | |
| loot drops | |
| helpers: "where's the player?", "is there floor ahead?", "shoot a bullet" | |

Put the left column in **one base class**, `EnemyBase`. Each enemy then only writes the right
column. That is inheritance used well: **share the boring parts, vary the interesting parts**.

## Lesson 8.2 — The enemy scene template

`scenes/enemies/mook_gunner.tscn` (the brute is identical except for the script, frames and
numbers):

```
mook_gunner       CharacterBody2D   layer 4 (enemies), mask 1|16
├── Sprite        AnimatedSprite2D  (0,-16), frames mook_gunner.tres
├── Shape         CollisionShape2D  10×18 at (0,-9)
├── Hitbox        Area2D            layer 0, mask 2 (player)
│   └── Shape     CollisionShape2D  12×16 at (0,-9)
└── Muzzle        Marker2D          (11,-7)
```

Root exports set **per scene**: gunner `max_hp = 4`, `score_value = 100`, and brute `max_hp = 6`,
`score_value = 150`.

**Why both `Shape` and `Hitbox`?** The body shape **collides** (stands on the floor, blocked by
walls). The `Hitbox` area **detects** the player without physically pushing them. Walking into an
enemy should hurt, not shove you around.

## Lesson 8.3 — `enemy_base.gd`: declaration

```gdscript
class_name EnemyBase
extends CharacterBody2D
## Shared code for every enemy and boss: health, gravity, hit flash,
## contact damage, death, and helpers for aiming and shooting.
## Child scripts override _ai(delta) to give each enemy its behaviour.

const BULLET := preload("res://scenes/projectiles/bullet.tscn")
const PICKUP := preload("res://scenes/pickups/pickup.tscn")

@export var max_hp := 4
@export var gravity := 720.0
@export var score_value := 100
@export var contact_damage := 1
@export var bullet_speed := 150.0

var hp := 0
var facing := -1
var dead := false
var player: Node2D

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var muzzle: Marker2D = $Muzzle
```
*(from the game)*

* `class_name EnemyBase` registers a global type: `var e: EnemyBase`, `if x is EnemyBase`.
* `facing := -1`: enemies start facing **left**, toward a player coming from the left.
* `player: Node2D` is set in `_ready`. It's typed loosely (`Node2D`) because the player script
  has no `class_name`. Accessing `player.dead` then works dynamically.
* **Every enemy scene must have `Sprite`, `Hitbox` and `Muzzle` children**, because the base
  class expects them. That's the implicit **contract between base script and scene**.

> ⚠️ `PICKUP` is preloaded here, so build the pickup scene (Lesson 8.10) before running enemies.

## Lesson 8.4 — The shared frame

```gdscript
func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	collision_layer = 4        # layer 3 "enemies"
	collision_mask = 1 | 16    # world + platforms
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2  # touches the player
	player = get_tree().get_first_node_in_group("player")
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 400.0)
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		return
	_ai(delta)
	move_and_slide()
	sprite.flip_h = facing < 0
	muzzle.position.x = absf(muzzle.position.x) * facing
	if contact_damage > 0:
		for body in hitbox.get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(contact_damage, global_position)
	if global_position.y > 340.0:
		die()
```
*(from the game)*

* **Layers set in code** as well as in the scene. Belt and braces: any enemy scene gets correct
  physics even if someone mis-clicks in the Inspector.
* **Finding the player** via the group: no node paths, so it works wherever the player sits in
  the tree.
* **The frame skeleton:** gravity → (dead? slide to a stop) → **`_ai(delta)`** → move → flip →
  contact damage → pit check. Children never rewrite this. They only fill in `_ai`.
* **Contact damage:** checked **every frame** with `get_overlapping_bodies()` (not
  `body_entered`, which only fires once). If you stand inside an enemy, you keep getting hurt as
  soon as your i-frames end. The player's 1 s invulnerability rate-limits it.

## Lesson 8.5 — 🔤 Virtual methods and the template method pattern

```gdscript
## Override in child scripts.
func _ai(_delta: float) -> void:
	pass
```
*(from the game)*

The base class **calls** `_ai()` but leaves it empty. A child class **overrides** it. When
`_physics_process` (in the base) calls `_ai(delta)`, GDScript runs the **child's** version. That's
**polymorphism**: one call, different behaviour depending on the object's actual class.

This structure, a fixed skeleton in the base with **hooks** that children override, is the
**template method pattern**. `EnemyBase` has three hooks:

| Hook | Default | Overridden by |
|---|---|---|
| `_ai(delta)` | nothing | gunner, brute, `BossBase` |
| `_on_hurt(amount, from_pos)` | nothing | gunner, brute (stagger) |
| `_on_died()` | random loot + fade out | `BossBase` (explosions, victory) |

## Lesson 8.6 — Helper methods

```gdscript
func player_alive() -> bool:
	return is_instance_valid(player) and not player.dead


func to_player() -> Vector2:
	return player.global_position - global_position


func face_player() -> void:
	var dx := to_player().x
	if absf(dx) > 2.0:
		facing = int(signf(dx))
```
*(from the game)*

* `player_alive` protects against both a freed player and a dead one. Every AI starts with it.
* `face_player` has a **2 px dead zone**. Directly above or below the player, `dx` jitters around
  0 and the enemy would flip every frame.

```gdscript
## True if there is floor a few pixels ahead in direction `dir`
## (stops enemies from walking off ledges).
func ground_ahead(dir: int) -> bool:
	var from := global_position + Vector2(dir * 12, -4)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 24), 1 | 16)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()
```
*(from the game)*

### 🔤 Raycasts from code
A **raycast** asks the physics engine "does this line hit anything?"

1. `PhysicsRayQueryParameters2D.create(from, to, mask)` describes the ray: start, end, and which
   layers to look for (world + platforms).
2. `get_world_2d().direct_space_state` is the physics world you can query directly.
3. `intersect_ray(q)` returns a **Dictionary**: empty if nothing was hit, otherwise
   `{position, normal, collider, …}`.

```
    enemy ──►  12 px ahead
      ●         │  ray from y−4 …
     ███        │
 ═══════════    ▼  … to y+20: floor? yes → keep walking
                    nothing? → there's a drop → stop
```

The alternative is a `RayCast2D` child node. That's handy in the editor, but you'd need to flip it
with `facing`. A code query is self-contained and runs only when asked.

```gdscript
func play(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func shoot_bullet(dir: Vector2, damage: int = 1, speed: float = -1.0) -> void:
	var b: Area2D = BULLET.instantiate().setup(muzzle.global_position, dir, false, damage,
			bullet_speed if speed < 0.0 else speed)
	b.modulate = Color(1.0, 0.45, 0.4)
	b.spark_color = Color(1.0, 0.4, 0.3)
	get_parent().add_child(b)


## Direction from the muzzle to the player's chest.
func aim_at_player() -> Vector2:
	return (player.global_position + Vector2(0, -10) - muzzle.global_position).normalized()
```
*(from the game)*

* `play()` restarts a one-shot animation if it has finished. Calling `play("hurt")` twice in a
  row plays it twice.
* `shoot_bullet` tints enemy bullets **red**. This is a readability rule: red means danger.
* A long line is continued on the next line inside the parentheses. GDScript allows line breaks
  inside `()`, `[]` and `{}`.
* `aim_at_player` aims 10 px above the feet, at the chest. Aiming at the origin (feet) would
  send bullets into the ground.

## Lesson 8.7 — Damage, flash and death

```gdscript
func take_damage(amount: int, from_pos: Vector2) -> void:
	if dead:
		return
	hp -= amount
	_flash()
	_on_hurt(amount, from_pos)
	if hp <= 0:
		die()


func _flash() -> void:
	sprite.modulate = Color(4, 4, 4)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.12)


## Override for a reaction to being hit (stagger, knockback...).
func _on_hurt(_amount: int, _from_pos: Vector2) -> void:
	pass
```
*(from the game)*

### 🔤 Tweens
A **Tween** animates a property from its current value to a target over time, with no animation
resource needed.

```gdscript
var t := create_tween()                                   # bound to this node
t.tween_property(sprite, "modulate", Color.WHITE, 0.12)   # object, property, final value, seconds
```

* `modulate` **multiplies** the sprite's colours. `Color(4, 4, 4)` pushes every pixel to white
  (a silhouette flash), then the tween returns it to normal (`WHITE` = ×1) in 0.12 s.
* Steps added to one tween run **in sequence**. Useful extras:
  `tween_interval(s)` waits, `tween_callback(f)` calls a function,
  `set_trans(Tween.TRANS_SINE)` eases the motion, and `set_loops()` repeats forever.
* A tween made with `create_tween()` on a node is killed automatically when the node is freed.

```gdscript
func die() -> void:
	if dead:
		return
	dead = true
	hp = 0
	collision_layer = 0
	hitbox.set_deferred("monitoring", false)
	sprite.play("dead")
	Game.add_score(score_value)
	_on_died()


## Override to change what happens on death. Default: maybe drop loot, then fade out.
func _on_died() -> void:
	var roll := randf()
	if roll < 0.25:
		_drop("health")
	elif roll < 0.35:
		_drop("grenade")
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)


func _drop(kind: String) -> void:
	var p := PICKUP.instantiate()
	p.kind = kind
	p.global_position = global_position + Vector2(0, -8)
	get_parent().add_child.call_deferred(p)
```
*(from the game)*

* `collision_layer = 0`: bullets pass through corpses.
* `hitbox.set_deferred("monitoring", false)`: no more contact damage. It's deferred because `die()`
  is often called *during* a physics callback (a bullet's `body_entered`).
* **Loot with one roll:** `randf()` in [0, 1). 0–0.25 gives health (25 %), 0.25–0.35 gives a
  grenade (10 %), and the rest gives nothing. One random number and a ladder of thresholds is the
  standard way to do weighted chances.
* **The death sequence as one tween:** wait 1.2 s (the corpse lies there) → fade alpha to 0 over
  0.5 s → free. `"modulate:a"` is a **sub-property path**: just the alpha channel.

## Lesson 8.8 — The Gunner

```gdscript
extends "res://scripts/enemies/enemy_base.gd"
## Street thug with a rifle (Enimies_1). Keeps his distance and fires
## 3-round bursts. Bullets are slow enough to jump over.

@export var walk_speed := 40.0
@export var aggro_range := 230.0
@export var burst_size := 3
@export var burst_cooldown := 1.8

var _cooldown := 1.0
var _burst_left := 0
var _burst_timer := 0.0
var _stun := 0.0
```
*(from the game)*

`_cooldown` starts at 1.0, so a gunner doesn't fire the instant you appear. It gives you a moment
to react.

```gdscript
func _ai(delta: float) -> void:
	_stun -= delta
	if _stun > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		return
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return

	var d := to_player()
	if absf(d.x) > aggro_range or absf(d.y) > 90.0:
		velocity.x = 0.0
		play("idle")
		return

	face_player()
	_cooldown -= delta
```
*(from the game)*

A **cascade of guard clauses**, each one a reason not to do the main behaviour:

1. Stunned? Slide to a stop and do nothing else.
2. Player dead? Idle.
3. Player out of range (230 px across, 90 px up or down)? Idle. Enemies off-screen don't shoot
   you in the back.

```gdscript
	# Firing a burst: stand still and shoot every 0.18s.
	if _burst_left > 0:
		velocity.x = 0.0
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_left -= 1
			_burst_timer = 0.18
			shoot_bullet(Vector2(facing, 0))
		play("shot")
		return
```
*(from the game)*

**A burst is a mini state** stored in two variables: shots left and time until the next shot.
While a burst is in progress, the gunner does nothing else.

```gdscript
	# Keep a comfortable distance from the player.
	var move := 0
	if absf(d.x) > 150.0:
		move = facing
	elif absf(d.x) < 60.0:
		move = -facing
	if move != 0 and ground_ahead(move):
		velocity.x = move * walk_speed
		play("walk")
	else:
		velocity.x = 0.0
		play("idle")

	if _cooldown <= 0.0 and absf(d.y) < 40.0:
		_cooldown = burst_cooldown + randf_range(0.0, 0.6)
		_burst_left = burst_size
		_burst_timer = 0.15
```
*(from the game)*

* **Spacing behaviour:** too far (> 150) → approach, too close (< 60) → back away, in between →
  hold position. Three lines give the gunner a believable "ranged fighter" personality.
* `ground_ahead(move)` stops it backing off a ledge.
* **Start a burst** only when the player is roughly level (|dy| < 40), so its horizontal shots can
  actually hit.
* **Random cooldown** (1.8–2.4 s): several gunners don't fire in perfect sync, which would look
  mechanical and be unfair.
* `_burst_timer = 0.15`: a tiny delay before the first shot, a tell.

```gdscript
func _on_hurt(_amount: int, from_pos: Vector2) -> void:
	_stun = 0.15
	_burst_left = 0
	velocity.x = signf(global_position.x - from_pos.x) * 50.0
	sprite.play("hurt")
```
*(from the game)*

Getting shot **interrupts the burst**. This rewards aggression: keep shooting a gunner and it
can't shoot back.

## Lesson 8.9 — The Brute

```gdscript
extends "res://scripts/enemies/enemy_base.gd"
## Bald brute with an axe (Enimies_4). Runs at the player and swings.

@export var walk_speed := 45.0
@export var run_speed := 80.0
@export var aggro_range := 200.0
@export var attack_damage := 2

var _attack_timer := 0.0
var _hit_done := false
var _stun := 0.0


func _ai(delta: float) -> void:
	_stun -= delta
	if _stun > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		return
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return

	var d := to_player()

	# Mid-swing: the hit lands ~0.2s into the animation.
	if _attack_timer > 0.0:
		_attack_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if not _hit_done and _attack_timer < 0.25:
			_hit_done = true
			if absf(d.x) < 30.0 and absf(d.y) < 24.0 and signf(d.x) == facing:
				player.take_damage(attack_damage, global_position)
		return
```
*(from the game)*

**Wind-up attacks.** The swing lasts 0.45 s. The damage check happens **once**, when 0.25 s remain
(0.2 s in). That delay is the **tell**: you see the axe go up and can back off. If the brute hit
instantly on contact, it would feel cheap.

* `_hit_done` makes sure the hit is checked only once per swing.
* The hit needs the player within 30 px **and in front** (`signf(d.x) == facing`). Jumping over
  the brute dodges the swing.

```gdscript
	if absf(d.x) > aggro_range or absf(d.y) > 90.0:
		velocity.x = 0.0
		play("idle")
		return

	face_player()
	if absf(d.x) < 22.0 and absf(d.y) < 24.0:
		_attack_timer = 0.45
		_hit_done = false
		velocity.x = 0.0
		sprite.play("attack_1")
	elif ground_ahead(facing):
		var fast := absf(d.x) < 110.0
		velocity.x = facing * (run_speed if fast else walk_speed)
		play("run_attack" if fast else "walk")
	else:
		velocity.x = 0.0
		play("idle")


func _on_hurt(_amount: int, from_pos: Vector2) -> void:
	_stun = 0.12
	_attack_timer = 0.0
	velocity.x = signf(global_position.x - from_pos.x) * 40.0
	sprite.play("hurt")
```
*(from the game)*

* **Escalation:** walk from far away, **sprint** when close (110 px). It reads as "he's coming for
  you!"
* Being hit **cancels the swing** (`_attack_timer = 0.0`). Shooting a brute is how you survive it.
* Note the swing trigger range (22 px) is smaller than the hit range (30 px), so the brute starts
  only when sure, and the hit still lands if you're just leaving.

## Lesson 8.10 — Pickups and the `collect` contract

`scenes/pickups/pickup.tscn`: an `Area2D` (layer 8 "pickups", mask 2 "player") with a `Sprite`
(offset (0, −8)) and a 14×14 shape.

```gdscript
extends Area2D
## Health or grenade pickup. The icon is cut out of the city tilesheet.

const TILES := preload("res://asset/Tiled/Tile1.png")
const GRENADE_TEX := preload("res://asset/Characters/Other/Granate_Cast.png")

@export_enum("health", "grenade") var kind := "health"
@export var expires := true     ## Dropped pickups vanish after a while.

var _life := 10.0


func _ready() -> void:
	collision_layer = 8   # layer 4 "pickups"
	collision_mask = 2    # only the player can collect it
	var tex := AtlasTexture.new()
	if kind == "health":
		tex.atlas = TILES
		tex.region = Rect2(26 * 16, 15 * 16, 16, 16)  # red soda can
	else:
		tex.atlas = GRENADE_TEX
		tex.region = Rect2(8, 8, 16, 16)
	$Sprite.texture = tex
	body_entered.connect(_on_body_entered)
	# Bob up and down forever.
	var t := create_tween().set_loops()
	t.tween_property($Sprite, "position:y", -3.0, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property($Sprite, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)
```
*(from the game)*

* `@export_enum("health", "grenade")` shows a **dropdown** in the Inspector, so designers can't
  type `"helth"`.
* **One scene, two looks:** the texture is chosen in code from `kind`. The health can is cut
  from the tilesheet (cell 26, 15). The grenade icon is cropped from the centre of the first
  grenade frame.
* **Endless bob:** a looping tween moves the sprite up 3 px and back, with **sine easing**
  (slow at the ends, fast in the middle), which gives a gentle float. Moving the **Sprite**, not
  the Area, keeps the collision box still.

```gdscript
func _process(delta: float) -> void:
	if not expires:
		return
	_life -= delta
	if _life < 3.0:
		visible = fmod(_life, 0.2) > 0.1  # blink before disappearing
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("collect") and body.collect(kind):
		queue_free()
```
*(from the game)*

* Dropped loot (`expires = true`) lasts 10 s and blinks for the last 3 as a warning. Placed and
  reward pickups set `expires = false`.
* **The collect contract:** `collect(kind) -> bool`. The pickup only disappears if the collector
  **used** it. Short-circuit `and` means `collect` is only called if it exists.

Now add the final method to `player.gd`:

```gdscript
## Called by pickups. Returns true if the item was used.
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
*(from the game)*

At full health, health pickups **stay on the ground** for later. That's a small kindness players
appreciate.

**The player script is now complete.** Compare it with `scripts/player/player.gd`. It should match
line for line.

---

## 🏋️ Exercises

1. ★ Make the gunner fire 5-round bursts with a shorter cooldown, only by editing the **scene's**
   Inspector values. Which values did you change?
2. ★ Change loot chances to 40 % health, 20 % grenade.
3. ★★ Give the brute a **jump**: if the player is on a platform above (d.y < −30) and close
   horizontally, jump with `velocity.y = -260` when on the floor.
4. ★★ Make enemies **patrol** when the player is out of range: walk back and forth, turning at
   ledges (`ground_ahead`) and walls (`is_on_wall()`).
5. ★★ Add a third enemy, a **Charger** using `Enimies_6` (it has `walk_attack`): it waits, then
   rushes in a straight line at 160 px/s for 1 s. Create the SpriteFrames (chapter 4), the scene,
   and a script that `extends` the base.
6. ★★★ Bullets currently pass through *other* enemies. Make the gunner **not shoot** when another
   enemy is between it and the player. (Hint: a raycast with mask 4, excluding itself via
   `q.exclude = [get_rid()]`.)
7. ★★★ Replace the loot ladder with a **weighted table**: `const LOOT := {"health": 25,
   "grenade": 10, "": 65}`, and write a function that picks a key by weight.

## ✅ Solutions

<details><summary>Exercise 1</summary>

Select the root of `mook_gunner.tscn` → **Burst Size = 5**, **Burst Cooldown = 1.0**. The script
defaults stay untouched. Only this scene (and its instances) change.
</details>

<details><summary>Exercise 2</summary>

```gdscript
if roll < 0.4:
	_drop("health")
elif roll < 0.6:
	_drop("grenade")
```
</details>

<details><summary>Exercise 3</summary>

```gdscript
# in mook_brute.gd _ai, before the walking branch:
if d.y < -30.0 and absf(d.x) < 60.0 and is_on_floor():
	velocity.y = -260.0
```
</details>

<details><summary>Exercise 4</summary>

```gdscript
var _patrol_dir := -1

# replace the "out of range → idle" block with:
if absf(d.x) > aggro_range or absf(d.y) > 90.0:
	if is_on_wall() or not ground_ahead(_patrol_dir):
		_patrol_dir = -_patrol_dir
	facing = _patrol_dir
	velocity.x = _patrol_dir * walk_speed * 0.5
	play("walk")
	return
```
</details>

<details><summary>Exercise 5</summary>

```gdscript
extends "res://scripts/enemies/enemy_base.gd"

var _timer := 1.5
var _charging := false

func _ai(delta: float) -> void:
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return
	_timer -= delta
	if _charging:
		velocity.x = facing * 160.0
		play("walk_attack")
		if _timer <= 0.0 or is_on_wall() or not ground_ahead(facing):
			_charging = false
			_timer = 1.5
	else:
		velocity.x = 0.0
		face_player()
		play("idle")
		if _timer <= 0.0 and absf(to_player().x) < 200.0:
			_charging = true
			_timer = 1.0
```
</details>

<details><summary>Exercise 6</summary>

```gdscript
func line_of_fire_clear() -> bool:
	var q := PhysicsRayQueryParameters2D.create(muzzle.global_position,
			player.global_position + Vector2(0, -10), 4)
	q.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

# when starting a burst:
if _cooldown <= 0.0 and absf(d.y) < 40.0 and line_of_fire_clear():
```
</details>

<details><summary>Exercise 7</summary>

```gdscript
const LOOT := {"health": 25, "grenade": 10, "": 65}

func pick_weighted(table: Dictionary) -> String:
	var total := 0
	for k in table:
		total += table[k]
	var r := randi() % total
	for k in table:
		r -= table[k]
		if r < 0:
			return k
	return ""

func _on_died() -> void:
	var kind := pick_weighted(LOOT)
	if kind != "":
		_drop(kind)
	...
```
Tables are easier to tune and extend than `if/elif` ladders.
</details>

---

📝 **Recap**
* Put shared behaviour in a base class and leave **hooks** (`_ai`, `_on_hurt`, `_on_died`) for
  children. That's the template method pattern.
* Children `extends` the base (by `class_name` or by path) and override hooks.
* AI is a cascade of guard clauses, then simple rules (ranges, spacing, cooldowns with
  randomness).
* Wind-ups (tells) and interrupts make attacks fair. Rays stop enemies walking off ledges.
* Tweens: flash, fade, bob, with sequences, intervals, callbacks, loops and easing.
* Pickups + `collect() -> bool` complete the player.

Next: **[Chapter 9 — Bosses & state machines](chapter-09-bosses-and-state-machines.md)**
