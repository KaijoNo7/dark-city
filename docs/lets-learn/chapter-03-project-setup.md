# Chapter 3 — Project setup

🎯 **Goals**
* Configure Godot for crisp, pixel-perfect 2D.
* Build the input map so one line of code handles keyboard, mouse and gamepad.
* Name and understand physics layers, and master **bitmasks**.
* Create the folder structure and the `Game` autoload, the game's global brain.

From this chapter on, you are building the real game. Open the project you created in chapter 0.

---

## Lesson 3.1 — Choosing a resolution

Pixel-art games draw at a **small internal resolution** and scale up. We choose **384 × 216**:

* It's 16:9, like almost every monitor, so there are no black bars at ×3 on 1152 × 648, ×5 on
  1920 × 1080, or ×10 on 4K.
* Our tiles are 16 px, so one screen is **24 tiles wide** and 13.5 tall. The 32 px characters
  are about 1/7 of the screen height, which reads well.
* It's small enough that one boss arena is **exactly one screen** (384 px).

**Project → Project Settings → Display → Window** (turn on **Advanced Settings** at the top right):

| Setting | Value |
|---|---|
| Size → Viewport Width / Height | `384` / `216` |
| Size → Window Width Override / Height Override | `1152` / `648` |
| Stretch → Mode | `canvas_items` |
| Stretch → Scale Mode | `integer` |

**Why each one:**

* **Viewport 384 × 216** is the coordinate system for your whole game. Every position in code
  uses these units.
* **Window override 1152 × 648** opens the window at 3× so it isn't tiny.
* **Stretch mode `canvas_items`** scales the game to fill the window, while text and shapes are
  still drawn at full screen resolution, so labels stay sharp. (`viewport` mode renders at 384 × 216
  and scales the final image. That's more "authentic", but text gets blocky.)
* **Scale mode `integer`** only scales ×2, ×3, ×4… With ×2.5, half the pixels would be 2 screen
  pixels wide and half 3, and moving sprites would shimmer.

## Lesson 3.2 — Keeping pixels sharp

**Rendering → Textures → Canvas Textures → Default Texture Filter = Nearest**

When a 32 px sprite is drawn 3× bigger, the GPU must invent the in-between pixels. *Linear*
blends neighbours (blurry). *Nearest* copies the closest pixel (crisp squares).

**Rendering → 2D → Snap → Snap 2D Transforms to Pixel = On**

Positions are floats (`x = 103.47`). Drawing a sprite at a fractional pixel makes it wobble
between two positions as it moves. Snapping rounds the *drawn* position to whole pixels. The real
position keeps its precision for physics.

**Rendering → Environment → Defaults → Default Clear Color** = `Color(0.05, 0.04, 0.09)`.
This is a near-black purple that matches the night theme for any area nothing draws over.

The resulting `project.godot` lines:

```ini
[display]
window/size/viewport_width=384
window/size/viewport_height=216
window/size/window_width_override=1152
window/size/window_height_override=648
window/stretch/mode="canvas_items"
window/stretch/scale_mode="integer"

[rendering]
textures/canvas_textures/default_texture_filter=0
environment/defaults/default_clear_color=Color(0.05, 0.04, 0.09, 1)
2d/snap/snap_2d_transforms_to_pixel=true
```

## Lesson 3.3 — The input map

Hard-coding keys (`if Input.is_key_pressed(KEY_SPACE)`) breaks the moment someone uses a gamepad
or a different keyboard layout. Instead, define **actions** and bind any number of inputs to each.

**Project → Project Settings → Input Map.** Add these actions and bindings:

| Action | Bindings |
|---|---|
| `move_left` | A, Left arrow, D-pad Left, Left Stick Left (axis 0, −1) |
| `move_right` | D, Right arrow, D-pad Right, Left Stick Right (axis 0, +1) |
| `move_down` | S, Down arrow, D-pad Down, Left Stick Down (axis 1, +1) |
| `jump` | Space, W, Up arrow, Joypad button 0 (A / Cross) |
| `shoot` | J, X, Left mouse button, Joypad button 2 (X / Square) |
| `grenade` | K, C, Right mouse button, Joypad button 1 (B / Circle) |
| `reload` | R, Joypad button 3 (Y / Triangle) |
| `pause` | Escape, P, Joypad button 6 (Start) |

When adding a key, choose **Physical Keycode** (the default in the dialog). It means "the key at
this position", so WASD stays where the fingers expect it on AZERTY and other layouts.

Each action has a **deadzone** (0.2 here). An analogue stick must be pushed past 20 % to count.
That ignores drift from worn sticks.

### How code reads actions

```gdscript
var dir := Input.get_axis("move_left", "move_right")   # -1.0 … +1.0
if Input.is_action_just_pressed("jump"): ...           # only the frame it's pressed
if Input.is_action_pressed("shoot"): ...               # every frame it's held
```

`get_axis(negative, positive)` returns `strength(positive) − strength(negative)`. It's −1 with A
held, +1 with D, 0 with both or neither, and in between for a half-pushed stick.

### 🧪 Try it
In `practice.gd`:
```gdscript
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("jump"):
		print("jump pressed")
	if Input.is_action_pressed("shoot"):
		print("shooting…")
```
Notice the difference: holding Space prints once, but holding J prints every frame.

## Lesson 3.4 — Physics layers and masks

Every physics object has a **layer** ("what I am") and a **mask** ("what I look for").

**Project Settings → Layer Names → 2D Physics:**

| Layer | Name |
|---|---|
| 1 | world |
| 2 | player |
| 3 | enemies |
| 4 | pickups |
| 5 | platforms |

Names are just labels for the Inspector checkboxes, but they make the setup readable.

Why so many layers? Because each relationship in the game is different:

* The player **stands on** world and platforms. Bosses stand on world only.
* Player bullets hit world and enemies. Enemy bullets hit world and the player.
* Pickups are touched only by the player.
* The player can **drop through** platforms but never through the world, so platforms need
  their own layer.

### 🔤 Language spotlight: bitmasks

In code, `collision_layer` and `collision_mask` are a single `int`. Each layer is **one bit**:

```
          bit:   5    4    3    2    1        ← layer number (editor)
        value:  16    8    4    2    1        ← what you write in code
                 │    │    │    │    │
  mask = 17 →    1    0    0    0    1        → layers 1 and 5 (world + platforms)
  mask =  5 →    0    0    1    0    1        → layers 1 and 3 (world + enemies)
```

The value of layer *N* is `2^(N−1)`, also written `1 << (N−1)`.

To **combine** layers, use bitwise OR `|`:

```gdscript
collision_mask = 1 | 16     # 17: world + platforms
```

The bullet builds its mask from two conditions:

```gdscript
collision_mask = (1 if hits_world else 0) | (4 if from_player else 2)
```
*(from `bullet.gd`)*

| `hits_world` | `from_player` | mask | means |
|---|---|---|---|
| true | true | 1 \| 4 = 5 | world + enemies |
| true | false | 1 \| 2 = 3 | world + player |
| false | false | 0 \| 2 = 2 | player only (shockwave) |

To **test** a bit, use AND `&`: `(mask & 16) != 0` means "platforms are in the mask".
To flip a single layer **by its number**, Godot provides helpers:

```gdscript
set_collision_mask_value(5, false)    # layer NUMBER 5 (platforms), not value 5!
```
*(from `player.gd`)*

> ⚠️ **The classic bug:** mixing up layer *numbers* and bit *values*.
> `set_collision_mask_value(5, …)` means layer 5 (value 16). `collision_mask = 5` means
> layers 1 and 3. Always ask yourself which one you mean.

## Lesson 3.5 — Folder structure

Create these folders (right-click in the FileSystem dock → **New Folder**):

```
res://
├── asset/            (already there)
├── resources/frames/
├── scenes/ui/  scenes/level/  scenes/player/  scenes/enemies/
├── scenes/bosses/  scenes/projectiles/  scenes/pickups/
├── scripts/autoload/  scripts/ui/  scripts/level/  scripts/player/
├── scripts/enemies/  scripts/bosses/  scripts/projectiles/  scripts/pickups/
└── tools/
```

**Why organise by feature** (player, enemies, ui) rather than by type (sprites, sounds)? When you
work on enemies, everything about enemies is in one place. Mirroring `scenes/` and `scripts/` is
this project's choice. Keeping each `.gd` next to its `.tscn` is equally valid.

## Lesson 3.6 — The `Game` autoload

Some things must outlive any single scene: the score, the run timer, and a way for unrelated
objects to talk. Godot's answer is the **autoload**: a script or scene that is loaded at startup,
added to the root of the tree, and accessible everywhere by name.

Create `scripts/autoload/game.gd`. We'll start with the signals and state, and add helpers in
chapter 6:

```gdscript
extends Node
## Global game state + an "event bus" of signals.
## Gameplay nodes emit these signals; the HUD and camera listen to them,
## so nodes never need direct references to each other.

signal player_hp_changed(hp: int, max_hp: int)
signal player_ammo_changed(ammo: int, mag_size: int, grenades: int, reloading: bool)
signal player_died
signal boss_started(boss_name: String, max_hp: int)
signal boss_hp_changed(hp: int)
signal boss_defeated(boss_name: String, is_final: bool)
signal show_message(text: String, seconds: float)
signal score_changed(score: int)
signal shake_requested(strength: float)

const TITLE_SCENE := "res://scenes/ui/title.tscn"
const LEVEL_SCENE := "res://scenes/level/level_1.tscn"

var score := 0
var bosses_defeated := 0
var run_time := 0.0
var running := false


func _process(delta: float) -> void:
	if running:
		run_time += delta
```
*(from the game: `game.gd`, first part)*

Register it: **Project Settings → Globals → Autoload**, path `res://scripts/autoload/game.gd`,
name `Game`, **Enable** checked → **Add**.

Line by line:

* `extends Node`: an autoload is a node in the tree (so it can have `_process`, timers…). It
  doesn't need a position, so plain `Node` is enough.
* **The signals** are the game's vocabulary of events. Each is past tense ("hp *changed*",
  "player *died*") because it reports something that already happened. The typed parameters
  document what listeners will receive.
* **The constants** are the two scene paths, so changing a file name means changing one line.
* **The state:** `score`, `bosses_defeated` and `run_time` must survive restarting the level,
  which destroys every node in the level. The autoload is never destroyed.
* **`_process`** advances the run clock only while `running`. Menus set `running = false`, so the
  clock stops on the title screen, the death screen and after victory.

### Why not just use a `static var`?
A static variable could hold the score, but it can't emit signals that the editor knows about,
can't use timers (`get_tree().create_timer`), and can't run `_process`. An autoload node can do
all of these.

### When *not* to use autoloads
Autoloads are global, and globals are convenient but can turn into a junk drawer. Keep them
small and focused. Dark City has exactly one, with a clear job: run state plus the event bus.

---

## 🏋️ Exercises

1. ★ Run your project with the main scene unset. Godot asks you to pick one. Pick `hello.tscn`
   from chapter 0, then change the window size override to 768 × 432. What scale is the game at
   now?
2. ★ Compute the mask values: (a) world + player, (b) enemies + pickups, (c) everything
   (layers 1–5).
3. ★★ Write `func layers_to_mask(layers: Array[int]) -> int` that converts editor layer numbers to
   a mask, e.g. `[1, 5]` → `17`. Use `1 << (n - 1)`.
4. ★★ Write `func mask_to_layers(mask: int) -> Array[int]` (the reverse). Test with 17 and 5.
5. ★★ Add a `dash` action bound to **Shift** and gamepad **RB** (button 10). In `practice.gd`,
   print "dash!" when it's just pressed.
6. ★★★ Temporarily add `func _ready(): print("Game ready")` to `game.gd` and
   `print("Scene ready")` to `hello.gd`. Which prints first? Why does that matter for the HUD and
   the player later?

## ✅ Solutions

<details><summary>Exercise 1</summary>

768 × 432 is exactly 2 × 384 × 216, so the game is at **×2**. With integer scaling, resizing the
window to 1000 × 600 would still render at ×2, with black bars filling the rest.
</details>

<details><summary>Exercise 2</summary>

(a) `1 | 2 = 3` (b) `4 | 8 = 12` (c) `1 | 2 | 4 | 8 | 16 = 31`
</details>

<details><summary>Exercise 3</summary>

```gdscript
func layers_to_mask(layers: Array[int]) -> int:
	var mask := 0
	for n in layers:
		mask |= 1 << (n - 1)
	return mask
```
</details>

<details><summary>Exercise 4</summary>

```gdscript
func mask_to_layers(mask: int) -> Array[int]:
	var result: Array[int] = []
	for n in range(1, 33):
		if mask & (1 << (n - 1)):
			result.append(n)
	return result
# 17 → [1, 5], 5 → [1, 3]
```
</details>

<details><summary>Exercise 5</summary>

Add the action in the Input Map, then:
```gdscript
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("dash"):
		print("dash!")
```
</details>

<details><summary>Exercise 6</summary>

`Game ready` prints first. Autoloads are added to the root **before** the main scene loads. So
when any scene's `_ready()` runs, `Game` already exists and its signals can be connected or
emitted safely. The player and HUD both depend on that.
</details>

---

📝 **Recap**
* 384 × 216 viewport, `canvas_items` stretch, integer scale, Nearest filter, pixel snap: that's
  pixel-perfect 2D.
* Actions, not keys. `get_axis`, `is_action_pressed`, `is_action_just_pressed`.
* Layers = what I am, masks = what I look for. Layer N has value `1 << (N−1)`. Combine with `|`.
* An autoload holds global state and signals. Register it in Project Settings → Globals.

Next: **[Chapter 4 — The asset pipeline](chapter-04-asset-pipeline.md)**
