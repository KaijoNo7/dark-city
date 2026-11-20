# 02 — Sprites & animation

## From sprite sheet to `SpriteFrames`

A **sprite sheet** is one image holding several frames side by side. Godot's `AnimatedSprite2D`
plays a **`SpriteFrames`** resource: a set of named animations, each a list of textures with an FPS
and a loop flag.

`tools/build_resources.gd` turns each strip into one animation:

```
Walk.png  (128 × 32)
┌────┬────┬────┬────┐
│ f0 │ f1 │ f2 │ f3 │   → animation "walk", 4 frames, 10 FPS, loops
└────┴────┴────┴────┘
```

Each frame is an **`AtlasTexture`**: a lightweight "window" into the big texture defined by a
`Rect2` region. No image data is copied.

```gdscript
for i in tex.get_width() / frame_w:
    var atlas := AtlasTexture.new()
    atlas.atlas = tex
    atlas.region = Rect2(i * frame_w, 0, frame_w, h)
    frames.add_frame(anim, atlas)
```

### Naming rule

`file.get_basename().to_lower().replace("+", "_").replace(" ", "_")`

| File | Animation |
|---|---|
| `Idle.png` | `idle` |
| `Walk+Shot.png` | `walk_shot` |
| `Walk+Attack.png` | `walk_attack` |
| `Run+Attack.png` | `run_attack` |
| `Attack_1.png` | `attack_1` |

## Animation table

| Animation | FPS | Loops | Player | Gunner | Brute | Rook | Bonecrusher | Plague Dr. |
|---|---|---|---|---|---|---|---|---|
| `idle` | 6 | ✔ | 4 | 4 | 4 | 4 | 4 | 4 |
| `walk` | 10 | ✔ | 4 | 4 | 4 | 4 | 4 | 4 |
| `shot` | 14 | ✔ | 4 | 4 | | 4 | | 4 |
| `walk_shot` | 12 | ✔ | 4 | 4 | | 4 | | 4 |
| `recharge` | 9 | | 5 | 9 | | 6 | | 7 |
| `cast` | 12 | | 3 | 3 | 3 | 3 | 3 | 3 |
| `hurt` | 14 | | 2 | 2 | 2 | 2 | 2 | 2 |
| `dead` | 8 | | 3 | 3 | 3 | 3 | 3 | 3 |
| `attack` / `attack_1` / `attack_2` | 14 / 12 | | 3 | 3 | 3+3 | 3 | 3+3 | 3 |
| `walk_attack` | 12 | ✔ | | | | | 4 | |
| `run_attack` | 12 | ✔ | | | 4 | | | |

(Numbers are frame counts.) Effects: `grenade.tres → default` (8 frames, 16 FPS, loops) and
`explosion.tres → default` (8 frames of 64 px, 18 FPS, once).

**Why some animations loop and others don't:** idle, walk and shooting are *continuous*
activities. Hurt, dead, cast and recharge are *events* that play once and stop on their last
frame. Death stays on the "lying down" frame. Code can test `sprite.is_playing()` or wait for
`animation_finished`.

## How each animation is used in code

| Animation | Player (`_update_animation`) | Enemies / bosses |
|---|---|---|
| `idle` | standing still | waiting, out of range, boss idle state |
| `walk` | moving on the floor; **frozen on frame 1 in the air** (legs apart = "jumping") | patrolling, Rook "walk", Plague Doctor "dash" |
| `shot` / `walk_shot` | 0.25 s after each shot, standing / moving | Gunner bursts, Rook burst, Plague Doctor spread |
| `recharge` | reloading | Rook "reload" window |
| `cast` | throwing a grenade | Bonecrusher leap, Plague Doctor grenades & summon |
| `hurt` | 0.25 s after taking damage | stagger after a hit |
| `dead` | death | death |
| `attack_1` | — | Brute swing, Bonecrusher swipe |
| `walk_attack` / `run_attack` | — | Bonecrusher charge / Brute running at you |

### Priority-based animation choice (player)

The player picks **one** animation per frame by priority. The first matching condition wins:

```
hurt  >  cast  >  recharge  >  shot/walk_shot  >  in air (walk, frozen)  >  walk  >  idle
```

This is a simple, robust alternative to a full animation state machine: the animation is always
derived from current state and is never "stuck".

### Avoiding restarts

Calling `sprite.play("walk")` every frame while already walking is fine in Godot 4 (it doesn't
restart). The code still guards with `if sprite.animation != anim` for clarity. The enemy helper
also restarts a finished one-shot when it is requested again:

```gdscript
func play(anim: String) -> void:
    if sprite.animation != anim or not sprite.is_playing():
        sprite.play(anim)
```

## Anchoring: feet at the origin

Frames are 32 × 32 with feet on the bottom row. Every character scene offsets its sprite:

```
         ┌──────────┐  y = −32
         │  sprite  │
         │  32×32   │
         │    ▲     │  position (0, −16) = sprite centre
         └────┼─────┘  y = 0  ← node origin = feet = ground contact
```

Bosses use `scale = (2, 2)` and `position = (0, −32)`. The pickup sprite uses `offset = (0, −8)`
for a 16 px icon.

**Benefit:** spawning a character "on the ground" is simply `position.y = 176`, the ground
surface, no matter how big the character is.

## Facing and flipping

All sheets face **right**. Facing left is a horizontal flip:

```gdscript
sprite.flip_h = facing < 0
muzzle.position.x = absf(muzzle.position.x) * facing
```

`flip_h` mirrors only the texture. The muzzle `Marker2D` is a separate node, so the code mirrors
its x position as well. Otherwise bullets would come out of the back of the gun.

Bullets flying left use `scale.x = -1` instead of rotating 180° (`bullet.gd`). A rotation would
turn the sprite upside down.

## Visual feedback on sprites

| Effect | Code | Where |
|---|---|---|
| **Hit flash** | `sprite.modulate = Color(4, 4, 4)`, then tween back to white over 0.12 s | `enemy_base.gd → _flash()` |
| **Invulnerability flicker** | `sprite.visible = fmod(_invuln_timer, 0.12) > 0.05` | `player.gd` |
| **Charge warning** | blink `Color(2.5, 0.6, 0.6)` every 0.08 s | `boss_bonecrusher.gd` windup |
| **Stunned wobble** | `sprite.rotation = sin(t * 30) * 0.08` | `boss_bonecrusher.gd` stunned |
| **Death fade** | tween `modulate:a` to 0, then `queue_free` | `enemy_base.gd`, `boss_base.gd` |
| **Enemy bullet tint** | `b.modulate = Color(1, 0.45, 0.4)` | `enemy_base.gd → shoot_bullet()` |

**Why `Color(4, 4, 4)` makes a white flash:** `modulate` *multiplies* the texture colour. Values
above 1 push every channel toward (and past) full brightness, so the sprite turns almost pure white
while keeping its silhouette.
