# 03 — Communication between objects

A game is many objects that need to react to each other. When the player takes damage, the HUD
hearts change, the camera shakes and time briefly freezes. How does the information travel?
Dark City uses four mechanisms, each for a different job.

| Mechanism | Direction | Example |
|---|---|---|
| **Direct call** | parent → child, or to a known node | `$Sprite.play("idle")` |
| **Event bus signals** (`Game`) | anyone → anyone listening | `Game.player_hp_changed.emit(hp, max_hp)` |
| **Groups** | find nodes by tag | `get_tree().get_first_node_in_group("player")` |
| **Duck-typed contracts** | projectile → whatever it hit | `if body.has_method("take_damage")` |
| **Service autoloads** | anyone → a global service | `Audio.sfx("shoot", global_position)`, `Settings.get_value("video/rain")` |

---

## 1. The event bus: `scripts/autoload/game.gd`

`Game` is an autoload: one global node, always present. It declares **signals** that describe
things that *happened*:

```gdscript
signal player_hp_changed(hp: int, max_hp: int)
signal player_ammo_changed(ammo: int, mag_size: int, grenades: int, reloading: bool)
signal player_died
signal boss_started(boss_name: String, max_hp: int)
signal boss_hp_changed(hp: int)
signal boss_defeated(boss_name: String, is_final: bool)
signal show_message(text: String, seconds: float)
signal score_changed(score: int)
signal shake_requested(strength: float)
```

### Who emits and who listens

| Signal | Emitted by | Listened to by |
|---|---|---|
| `player_hp_changed` | `player.gd → _emit_stats()` | `hud.gd` (hearts), `playtest.gd` |
| `player_ammo_changed` | `player.gd → _emit_stats()` | `hud.gd` (ammo text, grenade icons) |
| `player_died` | `player.gd → _die()` | `hud.gd` ("YOU DIED" dialog) |
| `boss_started` | `boss_base.gd → activate()` | `hud.gd` (shows boss bar) |
| `boss_hp_changed` | `boss_base.gd → take_damage()` | `hud.gd` (animates bar width) |
| `boss_defeated` | `boss_base.gd → _on_died()` | `hud.gd` (message / victory), `boss_arena.gd` (open walls, reward) |
| `show_message` | `Game.message()`, called from level, arena, bosses, HUD | `hud.gd` (centre banner) |
| `score_changed` | `Game.add_score()`, called from `enemy_base.gd → die()` | `hud.gd` |
| `shake_requested` | `Game.shake()`, called from many places | `game_camera.gd` |

### Why an event bus?

Without one, the boss would need a reference to the HUD to update the health bar, the arena to
open the walls, and so on. Every new feature would add another reference, and deleting the HUD
would crash the boss. With the bus:

* The **boss** only knows `Game` exists. It says "my HP is now 42".
* The **HUD** only knows `Game` exists. It hears "boss HP is 42" and redraws.
* You could delete the HUD and the game would still run, just without a UI.

### Helper methods

`Game` wraps some signals in short helpers, so calling code reads naturally:

```gdscript
func shake(strength: float = 3.0) -> void:
    shake_requested.emit(strength)

func message(text: String, seconds: float = 2.0) -> void:
    show_message.emit(text, seconds)

func add_score(amount: int) -> void:
    score += amount
    score_changed.emit(score)
```

### Global state

```gdscript
var score := 0
var bosses_defeated := 0
var run_time := 0.0
var running := false     # true while the level is being played (drives run_time)
```

This state lives in the autoload because **scene changes destroy everything else**.

### Hit-stop

```gdscript
func hit_stop(seconds: float = 0.05) -> void:
    Engine.time_scale = 0.05
    await get_tree().create_timer(seconds, true, false, true).timeout
    Engine.time_scale = 1.0
```

`Engine.time_scale` slows the **whole game**. The timer's fourth argument,
`ignore_time_scale = true`, makes it count real seconds. Otherwise a 0.06 s timer at 5 % speed
would last 1.2 s.

---

## 2. Groups

A group is a **tag** on a node. Any node can find tagged nodes through the scene tree.

| Group | Added in | Used for |
|---|---|---|
| `"player"` | `player.tscn` (`groups=["player"]`) and `player.gd → add_to_group("player")` | Enemies, level, arenas find the player |
| `"enemies"` | `enemy_base.gd → _ready()` | Playtest counts living enemies and finds bosses |
| `"summons"` | `boss_plague_doctor.gd → _summon()` | Final boss counts its backup. All summons die with the boss. |

```gdscript
player = get_tree().get_first_node_in_group("player")      # one node (or null)
for m in get_tree().get_nodes_in_group("summons"):         # all of them
    m.die()
```

Groups find nodes **without hard-coded paths** like `get_node("../../Player")`, which break as soon
as you rearrange the tree.

---

## 3. Duck-typed contracts

> "If it walks like a duck and quacks like a duck, it's a duck."

GDScript lets you ask whether an object *has a method* before calling it. The game defines two
informal contracts.

### The damage contract

```gdscript
func take_damage(amount: int, from_pos: Vector2) -> void
```

| Implemented by | Behaviour |
|---|---|
| `player.gd` | Ignored while invulnerable. Loses HP, knockback away from `from_pos`, 1 s invulnerability, shake, hit-stop. |
| `enemy_base.gd` | Loses HP, white flash, `_on_hurt()` hook (stagger), dies at 0. |
| `boss_base.gd` (override) | Ignored until active. Calls the base version, emits `boss_hp_changed`, announces phase 2. |

| Called by | How it finds the target |
|---|---|
| `bullet.gd` | `body_entered` signal |
| `explosion.gd` | `get_overlapping_bodies()` after 2 physics frames |
| `enemy_base.gd` | contact damage from `hitbox.get_overlapping_bodies()` |
| `mook_brute.gd`, `boss_bonecrusher.gd` | distance check on `player` during a swing |

`from_pos` lets the victim work out **which way to be knocked back**:

```gdscript
var push := signf(global_position.x - from_pos.x)   # +1 = hit from the left, push right
```

### The collect contract

```gdscript
func collect(kind: String) -> bool    # true = "I used it, delete the pickup"
```

Only `player.gd` implements it. Returning `false` when HP or grenades are already full leaves the
pickup on the ground for later.

---

## 4. Direct calls and `@onready` references

Inside a scene, a script reaches its own children directly:

```gdscript
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
```

`$Sprite` is shorthand for `get_node("Sprite")`. `@onready` delays the lookup until the node
enters the tree, because children don't exist yet when variables are first initialised.

The few cross-scene direct references are deliberate and checked:

* `boss_arena.gd` reads `body.camera` from the player who entered its trigger, to lock the camera.
* `level.gd` reads `player.camera` to set the level bounds.
* Enemies keep `player` and always check `is_instance_valid(player)` before using it
  (`player_alive()`).

---

## 5. Service autoloads: `Settings`, `Audio`, `SaveGame`

`Game` is a *bus* (it mostly announces events). The three newer autoloads are *services*: you
call them to get something done.

| Call | From | Effect |
|---|---|---|
| `Audio.sfx(name, pos)` | player, enemies, bosses, bullets, explosions, weather | plays a pooled sound |
| `Audio.play_music(track)` | title, intro, level, arenas, HUD | cross-fades the music |
| `Settings.get_value(key)` | everything that has an option | reads a preference |
| `Settings.rumble(w, s, t)` | player, explosions, bosses | gamepad vibration |
| `Settings.toast(text)` | HUD, arenas, `Settings` itself | small notification, any scene |
| `SaveGame.save_now()` | pause menu, arenas (autosave) | writes the save file |
| `SaveGame.apply_pending(level)` | `level.gd` | restores a loaded run |

And one signal goes the other way. **`Settings.changed(key)`** is emitted whenever a preference
changes, so things update live:

| Listener | Reacts to |
|---|---|
| `Audio` | `audio/*`: bus volumes |
| `weather.gd` | `video/rain`: particle count, ambience volume |
| `title.gd`, `hud.gd` | `profile/*`: name label, hero sprite |
| `Settings` itself | `video/*`: window, V-Sync, FPS cap, post-process shader |

`Settings.bindings_changed` refreshes the binding buttons in the menu, and
`Settings.input_device_changed(using_pad)` switches the on-screen prompts between keyboard and
gamepad names.

Why services instead of nodes in each scene? Music has to survive scene changes, the settings
must exist before any scene loads, and the save file must be reachable from the title, the pause
menu and the arenas alike. A node that lives as long as the game is exactly what an autoload is.

---

## Deferred calls: a rule you will see everywhere

```gdscript
get_parent().add_child.call_deferred(p)
s.set_deferred("disabled", not closed)
hitbox.set_deferred("monitoring", false)
```

Godot doesn't allow changes to the physics world (adding bodies, enabling shapes) **while it is in
the middle of processing collisions**, for example inside a `body_entered` callback. `call_deferred`
/ `set_deferred` queue the change until the end of the current frame, when it is safe.
