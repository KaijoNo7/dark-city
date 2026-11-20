# Chapter 0 — Before you start

🎯 **Goals**
* Install Godot 4.7 and create the project you'll build throughout the course.
* Find your way around the editor.
* Understand Godot's two central ideas: **nodes** and **scenes**.
* Write and run your first script.

---

## Lesson 0.1 — What is a game engine, and why Godot?

A game engine is a toolkit that already solves the problems every game has: drawing images,
playing sounds, reading the keyboard and gamepad, detecting collisions, loading files, running
at 60 frames per second. You write the parts that make *your* game unique.

**Godot** is a free, open-source engine (MIT licence: no fees, no royalties). It is especially
good for 2D. It has a dedicated 2D engine that works in real pixels, not a 3D engine faking 2D.
It's small (a single download of about 100 MB) and has its own language, **GDScript**, designed to
be easy to learn and closely integrated with the editor.

## Lesson 0.2 — Installing Godot

1. Go to <https://godotengine.org/download> and download **Godot 4.7** (the *standard* version;
   the *.NET* version is only needed for C#).
2. Godot doesn't need installing. Unzip it and run the executable.
   * **Linux:** many distributions package it (`pacman -S godot`, `flatpak install godot`…).
     Make sure it's version 4.7: `godot --version`.
   * **Windows:** you can put `Godot_v4.7-stable_win64.exe` anywhere, for example
     `C:\Tools\Godot\`.
   * **macOS:** drag `Godot.app` into Applications.
3. You'll see the **Project Manager**: a list of projects (empty for now).

> 💡 **Tip:** add Godot to your `PATH` so you can run `godot` from a terminal. Later chapters
> use the command line for tools and automated tests.

## Lesson 0.3 — Create the project

1. In the Project Manager click **Create**.
2. **Project Name:** `Dark City`. Choose an empty folder.
3. **Renderer:** *Forward+*. It's the default and what this game uses. (*Compatibility* would also
   work for this 2D game and is required for web export. See chapter 12.)
4. **Version control metadata:** *Git* (creates a `.gitignore` and `.gitattributes`).
5. Click **Create & Edit**.

Now copy the art pack into the project: put the `asset/` folder from this repository next to
`project.godot`. Switch back to Godot. It notices the new files and **imports** them, turning PNGs
into engine-ready textures stored in the hidden `.godot/` folder.

> ⚠️ The pack contains a `__MACOSX` folder of macOS junk files. Create an **empty file** named
> `.gdignore` inside `asset/__MACOSX/` to stop Godot from trying to import them. (Any folder with
> a `.gdignore` file is ignored.)

Your folder now looks like:

```
dark-city/
├── .godot/            ← Godot's cache (never edit, never commit)
├── asset/             ← the art
├── icon.svg
├── project.godot      ← project settings
├── .gitignore
└── .gitattributes
```

## Lesson 0.4 — A tour of the editor

```
┌──────────────────────────────────────────────────────────────────────────┐
│  Scene  Project  Debug  Editor  Help      2D  3D  Script  AssetLib   ▶ ⏸ ⏹ │ ← top bar
├────────────┬────────────────────────────────────────────┬────────────────┤
│ Scene dock │                                            │   Inspector    │
│ (node tree)│              Main viewport                 │ (properties of │
│            │        (2D / 3D view or script editor)     │  the selected  │
├────────────┤                                            │     node)      │
│ FileSystem │                                            │                │
│ (res://)   ├────────────────────────────────────────────┤                │
│            │ Output · Debugger · Animation · …          │                │
└────────────┴────────────────────────────────────────────┴────────────────┘
```

| Panel | What it's for |
|---|---|
| **Scene dock** | The tree of nodes in the scene you're editing |
| **FileSystem dock** | Your project files. `res://` is the project folder. |
| **Inspector** | Every property of the selected node: position, texture, script variables… |
| **Main viewport** | Switch with the **2D / 3D / Script** buttons at the top |
| **Bottom panel** | *Output* (prints and errors), *Debugger*, animation and tile editors |
| **Run buttons** (top right) | **F5** runs the main scene. **F6** runs the scene you're editing. **F8** stops. |

## Lesson 0.5 — Nodes and scenes: Godot's big idea

### Nodes
A **node** is a building block that does one job:

| Node | Job |
|---|---|
| `Sprite2D` | draws an image |
| `AnimatedSprite2D` | plays a flip-book animation |
| `CollisionShape2D` | defines a shape for physics |
| `CharacterBody2D` | a body you move with code that collides with walls and floors |
| `Area2D` | detects when things enter a region |
| `Camera2D` | decides what part of the world is visible |
| `Label` | shows text |
| `Timer` | counts down and fires a signal |

Nodes form a **tree**. Each node has one parent and any number of children. Children move with
their parent. If a character moves, its sprite and collision shape (children) move with it.

### Scenes
A **scene** is a tree of nodes saved to a file (`.tscn`). Our player is a scene:

```
Player (CharacterBody2D)
├── Sprite (AnimatedSprite2D)
├── Shape (CollisionShape2D)
├── Muzzle (Marker2D)
└── Camera (Camera2D)
```

The key idea is that **a scene can be placed inside another scene as a single node**. That's called
**instancing**. The level scene contains the player scene, 19 enemy scenes and 3 arena scenes.
Edit `player.tscn` once and every instance updates.

Scenes are Godot's version of what other engines call prefabs, actors or objects. They are the
unit you design, reuse and reason about.

### Scripts
A **script** attaches behaviour to a node. A script *extends* the node's type: a script on a
`CharacterBody2D` starts with `extends CharacterBody2D` and can use all of its features
(`velocity`, `move_and_slide()`…) plus anything you add.

## Lesson 0.6 — Your first script

Let's make sure everything works.

1. **Scene → New Scene**. In the Scene dock click **2D Scene**. That creates a `Node2D` root.
2. Rename it `Hello` (double-click the name).
3. Right-click `Hello` → **Attach Script**. Keep the defaults (`extends Node2D`, path
   `res://hello.gd`) and click **Create**.
4. Replace the contents with:

```gdscript
extends Node2D


func _ready() -> void:
	print("Hello, Dark City!")
```

5. Save the scene (**Ctrl+S**) as `hello.tscn`, then press **F6**.

A grey window opens, and the **Output** panel shows `Hello, Dark City!`. 🎉

What happened:

* `extends Node2D`: this script adds behaviour to a `Node2D`.
* `func _ready() -> void:` defines a function named `_ready`. Godot calls `_ready` automatically
  once the node and its children have entered the scene tree. `-> void` means it returns nothing.
* `print(...)` writes to the Output panel.
* **Indentation matters.** The body of a function is indented by one **tab**. GDScript uses
  indentation (like Python) instead of `{ }` braces.

### 🧪 Try it
1. Add a second line: `print(2 + 3 * 4)`. Is it 20 or 14? (Multiplication happens first.)
2. Add a function that runs every frame:

```gdscript
func _process(delta: float) -> void:
	print(delta)
```

Run it. You'll see numbers near `0.0166`, which is 1/60 of a second. `delta` is the time since the
last frame, and it will matter a lot in chapter 5. Remove the line afterwards, because printing
60 times a second floods the output.

## Lesson 0.7 — Reading the rest of this course

* Code blocks marked **(from the game)** are exact copies of this repository's code.
* Code blocks marked **(example)** are for learning only. Don't add them to the game.
* GDScript uses **tabs** for indentation. If you copy from a web page that turned tabs into
  spaces, Godot will complain about "mixed indentation". Use **Edit → Convert Indent to Tabs**
  in the script editor.

---

## 🏋️ Exercises

1. ★ Change `hello.gd` to print your name and the result of `365 * 24` (hours in a year).
2. ★ Add a `Sprite2D` child to `Hello`. In the Inspector, drag
   `asset/Characters/Character_1/Idle.png` into its **Texture** property. Run the scene. What do
   you see? (Hint: the whole strip.) Then turn on **Region** and set **Rect** to `x=0, y=0, w=32, h=32`.
3. ★★ The character looks blurry when you zoom in. Find the project setting that fixes it.
   (Hint: *Rendering → Textures → Canvas Textures → Default Texture Filter*.)
4. ★★ Make the sprite move right by writing `_process(delta)` with `position.x += 30 * delta`.
   How many pixels does it move per second? Why multiply by `delta`?

## ✅ Solutions

<details><summary>Exercise 1</summary>

```gdscript
extends Node2D

func _ready() -> void:
	print("My name is Ada")
	print(365 * 24)   # 8760
```
</details>

<details><summary>Exercise 2</summary>

Without a region you see all 4 idle frames side by side (a 128 × 32 strip). With
**Region → Rect = (0, 0, 32, 32)** you see only the first frame. This is exactly what the asset
pipeline in chapter 4 automates for hundreds of frames.
</details>

<details><summary>Exercise 3</summary>

Set **Default Texture Filter** to **Nearest**. Pixel art then stays sharp when scaled. Chapter 3
explains this and the other pixel-perfect settings.
</details>

<details><summary>Exercise 4</summary>

```gdscript
func _process(delta: float) -> void:
	$Sprite2D.position.x += 30 * delta
```

It moves **30 pixels per second**. Without `delta` it would move 30 px *per frame*: 1,800 px/s at
60 FPS but 4,320 px/s at 144 FPS. Multiplying by `delta` makes speed independent of the frame
rate.
</details>

---

📝 **Recap**
* Godot = free engine. Its building blocks are **nodes**, organised in **trees**, saved as
  **scenes**.
* Scenes can be **instanced** inside other scenes.
* Scripts extend a node type. `_ready()` runs once at start and `_process(delta)` runs every frame.
* GDScript is **indentation-based** (tabs).

Next: **[Chapter 1 — GDScript basics](chapter-01-gdscript-basics.md)**
