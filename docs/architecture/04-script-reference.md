# 04 — Script reference

Every script in `scripts/`, with its exported properties, public API and the signals it uses.
`→` means "returns". Private members (leading `_`) are only listed when they help understanding.

---

## `autoload/game.gd` — `extends Node` (autoload `Game`)

Global state and the event bus. See [03 — Communication](03-communication.md).

| Member | Kind | Description |
|---|---|---|
| `TITLE_SCENE`, `LEVEL_SCENE` | const | Scene paths |
| `score`, `bosses_defeated`, `run_time`, `running` | var | Run state |
| `start_game()` | func | Reset state, unpause, load the level |
| `restart_level()` | func | Same as `start_game()` |
| `go_to_title()` | func | Stop the clock, unpause, load the title |
| `add_score(amount)` | func | Add to `score`, emit `score_changed` |
| `shake(strength = 3.0)` | func | Emit `shake_requested` |
| `message(text, seconds = 2.0)` | func | Emit `show_message` |
| `hit_stop(seconds = 0.05)` | func (async) | Run the game at 5 % speed for `seconds` of real time |
| `format_time(t)` → `String` | func | `125.3` → `"02:05"` |

---

## `player/player.gd` — `extends CharacterBody2D`

| Export | Default | Meaning |
|---|---|---|
| `speed` | 95.0 | Max run speed (px/s) |
| `acceleration` | 900.0 | How quickly speed changes (px/s²) |
| `jump_velocity` | −265.0 | Upward speed when jumping (negative = up) |
| `gravity` | 720.0 | Downward acceleration (px/s²) |
| `max_fall_speed` | 380.0 | Terminal velocity |
| `max_hp` | 10 | Hearts |
| `mag_size` | 12 | Bullets per magazine |
| `fire_cooldown` | 0.14 | Seconds between shots when holding shoot |
| `reload_time` | 0.9 | Seconds |
| `max_grenades` | 3 | |

| Public | Description |
|---|---|
| `hp`, `ammo`, `grenades`, `facing` (±1), `dead` | State read by enemies, HUD, bot |
| `camera` | `@onready` reference to the child `Camera2D` (used by level and arenas) |
| `take_damage(amount, from_pos)` | Damage contract |
| `collect(kind)` → `bool` | `"health"` (+3 HP) or `"grenade"` (+1). `false` if already full. |

Per-frame order in `_physics_process`: `_tick_timers` → `_apply_gravity` → `_handle_movement` →
`_handle_jump` → `_handle_combat` → `move_and_slide()` → `_update_animation` → pit check.

Timers (all count down in seconds): `_fire_timer`, `_shoot_anim_timer`, `_reload_timer`,
`_cast_timer`, `_hurt_timer`, `_invuln_timer`, `_coyote_timer`, `_jump_buffer`, `_drop_timer`.

Emits: `Game.player_hp_changed`, `Game.player_ammo_changed`, `Game.player_died`.

## `player/game_camera.gd` — `extends Camera2D`

Listens to `Game.shake_requested`. Keeps the **strongest** pending shake (`maxf`), offsets the
camera randomly by up to that many pixels (rounded to whole pixels), and decays it by 20 px/s.

---

## `enemies/enemy_base.gd` — `class_name EnemyBase extends CharacterBody2D`

| Export | Default | Meaning |
|---|---|---|
| `max_hp` | 4 | |
| `gravity` | 720.0 | |
| `score_value` | 100 | Added to the score on death |
| `contact_damage` | 1 | Damage for touching the player (0 = harmless) |
| `bullet_speed` | 150.0 | Default speed for `shoot_bullet()` |

| Method | Description |
|---|---|
| `_ai(delta)` | **Override.** Called every physics frame while alive. Set `velocity` and `facing` here. |
| `_on_hurt(amount, from_pos)` | **Override (optional).** Reaction to a hit. |
| `_on_died()` | **Override (optional).** Default: 25 % health drop, 10 % grenade drop, fade out, free. |
| `player_alive()` → `bool` | Player exists and isn't dead |
| `to_player()` → `Vector2` | Vector from me to the player |
| `face_player()` | Set `facing` toward the player (2 px dead zone stops flicker) |
| `ground_ahead(dir)` → `bool` | Raycast for floor 12 px ahead |
| `play(anim)` | Play an animation only if it's not already playing (avoids restarting it) |
| `shoot_bullet(dir, damage = 1, speed = -1)` | Spawn a red enemy bullet from the muzzle |
| `aim_at_player()` → `Vector2` | Unit vector from muzzle to the player's chest (feet − 10 px) |
| `take_damage(amount, from_pos)` | Damage contract |
| `die()` | Disable collision, play "dead", add score, call `_on_died()` |

Group: `"enemies"`. Layer 4, mask 1|16. Hitbox mask 2.

## `enemies/mook_gunner.gd` — `extends "res://scripts/enemies/enemy_base.gd"`

| Export | Default |
|---|---|
| `walk_speed` | 40.0 |
| `aggro_range` | 230.0 |
| `burst_size` | 3 |
| `burst_cooldown` | 1.8 |

Behaviour: idle when the player is more than 230 px away horizontally or 90 px vertically.
Otherwise faces the player and keeps a distance of 60–150 px. When the cooldown runs out and the
player is roughly level (|dy| < 40), fires a 3-shot burst (one shot every 0.18 s), standing still.
Being hit cancels the burst and staggers it for 0.15 s.

## `enemies/mook_brute.gd` — `extends "res://scripts/enemies/enemy_base.gd"`

| Export | Default |
|---|---|
| `walk_speed` | 45.0 |
| `run_speed` | 80.0 |
| `aggro_range` | 200.0 |
| `attack_damage` | 2 |

Behaviour: walks toward the player, **runs** when within 110 px. Within 22 px it swings
(`attack_1`, 0.45 s). The hit is checked once, 0.2 s into the swing, and only lands if the player
is still within 30 px **in front**. Being hit cancels the swing (0.12 s stagger).

---

## `bosses/boss_base.gd` — `class_name BossBase extends "res://scripts/enemies/enemy_base.gd"`

| Export | Default | |
|---|---|---|
| `boss_name` | "BOSS" | Shown in banners and on the health bar |
| `is_final` | false | Set on the last boss to trigger victory |

| Member | Description |
|---|---|
| `active` | `false` until the arena calls `activate()`. Inactive bosses stand idle and are invulnerable. |
| `state`, `state_time` | Current state name and seconds spent in it |
| `arena_left`, `arena_right` | World x of the arena walls (set by the arena) |
| `activate()` | Start the fight, emit `boss_started` |
| `in_phase2()` → `bool` | `hp <= max_hp / 2` |
| `set_state(name)` | Change state and reset `state_time` |
| `arena_center()` → `float` | |
| `_boss_ai(delta)` | **Override.** Called while active. |

Bosses use collision mask 1 only (they ignore platforms). On death: hit-stop, big shake, 4 visual
explosions, all `"summons"` die, `boss_defeated` is emitted, then a fade-out.

## `bosses/boss_rook.gd` — DEADEYE ROOK (60 HP)

States: `idle` → (`burst` | `hop_fan` | `walk` | `reload`).

* **burst**: 3 aimed shots (5 in phase 2), 0.16 s apart (0.12 s in phase 2).
* **hop_fan**: hops away (toward the centre if a wall is close), and on landing fires a fan of 3
  (5) bullets spaced 0.22 rad apart.
* **walk**: approaches for up to 1 s, then a 2-shot burst.
* **reload**: `_choose_attack()` sends him to `reload` once 3 attacks have been chosen since the
  last reload, so every 4th choice is a reload. He stands still for 1.3 s (0.9 s in phase 2), which
  is the player's free damage window.

## `bosses/boss_bonecrusher.gd` — BONECRUSHER (90 HP)

States: `idle`, `windup`, `charge`, `stunned`, `leap`, `swipe`.

* **windup → charge**: blinks red for 0.65 s (0.45 s), then runs at 190 (240) px/s with
  contact damage 2. Hitting a wall (or running for 2.5 s) → **stunned** for 1.1 s (0.7 s) with
  contact damage 0.
* **leap**: jumps toward the player (at most 160 px), and on landing sends **two shockwaves**
  along the floor. Phase 2: two leaps in a row.
* **swipe**: within 44 px, a close hit for 2 damage, 0.2 s into the animation.

## `bosses/boss_plague_doctor.gd` — THE PLAGUE DOCTOR (120 HP, final)

States: `idle`, `spread`, `grenades`, `dash`, `summon`.

* **spread**: 2 (3) volleys of a 5-bullet fan, 0.2 rad apart, aimed at the player.
* **grenades**: lobs 2 (3) grenades that land within ±50 px of the player. Their flight time is
  0.9 s, and each has a slightly longer fuse than the last.
* **dash**: jumps to the side of the arena the player is **not** on. Also used when the player is
  closer than 60 px.
* **summon** (phase 2 only, 9 s cooldown, at most 2 alive): drops two gunners from above at the
  arena edges. They are in group `"summons"` and worth 50 points.

---

## `projectiles/bullet.gd` — `extends Area2D`

| Export | Default | |
|---|---|---|
| `speed` | 260.0 | px/s |
| `damage` | 1 | |
| `lifetime` | 1.6 | seconds before it's freed |
| `hits_world` | true | false → passes through walls (shockwave) |
| `spark_color` | gold | Particle colour on impact |

| Method | Description |
|---|---|
| `setup(pos, dir, is_player, dmg = 1, spd = -1)` → `Area2D` | Configure **before** `add_child`. Returns `self` for chaining. |

## `projectiles/grenade.gd` — `extends CharacterBody2D`

Exports: `fuse` 1.1, `gravity` 600, `damage` 6. Vars: `from_player`.
Bounces with 45 % energy, plus 30 % ground friction. `explode()` is guarded so it only happens
once, spawns an `Explosion` and frees itself.

## `projectiles/explosion.gd` — `extends Area2D`

Vars: `from_player`, `damage` (6). Plays the blast, shakes the screen, waits **two physics
frames** (so the area's overlap list is filled), damages every overlapping body once, and frees
itself when the animation ends.

## `pickups/pickup.gd` — `extends Area2D`

| Export | Default | |
|---|---|---|
| `kind` | "health" | `@export_enum("health", "grenade")` |
| `expires` | true | Dropped loot disappears after 10 s (blinking in the last 3 s) |

The icon is cut from a sprite sheet in code with an `AtlasTexture`. It bobs forever with a looping
`Tween`.

---

## `level/level.gd` — `extends Node2D`

Exports: `level_width` 3776, `ground_bottom` 210. In `_ready()` it sets the player camera's
limits, calls `reset_smoothing()` so the camera doesn't glide in from (0, 0), and shows
"DARK CITY / Take back the streets."

## `level/boss_arena.gd` — `extends Node2D`

| Export | Default | |
|---|---|---|
| `boss_scene` | — | `PackedScene` of the boss |
| `width` | 384.0 | Arena width (one screen) |
| `reward` | "health" | Pickup kind dropped after a non-final boss |

Sequence: trigger → close walls → lock camera limits to the arena → spawn boss at `BossSpawn` →
"WARNING!" banner → wait 2 s → `boss.activate()`.
On `boss_defeated` (for *its* boss): open walls → restore camera limits → drop reward →
"AREA CLEAR / GO >>>".

## `level/stars.gd` — `extends Control`

Generates 70 stars with a fixed seed (7), so the sky looks the same every time. Redraws every
frame. Each star's brightness is `0.4 + 0.6·|sin(1.5t + phase)|`. The moon is two circles: a pale
one, and a sky-coloured one offset to cut a crescent.

---

## `ui/ui_kit.gd` — `extends RefCounted` (static library)

Use it with `const UI := preload("res://scripts/ui/ui_kit.gd")`.

| Static function | Returns |
|---|---|
| `icon(n)` | `Texture2D` from `asset/UI/Icons/n.png` |
| `panel(size)` | Beige 9-slice `NinePatchRect` cut from `asset/UI/UI.png` |
| `label(text, font_size = 8, color = COLOR_LIGHT, outline = true)` | Centred `Label` |
| `button(text, on_pressed: Callable)` | Styled `Button`, already connected |
| `dialog(title, info, buttons, title_color = COLOR_DANGER)` | Full-screen dimmed pop-up |

Constants: `COLOR_TEXT`, `COLOR_LIGHT`, `COLOR_ACCENT`, `COLOR_DANGER`.

## `ui/hud.gd` — `extends CanvasLayer`

Builds the status panel (10 hearts, ammo, 3 grenade icons), the score and time, the centre
message, and the boss bar. Handles pause (`_unhandled_input`), the game-over dialog and the
victory dialog. Listens to 8 `Game` signals and emits none.

## `ui/title.gd` — `extends Control`

Builds the title screen in code: gradient sky + stars, two buildings and a sidewalk cut from the
tilesheet, the hero facing the three bosses (idle, at 2× scale, slightly random speeds), the
title, START/QUIT buttons and the controls help.
