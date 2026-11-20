# Chapter 11 — User interface

🎯 **Goals**
* Understand `Control` nodes, anchors, containers and `CanvasLayer`.
* Build a reusable **static helper library** for consistent UI (`ui_kit.gd`).
* Style labels and buttons with **theme overrides** and `StyleBoxFlat`. Use 9-slice panels.
* Pass functions around as **`Callable`s** (buttons that know what to do).
* Build the HUD: hearts, ammo, score, timer, messages, a boss bar, all driven by **signals**.
* Implement **pause**, game-over and victory dialogs with keyboard and gamepad **focus**.
* Build the title screen.

---

## Lesson 11.1 — `Control` nodes in five minutes

UI in Godot is made of **`Control`** nodes. Like `Node2D`, they draw on a canvas, but they're
designed for rectangles: they have a `size`, **anchors** and **margins**, and they receive mouse
and focus events.

| Node | Purpose |
|---|---|
| `Control` | an empty rectangle (a container for others) |
| `Label` | text |
| `Button` | clickable / focusable button with a `pressed` signal |
| `TextureRect` | shows a texture |
| `ColorRect` | a solid colour rectangle |
| `NinePatchRect` | a texture stretched as a 9-slice frame |
| `VBoxContainer` / `HBoxContainer` | automatically stack children vertically / horizontally |

**Anchors** pin a control's edges to its parent's edges (0 = left/top, 1 = right/bottom).
`set_anchors_preset(Control.PRESET_FULL_RECT)` stretches a control to fill its parent, which is
how the dialog's dim background covers the whole screen.

**Containers** position their children for you. A `VBoxContainer` with `separation = 4` lays out
title, text and buttons in a column with 4 px gaps. Children set **size flags** to say how they
want to be placed (e.g. `SIZE_SHRINK_CENTER` = don't stretch, centre me).

### Why `CanvasLayer` for the HUD?
A `Control` in the level would move with the camera. A **`CanvasLayer`** has its own canvas,
unaffected by the camera, so the HUD stays fixed on screen. `layer = 10` draws it above the rain
(5) and the world (0).

## Lesson 11.2 — Building UI in code vs in the editor

Dark City builds its HUD and title screen **in code**. In the editor, `hud.tscn` is a single
`CanvasLayer` node, which is why it looks "empty" until you run it.

| | Editor-built UI | Code-built UI (this game) |
|---|---|---|
| Visual layout while editing | ✔ | ✘ (run with F6 to see it) |
| Consistent styling | `Theme` resource | helper functions |
| Repetition (10 hearts) | duplicate nodes | a `for` loop |
| Easy to diff / review | `.tscn` diffs are noisy | readable code |
| Good for | larger menus, artists editing | small HUDs on a fixed pixel canvas |

Both are legitimate. Learning the code approach teaches you exactly what the editor is doing for
you. Exercise 7 asks you to rebuild the pause dialog in the editor.

## Lesson 11.3 — `ui_kit.gd`: a static helper library

```gdscript
extends RefCounted
## Small helper library for building UI from the pack's UI art.
## Usage:  const UI := preload("res://scripts/ui/ui_kit.gd")

const UI_SHEET := preload("res://asset/UI/UI.png")
const PANEL_REGION := Rect2(112, 108, 48, 48)

const COLOR_TEXT := Color(0.16, 0.11, 0.11)
const COLOR_LIGHT := Color(0.96, 0.92, 0.85)
const COLOR_ACCENT := Color(1.0, 0.72, 0.2)
const COLOR_DANGER := Color(0.85, 0.2, 0.25)
```
*(from the game)*

### 🔤 Preloading a script as a namespace
```gdscript
const UI := preload("res://scripts/ui/ui_kit.gd")
UI.label("Hi")        # call a static function
UI.COLOR_ACCENT       # read a constant
```
A preloaded script **is** its class, so its constants and `static func`s are reachable through
the constant. Nobody creates an instance (`UI.new()` would work, but there's no reason to). It's a
neat way to group helpers without adding a global `class_name`.

**A palette as constants:** four named colours used everywhere. Changing the accent colour
changes the title, score and focused buttons in one edit.

```gdscript
static func icon(n: int) -> Texture2D:
	return load("res://asset/UI/Icons/%d.png" % n)


## Beige 9-slice panel cut from asset/UI/UI.png.
static func panel(size: Vector2) -> NinePatchRect:
	var p := NinePatchRect.new()
	p.texture = UI_SHEET
	p.region_rect = PANEL_REGION
	p.patch_margin_left = 4
	p.patch_margin_top = 4
	p.patch_margin_right = 4
	p.patch_margin_bottom = 4
	p.custom_minimum_size = size
	p.size = size
	return p
```
*(from the game)*

* **`load` with a formatted path:** icons are numbered files, so `icon(33)` is the heart. `load`
  (not `preload`) is required because the path is built at runtime. Loaded resources are cached,
  so calling it 10 times loads the file once.
* **9-slice panel:** `region_rect` picks a 48 × 48 frame from the UI sheet. The 4 px patch margins
  are the corners and borders that **don't stretch**. The same small image makes the 98 × 30 HUD
  box and the 190 × 130 dialog with crisp borders.
* `custom_minimum_size` matters inside containers. `size` matters when placed freely.

```gdscript
static func label(text: String, font_size: int = 8, color: Color = COLOR_LIGHT, outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
		l.add_theme_constant_override("outline_size", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l
```
*(from the game)*

### 🔤 Theme overrides
Every Control looks up its style (fonts, colours, constants, styleboxes) from a **Theme**. To
change one value on one control, add an **override**:

| Method | Overrides | Example key |
|---|---|---|
| `add_theme_font_size_override` | font size | `"font_size"` |
| `add_theme_color_override` | a colour | `"font_color"`, `"font_outline_color"`, `"font_hover_color"` |
| `add_theme_constant_override` | a number | `"outline_size"`, `"separation"` |
| `add_theme_stylebox_override` | a background box | `"normal"`, `"hover"`, `"focus"`, `"pressed"` |

The keys come from each control's documentation (**Theme Properties** section). The editor also
lists them in the Inspector under **Theme Overrides**.

**Why outlines?** Text over a busy, rainy street needs contrast. A dark 3 px outline makes light
text readable on any background. On a beige panel, the outline is turned off (`outline = false`)
and dark text is used instead.

```gdscript
static func button(text: String, on_pressed: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(100, 16)
	b.add_theme_font_size_override("font_size", 8)
	b.add_theme_color_override("font_color", COLOR_TEXT)
	b.add_theme_color_override("font_hover_color", COLOR_TEXT)
	b.add_theme_color_override("font_focus_color", COLOR_TEXT)
	b.add_theme_color_override("font_pressed_color", COLOR_TEXT)
	b.add_theme_stylebox_override("normal", _box(Color(0.82, 0.74, 0.66)))
	b.add_theme_stylebox_override("hover", _box(COLOR_ACCENT))
	b.add_theme_stylebox_override("focus", _box(COLOR_ACCENT))
	b.add_theme_stylebox_override("pressed", _box(Color(0.9, 0.5, 0.15)))
	b.pressed.connect(on_pressed)
	return b


static func _box(bg: Color) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = COLOR_TEXT
	s.set_border_width_all(1)
	s.set_corner_radius_all(2)
	s.content_margin_left = 4
	s.content_margin_right = 4
	return s
```
*(from the game)*

### 🔤 `Callable`: functions as values
`on_pressed: Callable` means "give me a function to call". Callers pass a method **without
parentheses**:

```gdscript
UI.button("START", Game.start_game)       # a method on the Game autoload
UI.button("QUIT", get_tree().quit)        # a method on the SceneTree
UI.button("RESUME", _toggle_pause)        # a method on this node
```

The button connects its `pressed` signal to that function. **The button knows nothing about the
game.** It just calls whatever it was given. This is how one generic helper produces every button.

* **States:** `normal`, `hover` (mouse over), `focus` (selected with keyboard or gamepad) and
  `pressed`. Hover and focus share the accent colour, so mouse and gamepad users get the same
  feedback.
* **`StyleBoxFlat`** draws a rectangle with a background, border and rounded corners, with no
  image. It's quick to style from code.

```gdscript
## A centered pop-up window: panel + title + info text + buttons.
## Returns the root Control (full-screen, with a dark backdrop).
static func dialog(title: String, info: String, buttons: Array[Button], title_color: Color = COLOR_DANGER) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var h := 70 + buttons.size() * 20
	var p := panel(Vector2(190, h))
	p.position = Vector2((384 - 190) / 2.0, (216 - h) / 2.0)
	root.add_child(p)

	var box := VBoxContainer.new()
	box.position = Vector2(8, 6)
	box.size = Vector2(174, h - 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 4)
	p.add_child(box)
	box.add_child(label(title, 16, title_color))
	if info != "":
		box.add_child(label(info, 8, COLOR_TEXT, false))
	for b in buttons:
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(b)
	return root
```
*(from the game)*

* **The dim layer** (60 % black, full screen) focuses attention on the dialog and also **blocks
  mouse clicks** to anything behind it.
* **Height grows with the button count:** `70 + buttons × 20`.
* **Centring maths:** `(screen − panel) / 2` on each axis. `2.0` keeps it a float.
* **A VBoxContainer** stacks title, info and buttons, centred vertically
  (`ALIGNMENT_CENTER`), with `SIZE_SHRINK_CENTER` so buttons keep their 100 px width.
* It **returns** the root. The caller decides where to add it.

## Lesson 11.4 — The HUD: building it

`scenes/ui/hud.tscn` is a `CanvasLayer` with `layer = 10`, `process_mode = Always` and `hud.gd`.

```gdscript
extends CanvasLayer
## In-game HUD + pause / game over / victory screens.
## Everything listens to signals on the Game autoload, so the HUD never
## needs a direct reference to the player or bosses.

const UI := preload("res://scripts/ui/ui_kit.gd")
const HEART_ICON := 33
const GRENADE_ICON := 1
const BULLET_ICON := 26
const SKULL_ICON := 25

var _hearts: Array[TextureRect] = []
var _grenade_icons: Array[TextureRect] = []
var _ammo_label: Label
var _score_label: Label
var _time_label: Label
var _message: Label
var _message_tween: Tween
var _boss_box: Control
var _boss_name: Label
var _boss_fill: ColorRect
var _boss_max := 1
var _overlay: Control
var _game_over := false

const BOSS_BAR_W := 200.0
```
*(from the game)*

**Named icon numbers** (`HEART_ICON := 33`) instead of a bare `33` in the code: the reader knows
what icon 33 *is*.

```gdscript
func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working while the game is paused
	_build_status()
	_build_boss_bar()
	_message = UI.label("", 16, UI.COLOR_LIGHT)
	_message.position = Vector2(0, 55)
	_message.size = Vector2(384, 50)
	_message.modulate.a = 0.0
	add_child(_message)

	Game.player_hp_changed.connect(_on_hp_changed)
	Game.player_ammo_changed.connect(_on_ammo_changed)
	Game.score_changed.connect(func(s: int) -> void: _score_label.text = "%06d" % s)
	Game.show_message.connect(_show_message)
	Game.boss_started.connect(_on_boss_started)
	Game.boss_hp_changed.connect(_on_boss_hp_changed)
	Game.boss_defeated.connect(_on_boss_defeated)
	Game.player_died.connect(_on_player_died)
```
*(from the game)*

### 🔤 `process_mode` and pausing
When `get_tree().paused = true`, nodes stop processing **unless** their `process_mode` says
otherwise:

| `process_mode` | When paused |
|---|---|
| `INHERIT` (default) | same as parent |
| `PAUSABLE` | stops |
| `WHEN_PAUSED` | **only** runs while paused |
| `ALWAYS` | always runs |
| `DISABLED` | never runs |

The HUD is `ALWAYS`, so the pause dialog's buttons work while the game is frozen. Its children
inherit that.

**The message label** spans the full width and starts invisible (`modulate.a = 0`). Tweens fade it
in and out. **Eight signal connections** are the HUD's entire interface to the game. It holds no
reference to the player or any boss.

```gdscript
func _build_status() -> void:
	var bg := UI.panel(Vector2(98, 30))
	bg.position = Vector2(4, 4)
	bg.modulate = Color(1, 1, 1, 0.85)
	add_child(bg)
	for i in 10:
		var h := TextureRect.new()
		h.texture = UI.icon(HEART_ICON)
		h.scale = Vector2(0.5, 0.5)
		h.position = Vector2(9 + i * 9, 8)
		add_child(h)
		_hearts.append(h)
	var bullet := TextureRect.new()
	bullet.texture = UI.icon(BULLET_ICON)
	bullet.modulate = Color(0.25, 0.2, 0.2)
	bullet.scale = Vector2(0.5, 0.5)
	bullet.position = Vector2(8, 20)
	add_child(bullet)
	_ammo_label = UI.label("12/12", 8, UI.COLOR_TEXT, false)
	_ammo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_ammo_label.position = Vector2(17, 18)
	_ammo_label.size = Vector2(50, 12)
	add_child(_ammo_label)
	for i in 3:
		var g := TextureRect.new()
		g.texture = UI.icon(GRENADE_ICON)
		g.scale = Vector2(0.5, 0.5)
		g.position = Vector2(70 + i * 9, 20)
		add_child(g)
		_grenade_icons.append(g)

	_score_label = UI.label("000000", 10, UI.COLOR_ACCENT)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_score_label.position = Vector2(284, 3)
	_score_label.size = Vector2(96, 14)
	add_child(_score_label)
	_time_label = UI.label("00:00", 8, UI.COLOR_LIGHT)
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_label.position = Vector2(284, 16)
	_time_label.size = Vector2(96, 12)
	add_child(_time_label)
```
*(from the game)*

* **Icons are white**, so `modulate` colours them: red hearts, a dark bullet, olive grenades. One
  white icon serves every colour.
* **Half-scale icons** (16 px → 8 px) fit 10 hearts in a small box.
* We **keep references** to hearts and grenade icons in arrays so the signal handlers can update
  them by index.
* The score is **right-aligned** in a box ending at x 380 (4 px margin), so it grows leftwards as
  digits are added.

```gdscript
func _build_boss_bar() -> void:
	_boss_box = Control.new()
	_boss_box.position = Vector2((384 - BOSS_BAR_W) / 2.0, 192)
	_boss_box.visible = false
	add_child(_boss_box)
	var skull := TextureRect.new()
	skull.texture = UI.icon(SKULL_ICON)
	skull.modulate = UI.COLOR_DANGER
	skull.scale = Vector2(0.75, 0.75)
	skull.position = Vector2(-14, 7)
	_boss_box.add_child(skull)
	_boss_name = UI.label("BOSS", 8, UI.COLOR_LIGHT)
	_boss_name.size = Vector2(BOSS_BAR_W, 10)
	_boss_name.position = Vector2(0, -6)
	_boss_box.add_child(_boss_name)
	var back := ColorRect.new()
	back.color = Color(0.1, 0.05, 0.08)
	back.position = Vector2(-1, 9)
	back.size = Vector2(BOSS_BAR_W + 2, 8)
	_boss_box.add_child(back)
	_boss_fill = ColorRect.new()
	_boss_fill.color = UI.COLOR_DANGER
	_boss_fill.position = Vector2(0, 10)
	_boss_fill.size = Vector2(BOSS_BAR_W, 6)
	_boss_box.add_child(_boss_fill)
```
*(from the game)*

**A health bar is two rectangles:** a dark background 1 px bigger on each side (a border), and a
red fill whose **width** is proportional to HP. Grouping them in `_boss_box` lets one
`visible = false` hide the whole bar.

## Lesson 11.5 — The HUD: reacting to signals

```gdscript
func _on_hp_changed(hp: int, max_hp: int) -> void:
	for i in _hearts.size():
		_hearts[i].visible = i < max_hp
		_hearts[i].modulate = UI.COLOR_DANGER if i < hp else Color(0.3, 0.25, 0.25)


func _on_ammo_changed(ammo: int, mag: int, grenades: int, reloading: bool) -> void:
	_ammo_label.text = "RELOAD..." if reloading else "%d/%d" % [ammo, mag]
	for i in _grenade_icons.size():
		_grenade_icons[i].modulate = Color(0.35, 0.45, 0.2) if i < grenades else Color(0, 0, 0, 0.2)
```
*(from the game)*

**"Index < value" rendering:** heart *i* is full if `i < hp`. With hp = 7, hearts 0–6 are red and
7–9 grey. Hearts beyond `max_hp` are hidden, so lowering `max_hp` to 6 shows 6 hearts. The HUD
**redraws everything** on each change. With 13 icons, that costs nothing and can never get out of
sync.

```gdscript
func _show_message(text: String, seconds: float) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.15)
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)
```
*(from the game)*

**Kill the old tween.** If a new message arrives while one is fading out, two tweens would fight
over the same property. Keeping a reference and calling `kill()` guarantees one animation at a
time. The new message also simply replaces the text.

```gdscript
func _on_boss_started(boss_name: String, max_hp: int) -> void:
	_boss_max = max_hp
	_boss_name.text = boss_name
	_boss_fill.size.x = BOSS_BAR_W
	_boss_box.visible = true


func _on_boss_hp_changed(hp: int) -> void:
	var t := create_tween()
	t.tween_property(_boss_fill, "size:x", BOSS_BAR_W * hp / float(_boss_max), 0.15)
```
*(from the game)*

* `"size:x"`: tween just the width.
* `float(_boss_max)` avoids integer division: `200.0 * 45 / 90.0 = 100.0`.
* **The 0.15 s slide** makes every hit's size visible. Big hits from grenades slide further.

```gdscript
func _on_boss_defeated(boss_name: String, is_final: bool) -> void:
	_boss_box.visible = false
	Game.message(boss_name + "\nDEFEATED!", 1.6)
	if is_final:
		_game_over = true
		Game.running = false
		await get_tree().create_timer(3.0).timeout
		_show_overlay(UI.dialog("CITY SAVED",
			"All 3 bosses down!\nScore: %d    Time: %s" % [Game.score, Game.format_time(Game.run_time)],
			[UI.button("PLAY AGAIN", Game.restart_level), UI.button("TITLE", Game.go_to_title)],
			UI.COLOR_ACCENT))


func _on_player_died() -> void:
	_game_over = true
	Game.running = false
	await get_tree().create_timer(1.6).timeout
	_show_overlay(UI.dialog("YOU DIED",
		"Bosses defeated: %d/3\nScore: %d" % [Game.bosses_defeated, Game.score],
		[UI.button("RETRY", Game.restart_level), UI.button("TITLE", Game.go_to_title)]))
```
*(from the game)*

* `Game.running = false` **stops the clock** immediately, so the final time is exact.
* **Delays before the dialog** (3 s for victory, 1.6 s for death) let the moment land: explosions
  and the death animation play out first.
* `_game_over = true` disables the pause key so you can't pause over the end screen.
* Note how readable the dialog calls are, thanks to the helpers: title, text, buttons with their
  actions, colour.

## Lesson 11.6 — Pause and overlays

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _game_over:
		_toggle_pause()
		get_viewport().set_input_as_handled()
```
*(from the game)*

### 🔤 `_input` vs `_unhandled_input`
Input events travel: `_input` on all nodes → GUI controls (buttons and so on) →
`_unhandled_input` on all nodes. Using **`_unhandled_input`** means if a UI control consumed the
key, the pause toggle won't also fire. `set_input_as_handled()` stops the event travelling further.

Why not `Input.is_action_just_pressed("pause")` in `_process`? It would work too (the HUD processes
while paused). Event callbacks are the idiomatic choice for one-off UI actions and respect GUI
consumption.

```gdscript
func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		_close_overlay()
	else:
		get_tree().paused = true
		_show_overlay(UI.dialog("PAUSED", "",
			[UI.button("RESUME", _toggle_pause), UI.button("RESTART", Game.restart_level),
			UI.button("QUIT TO TITLE", Game.go_to_title)], UI.COLOR_ACCENT))


func _show_overlay(o: Control) -> void:
	_close_overlay()
	_overlay = o
	add_child(o)
	var first := o.find_children("*", "Button", true, false)
	if first.size() > 0:
		(first[0] as Button).grab_focus()


func _close_overlay() -> void:
	if is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
```
*(from the game)*

* **`get_tree().paused = true`** freezes every pausable node (player, enemies, bullets, timers),
  but not the HUD.
* **RESUME calls `_toggle_pause`** itself, the same code path as pressing Esc. One function, two
  triggers.
* **One overlay at a time:** `_show_overlay` closes any previous one first.
* **Focus for gamepads:** `find_children("*", "Button", true, false)` finds all buttons inside the
  dialog (pattern `*`, type `Button`, recursive, not only owned nodes). The first one **grabs
  focus**, so a gamepad or keyboard user can press A or Enter immediately and move between buttons
  with the D-pad or arrow keys. Without this, gamepad players would be stuck.
* `(first[0] as Button)`: `as` casts to the type so `grab_focus()` is type-checked.

## Lesson 11.7 — The title screen

`scenes/ui/title.tscn` is a `Control` (full rect) with `title.gd`, the **main scene**.

```gdscript
extends Control
## Title screen: a small night-street diorama made from the asset pack,
## the game title, the three bosses lined up, controls and menu buttons.

const UI := preload("res://scripts/ui/ui_kit.gd")
const TILES := preload("res://asset/Tiled/Tile1.png")


func _ready() -> void:
	Game.running = false
	_build_backdrop()
	_build_menu()
```
*(from the game)*

```gdscript
func _build_backdrop() -> void:
	var sky := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.04, 0.03, 0.1))
	grad.gradient.set_color(1, Color(0.22, 0.12, 0.25))
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	sky.texture = grad
	sky.size = Vector2(384, 216)
	add_child(sky)
	var stars := preload("res://scripts/level/stars.gd").new()
	stars.size = Vector2(384, 216)
	add_child(stars)

	# Buildings (cut straight out of the tilesheet).
	_tile_sprite(Rect2(16, 144, 128, 192), Vector2(-20, 168), Color(0.55, 0.5, 0.7))
	_tile_sprite(Rect2(192, 192, 176, 144), Vector2(250, 168), Color(0.55, 0.5, 0.7))
	# Sidewalk
	for x in 24:
		_tile_sprite(Rect2((1 + x % 4) * 16, 22 * 16, 16, 16), Vector2(x * 16, 184), Color(0.7, 0.68, 0.8))
		_tile_sprite(Rect2((1 + (x + 2) % 4) * 16, 26 * 16, 16, 16), Vector2(x * 16, 200), Color(0.7, 0.68, 0.8))

	# Hero vs the three bosses.
	_actor("res://resources/frames/player.tres", Vector2(110, 184), 2, false)
	_actor("res://resources/frames/boss_rook.tres", Vector2(215, 184), 2, true)
	_actor("res://resources/frames/boss_bonecrusher.tres", Vector2(255, 184), 2, true)
	_actor("res://resources/frames/boss_plague_doctor.tres", Vector2(295, 184), 2, true)
```
*(from the game)*

* **`preload(script).new()`** creates a node from a script directly: the star field from
  chapter 10, reused. `stars.gd` extends `Control`, so `.new()` returns a working Control.
* **Buildings tinted purple-grey** sit in the background, so the menu text stands out.
* **The sidewalk** uses `x % 4` to cycle through 4 tile variants. `(x + 2) % 4` offsets the second
  row so the pattern doesn't line up.
* **A diorama of the game:** the hero facing the three bosses tells a new player what the game is
  before they press anything.

```gdscript
func _tile_sprite(region: Rect2, bottom_left: Vector2, tint: Color) -> void:
	var s := Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = TILES
	tex.region = region
	s.texture = tex
	s.centered = false
	s.position = bottom_left - Vector2(0, region.size.y)
	s.modulate = tint
	add_child(s)


func _actor(frames_path: String, feet: Vector2, scale_factor: int, flip: bool) -> void:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = load(frames_path)
	a.scale = Vector2(scale_factor, scale_factor)
	a.position = feet - Vector2(0, 16 * scale_factor)
	a.flip_h = flip
	a.play("idle")
	a.speed_scale = randf_range(0.8, 1.2)
	add_child(a)
```
*(from the game)*

* `Sprite2D` and `AnimatedSprite2D` are `Node2D`s, but they work fine as children of a `Control`.
  They draw at their position relative to it.
* **Feet anchoring again:** `feet − (0, 16 × scale)` puts the 2× sprite's feet on the sidewalk.
* **`speed_scale = randf_range(0.8, 1.2)`**: each actor breathes at a slightly different speed.
  Perfectly synced idles look robotic, and this small change makes them feel alive.

```gdscript
func _build_menu() -> void:
	var title := UI.label("DARK CITY", 32, UI.COLOR_ACCENT)
	title.position = Vector2(0, 10)
	title.size = Vector2(384, 40)
	add_child(title)
	var sub := UI.label("one night  -  one street  -  three bosses", 8, UI.COLOR_LIGHT)
	sub.position = Vector2(0, 46)
	sub.size = Vector2(384, 12)
	add_child(sub)

	var box := VBoxContainer.new()
	box.position = Vector2(142, 66)
	box.size = Vector2(100, 40)
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var start := UI.button("START", Game.start_game)
	box.add_child(start)
	box.add_child(UI.button("QUIT", get_tree().quit))
	start.grab_focus()

	var lines := [
		"Move A/D   Jump Space   Shoot J   Grenade K   Reload R",
		"Drop down S+Space   Pause Esc   Gamepad works too",
	]
	for i in lines.size():
		var help := UI.label(lines[i], 7, UI.COLOR_LIGHT)
		add_child(help)
		help.position = Vector2(0, 190 + i * 11)
		help.size = Vector2(384, 11)
```
*(from the game)*

* **Full-width centred labels:** `size.x = 384` with centre alignment centres text on screen
  without measuring it.
* **`start.grab_focus()`:** press Enter or A immediately to play.
* **`get_tree().quit`** passed as a Callable: the QUIT button exits the game.
* **The controls are on the title screen**, so no separate help screen is needed.

Finally, set the main scene: **Project Settings → Application → Run → Main Scene =
`res://scenes/ui/title.tscn`**. Press **F5**. The whole game runs from the title screen. 🎉

---

## 🏋️ Exercises

1. ★ Change `COLOR_ACCENT` to cyan. What changes across the game?
2. ★ Show the **number of hearts** as text ("7/10") next to the hearts, updated in
   `_on_hp_changed`.
3. ★★ Make hearts **pulse** (scale 0.5 → 0.65 → 0.5 tween) when the player is at 3 HP or less.
4. ★★ Add a **"best score"**: keep `best_score` in `Game`, update it on victory or death, and show
   "BEST 012345" under the score.
5. ★★ Add a **SETTINGS** button to the title screen that opens a dialog (via `UI.dialog`) with a
   "SCREEN SHAKE: ON/OFF" toggle button. Store the setting in `Game` and respect it in
   `game_camera.gd`.
6. ★★★ Save the best score to disk with `ConfigFile` (`user://save.cfg`) so it survives quitting.
7. ★★★ Rebuild the PAUSED dialog **in the editor** as `scenes/ui/pause_menu.tscn` using a
   `Theme` resource for the button styles, and instance it from `hud.gd` instead of `UI.dialog`.
   Compare the two approaches.

## ✅ Solutions

<details><summary>Exercise 1</summary>

The title text, score, focused or hovered buttons, and the PAUSED / CITY SAVED titles all turn
cyan. One constant, consistent everywhere. That's the payoff of a palette.
</details>

<details><summary>Exercise 2</summary>

```gdscript
var _hp_label: Label
# in _build_status():
_hp_label = UI.label("", 8, UI.COLOR_TEXT, false)
_hp_label.position = Vector2(102, 4)
_hp_label.size = Vector2(30, 12)
add_child(_hp_label)
# in _on_hp_changed():
_hp_label.text = "%d/%d" % [hp, max_hp]
```
</details>

<details><summary>Exercise 3</summary>

```gdscript
var _pulse: Tween

func _on_hp_changed(hp: int, max_hp: int) -> void:
	...  # existing code
	if hp <= 3 and hp > 0 and _pulse == null:
		_pulse = create_tween().set_loops()
		for h in _hearts:
			_pulse.parallel().tween_property(h, "scale", Vector2(0.65, 0.65), 0.25)
		_pulse.tween_interval(0.0)
		for h in _hearts:
			_pulse.parallel().tween_property(h, "scale", Vector2(0.5, 0.5), 0.25)
	elif hp > 3 and _pulse:
		_pulse.kill()
		_pulse = null
		for h in _hearts:
			h.scale = Vector2(0.5, 0.5)
```
`parallel()` makes the next step run at the same time as the previous one, so all hearts animate
together.
</details>

<details><summary>Exercise 4</summary>

```gdscript
# game.gd
var best_score := 0
func record_score() -> void:
	best_score = maxi(best_score, score)

# hud.gd: call Game.record_score() in _on_player_died and in the is_final branch,
# and show "BEST %06d" % Game.best_score in a label under the score.
```
</details>

<details><summary>Exercise 5</summary>

```gdscript
# game.gd
var shake_enabled := true
func shake(strength: float = 3.0) -> void:
	if shake_enabled:
		shake_requested.emit(strength)

# title.gd
box.add_child(UI.button("SETTINGS", _open_settings))

var _settings: Control
func _open_settings() -> void:
	var toggle := UI.button(_shake_text(), func() -> void: pass)
	toggle.pressed.connect(func() -> void:
		Game.shake_enabled = not Game.shake_enabled
		toggle.text = _shake_text())
	_settings = UI.dialog("SETTINGS", "", [toggle, UI.button("BACK", func() -> void: _settings.queue_free())], UI.COLOR_ACCENT)
	add_child(_settings)
	toggle.grab_focus()

func _shake_text() -> String:
	return "SHAKE: " + ("ON" if Game.shake_enabled else "OFF")
```
Putting the check in `Game.shake` means no other file changes.
</details>

<details><summary>Exercise 6</summary>

```gdscript
const SAVE_PATH := "user://save.cfg"

func load_best() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_score = cfg.get_value("scores", "best", 0)

func save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("scores", "best", best_score)
	cfg.save(SAVE_PATH)
```
Call `load_best()` in `Game._ready()`, and `save_best()` after `record_score()`. `user://` is a
per-user writable folder (game files under `res://` are read-only in exported builds).
</details>

<details><summary>Exercise 7</summary>

There's no single answer. You'll find the editor version easier to tweak visually and to hand to
an artist, while the code version is shorter to read and easier to review in git. Many projects
use editor-built scenes for menus and code for small, dynamic HUD elements.
</details>

---

📝 **Recap**
* `Control` nodes for UI. `CanvasLayer` keeps the HUD off the camera. Containers lay out
  children.
* A preloaded script with `static func`s is a tidy helper namespace (`UI.label`, `UI.button`).
* Theme overrides + `StyleBoxFlat` + `NinePatchRect` = styled UI with no extra art.
* `Callable` parameters make generic buttons. Pass methods without `()`.
* The HUD is a pure signal listener. Redraw from state, and kill old tweens.
* Pause: `get_tree().paused` + `process_mode = ALWAYS` for the UI. `_unhandled_input` for keys.
  `grab_focus()` for gamepads.

Next: **[Chapter 12 — Game flow, testing & shipping](chapter-12-game-flow-testing-shipping.md)**
