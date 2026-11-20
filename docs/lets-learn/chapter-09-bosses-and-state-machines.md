# Chapter 9 — Bosses & state machines

🎯 **Goals**
* Understand **finite state machines** (FSMs) and implement them with a string state plus `match`.
* Build a second inheritance layer: `EnemyBase` → `BossBase` → three bosses.
* Design boss fights with **tells**, **punish windows** and a **phase 2**.
* Use trigonometry for aimed bursts and bullet fans, and basic **ballistics** to land grenades
  and leaps where you want.
* Coordinate a boss with the rest of the game through signals.

---

## Lesson 9.1 — Why bosses need a state machine

A mook's AI is a few rules evaluated every frame. A boss does **sequences**: blink red, then
charge, then slam into the wall, then be stunned, then recover. Each step lasts a while and
behaves differently.

A **finite state machine** models exactly that:

* The boss is in **one state** at a time (`idle`, `windup`, `charge`…).
* Each state has its own **behaviour** each frame.
* Each state has **transitions**: conditions that switch to another state.

```
              ┌──────────── state_time > 0.8 ────────────┐
              ▼                                           │
          ┌──────┐ choose ┌────────┐ 0.65s ┌────────┐ wall ┌─────────┐
          │ idle │───────►│ windup │──────►│ charge │─────►│ stunned │
          └──────┘        └────────┘       └────────┘      └─────────┘
              ▲                                                 │ 1.1s
              └─────────────────────────────────────────────────┘
```

**Implementation options:**

| Approach | When it fits |
|---|---|
| `var state: String` + `match` (this game) | small to medium FSMs, everything visible in one function |
| `enum State { IDLE, CHARGE }` + `match` | same, with typo-proof names |
| One node or class per state | large FSMs with complex enter/exit logic |
| `AnimationTree` state machine | when states are mostly animations |

Strings are the simplest to read and debug (`print(state)` shows `"charge"`). The trade-off is
that a typo like `"chrage"` silently never matches. Exercise 1 converts a boss to an `enum`.

## Lesson 9.2 — `boss_base.gd`

```gdscript
class_name BossBase
extends "res://scripts/enemies/enemy_base.gd"
## Shared boss logic. A boss waits until its arena calls activate(),
## runs a simple state machine (state + state_time), and enters
## "phase 2" (faster, more aggressive) below half health.

const EXPLOSION := preload("res://scenes/projectiles/explosion.tscn")

@export var boss_name := "BOSS"
@export var is_final := false

var active := false
var state := "idle"
var state_time := 0.0
var arena_left := -INF   ## Set by the arena so bosses know where the walls are.
var arena_right := INF
var _phase2_announced := false
```
*(from the game)*

* A second inheritance layer: a boss **is an** enemy (HP, flash, contact damage, helpers all
  come for free) **plus** boss features.
* `active`: bosses spawn **inactive** during the intro. They stand idle and can't be hurt
  (see `take_damage`).
* `state` + `state_time` are the whole FSM engine: which state, and for how long.
* `arena_left/right` start at ±infinity (`INF`), meaning "no walls", so a boss dropped into a test
  scene still works.

```gdscript
func _ready() -> void:
	super._ready()
	# Bosses are heavy: they ignore one-way platforms and stay on the street,
	# so the platforms are only an escape route for the player.
	collision_mask = 1
```
*(from the game)*

**Design through physics:** removing bit 16 (platforms) from the mask means bosses can't stand on
platforms. Platforms become the player's **safe zone** and escape route. That's a design decision
made with one integer.

```gdscript
func activate() -> void:
	active = true
	Game.boss_started.emit(boss_name, max_hp)
	set_state("idle")


func in_phase2() -> bool:
	return hp <= max_hp / 2


func set_state(new_state: String) -> void:
	state = new_state
	state_time = 0.0


func arena_center() -> float:
	return (arena_left + arena_right) * 0.5
```
*(from the game)*

* `activate()` is called by the arena after the intro. It announces the fight, and the HUD shows
  the boss bar.
* `in_phase2()`: half HP or less. (`max_hp / 2` is integer division: 60 → 30, 90 → 45.)
* **Always change state through `set_state`**, so `state_time` resets. Every "after X seconds"
  check then just reads `state_time > X`.

```gdscript
func _ai(delta: float) -> void:
	if not active:
		velocity.x = 0.0
		play("idle")
		return
	state_time += delta
	_boss_ai(delta)


## Override in each boss.
func _boss_ai(_delta: float) -> void:
	pass
```
*(from the game)*

`BossBase` **implements** `EnemyBase`'s hook `_ai` and **offers a new hook** `_boss_ai`. Each
layer adds what it knows and leaves the rest to the next one down.

```gdscript
func take_damage(amount: int, from_pos: Vector2) -> void:
	if not active or dead:
		return
	super.take_damage(amount, from_pos)
	Game.boss_hp_changed.emit(maxi(hp, 0))
	if not dead and in_phase2() and not _phase2_announced:
		_phase2_announced = true
		Game.message(boss_name + " IS ENRAGED!", 1.5)
		Game.shake(4.0)
```
*(from the game)*

* **Extending, not replacing:** `super.take_damage(...)` runs all the normal enemy logic (HP,
  flash, `_on_hurt`, death). Then boss extras: update the bar and announce phase 2 **once**.
* Invulnerable while inactive, so you can't kill the boss during its intro.

```gdscript
func _on_died() -> void:
	active = false
	Game.bosses_defeated += 1
	Game.hit_stop(0.15)
	Game.shake(8.0)
	# Chain of explosions (damage 0, purely visual).
	for i in 4:
		var e := EXPLOSION.instantiate()
		e.damage = 0
		e.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-30, 0))
		get_tree().create_timer(0.2 * i).timeout.connect(func() -> void: get_parent().add_child(e))
	for m in get_tree().get_nodes_in_group("summons"):
		m.die()
	Game.boss_defeated.emit(boss_name, is_final)
	var t := create_tween()
	t.tween_interval(2.5)
	t.tween_property(self, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)
```
*(from the game)*

* **Overrides** the default (no random loot. The arena gives a fixed reward instead).
* **Big feedback:** the longest hit-stop (0.15 s) and strongest shake (8) in the game.
* **Explosion chain:** four explosions at random offsets, 0.2 s apart. Each is scheduled with a
  one-shot timer and a lambda that **captures** its own `e`. That's a neat way to schedule several
  delayed actions without `await` (which would pause this function).
* **Clean up summons** so the player isn't left fighting backup after the boss dies.
* **`boss_defeated` signal:** the HUD shows the message or victory, and the arena opens its walls.
  The boss doesn't know about either.

## Lesson 9.3 — Boss 1: DEADEYE ROOK, the teacher

**Design goal:** the first boss teaches the core skills. Jump over bullets, read the pose, and
punish the reload.

```gdscript
extends "res://scripts/bosses/boss_base.gd"
## BOSS 1 - "DEADEYE" ROOK (Enimies_3, shown at 2x size).
## A gunslinger. Attacks:
##   burst   - aimed rapid bursts (3 shots, 5 in phase 2)
##   hop_fan - hops away from the player, then fires a fan of bullets on landing
##   walk    - closes the distance
##   reload  - every 3rd attack he must reload: free damage window

var _attacks_since_reload := 0
var _shots_left := 0
var _shot_timer := 0.0
```
*(from the game)*

> 📝 The comment says "every 3rd attack", but the code below picks `reload` once 3 attacks have
> been chosen since the last one, so the **4th choice** is a reload. Comments drift from code. When
> they disagree, trust the code, and fix the comment.

```gdscript
func _boss_ai(delta: float) -> void:
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return
	var p2 := in_phase2()
	match state:
		"idle":
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			play("idle")
			if state_time > (0.45 if p2 else 0.75):
				_choose_attack()
```
*(from the game)*

**Idle is the hub.** Every attack returns here. The pause between attacks (0.75 s, or 0.45 s in
phase 2) is the player's breathing room, and shortening it is the cheapest way to raise
difficulty.

```gdscript
		"burst":
			velocity.x = 0.0
			face_player()
			play("shot")
			_shot_timer -= delta
			if _shot_timer <= 0.0 and _shots_left > 0:
				_shots_left -= 1
				_shot_timer = 0.12 if p2 else 0.16
				shoot_bullet(aim_at_player(), 1, 170.0)
			if _shots_left == 0 and _shot_timer <= 0.0:
				set_state("idle")
```
*(from the game)*

* **Aimed** shots (`aim_at_player()` each shot) track you, so you must move or jump.
* The state ends when shots are used up **and** the last interval has passed, so the final shot
  isn't cut short.

```gdscript
		"hop_fan":
			play("walk")
			if state_time > 0.15 and is_on_floor():
				velocity.x = 0.0
				face_player()
				var count := 5 if p2 else 3
				var base := aim_at_player().angle()
				for i in count:
					var a := base + (i - (count - 1) / 2.0) * 0.22
					shoot_bullet(Vector2.from_angle(a), 1, 150.0)
				sprite.play("shot")
				set_state("idle")
```
*(from the game)*

* `state_time > 0.15 and is_on_floor()`: **landing detection**. Right after the jump starts, the
  boss may still be touching the floor. Waiting 0.15 s ensures we detect the *landing*, not the
  take-off.
* **The fan formula** `(i − (count − 1) / 2.0) × spacing` centres any number of bullets on the aim
  angle:

| count | i values | offsets (× 0.22 rad) |
|---|---|---|
| 3 | 0, 1, 2 | −1, 0, +1 |
| 5 | 0…4 | −2, −1, 0, +1, +2 |

```gdscript
		"walk":
			face_player()
			play("walk")
			velocity.x = facing * (75.0 if p2 else 55.0)
			if state_time > 1.0 or absf(to_player().x) < 60.0:
				set_state("burst")
				_shots_left = 2
				_shot_timer = 0.1

		"reload":
			velocity.x = 0.0
			play("recharge")
			if state_time > (0.9 if p2 else 1.3):
				set_state("idle")
```
*(from the game)*

**The reload is a punish window.** For 1.3 s he stands still doing nothing dangerous. Good boss
design gives the player **openings** to earn. Here, recognising the `recharge` animation means
free damage.

```gdscript
func _choose_attack() -> void:
	_attacks_since_reload += 1
	if _attacks_since_reload > 3:
		_attacks_since_reload = 0
		set_state("reload")
		return
	var roll := randf()
	var dist := absf(to_player().x)
	if dist < 70.0 or roll < 0.35:
		# Hop away from the player, but toward the arena centre if a wall is behind.
		var away := -facing
		if (away < 0 and global_position.x - arena_left < 70.0) or (away > 0 and arena_right - global_position.x < 70.0):
			away = facing
		velocity = Vector2(away * 120.0, -260.0)
		set_state("hop_fan")
	elif roll < 0.8 or dist < 140.0:
		_shots_left = 5 if in_phase2() else 3
		_shot_timer = 0.25  # short wind-up so the player can react
		set_state("burst")
	else:
		set_state("walk")
```
*(from the game)*

**Choosing attacks** mixes **rules** with **randomness**:

* A **guaranteed** reload on a counter is predictable, which is learnable.
* **Too close** (< 70 px) → hop away, so a gunslinger keeps his distance.
* **Wall awareness:** if hopping "away" would hit a wall within 70 px, hop the other way. Without
  this, he'd jump into the wall and fire point-blank.
* Otherwise, weighted random: 35 % hop, 45 % burst, 20 % walk, with mid-range forcing burst.
* `_shot_timer = 0.25`: a **tell** before the first shot.

## Lesson 9.4 — Boss 2: BONECRUSHER, read the tells

**Design goal:** a melee boss. Telegraphed charges, leaps with shockwaves, and a big reward for
dodging.

```gdscript
extends "res://scripts/bosses/boss_base.gd"
## BOSS 2 - BONECRUSHER (Enimies_5, shown at 2x size).
## A heavy melee bruiser. Attacks:
##   charge - flashes red, then rushes across the arena; gets stunned on hitting a wall
##   leap   - jumps at the player and sends shockwaves along the floor (jump over them!)
##   swipe  - close-range hit

const SHOCKWAVE := preload("res://scenes/projectiles/shockwave.tscn")

var _hit_done := false
var _leaps_left := 0


func _boss_ai(delta: float) -> void:
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return
	var p2 := in_phase2()
	match state:
		"idle":
			contact_damage = 1
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			play("idle")
			if state_time > (0.45 if p2 else 0.8):
				_choose_attack()

		"windup":
			velocity.x = 0.0
			play("idle")
			# Blink red as a warning.
			sprite.modulate = Color(2.5, 0.6, 0.6) if fmod(state_time, 0.16) < 0.08 else Color.WHITE
			if state_time > (0.45 if p2 else 0.65):
				sprite.modulate = Color.WHITE
				set_state("charge")
```
*(from the game)*

* **Contact damage changes by state:** 1 normally, 2 while charging, 0 while stunned. It reuses
  `EnemyBase`'s contact system by changing just one number.
* **The windup tell:** red blinking for 0.65 s. `fmod(t, 0.16) < 0.08` toggles every 0.08 s.
  **Reset to white** before leaving, or he'd stay red.

```gdscript
		"charge":
			contact_damage = 2
			play("walk_attack")
			velocity.x = facing * (240.0 if p2 else 190.0)
			if state_time > 0.1 and (is_on_wall() or state_time > 2.5):
				Game.shake(6.0)
				velocity.x = -facing * 60.0
				velocity.y = -120.0
				set_state("stunned")

		"stunned":
			contact_damage = 0
			play("hurt" if state_time < 0.2 else "idle")
			sprite.rotation = sin(state_time * 30.0) * 0.08
			if state_time > (0.7 if p2 else 1.1):
				sprite.rotation = 0.0
				set_state("idle")
```
*(from the game)*

* **Charge** runs until he hits a wall (`is_on_wall()`, available after `move_and_slide`). The
  2.5 s timeout is a **safety net**: if he somehow never hits a wall, he doesn't charge forever.
  Always give states an exit.
* `state_time > 0.1`: ignore a wall he's already touching at the start.
* **Wall slam:** shake, bounce back, and become **stunned**. The arena walls exist for gameplay,
  not just to trap you.
* **Stunned wobble:** `sin(t × 30) × 0.08` rotates the sprite slightly back and forth (about
  5 times a second), a "seeing stars" effect done with one line of maths.

```gdscript
		"leap":
			play("cast")
			if state_time > 0.2 and is_on_floor():
				velocity.x = 0.0
				Game.shake(5.0)
				_spawn_shockwaves()
				_leaps_left -= 1
				if _leaps_left > 0:
					_start_leap()
				else:
					set_state("idle")

		"swipe":
			velocity.x = 0.0
			if not _hit_done and state_time > 0.2:
				_hit_done = true
				var d := to_player()
				if absf(d.x) < 46.0 and absf(d.y) < 40.0:
					player.take_damage(2, global_position)
			if state_time > 0.5:
				set_state("idle")
```
*(from the game)*

* **Chained leaps:** a counter (`_leaps_left`) makes the `leap` state loop into itself. In phase 2
  he leaps twice.
* The **swipe** is the brute's wind-up pattern at boss scale (0.2 s delay, one check).

```gdscript
func _choose_attack() -> void:
	var d := to_player()
	if absf(d.x) < 44.0:
		_hit_done = false
		sprite.play("attack_1")
		set_state("swipe")
	elif randf() < 0.55:
		face_player()
		set_state("windup")
	else:
		_leaps_left = 2 if in_phase2() else 1
		_start_leap()


func _start_leap() -> void:
	face_player()
	var dx := clampf(to_player().x, -160.0, 160.0)
	velocity = Vector2(dx / 0.8, -300.0)
	set_state("leap")


func _spawn_shockwaves() -> void:
	for dir in [-1, 1]:
		var w: Area2D = SHOCKWAVE.instantiate().setup(global_position + Vector2(dir * 20, 0), Vector2(dir, 0), false, 1, 140.0)
		get_parent().add_child(w)
```
*(from the game)*

### 🔤 Ballistics: aiming a jump
`velocity = Vector2(dx / 0.8, -300.0)`. With gravity 720 and an upward speed of 300, the time in
the air is `2 × 300 / 720 ≈ 0.83 s`. Covering `dx` pixels in about 0.8 s needs a horizontal speed
of `dx / 0.8`. So he **lands near where you were** when he jumped, which is aimed but dodgeable.
`clampf(…, ±160)` limits the leap to less than half the arena.

**Shockwaves:** one in each direction, reusing `bullet.gd` through the shockwave scene (passes
through walls, hurts only the player). The counter is to **jump**.

## Lesson 9.5 — Boss 3: THE PLAGUE DOCTOR, the final exam

**Design goal:** combine everything. Bullet patterns, area denial, repositioning and extra
enemies.

```gdscript
extends "res://scripts/bosses/boss_base.gd"
## BOSS 3 (FINAL) - THE PLAGUE DOCTOR (Enimies_2, shown at 2x size).
## Ruler of the dark city. Attacks:
##   spread   - volleys of 5-bullet fans
##   grenades - lobs grenades that land around the player
##   dash     - leaps over to the other side of the arena
##   summon   - (phase 2) calls two gunmen as backup

const GRENADE := preload("res://scenes/projectiles/grenade.tscn")
const MOOK := preload("res://scenes/enemies/mook_gunner.tscn")

var _volleys_left := 0
var _volley_timer := 0.0
var _summon_cooldown := 0.0
```
*(from the game)*

Notice how much this boss **reuses**: the player's grenade scene and the gunner enemy become the
boss's weapons, just by setting `from_player = false`.

```gdscript
func _boss_ai(delta: float) -> void:
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return
	var p2 := in_phase2()
	_summon_cooldown -= delta
	match state:
		"idle":
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			play("idle")
			if state_time > (0.5 if p2 else 0.8):
				_choose_attack()

		"spread":
			velocity.x = 0.0
			face_player()
			play("shot")
			_volley_timer -= delta
			if _volley_timer <= 0.0 and _volleys_left > 0:
				_volleys_left -= 1
				_volley_timer = 0.45
				var base := aim_at_player().angle()
				for i in 5:
					shoot_bullet(Vector2.from_angle(base + (i - 2) * 0.2), 1, 140.0)
			if _volleys_left == 0 and _volley_timer <= 0.2:
				set_state("idle")

		"grenades":
			velocity.x = 0.0
			play("cast")
			if state_time > 0.25:
				_throw_grenades(3 if p2 else 2)
				set_state("idle")
				state_time = -0.4  # a little extra pause after throwing
```
*(from the game)*

* **Re-aimed volleys:** each fan aims at your *current* position, so after one volley you must
  keep moving.
* **A neat trick:** `state_time = -0.4` right after `set_state("idle")`. Idle waits until
  `state_time > 0.8`, so starting at −0.4 makes this one idle last 1.2 s, giving extra recovery
  after the grenades **without a new state**.

```gdscript
		"dash":
			play("walk")
			if state_time > 0.2 and is_on_floor():
				velocity.x = 0.0
				set_state("idle")

		"summon":
			velocity.x = 0.0
			play("cast")
			if state_time > 0.6:
				_summon()
				set_state("idle")


func _choose_attack() -> void:
	var p2 := in_phase2()
	if p2 and _summon_cooldown <= 0.0 and get_tree().get_nodes_in_group("summons").size() < 2:
		set_state("summon")
		return
	var roll := randf()
	if absf(to_player().x) < 60.0 or roll < 0.25:
		_start_dash()
	elif roll < 0.62:
		_volleys_left = 3 if p2 else 2
		_volley_timer = 0.2
		set_state("spread")
	else:
		set_state("grenades")
```
*(from the game)*

* **Summon has priority** in phase 2, limited by a cooldown **and** a cap (fewer than 2 alive), so
  the arena never floods.
* Too close → **dash away**. A caster shouldn't be easy to stand next to.

```gdscript
func _start_dash() -> void:
	# Jump to the side of the arena the player is NOT on.
	var target := arena_left + 50.0
	if player.global_position.x < arena_center():
		target = arena_right - 50.0
	velocity = Vector2((target - global_position.x) / 1.0, -320.0)
	facing = int(signf(velocity.x)) if velocity.x != 0.0 else facing
	set_state("dash")
```
*(from the game)*

The same ballistics idea: −320 upward gives ≈ 0.9 s of air time, so dividing the distance by ~1 s
lands him near the target. The `/ 1.0` is written out to make the "flight time" assumption visible.

```gdscript
func _throw_grenades(count: int) -> void:
	for i in count:
		var target_x := player.global_position.x + randf_range(-50.0, 50.0)
		var t := 0.9
		var g := GRENADE.instantiate()
		g.global_position = global_position + Vector2(facing * 10, -40)
		g.velocity = Vector2((target_x - g.global_position.x) / t, -0.5 * 600.0 * t + 15.0)
		g.from_player = false
		g.damage = 2
		g.fuse = 1.1 + i * 0.15
		get_parent().add_child(g)
```
*(from the game)*

### 🔤 Ballistics: landing a grenade at a target
We want the grenade to land at `target_x` after `t = 0.9` s.

* **Horizontal:** constant speed → `vx = distance / t`.
* **Vertical:** for a projectile thrown up at `vy` under gravity `g` to come back to the same height
  after `t`, you need `vy = −½ g t`. With g = 600 (the grenade's gravity): `−0.5 × 600 × 0.9 = −270`.
* `+ 15.0` aims slightly lower, because the grenade starts 40 px above the boss's feet and has to
  fall a bit further to reach the ground.
* **Staggered fuses** (`1.1 + i × 0.15`): the explosions go off one after another, not all at once.
  That's more readable, and more threatening.

```gdscript
func _summon() -> void:
	_summon_cooldown = 9.0
	Game.message("BACKUP INCOMING!", 1.2)
	for x in [arena_left + 30.0, arena_right - 30.0]:
		var m := MOOK.instantiate()
		m.global_position = Vector2(x, global_position.y - 150.0)
		m.add_to_group("summons")
		m.score_value = 50
		get_parent().add_child(m)
```
*(from the game)*

Two gunners **drop in from above** at both edges, so the player is caught between them. They're
tagged `"summons"` (so the boss can count them and kill them on death) and worth less score, so
summon farming isn't profitable.

## Lesson 9.6 — Boss design checklist

What these three bosses have in common, as a reusable recipe:

1. **A hub state** (`idle`) with a pause the player can use.
2. **Every dangerous attack has a tell** of at least about 0.25 s (pose, blink, wind-up timer).
3. **At least one punish window** (reload, wall stun, recovery after grenades).
4. **Rules plus randomness** in attack choice: predictable enough to learn, varied enough to stay
   interesting.
5. **Phase 2** raises pressure with the same moves (shorter pauses, more projectiles, faster
   speed), and with a new move for the finale.
6. **Every state has an exit**, including a timeout.
7. **The arena is part of the fight** (walls stop charges, platforms are safe from bosses).

---

## 🏋️ Exercises

1. ★★ Convert `boss_rook.gd` to an `enum State { IDLE, BURST, HOP_FAN, WALK, RELOAD }`. What do
   you gain? What changes in `set_state`'s signature in `boss_base.gd`?
2. ★ Make Bonecrusher's charge telegraph longer in phase 1 (1.0 s). Play it. Is it too easy now?
3. ★★ Give the Rook a **phase-2-only** attack: a 360° ring of 12 bullets on landing from a hop.
4. ★★ Add `print(boss_name, " → ", new_state)` in `set_state` and watch a whole fight in the
   Output. This is how you debug state machines.
5. ★★ The Plague Doctor's grenades always take 0.9 s. Make the flight time random (0.7–1.1 s)
   and update the vertical-velocity formula to match.
6. ★★★ Add an `on_enter(state)` hook to `BossBase` that's called from `set_state`, and use it in
   Bonecrusher to set `contact_damage` once per state instead of every frame.
7. ★★★ Design and implement a **fourth boss** with `Enimies_6`: at least three states, one tell,
   one punish window and a phase-2 change. Add it as a new arena in `build_level.gd` (chapter 10).

## ✅ Solutions

<details><summary>Exercise 1</summary>

```gdscript
enum State { IDLE, BURST, HOP_FAN, WALK, RELOAD }
var st: State = State.IDLE

func set_st(s: State) -> void:
	st = s
	state_time = 0.0

match st:
	State.IDLE:
		...
	State.BURST:
		...
```
You gain **typo safety** (a misspelt enum is a parse error) and autocompletion. `BossBase.state`
is a `String` shared by all bosses (the playtest bot reads it), so either make it `int` in the
base and keep a name table for printing, or keep strings in the base and use enums locally as
shown.
</details>

<details><summary>Exercise 2</summary>

Change `(0.45 if p2 else 0.65)` to `(0.45 if p2 else 1.0)` in the `windup` state. Telegraph length
is a difficulty knob: longer is easier to read but drags the fight. 0.5–0.8 s is typical for a big
attack.
</details>

<details><summary>Exercise 3</summary>

```gdscript
# in "hop_fan", replacing the fan when p2:
if p2:
	for i in 12:
		shoot_bullet(Vector2.from_angle(i * TAU / 12.0), 1, 120.0)
else:
	# original 3-bullet fan
```
`TAU` = 2π, a full circle.
</details>

<details><summary>Exercise 4</summary>

```gdscript
func set_state(new_state: String) -> void:
	print("%s → %s (after %.2fs)" % [boss_name, new_state, state_time])
	state = new_state
	state_time = 0.0
```
</details>

<details><summary>Exercise 5</summary>

```gdscript
var t := randf_range(0.7, 1.1)
g.velocity = Vector2((target_x - g.global_position.x) / t, -0.5 * 600.0 * t + 15.0)
```
The formula already uses `t` everywhere, so randomising it just works. That's the benefit of
writing the maths instead of hard-coding the result (−270).
</details>

<details><summary>Exercise 6</summary>

```gdscript
# boss_base.gd
func set_state(new_state: String) -> void:
	state = new_state
	state_time = 0.0
	_on_enter(new_state)

func _on_enter(_s: String) -> void:
	pass

# boss_bonecrusher.gd
func _on_enter(s: String) -> void:
	match s:
		"charge": contact_damage = 2
		"stunned": contact_damage = 0
		_: contact_damage = 1
```
Then remove the `contact_damage = …` lines inside `_boss_ai`. Enter and exit hooks are the next
step toward a full state-machine architecture.
</details>

<details><summary>Exercise 7</summary>

There's no single answer. Check yours against the checklist in Lesson 9.6. A sample idea: a
"Jumper" that hops between the arena edges (state `hop`), slams down creating shockwaves (tell:
hangs in the air for 0.4 s), and is stunned for 1 s after every third slam (punish). In phase 2 it
adds a mid-air bullet ring.
</details>

---

📝 **Recap**
* FSM = one state at a time + per-state behaviour + transitions. Here: `state` string, `state_time`,
  `match`, `set_state()`.
* Inheritance layers: each adds what it knows and exposes a new hook (`_ai` → `_boss_ai`).
* `super.method()` extends parent behaviour instead of replacing it.
* Boss design: hub state, tells, punish windows, rules + randomness, phase 2, exits on every state.
* Fans: `(i − (n−1)/2) × spacing`. Ballistics: `vx = dx / t`, `vy = −½ g t`.

Next: **[Chapter 10 — Building the level](chapter-10-building-the-level.md)**
