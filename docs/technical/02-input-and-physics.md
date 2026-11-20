# 02 — Input & physics

## Part A — The input map

Godot separates **what the player pressed** (a key, a mouse button, a gamepad button) from
**what it means** (an *action* such as `jump`). Game code only asks about actions:

```gdscript
if Input.is_action_just_pressed("jump"):
    ...
```

That is why one line of code works for the keyboard, the mouse and a gamepad.

### Actions defined in `project.godot`

| Action | Keyboard | Mouse | Gamepad | Used in |
|---|---|---|---|---|
| `move_left` | A, ← | | D-pad left, left stick left | `player.gd` |
| `move_right` | D, → | | D-pad right, left stick right | `player.gd` |
| `move_down` | S, ↓ | | D-pad down, left stick down | `player.gd` (drop through platforms) |
| `jump` | Space, W, ↑ | | A / Cross (button 0) | `player.gd` |
| `shoot` | J, X | Left button | X / Square (button 2) | `player.gd` |
| `grenade` | K, C | Right button | B / Circle (button 1) | `player.gd` |
| `reload` | R | | Y / Triangle (button 3) | `player.gd` |
| `pause` | Esc, P | | Start (button 6) | `hud.gd` |

These are the **defaults**. Players can change every one of them in **SETTINGS → CONTROLS**
(keyboard, up to 3 keys per action) and **SETTINGS → GAMEPAD** (up to 2 pad inputs per action).
At start-up `Settings` copies these defaults, applies the player's saved bindings over them and
rewrites the `InputMap` with `InputMap.action_erase_events()` / `action_add_event()`. Game code
never notices: it still asks `Input.is_action_pressed("jump")`. Details:
[05 — Settings, save games & controllers](05-settings-saves-controllers.md#part-b--input-bindings).

The **deadzone** starts at 0.2 and is also a setting (*Stick dead zone*). A stick has to move more
than 20 % before it counts, so a worn stick that rests at 0.05 doesn't make the hero walk on their
own.

Keys are stored as **physical** keycodes (`physical_keycode`). That means "the key in the
position of W on a US keyboard". French AZERTY players get the same *positions* (Z Q S D) without
any remapping.

### Reading input: the four calls used in this project

| Call | Returns | Used for |
|---|---|---|
| `Input.get_axis("move_left", "move_right")` | A float from −1 to +1 (partial values on a stick) | Walking direction |
| `Input.is_action_just_pressed("jump")` | `true` only on the frame the button goes down | Jump, grenade, reload |
| `Input.is_action_pressed("shoot")` | `true` every frame the button is held | Auto-fire, variable jump height |
| `event.is_action_pressed("pause")` inside `_unhandled_input` | `true` for that input event | Pause. It is event-based, so it still works while the tree is paused. |

### Adding a new action

1. **Project → Project Settings → Input Map**, type a name such as `dash`, click **Add**.
2. Click **+** next to it and press the key or button.
3. In code: `if Input.is_action_just_pressed("dash"): ...`
4. To make it rebindable, add `"dash"` to `REBINDABLE` and a display name to `ACTION_NAMES` in
   `scripts/autoload/settings.gd`. The settings menu builds its rows from that list.

### Gamepads

Xbox, PlayStation 2 (through a USB adapter), 3, 4 and 5, Switch and generic pads are detected
automatically, with the right button names in menus, vibration, and a guided set-up for pads
whose buttons are numbered unusually. See
[05 — Settings, save games & controllers, part C](05-settings-saves-controllers.md#part-c--controllers).

---

## Part B — Collision layers and masks

Every physics object has two sets of 32 checkboxes:

* **Layer**: "which groups *I belong to*".
* **Mask**: "which groups *I look for* (collide with or detect)".

Object A collides with B when **A's mask includes one of B's layers**. Bodies that block each other
generally both need the other in their mask. Areas only need it in their own mask to detect.

### The five layers in Dark City

| Layer # (editor) | Name | Bit value (code) | Who is on it |
|---|---|---|---|
| 1 | world | `1` | Ground tiles, level bounds, arena walls |
| 2 | player | `2` | The player |
| 3 | enemies | `4` | Mooks and bosses |
| 4 | pickups | `8` | Health and grenade pickups |
| 5 | platforms | `16` | One-way platform tiles |

### Layer numbers vs bit values

The editor counts layers from **1**. In code, `collision_layer` and `collision_mask` are a single
integer in which **each layer is one bit**:

```
layer N  →  bit value 2^(N−1)

layer 1 → 1        (binary 00001)
layer 2 → 2        (binary 00010)
layer 3 → 4        (binary 00100)
layer 4 → 8        (binary 01000)
layer 5 → 16       (binary 10000)
```

To combine layers, use bitwise OR, written `|`:

```gdscript
collision_mask = 1 | 16     # world + platforms = 17 (binary 10001)
```

There are two equivalent ways to set masks in code. The project uses both:

```gdscript
collision_mask = 1 | 16              # set the whole number at once (bit values)
set_collision_mask_value(5, false)   # flip one layer by its editor NUMBER (1-based)
```

### Who collides with what

| Object | Layer | Mask | Meaning |
|---|---|---|---|
| Player (`CharacterBody2D`) | 2 | 1 \| 16 = **17** | Stands on ground and platforms |
| Enemy / boss body | 4 | 1 \| 16 (mooks), **1** (bosses) | Bosses ignore platforms so they stay on the street |
| Enemy `Hitbox` (`Area2D`) | 0 | 2 | Detects the player for contact damage |
| Bullet, player's | 0 | 1 \| 4 | Hits walls and enemies |
| Bullet, enemy's | 0 | 1 \| 2 | Hits walls and the player |
| Shockwave | 0 | 2 | `hits_world = false`, so it slides along the floor and hurts only the player |
| Grenade body | 0 | 1 \| 16 | Bounces on ground and platforms |
| Grenade `Hitbox` | 0 | 4 or 2 | Explodes on touching a target |
| Explosion | 0 | 4 or 2 | Damages everything in its circle once |
| Pickup | 8 | 2 | Only the player can collect it |
| Boss arena `Trigger` | 0 | 2 | Starts the fight when the player enters |

Notice that **all projectiles have `collision_layer = 0`**. Nothing needs to detect a bullet. The
bullet detects things. Keeping the layer empty avoids accidental interactions such as bullets
hitting other bullets.

### One-way platforms

Platform tiles have a collision polygon marked **one-way**
(`set_collision_polygon_one_way(...)` in `tools/build_resources.gd`). A one-way shape only blocks
bodies coming from above. The player can jump up through it from below and land on top.

To **drop down**, the player turns off mask layer 5 for 0.25 seconds (`player.gd`):

```gdscript
set_collision_mask_value(5, false)   # stop seeing platforms…
_drop_timer = 0.25                   # …turn it back on after 0.25 s (in _tick_timers)
```

### The pit death check

There is no "death zone" node. Each body checks its own height every physics frame:

* Player: `if global_position.y > 320.0` → die (`player.gd`)
* Enemies: `if global_position.y > 340.0` → die (`enemy_base.gd`)

The ground surface is at `y = 176`, so these thresholds are well below the screen.

### Raycasts

Enemies use a **raycast**, an invisible line test, to avoid walking off ledges
(`enemy_base.gd → ground_ahead`):

```gdscript
var from := global_position + Vector2(dir * 12, -4)
var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 24), 1 | 16)
return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()
```

It casts a 24 px line straight down, 12 px in front of the enemy. The last argument is the
**mask**: it only looks for world and platforms. If the ray hits nothing, there is a drop ahead.
