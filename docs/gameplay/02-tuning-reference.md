# 02 — Tuning reference

Every number that shapes how the game plays, and where to change it.

**How to change an `@export` value:** open the scene (for example `scenes/player/player.tscn`),
select the root node, and edit the value in the **Inspector**. The scene stores your value and
overrides the script default. To change it for *every* instance, edit the default in the script
instead.

> Values set in a `.tscn` win over script defaults. Mooks and bosses set `max_hp` and
> `score_value` in their scene files.

## Player — `scripts/player/player.gd` (exports)

| Property | Default | Raise it → | Lower it → |
|---|---|---|---|
| `speed` | 95 | faster, harder to control precisely | slower, more deliberate |
| `acceleration` | 900 | snappier starts and stops | slidier, "on ice" |
| `jump_velocity` | −265 | (more negative) higher jumps | lower jumps |
| `gravity` | 720 | heavier, faster arcs | floatier |
| `max_fall_speed` | 380 | faster falls | parachute feel |
| `max_hp` | 10 | easier (HUD shows up to 10 hearts) | harder |
| `mag_size` | 12 | fewer reloads | more reload pauses |
| `fire_cooldown` | 0.14 | slower fire | faster fire |
| `reload_time` | 0.9 | longer vulnerability | quicker |
| `max_grenades` | 3 | more grenades (HUD shows 3 icons) | fewer |

### Player constants inside functions (edit the code)

| Value | Where | Meaning |
|---|---|---|
| `0.1` | `_tick_timers` | Coyote time (s) |
| `0.12` | `_handle_jump` | Jump buffer (s) |
| `2.2` | `_apply_gravity` | Gravity multiplier when jump is released early |
| `0.25` | `_handle_jump` | Drop-through duration (s) |
| `±0.04` | `_shoot` | Bullet spread (rad) |
| `8.0` | `_shoot` | Recoil (px/s) |
| `0.25` | `_shoot` | How long the shooting pose holds (s) |
| `(150·facing + vx·0.5, −190)` | `_throw_grenade` | Grenade throw velocity |
| `1.0`, `0.25` | `take_damage` | Invulnerability / hurt-lock duration (s) |
| `(±140, −140)` | `take_damage` | Knockback velocity |
| `+3` | `collect` | HP restored by a health pickup |
| `320.0` | `_physics_process` | Pit-death height (y) |

## Enemies

| Property | Gunner | Brute | File |
|---|---|---|---|
| `max_hp` | 4 | 6 | scene |
| `score_value` | 100 | 150 | scene |
| `contact_damage` | 1 | 1 | `enemy_base.gd` |
| `bullet_speed` | 150 | — | `enemy_base.gd` |
| `walk_speed` | 40 | 45 | own script |
| `run_speed` | — | 80 | `mook_brute.gd` |
| `aggro_range` | 230 | 200 | own script |
| `burst_size` / `burst_cooldown` | 3 / 1.8 s (+0–0.6 random) | — | `mook_gunner.gd` |
| `attack_damage` | — | 2 | `mook_brute.gd` |
| Loot chance | 25 % health, 10 % grenade | same | `enemy_base.gd → _on_died` |

## Bosses

| | Rook | Bonecrusher | Plague Doctor |
|---|---|---|---|
| `max_hp` (scene) | 60 | 90 | 120 |
| `score_value` (scene) | 2000 | 3000 | 5000 |
| Idle pause (normal / phase 2) | 0.75 / 0.45 s | 0.8 / 0.45 s | 0.8 / 0.5 s |
| Main projectile speed | 170 (burst), 150 (fan) | 140 (shockwave) | 140 (spread) |
| Signature numbers | burst 3/5, fan 3/5, reload 1.3/0.9 s | charge 190/240 px/s, stun 1.1/0.7 s, leaps 1/2 | volleys 2/3, grenades 2/3, summon cooldown 9 s |

Phase 2 threshold: `hp <= max_hp / 2` in `boss_base.gd → in_phase2()`.

## Projectiles

| Property | Bullet | Shockwave | File |
|---|---|---|---|
| `speed` | 260 (player) | 140 | `bullet.gd` / `shockwave.tscn` |
| `damage` | 1 | 1 | |
| `lifetime` | 1.6 s | 2.2 s | |
| `hits_world` | true | false | |

| Property | Grenade | File |
|---|---|---|
| `fuse` | 1.1 s | `grenade.gd` |
| `gravity` | 600 | |
| `damage` | 6 (player), 2 (Plague Doctor) | |
| Bounce energy / ground friction | 0.45 / 0.7 | |
| Explosion radius | 28 px | `explosion.tscn` |

## Pickups — `pickup.gd`

| Property | Default |
|---|---|
| `kind` | `"health"` / `"grenade"` |
| `expires` | true (dropped), false (placed / boss reward) |
| Lifetime | 10 s, blinking in the last 3 s |

## Level — `tools/build_level.gd` (then rebuild)

| Constant | Meaning |
|---|---|
| `LEVEL_TILES = 236` | Level length in tiles |
| `GROUND_ROW = 11` | Ground surface row (y = 176) |
| `PITS`, `PLATFORMS`, `ARENAS`, `ENEMIES`, `PICKUPS` | Layout data |
| `rng.seed = 2026` | Decoration seed. Change it for a different-looking street. |

## Camera & feel

| Value | Where |
|---|---|
| Smoothing speed 7 | `player.tscn → Camera` |
| Shake decay 20 px/s | `game_camera.gd` |
| Hit-stop time scale 0.05 | `game.gd → hit_stop` |
| Message fade 0.15 s in / 0.4 s out | `hud.gd → _show_message` |

## Balancing tips

1. **Change one number at a time** and play the same section twice.
2. Use the playtest bot's `hits_taken` as a rough difficulty measure before and after a change.
3. Boss fights should feel learnable: every dangerous attack needs a **tell** (pose, blink,
   pause) of at least 0.25 s.
4. Keep enemy bullets **slower than the player can react to** (about 140–170 px/s on a 384 px
   screen gives about 2 s to cross the screen).
