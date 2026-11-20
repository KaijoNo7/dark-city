# Chapter 4 — The asset pipeline

🎯 **Goals**
* Understand **resources** (`.tres`) and how they differ from scenes and nodes.
* Know what `SpriteFrames`, `AtlasTexture`, `TileSet` and `TileSetAtlasSource` are.
* Write a **tool script** that runs from the command line and generates resources.
* Use `DirAccess` to list files and `ResourceSaver` to save.
* Understand tileset **physics layers**, collision polygons and **one-way** collision.

---

## Lesson 4.1 — Study the art before you code

Open `asset/Characters/Character_1/` and look at the images. Before writing a pipeline, measure
the art. These are the facts the whole game relies on:

| Observation | Consequence |
|---|---|
| Each PNG (`Idle.png`, `Walk.png`…) is **one horizontal strip** | one PNG = one animation |
| Every frame is **32 × 32** | frame count = `width / 32` |
| Feet touch the **bottom** of the frame | offset sprites by −16 so the node origin is at the feet |
| `Sleeve.png` is 16 px tall (shell casings) | skip anything not 32 px tall |
| `Granate_Explosion.png` uses **64 px** frames | handle frame width as a parameter |
| `Tile1.png` is the entire city on a 16 px grid | one tileset source for everything |

> 💡 **Professional habit:** open sheets in an image editor with a grid (32 px for characters,
> 16 px for tiles) and write coordinates down. The constants in `build_resources.gd` and
> `build_level.gd` came from doing exactly that.

## Lesson 4.2 — What is a resource?

A **Resource** is a data object that can be saved to disk and shared: textures, sounds, fonts,
`SpriteFrames`, `TileSet`, `Gradient`, materials… Resources are **not** in the scene tree. Nodes
*use* them.

| | Node | Resource |
|---|---|---|
| Lives in | the scene tree | memory / disk |
| Has `_process`? | yes | no |
| Saved as | part of a `.tscn` | `.tres` (text) or `.res` (binary), or inside a `.tscn` |
| Shared? | each instance is separate | **loaded once, shared** by everyone who uses it |

When 19 enemies use `mook_gunner.tres`, there is **one** `SpriteFrames` in memory. That's why
resources are efficient.

## Lesson 4.3 — `SpriteFrames` and `AtlasTexture`

* **`AnimatedSprite2D`** (a node) plays a **`SpriteFrames`** (a resource).
* A `SpriteFrames` holds **named animations**. Each has a list of frame textures, a speed (FPS)
  and a loop flag.
* An **`AtlasTexture`** is a texture that shows only a rectangular **region** of another texture.
  It copies no pixels. It's a "window".

```
Walk.png (128×32)                 SpriteFrames
┌────┬────┬────┬────┐             "walk": [Atlas(0,0,32,32), Atlas(32,0,32,32),
│    │    │    │    │                      Atlas(64,0,32,32), Atlas(96,0,32,32)]
└────┴────┴────┴────┘                      speed 10, loop true
```

You *could* do this by hand in the SpriteFrames editor ("Add frames from sprite sheet"). For about
300 frames across 8 characters, that's an hour of clicking, and it's easy to get one wrong. Code
does it in a second, and does it the same way every time.

## Lesson 4.4 — Tool scripts that run from the command line

```bash
godot --headless --script res://tools/build_resources.gd
```

* `--headless`: no window, no GPU rendering. Fast.
* `--script`: instead of loading the main scene, run this script **as the main loop**.

A script run with `--script` must extend `SceneTree` (or `MainLoop`). Its work goes in `_init()`,
which runs as soon as the script is created, and it must call `quit()` at the end.

> ⚠️ In `--script` mode, **autoloads aren't loaded**. That's fine here because this tool doesn't
> touch `Game`. The level builder in chapter 10 *does* need autoloads, so it runs as a scene
> instead.

Before running it, Godot must have **imported** the PNGs. Opening the project in the editor does
that, or you can run:

```bash
godot --headless --import
```

## Lesson 4.5 — `build_resources.gd`, part 1: the setup

Create `tools/build_resources.gd`:

```gdscript
extends SceneTree
## Asset pipeline step 1: converts the raw sprite sheets in res://asset into
## Godot resources (SpriteFrames + TileSet).
##
## Run from the project folder:
##   godot --headless --import
##   godot --headless --script res://tools/build_resources.gd
##
## Every sheet in the pack is a single row of 32x32 frames, so the number of
## frames is simply image_width / 32. Each PNG becomes one animation whose
## name is the file name in snake_case ("Walk+Shot.png" -> "walk_shot").

const FRAME_DIR := "res://resources/frames/"

# Which animations loop, and their playback speed (frames per second).
const LOOPING := ["idle", "walk", "walk_shot", "shot", "walk_attack", "run_attack"]
const FPS := {
	"idle": 6.0, "walk": 10.0, "walk_shot": 12.0, "shot": 14.0, "recharge": 9.0,
	"cast": 12.0, "hurt": 14.0, "dead": 8.0, "attack": 14.0, "attack_1": 12.0,
	"attack_2": 12.0, "walk_attack": 12.0, "run_attack": 12.0,
}
```
*(from the game)*

**Why these values?**
* **Looping** animations are continuous activities (standing, walking, firing). Everything else
  (hurt, dead, cast, recharge, attacks) plays **once** and stops on the last frame.
* **FPS:** idle is slow (6) for a calm "breathing" loop. Walking at 10 matches 95 px/s strides.
  Shooting is fast (14) so it feels punchy. Death at 8 gives a heavy collapse.
* Putting these in **tables** at the top means tuning feel is editing numbers, not logic.

## Lesson 4.6 — Part 2: `_init` and building characters

```gdscript
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)

	build_character("player", "res://asset/Characters/Character_1")
	build_character("mook_gunner", "res://asset/Enimies/Enimies_1")
	build_character("mook_brute", "res://asset/Enimies/Enimies_4")
	build_character("boss_rook", "res://asset/Enimies/Enimies_3")
	build_character("boss_bonecrusher", "res://asset/Enimies/Enimies_5")
	build_character("boss_plague_doctor", "res://asset/Enimies/Enimies_2")

	build_single("grenade", "res://asset/Characters/Other/Granate_Cast.png", 32, 16.0, true)
	build_single("explosion", "res://asset/Characters/Other/Granate_Explosion.png", 64, 18.0, false)

	build_tileset()
	print("build_resources: done")
	quit()
```
*(from the game)*

* `DirAccess.make_dir_recursive_absolute(path)` creates the output folder (and parents) if
  needed. Saving into a missing folder would fail.
* The six `build_character` calls are the **casting decisions** of the game: which art becomes
  which role. Swapping `Enimies_3` and `Enimies_5` swaps how bosses 1 and 2 look.
* `quit()` ends the program. Without it, the headless process would wait forever.

```gdscript
func build_character(id: String, dir_path: String) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var dir := DirAccess.open(dir_path)
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		var anim := file.get_basename().to_lower().replace("+", "_").replace(" ", "_")
		var tex: Texture2D = load(dir_path + "/" + file)
		if tex.get_height() != 32:
			continue  # e.g. Sleeve.png (bullet casings) is not a character pose
		add_strip(frames, anim, tex, 32, FPS.get(anim, 10.0), anim in LOOPING)
	save(frames, FRAME_DIR + id + ".tres")
```
*(from the game)*

Line by line:

1. `SpriteFrames.new()` creates an empty resource **in memory**.
2. A new `SpriteFrames` comes with an empty animation called `"default"`. We remove it so the
   animation list contains only real animations.
3. `DirAccess.open(path)` returns an object for browsing a folder. `get_files()` lists file names.
4. `ends_with(".png")` skips the `.import` files Godot keeps next to each image.
5. **Name normalisation:** `"Walk+Shot.png"` → `get_basename()` → `"Walk+Shot"` →
   `to_lower()` → `"walk+shot"` → `replace("+", "_")` → `"walk_shot"`. Code can then always
   write `sprite.play("walk_shot")`.
6. `var tex: Texture2D = load(...)`: `load` returns a generic `Resource`, and the explicit type
   tells Godot (and you) that it's a texture, so `get_height()` autocompletes.
7. The height check skips `Sleeve.png` **automatically**, with no special-case file name. Rules
   based on properties are sturdier than lists of exceptions.
8. `FPS.get(anim, 10.0)` gives a sensible default for unexpected names, and `anim in LOOPING`
   gives the loop flag.

```gdscript
func build_single(id: String, path: String, frame_w: int, fps: float, loop: bool) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	add_strip(frames, "default", load(path), frame_w, fps, loop)
	save(frames, FRAME_DIR + id + ".tres")
```
*(from the game)*

For single effects (grenade, explosion) we want one animation called `"default"`, which is what
`AnimatedSprite2D.play()` plays when you pass no name.

## Lesson 4.7 — Part 3: slicing a strip

```gdscript
func add_strip(frames: SpriteFrames, anim: String, tex: Texture2D, frame_w: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var h := tex.get_height()
	for i in tex.get_width() / frame_w:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, h)
		frames.add_frame(anim, atlas)
```
*(from the game)*

* `tex.get_width() / frame_w` is integer division: 128 / 32 = 4 frames.
* Frame *i* starts at `x = i * frame_w`. This is the `start + index * spacing` pattern from
  chapter 1.
* Each frame is a new `AtlasTexture` pointing at the **same** big texture. Memory cost is tiny.

## Lesson 4.8 — Part 4: the tileset

A **`TileSet`** describes tiles: their size, which image they come from, and their collision.
A **`TileMapLayer`** node (chapter 10) paints a grid using a `TileSet`.

```gdscript
# Ground tiles (solid) and platform tiles (one-way) in asset/Tiled/Tile1.png.
const GROUND_TILES := [
	Vector2i(1, 22), Vector2i(2, 22), Vector2i(3, 22), Vector2i(4, 22),
	...
	Vector2i(6, 28), Vector2i(7, 28), Vector2i(8, 28), Vector2i(9, 28),
]
# Roof ledge of the yellow building: left cap, middle pieces, right cap.
const PLATFORM_TILES := [
	Vector2i(12, 15), Vector2i(13, 15), Vector2i(14, 15), Vector2i(15, 15),
	Vector2i(16, 15), Vector2i(17, 15), Vector2i(18, 15), Vector2i(19, 15),
	Vector2i(20, 15), Vector2i(22, 15),
]
```
*(from the game, shortened)*

`Vector2i(column, row)` are **atlas coordinates** in tiles, not pixels. `(1, 22)` is the tile at
pixel (16, 352).

```gdscript
func build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	# Physics layer 0 = solid ground (collision layer 1 "world").
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	# Physics layer 1 = one-way platforms (collision layer 5 "platforms").
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 1 << 4)
	ts.set_physics_layer_collision_mask(1, 0)
```
*(from the game)*

**TileSet physics layers vs collision layers** confuse everyone at first:

* A TileSet **physics layer** is a slot (0, 1, 2…) where tiles can store collision shapes.
* Each slot is assigned a normal **collision layer** (bitmask).

We make two slots: slot 0 → collision layer 1 (world), and slot 1 → collision layer 5
(`1 << 4 = 16`, platforms). Ground tiles put their shape in slot 0 and platform tiles in slot 1.
Now the player can ignore platforms (mask bit 16 off) while still standing on ground (bit 1).
Tiles have mask 0 because they never move, so they don't need to *look* for anything.

```gdscript
	var src := TileSetAtlasSource.new()
	src.texture = load("res://asset/Tiled/Tile1.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)
```
*(from the game)*

A **source** is where tile images come from. A `TileSetAtlasSource` slices one texture into a grid.
We register it with **source id 0**. Later, `set_cell(pos, 0, atlas_coords)` means "source 0, this
tile".

```gdscript
	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var top := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -2), Vector2(-8, -2)])
	for c in GROUND_TILES:
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
	for c in PLATFORM_TILES:
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(1)
		td.set_collision_polygon_points(1, 0, top)
		td.set_collision_polygon_one_way(1, 0, true)
	save(ts, "res://resources/city_tileset.tres")
```
*(from the game)*

* Polygon points are relative to the **tile centre**, so a 16 px tile spans −8…+8.
* `full` is the whole square. `top` is the top 6 px strip, a thin ledge.
* `create_tile(c)` makes that grid cell a usable tile. Cells you don't create can't be painted.
* `get_tile_data(c, 0)` gets that tile's data (the `0` is the alternative-tile id, here the
  default).
* `add_collision_polygon(layer)` then `set_collision_polygon_points(layer, polygon_index, points)`.
* **`set_collision_polygon_one_way(1, 0, true)`**: a one-way shape only blocks bodies moving
  **into it from above** (along its "up"). Jump up through it from below and you pass. Fall onto
  it and you land.

### 🔤 Language spotlight: `PackedVector2Array` and other packed arrays
`PackedVector2Array`, `PackedStringArray`, `PackedColorArray`… are arrays of one fixed type stored
compactly in memory. Engine APIs that take lots of points (polygons, lines) use them. Create one
from a normal array literal as shown above.

## Lesson 4.9 — Saving resources

```gdscript
func save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
	else:
		print("  saved ", path)
```
*(from the game)*

* `ResourceSaver.save` writes the resource. The extension picks the format: `.tres` is text
  (readable and diff-friendly in git), `.res` is binary.
* It returns an **`Error`** code. `OK` (0) means success.
* `push_error` prints a red error in the Output and debugger, and doesn't stop the program. Always
  check error codes in tools, so a typo in a path doesn't fail silently.

Run it:

```bash
godot --headless --import
godot --headless --script res://tools/build_resources.gd
```

You should see `saved res://resources/frames/player.tres` … `build_resources: done`. Open
`player.tres` in the editor (double-click). The SpriteFrames panel shows every animation. ✔

---

## 🏋️ Exercises

1. ★ Change `"idle": 6.0` to `2.0`, re-run the tool, and run any scene with the player. Then put
   it back. What does idle FPS communicate about a character?
2. ★ Add `print(anim, ": ", tex.get_width() / 32, " frames")` inside `build_character`. Which
   enemy has the longest `recharge`?
3. ★★ Add `Character_2` as `"player2"` to the pipeline. Which extra animation does it have that
   the player doesn't? (Look for `shield`.)
4. ★★ Write a small `extends SceneTree` script `tools/list_assets.gd` that prints every PNG in
   `res://asset/Characters/Other/` with its size (`get_width()` × `get_height()`).
5. ★★★ The tool assumes every sheet is a single row. Extend `add_strip` with a `frame_h`
   parameter and support **grids** (several rows): loop over rows and columns. Keep existing calls
   working with a default value.
6. ★★★ Add a third TileSet physics layer for "hazard" tiles (spikes) on collision layer 6, and
   create one tile from the sheet with a full collision polygon on it. (You'll name layer 6 in
   Project Settings too.)

## ✅ Solutions

<details><summary>Exercise 1</summary>

At 2 FPS the idle looks sluggish or sleepy. Faster idles read as tense or energetic. Animation
speed is part of a character's personality.
</details>

<details><summary>Exercise 2</summary>

The gunner (`Enimies_1`) has the longest recharge: 9 frames. The player has 5, the Rook 6, and the
Plague Doctor 7.
</details>

<details><summary>Exercise 3</summary>

```gdscript
build_character("player2", "res://asset/Characters/Character_2")
```
It has a **`shield`** animation. It isn't listed in `FPS`, so it gets the default 10 FPS and
doesn't loop. You may want to add `"shield": 8.0` and add it to `LOOPING` if the shield is held.
</details>

<details><summary>Exercise 4</summary>

```gdscript
extends SceneTree

func _init() -> void:
	var path := "res://asset/Characters/Other/"
	for f in DirAccess.open(path).get_files():
		if f.ends_with(".png"):
			var t: Texture2D = load(path + f)
			print("%s  %dx%d" % [f, t.get_width(), t.get_height()])
	quit()
```
</details>

<details><summary>Exercise 5</summary>

```gdscript
func add_strip(frames: SpriteFrames, anim: String, tex: Texture2D, frame_w: int,
		fps: float, loop: bool, frame_h: int = -1) -> void:
	if frame_h <= 0:
		frame_h = tex.get_height()          # old behaviour: one row
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for row in tex.get_height() / frame_h:
		for col in tex.get_width() / frame_w:
			var atlas := AtlasTexture.new()
			atlas.atlas = tex
			atlas.region = Rect2(col * frame_w, row * frame_h, frame_w, frame_h)
			frames.add_frame(anim, atlas)
```
The default `-1` keeps every existing call unchanged. That's a good way to extend a function
without breaking callers.
</details>

<details><summary>Exercise 6</summary>

```gdscript
ts.add_physics_layer()                         # slot 2
ts.set_physics_layer_collision_layer(2, 1 << 5) # layer 6 = value 32
ts.set_physics_layer_collision_mask(2, 0)
...
var spike := Vector2i(24, 20)                  # pick any cell you like
src.create_tile(spike)
var td := src.get_tile_data(spike, 0)
td.add_collision_polygon(2)
td.set_collision_polygon_points(2, 0, full)
```
An `Area2D` on the player with mask 32 could then detect hazards.
</details>

---

📝 **Recap**
* Resources are shared data (`.tres`). Nodes use them.
* `SpriteFrames` = named animations of `AtlasTexture` frames. `AtlasTexture` = a region of a texture.
* `extends SceneTree` + `--script` + `_init()` + `quit()` = command-line tool. No autoloads.
* `DirAccess` lists files. `ResourceSaver.save` writes and returns an `Error`.
* `TileSet` physics *slots* map to collision *layers*. Polygons are centred. `one_way` makes
  platforms you can jump through.

Next: **[Chapter 5 — The player](chapter-05-the-player.md)**
