# 01 — Project settings

All engine configuration lives in `project.godot`. Godot writes this file when you change
**Project → Project Settings** in the editor. It is plain text, so you can also read it in any
text editor. This page explains every setting the game depends on, and why.

---

## Application

```ini
[application]
config/name="Dark city"
config/description="A 2D pixel run-and-gun: one night, one street, three bosses."
run/main_scene="res://scenes/ui/title.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://icon.svg"
```

| Key | Meaning |
|---|---|
| `run/main_scene` | The scene Godot loads when you press **F5** or run an exported build. It is the title screen. |
| `config/features` | Records the Godot version (`4.7`) and renderer the project was made with. Opening it in an older Godot shows a warning. |

## Autoload

```ini
[autoload]
Game="*res://scripts/autoload/game.gd"
```

An **autoload** (also called a singleton) is a node Godot creates before any scene and keeps alive
the whole time the game runs. The `*` means "make it a global variable", so every script can write
`Game.add_score(100)` without looking anything up. See
[architecture/03-communication.md](../architecture/03-communication.md) for what `Game` does.

## Display — the pixel-perfect setup

```ini
[display]
window/size/viewport_width=384
window/size/viewport_height=216
window/size/window_width_override=1152
window/size/window_height_override=648
window/stretch/mode="canvas_items"
window/stretch/scale_mode="integer"
```

These six lines are what make the game look like crisp pixel art at any window size.

| Setting | Value | Why |
|---|---|---|
| `viewport_width/height` | 384 × 216 | The **game's internal canvas**. All positions in the code (`384`, `216`, `y = 176`…) are in these units. 384 × 216 is 16:9, and the 16 px tiles fit 24 across and 13.5 down. |
| `window_*_override` | 1152 × 648 | The **window** opens 3× bigger, because 384 × 216 would be tiny on a modern screen. |
| `stretch/mode` | `canvas_items` | Godot scales the 2D canvas up to the window. Text and vector shapes are drawn at the real window resolution, so fonts stay sharp while sprites scale. (The alternative, `viewport`, renders at 384 × 216 and then scales the finished image, which makes text blocky.) |
| `stretch/scale_mode` | `integer` | The canvas is only ever scaled by whole numbers (×2, ×3, ×4…). With ×2.5, some pixels would be 2 screen pixels wide and some 3, which makes pixel art shimmer. Leftover space becomes black bars. |

## Rendering

```ini
[rendering]
textures/canvas_textures/default_texture_filter=0
rendering_device/driver.windows="d3d12"
environment/defaults/default_clear_color=Color(0.05, 0.04, 0.09, 1)
2d/snap/snap_2d_transforms_to_pixel=true
```

| Setting | Why |
|---|---|
| `default_texture_filter=0` (**Nearest**) | When a texture is scaled up, each pixel stays a hard-edged square. The default (Linear) blurs pixel art. |
| `snap_2d_transforms_to_pixel=true` | Node positions are rounded to whole pixels when drawn. Without it, a sprite at `x = 10.4` can look blurry or jitter as the camera moves. |
| `default_clear_color` | The colour behind everything (a very dark purple). The level draws a sky over it, but menus and black bars show it. |
| `driver.windows="d3d12"` | On Windows, use Direct3D 12 instead of Vulkan. It has no effect on Linux or macOS. |

## Physics

```ini
[physics]
3d/physics_engine="Jolt Physics"
```

This only affects **3D** physics, which the game does not use. It is the default for new Godot 4.4+
projects and is harmless. 2D physics uses Godot's built-in 2D engine.

## Layer names

```ini
[layer_names]
2d_physics/layer_1="world"
2d_physics/layer_2="player"
2d_physics/layer_3="enemies"
2d_physics/layer_4="pickups"
2d_physics/layer_5="platforms"
```

Naming layers does not change behaviour. It makes the collision checkboxes in the Inspector
readable. The meaning of each layer is covered in [02 — Input & physics](02-input-and-physics.md).

## Input

The `[input]` section defines eight actions: `move_left`, `move_right`, `move_down`, `jump`,
`shoot`, `grenade`, `reload` and `pause`. The full table is in
[02 — Input & physics](02-input-and-physics.md).

---

## Changing settings safely

* Prefer the editor (**Project → Project Settings**). Turn on **Advanced Settings** to see
  everything listed above.
* If you edit `project.godot` by hand, close the editor first. An open editor rewrites the file
  when it saves and can discard your edits.
* Changing `viewport_width/height` is a big change. Many layout numbers in `hud.gd`, `title.gd`,
  `ui_kit.gd` and `stars.gd` assume 384 × 216.
