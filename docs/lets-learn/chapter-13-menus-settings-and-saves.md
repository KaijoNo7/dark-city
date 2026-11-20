# Chapter 13 — Menus, settings, controllers & save games

🎯 **Goals**
* Build a **settings system**: one dictionary of defaults, live updates through a signal, a file in
  `user://` written with `ConfigFile`.
* Apply **video settings** in code: window mode, window size, pixel-perfect scaling, V-Sync, FPS
  cap, and a **post-processing shader** for brightness, contrast and gamma.
* Let players **rebind keys and gamepad buttons**, store bindings safely and rewrite the
  `InputMap` at runtime.
* **Detect controllers** (Xbox, PlayStation 2/3/4/5, Switch) and show the right button names.
* Write a reusable **settings row widget** that works with mouse, keyboard and gamepad.
* Build the **SETTINGS window**: tabs, focus, `Esc` handling and input capture.
* **Save and load** a run with JSON, plus a **CUSTOMIZE** screen for name, tag and character.

This chapter adds about 1,500 lines across eight files. Don't try to type them all in one go.
Each lesson ends with something you can run.

---

## Lesson 13.1 — The plan

Before this chapter, the title screen had two buttons and the pause dialog had three. Here is what
we're adding, and where each piece lives:

| Need | Where | Why there |
|---|---|---|
| Preferences that exist before any scene and survive scene changes | `scripts/autoload/settings.gd` (autoload `Settings`) | An autoload lives as long as the game |
| A save slot reachable from the title, the pause menu and the boss arenas | `scripts/autoload/save_game.gd` (autoload `SaveGame`) | Same |
| Brand detection for gamepads | `scripts/input/pad_info.gd` | Pure functions, so a static library like `ui_kit.gd` |
| One menu row = one option | `scripts/ui/setting_row.gd` | Reused ~40 times |
| The SETTINGS window | `scripts/ui/options_menu.gd` | Opened from the title *and* the pause menu |
| The CUSTOMIZE window | `scripts/ui/customize_menu.gd` | Title only |

Register the two new autoloads in **Project → Project Settings → Globals → Autoload**, in this
order (Audio comes in chapter 14):

```ini
[autoload]
Settings="*res://scripts/autoload/settings.gd"
Audio="*res://scripts/autoload/audio.gd"
SaveGame="*res://scripts/autoload/save_game.gd"
Game="*res://scripts/autoload/game.gd"
```

### 🔤 Autoload order
Godot creates autoloads **top to bottom**, and each one's `_ready()` runs as soon as it is added.
When `Audio._ready()` runs, `Settings` already exists, but `Game` doesn't yet. Rule of thumb: put
a service *above* everything that uses it in `_ready()`. Using another autoload later, in a
function called during play, is always fine.

---

## Lesson 13.2 — `Settings`: one dictionary to rule them all

The core idea: **every preference is one entry in a dictionary**, and everything else (saving,
loading, resetting, menu rows) loops over that dictionary.

```gdscript
extends Node

signal changed(key: String)
signal bindings_changed
signal input_device_changed(using_pad: bool)

const PadInfo := preload("res://scripts/input/pad_info.gd")
const PATH := "user://settings.cfg"
```
*(from the game)*

* **`signal changed(key: String)`**: emitted every time a preference changes. Rain, volumes, the
  hero sprite on the title screen: everything listens to this one signal and checks the key.
* **`user://`** is Godot's per-user writable folder. `res://` (the game files) is read-only in an
  exported game, so user data must go to `user://`.

```gdscript
const DEFAULTS := {
	"audio/master": 80, "audio/music": 70, "audio/sfx": 80, "audio/ambience": 60, "audio/ui": 70,
	"video/window_mode": 0, "video/resolution": 1, "video/vsync": true, "video/fps_cap": 0,
	"video/pixel_perfect": true, "video/brightness": 100, "video/contrast": 100, "video/gamma": 100,
	"video/rain": 2, "video/lightning": true, "video/screen_shake": 100, "video/scanlines": false,
	"video/vignette": false, "video/show_fps": false, "video/intro": true,
	"input/deadzone": 20, "input/vibration": 70, "input/glyphs": 0,
	"profile/name": "VEGA", "profile/tag": "SWAT", "profile/character": 0, "profile/tint": 0,
	"profile/show_tag": true,
}

var values := DEFAULTS.duplicate()
```
*(from the game)*

* Keys look like `"section/name"`. The part before `/` becomes the `[section]` in the file. The
  slash is just a naming convention that we split later.
* **Percentages are stored as integers** (`80`, not `0.8`). Integers compare exactly
  (`80 == 80`), print nicely, and match what the slider shows.
* **Choices are stored as indexes** (`"video/rain": 2` means `RAIN_LEVELS[2]`, "Normal").
* `values` starts as a **copy** of the defaults. `duplicate()` matters. Without it `values` *is*
  `DEFAULTS` (same object), and a constant dictionary is read-only, so the first write would fail.

### Reading and writing

```gdscript
func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	if values.get(key) == value:
		return
	values[key] = value
	if key.begins_with("video/"):
		_apply_video()
	elif key == "input/deadzone":
		apply_bindings()
	changed.emit(key)
	_save_timer.start()   # save shortly after the last change, not on every slider tick
```
*(from the game)*

Line by line:

1. `values.get(key, DEFAULTS.get(key))`: `Dictionary.get(key, fallback)` never errors on a
   missing key. If someone asks for a key that isn't in `values`, we answer with the default.
2. `if values.get(key) == value: return`: **early exit when nothing changes.** Without it,
   re-selecting the same option would re-apply the window size and rewrite the file for nothing.
3. `values[key] = value`: store it.
4. `begins_with("video/")`: video settings must be *applied* (the window resized and so on). Other
   systems apply their own settings by listening to `changed`.
5. `changed.emit(key)`: tell everyone.
6. `_save_timer.start()`: the **debounce** trick, explained next.

### 🔤 Debouncing with a one-shot Timer
Dragging a slider from 0 to 100 calls `set_value` 20 times in a second. Writing the file 20 times
is wasteful. Instead:

```gdscript
_save_timer = Timer.new()
_save_timer.one_shot = true
_save_timer.wait_time = 0.4
_save_timer.timeout.connect(save)
add_child(_save_timer)
```
*(from the game, in `_ready()`)*

Calling `start()` on a running timer **restarts it from 0.4 s**. So the file is written once, 0.4 s
after the *last* change. This pattern is called *debouncing*, and it's useful any time an event
fires in bursts (search-as-you-type, window resizing…).

### Saving with `ConfigFile`

```gdscript
func save() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	for key in values:
		var parts: PackedStringArray = key.split("/")
		cfg.set_value(parts[0], parts[1], values[key])
	for action in binds:
		cfg.set_value("bindings", action, {
			"keys": binds[action]["keys"].map(event_to_dict),
			"pad": binds[action]["pad"].map(event_to_dict),
		})
	cfg.save(PATH)
```
*(from the game)*

* `if not persist: return`: developer tools set `persist = false` so tests never overwrite your
  real settings (lesson 13.12).
* `key.split("/")` turns `"video/rain"` into `["video", "rain"]`, so `cfg.set_value("video",
  "rain", 2)` writes:
  ```ini
  [video]
  rain=2
  ```
* Bindings are saved in their own `[bindings]` section (lesson 13.5 explains `event_to_dict`).
* `Array.map(callable)` returns a new array with the function applied to each element.

```gdscript
func load_file() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in DEFAULTS:
		var parts: PackedStringArray = key.split("/")
		var v: Variant = cfg.get_value(parts[0], parts[1], DEFAULTS[key])
		# Ignore values of the wrong type (e.g. a hand-edited file).
		if typeof(v) == typeof(DEFAULTS[key]):
			values[key] = v
	...
```
*(from the game)*

* `cfg.load(PATH) != OK`: first launch, there is no file, so keep the defaults.
* **We loop over `DEFAULTS`, not over the file.** Old keys left in the file are ignored, and new
  options added in an update get their defaults.
* `typeof(v) == typeof(DEFAULTS[key])`: if someone typed `rain="lots"` into the file, we ignore it
  instead of crashing later on `RAIN_LEVELS["lots"]`. **Never trust a file a user can edit.**

### 🔤 `ConfigFile` or JSON?
| | `ConfigFile` | JSON |
|---|---|---|
| Looks like | INI: `[section]` + `key=value` | `{"key": value}` |
| Godot types (Vector2, Color…) | yes | no (numbers, strings, arrays, dicts only) |
| Ints stay ints | yes | no: every number comes back as a float |
| Best for | settings | data exchanged with other programs, or simple saves |

We use `ConfigFile` for settings and JSON for the save file (lesson 13.10), so you see both.

### 🧪 Try it
Add `print(Settings.get_value("audio/music"))` to any `_ready()`. Run, change the music volume in
the menu (once it exists), quit, run again: the new value is printed. Open the file at
`~/.local/share/godot/app_userdata/Dark city/settings.cfg` (Linux) or
`%APPDATA%\Godot\app_userdata\Dark city\settings.cfg` (Windows) in a text editor.

---

## Lesson 13.3 — Applying video settings

```gdscript
func _apply_video() -> void:
	var root := get_tree().root
	root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER if get_value("video/pixel_perfect") \
			else Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	Engine.max_fps = FPS_CAPS[clampi(get_value("video/fps_cap"), 0, FPS_CAPS.size() - 1)]
	_update_post()
	_fps_label.visible = get_value("video/show_fps")
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("video/vsync")
			else DisplayServer.VSYNC_DISABLED)
	match int(get_value("video/window_mode")):
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			_resize_window.call_deferred()
```
*(from the game)*

* **`content_scale_stretch`** is the runtime version of the project setting
  `window/stretch/scale_mode` from chapter 3. *Integer* keeps every game pixel the same size (crisp,
  but maybe black borders). *Fractional* fills the window (some pixels a bit wider than others).
  Giving players the choice is kind.
* `\` at the end of a line continues the statement on the next line. Inside `(...)` you don't need
  it, as the V-Sync line shows.
* **`Engine.max_fps = 0`** means unlimited. `FPS_CAPS = [0, 30, 60, 120, 144, 240]`.
* **`clampi(index, 0, size - 1)`** protects array access from a bad saved index.
* **Headless guard:** the playtest bot runs with `--headless`, where there is no window. Window
  calls would print errors, so we stop early.
* **Godot's two fullscreens:** `WINDOW_MODE_FULLSCREEN` is a borderless window covering the
  screen (fast alt-tab). `EXCLUSIVE_FULLSCREEN` takes over the display (can be slightly faster,
  slower to alt-tab).
* **`call_deferred`** on the resize: right after switching from fullscreen to windowed, some
  window managers ignore a size change made in the same frame. Waiting until the end of the frame
  is more reliable.

```gdscript
func _resize_window() -> void:
	var list := available_resolutions()
	var size := RESOLUTIONS[clampi(get_value("video/resolution"), 0, RESOLUTIONS.size() - 1)]
	if not size in list:
		size = list[list.size() - 1]
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)
```
*(from the game)*

* `RESOLUTIONS` are all **16:9 multiples of 384 × 216** (×2, ×3 … ×10), so integer scaling never
  needs black bars in a window.
* `available_resolutions()` filters out sizes bigger than the monitor. If the saved size doesn't
  fit (new, smaller monitor), we take the biggest one that does.
* **Centring:** `screen_get_usable_rect` is the screen minus taskbars. Position =
  top-left + (free space ÷ 2).

### The post-processing shader

Brightness can't be done by tinting nodes: the HUD, menus and particles would all need it. Instead
we draw one rectangle **over everything** that re-colours what's already on screen.

```gdscript
func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 128   # above everything, including the HUD and menus
	add_child(layer)
	_post = ColorRect.new()
	_post.set_anchors_preset(Control.PRESET_FULL_RECT)
	_post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_post.material = ShaderMaterial.new()
	_post.material.shader = preload("res://scripts/ui/post_process.gdshader")
	layer.add_child(_post)
	...
```
*(from the game)*

* **Layer 128** is the highest a `CanvasLayer` can be, so it draws after the world (0), rain (5),
  HUD (10) and menus.
* **`MOUSE_FILTER_IGNORE`** lets clicks pass through. Without it, this invisible rectangle would
  swallow every mouse click in the game.

```glsl
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float brightness = 1.0;
uniform float contrast = 1.0;
uniform float gamma = 1.0;
uniform float scanlines = 0.0;
uniform float vignette = 0.0;

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	c = (c - 0.5) * contrast + 0.5;
	c *= brightness;
	c = pow(max(c, vec3(0.0)), vec3(1.0 / gamma));
	if (fract(SCREEN_UV.y * 216.0) > 0.5) {
		c *= 1.0 - scanlines;
	}
	vec2 d = SCREEN_UV - 0.5;
	c *= 1.0 - vignette * dot(d, d) * 1.6;
	COLOR = vec4(c, 1.0);
}
```
*(from the game: `scripts/ui/post_process.gdshader`)*

* **`hint_screen_texture`** gives the shader a copy of everything drawn so far. `SCREEN_UV` is this
  pixel's position on screen (0–1).
* **Contrast:** move each colour away from mid-grey (0.5) by a factor. 1.2 = punchier, 0.8 = flatter.
* **Brightness:** multiply.
* **Gamma:** `pow(c, 1/gamma)`. Gamma 1.2 lifts dark tones a lot and bright tones barely, which is
  exactly what "I can't see in the dark areas" needs. `max(c, 0)` avoids `pow` of a negative
  number (undefined).
* **Scanlines:** `SCREEN_UV.y * 216` is the row in *game* pixels. `fract(...) > 0.5` is true for the
  bottom half of every game pixel, which gets darkened.
* **Vignette:** `dot(d, d)` is the squared distance from the centre: 0 in the middle, 0.5 in the
  corners.

```gdscript
	_post.visible = not (is_equal_approx(b, 1) and is_equal_approx(c, 1) and is_equal_approx(g, 1)
			and not scan and not vig)
```
*(from the game, end of `_update_post()`)*

A full-screen shader isn't free. With neutral settings it would change nothing, so we hide it.
`is_equal_approx` compares floats safely (`100 / 100.0` might not be *exactly* 1.0 after
arithmetic).

### 🧪 Try it
Set brightness to 150 % and turn scanlines on. Then set gamma to 50 % and look at the dark
alleys. That's why games ship a gamma slider.

---

## Lesson 13.4 — Controllers: which brand is this?

Godot reads gamepads through SDL's controller database. For any pad in that database, button 0
is *always* the bottom face button, whether it's labelled **A** (Xbox) or **✕ Cross**
(PlayStation). So bindings are the same for every known pad. What changes is the **name printed on
the button**, and that's what we need for menus.

`scripts/input/pad_info.gd` is a static library:

```gdscript
extends RefCounted

enum Family { GENERIC, XBOX, PS2, PS3, PS4, PS5, SWITCH }

const VID_SONY := 0x054C
const VID_MICROSOFT := 0x045E
const PID_PS3 := [0x0268]
const PID_PS4 := [0x05C4, 0x09CC, 0x0BA0]
const PID_PS5 := [0x0CE6, 0x0DF2]
const VID_PS2_ADAPTERS := [0x0810, 0x0925]
const PS2_WORDS := ["ps2", "playstation 2", "playstation(r)2", "playstation®2", "twin usb",
	"dual usb", "psx", "wisegroup", "ps1/ps2", "ps/ps2"]
```
*(from the game)*

* **`enum Family`** gives readable names to the numbers 0–6. `Family.PS4` reads better than `4`.
* **USB IDs:** every USB device reports a **vendor ID** (who made it: `0x054C` is Sony) and a
  **product ID** (which model: `0x05C4` is the first DualShock 4). `0x` means hexadecimal.
* **PS2 pads have no USB.** You plug them into an adapter, and the computer sees *the adapter*.
  Common adapter chips call themselves "Twin USB Joystick" or "WiseGroup", which is why we check
  names as well as IDs.

```gdscript
static func detect(device: int) -> int:
	var name := Input.get_joy_name(device).to_lower()
	var info := Input.get_joy_info(device)
	var vid := _to_int(info.get("vendor_id", 0))
	var pid := _to_int(info.get("product_id", 0))
	# PS2 adapters first: some of them report Sony-like names.
	for w in PS2_WORDS:
		if w in name:
			return Family.PS2
	if vid in VID_PS2_ADAPTERS:
		return Family.PS2
	if vid == VID_SONY:
		if pid in PID_PS3:
			return Family.PS3
		if pid in PID_PS5:
			return Family.PS5
		return Family.PS4
	...
	return Family.GENERIC
```
*(from the game)*

* `Input.get_joy_name(device)`: e.g. `"PS4 Controller"`, `"Xbox Series X Controller"`.
  `.to_lower()` so `"PS4"` and `"ps4"` both match.
* `Input.get_joy_info(device)`: a dictionary with `vendor_id` and `product_id` on desktop
  platforms. Some platforms give numbers, some give strings, so `_to_int()` handles both:
  ```gdscript
  static func _to_int(v: Variant) -> int:
  	if v is int:
  		return v
  	if v is String:
  		return (v as String).to_int()
  	return 0
  ```
* **Order matters.** The most specific test goes first (PS2 adapters), the vaguest last
  (generic).
* `"ps2" in name`: for strings, `in` means "contains".
* Sony + unknown product → PS4: it's the most common Sony pad, and PS4/PS5 share button names.

### Button names

```gdscript
const XBOX_BUTTONS := ["A", "B", "X", "Y", "View", "Xbox", "Menu", "LS", "RS", "LB", "RB",
	"D-Up", "D-Down", "D-Left", "D-Right", "Share"]
const PS4_BUTTONS := ["Cross", "Circle", "Square", "Triangle", "Share", "PS", "Options", "L3", "R3",
	"L1", "R1", "D-Up", "D-Down", "D-Left", "D-Right", "Mic"]
const PS_CLASSIC_BUTTONS := ["Cross", "Circle", "Square", "Triangle", "Select", "PS", "Start", "L3", "R3",
	"L1", "R1", "D-Up", "D-Down", "D-Left", "D-Right", "Analog"]

static func button_name(index: int, family: int) -> String:
	var names: Array = XBOX_BUTTONS
	if family in [Family.PS4, Family.PS5]:
		names = PS4_BUTTONS
	elif family in [Family.PS2, Family.PS3]:
		names = PS_CLASSIC_BUTTONS
	elif family == Family.SWITCH:
		names = SWITCH_BUTTONS
	elif family == Family.GENERIC:
		return "Button %d" % index
	...
	if index >= 0 and index < names.size():
		return names[index]
	return "Button %d" % index
```
*(from the game)*

The array **index is the SDL button number**, so `XBOX_BUTTONS[0]` is "A" and
`PS4_BUTTONS[0]` is "Cross". PS2/PS3 call buttons 4 and 6 *Select* and *Start*; PS4/PS5 call them
*Share* and *Options*. That's the only difference, and it's why there are two PlayStation lists.
For an unknown brand we say "Button 7" rather than guess wrong.

`axis_name()` works the same way for sticks and triggers: axis 0 with a negative value is
"L-Stick Left", axis 4 is "LT" on Xbox and "L2" on PlayStation.

### 🔤 `Input.is_joy_known(device)`
`true` if SDL has a mapping for this pad, so its buttons follow the standard layout. Many PS2
adapters aren't in the database. Their buttons arrive as raw numbers in whatever order the
adapter's chip uses. We can't fix that by guessing, so instead we **let the player teach us**:
the guided set-up in lesson 13.8 asks for each action's button in turn. Whatever number arrives
becomes the binding.

---

## Lesson 13.5 — Rebindable input

### The data

```gdscript
## action -> {"keys": [InputEvent or null, ...], "pad": [...], "mouse": [...]}
var binds := {}
```
*(from the game)*

Each action has **fixed-size slot arrays**: 3 keyboard slots and 2 gamepad slots. `null` is an
empty slot. Fixed sizes make the menu simple: slot 2 is always the third box in the row.

### Capturing the defaults

```gdscript
	for action in REBINDABLE:
		_default_binds[action] = _split_events(InputMap.action_get_events(action))
	binds = _copy_binds(_default_binds)
	load_file()
	apply_bindings()
```
*(from the game, `_ready()`)*

When `Settings._ready()` runs, the `InputMap` still holds the bindings from `project.godot`.
We copy them once as the **factory defaults** (for RESET), then load the player's saved bindings
over them.

```gdscript
func _split_events(events: Array[InputEvent]) -> Dictionary:
	var keys := []
	var pad := []
	var mouse := []
	for e in events:
		if e is InputEventKey:
			keys.append(e)
		elif e is InputEventJoypadButton or e is InputEventJoypadMotion:
			var copy: InputEvent = e.duplicate()
			copy.device = -1
			pad.append(copy)
		elif e is InputEventMouseButton:
			mouse.append(e)
	return {"keys": _fit(keys, KEY_SLOTS), "pad": _fit(pad, PAD_SLOTS), "mouse": mouse}
```
*(from the game)*

* **`is`** checks the class of an object.
* **`copy.device = -1`**: the project's events say `device 0` (the first pad). **−1 means "all
  devices"**, so a second pad, or a pad that reconnects with a new id, still works.
  `duplicate()` first, so we don't modify the `InputMap`'s own event object.
* Mouse events (left click = shoot) are kept but not offered for rebinding.

```gdscript
static func _fit(list: Array, n: int) -> Array:
	var out := list.slice(0, n)
	while out.size() < n:
		out.append(null)
	return out
```
*(from the game)*

`slice(0, n)` keeps at most `n` items. Then we pad with `null` up to exactly `n`.

### Rewriting the `InputMap`

```gdscript
func apply_bindings() -> void:
	var deadzone: float = get_value("input/deadzone") / 100.0
	for action in REBINDABLE:
		InputMap.action_erase_events(action)
		InputMap.action_set_deadzone(action, maxf(deadzone, 0.05))
		var b: Dictionary = binds[action]
		for e in b["keys"] + b["pad"] + b["mouse"]:
			if e != null:
				InputMap.action_add_event(action, e)
	bindings_changed.emit()
```
*(from the game)*

* `action_erase_events` empties the action, and then we add back everything from our slots.
  Simple and always correct: no need to work out what changed.
* `b["keys"] + b["pad"] + b["mouse"]`: `+` on arrays concatenates them.
* **The player script never changed.** It still calls `Input.is_action_pressed("jump")`. That's
  the payoff of using actions from chapter 3.

### 🔤 Why `b["keys"]` and not `b.keys`?
GDScript lets you read dictionary entries with a dot: `d.name` means `d["name"]`. But `keys` is
also a **method** of `Dictionary` (`d.keys()` lists the keys), and so are `size`, `values`,
`has`… Writing `b.keys` is at best confusing and at worst refers to the method. **Use brackets
when a key could clash with a method name.** This file uses brackets for all three slot lists to
stay consistent.

### Rebinding one slot

```gdscript
func rebind(action: String, kind: String, slot: int, event: InputEvent) -> String:
	var stolen_from := ""
	if event != null:
		var wanted: Variant = event_to_dict(event)
		for other in REBINDABLE:
			var list: Array = binds[other][kind]
			for i in list.size():
				if list[i] != null and event_to_dict(list[i]) == wanted and not (other == action and i == slot):
					list[i] = null
					if other != action:
						stolen_from = other
	binds[action][kind][slot] = event
	apply_bindings()
	_save_timer.start()
	return stolen_from
```
*(from the game)*

* **Conflict rule:** if *L* is bound to Jump and you bind *L* to Shoot, it's removed from Jump.
  Otherwise one key would fire two actions.
* **How do we compare two events?** `InputEvent` objects aren't equal just because they describe
  the same key (they're different objects). We convert both to small dictionaries and compare
  those. **Dictionaries compare by content**: `{"t": "key", "code": 76} == {"t": "key", "code":
  76}` is `true`.
* `var list: Array = binds[other][kind]` is a **reference** to the array inside `binds`, so
  `list[i] = null` changes `binds`. Arrays and dictionaries are passed by reference in GDScript.
* We return which action lost the key, so the menu can say *"L was removed from JUMP"*.

### Storing events in a file

```gdscript
static func event_to_dict(e: Variant) -> Variant:
	if e is InputEventKey:
		if e.physical_keycode != KEY_NONE:
			return {"t": "key", "code": int(e.physical_keycode), "phys": true}
		return {"t": "key", "code": int(e.keycode), "phys": false}
	if e is InputEventJoypadButton:
		return {"t": "btn", "i": e.button_index}
	if e is InputEventJoypadMotion:
		return {"t": "axis", "i": e.axis, "v": signf(e.axis_value)}
	return null
```
*(from the game)*

* **Physical vs logical keys:** `physical_keycode` is the key's *position* (the key where W is on
  a US keyboard). `keycode` is the *letter printed on it*. Physical is right for games: WASD stays
  a triangle of keys on a French AZERTY keyboard (where those keys read ZQSD).
* **Axes:** `signf(axis_value)` keeps only the direction (−1 or +1). "Left stick pushed left" is
  axis 0, value −1.
* `dict_to_event()` does the reverse, creating fresh `InputEvent` objects with `device = -1`.

### Showing names

```gdscript
func event_name(e: InputEvent) -> String:
	if e == null:
		return "---"
	if e is InputEventKey:
		var code: Key = e.keycode
		if e.physical_keycode != KEY_NONE:
			code = e.physical_keycode
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
		return OS.get_keycode_string(code)
	if e is InputEventJoypadButton:
		return PadInfo.button_name(e.button_index, glyph_family())
	...
```
*(from the game)*

`keyboard_get_keycode_from_physical` asks the OS what the key in that position is labelled *on
this user's keyboard layout*. A French player sees "Z" for the forward key, not "W".
`OS.get_keycode_string` turns the code into text ("Space", "Left", "J").

---

## Lesson 13.6 — Following the player's hands

When the player picks up a gamepad, prompts should switch from "Jump Space" to "Jump Cross".

```gdscript
func _input(event: InputEvent) -> void:
	var pad := false
	if event is InputEventJoypadButton and event.pressed:
		pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.5:
		pad = true
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseButton and event.pressed):
		pad = false
	else:
		return
	if pad:
		last_pad = event.device
	if pad != using_pad:
		using_pad = pad
		input_device_changed.emit(pad)
```
*(from the game)*

* `_input` sees **every** event before anyone else, which is ideal for watching (we never mark the
  event handled, so it still reaches the game).
* `absf(axis_value) > 0.5`: sticks send a stream of tiny values when resting. Only a real push
  counts.
* Mouse **motion** hits the `else: return`. Otherwise nudging the mouse while playing on a pad
  would flip the prompts back and forth.
* We only emit when the type **changes**, not on every button press.

```gdscript
func action_prompt(action: String) -> String:
	var b: Dictionary = binds.get(action, {})
	if b.is_empty():
		return "?"
	for e in (b["pad"] if using_pad else b["keys"]):
		if e != null:
			return event_name(e)
	return "---"
```
*(from the game)*

The title footer builds its help line with this. It updates on `input_device_changed` and when the
focus moves.

### Vibration

```gdscript
func rumble(weak: float, strong: float, seconds: float) -> void:
	var k: float = get_value("input/vibration") / 100.0
	if k <= 0.0 or not using_pad:
		return
	Input.start_joy_vibration(last_pad, clampf(weak * k, 0, 1), clampf(strong * k, 0, 1), seconds)
```
*(from the game)*

Most pads have two motors: a small fast "weak" one (buzz) and a big slow "strong" one (thud).
`player.gd` calls `Settings.rumble(0.5, 0.8, 0.25)` when hit; explosions use `(0.7, 0.9, 0.3)`.

### Connection toasts

```gdscript
func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		toast("Controller connected:\n" + PadInfo.FAMILY_NAMES[PadInfo.detect(device)])
		last_pad = device
	else:
		toast("Controller disconnected")
	bindings_changed.emit()   # button names in menus may change
```
*(from the game)*

`toast()` fades a gold label in the top-right corner on the layer-128 overlay. It works in every
scene, paused or not, because `Settings` has `process_mode = PROCESS_MODE_ALWAYS`.

---

## Lesson 13.7 — `SettingRow`: one widget, every device

A settings menu has ~40 options. We need one widget that can be a **slider**, a **choice** or a
**toggle**, and that works with a mouse, a keyboard and any gamepad.

The trick: **make the whole row a single `Button`**. Godot's focus system already moves between
buttons with up/down. We just catch left/right to change the value.

```gdscript
class_name SettingRow
extends Button

signal value_changed(value: Variant)

enum Kind { SLIDER, CHOICE, TOGGLE }

const UI := preload("res://scripts/ui/ui_kit.gd")

var kind := Kind.SLIDER
var key := ""
var choices: Array = []
var min_value := 0
var max_value := 100
var step := 5
var suffix := "%"
var value: Variant = 0
```
*(from the game)*

### 🔤 Static factory functions

```gdscript
static func slider(text: String, settings_key: String, lo: int = 0, hi: int = 100, inc: int = 5,
		unit: String = "%") -> Button:
	var r := SettingRow.new()
	r.kind = Kind.SLIDER
	r.min_value = lo
	r.max_value = hi
	r.step = inc
	r.suffix = unit
	r._setup(text, settings_key)
	return r
```
*(from the game)*

A `static func` belongs to the class, not to an instance, so you call it as
`SettingRow.slider("Music", "audio/music")`. Inside, `SettingRow.new()` creates the instance.
That's why this script has a `class_name`: the class must refer to itself by name. A factory
reads better than "new, then set five properties" at every call site:

```gdscript
_list.add_child(SettingRow.slider("Brightness", "video/brightness", 50, 150))
_list.add_child(SettingRow.toggle("V-Sync", "video/vsync"))
_list.add_child(SettingRow.choice("Rain", "video/rain", Settings.RAIN_LEVELS))
```

### Building the row

```gdscript
func _setup(text_: String, settings_key: String) -> void:
	key = settings_key
	custom_minimum_size = Vector2(0, 13)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	focus_mode = Control.FOCUS_ALL
	var clear := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", clear)
	add_theme_stylebox_override("pressed", clear)
	add_theme_stylebox_override("disabled", clear)
	add_theme_stylebox_override("hover", _highlight(0.18))
	add_theme_stylebox_override("focus", _highlight(0.4))
```
*(from the game)*

* `SIZE_EXPAND_FILL`: stretch across the list's full width.
* **Styleboxes:** the row is invisible until hovered (18 % gold) or focused (40 % gold). Button
  draws the `focus` box *on top of* the normal/hover box.

```gdscript
	_name_label = UI.label(text_, 8, UI.COLOR_TEXT, false)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.anchor_right = 0.55
	_name_label.anchor_bottom = 1.0
	_name_label.offset_left = 4
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_value_label = UI.label("", 8, UI.COLOR_TEXT, false)
	_value_label.anchor_left = 0.8 if kind == Kind.SLIDER else 0.55
	_value_label.anchor_right = 1.0
	_value_label.anchor_bottom = 1.0
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_value_label)
```
*(from the game)*

* **Anchors as fractions:** the name takes the left 55 % of the row. The value takes the rest, or
  only the last 20 % for sliders, which draw a bar in between.
* **`MOUSE_FILTER_IGNORE` on the labels** is essential. Labels on top of a button would otherwise
  catch the clicks and the button would never be pressed.

```gdscript
	if key != "":
		value = Settings.get_value(key)
	pressed.connect(func() -> void: change(1))
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	UI.add_sounds(self)
	_refresh()
```
*(from the game)*

Clicking (or pressing Enter / Cross on) a row moves to the next value, and focus changes redraw
the `< >` arrows.

### Left and right

```gdscript
func _gui_input(event: InputEvent) -> void:
	if disabled:
		return
	if event.is_action_pressed("ui_left", true):
		change(-1)
		accept_event()
	elif event.is_action_pressed("ui_right", true):
		change(1)
		accept_event()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			change(-1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and kind == Kind.SLIDER and _bar_rect().grow(2).has_point(event.position):
			var t := clampf((event.position.x - _bar_rect().position.x) / _bar_rect().size.x, 0.0, 1.0)
			set_value(int(round(lerpf(min_value, max_value, t) / step)) * step)
			accept_event()
```
*(from the game)*

* **`_gui_input`** receives input only while this control has focus (or the mouse is over it).
* **`is_action_pressed("ui_left", true)`**: the second argument allows *echo* events, so holding
  the arrow keeps changing the value, like a real slider. `ui_left` is Godot's built-in action:
  ← key, d-pad left and left stick left are all included.
* **`accept_event()`** marks the event used. Without it, Godot's focus system would *also* move
  the focus to a neighbour on the left.
* **Click on the bar:** `inverse` of the drawing maths. Position in the bar (0–1) → `lerpf` to the
  range → round to the nearest step.

```gdscript
func change(direction: int) -> void:
	if disabled:
		return
	match kind:
		Kind.SLIDER:
			set_value(clampi(int(value) + direction * step, min_value, max_value))
		Kind.CHOICE:
			set_value(wrapi(int(value) + direction, 0, choices.size()))
		Kind.TOGGLE:
			set_value(not bool(value))
	Audio.ui("ui_move")


func set_value(v: Variant) -> void:
	if v == value:
		return
	value = v
	if key != "":
		Settings.set_value(key, v)
	_refresh()
	value_changed.emit(v)
```
*(from the game)*

* **`clampi`** stops sliders at their ends. **`wrapi`** makes choices loop: right on the last
  choice goes back to the first.
* `set_value` writes through to `Settings`, which applies, saves and broadcasts `changed`. The row
  doesn't know or care what the setting does.

```gdscript
func _draw() -> void:
	if kind != Kind.SLIDER:
		return
	var r := _bar_rect()
	var t := inverse_lerp(min_value, max_value, float(value))
	draw_rect(r, Color(UI.COLOR_TEXT, 0.25))
	draw_rect(Rect2(r.position, Vector2(r.size.x * t, r.size.y)), Color(0.85, 0.45, 0.12))
	draw_rect(r, UI.COLOR_TEXT, false, 1.0)
```
*(from the game)*

`_draw` (chapter 10) draws on top of the button. `inverse_lerp(a, b, v)` is the opposite of `lerp`:
where `v` sits between `a` and `b`, as 0–1. Three rectangles: the track, the fill, and an
outline (`false` = not filled, `1.0` = line width). `_refresh()` calls `queue_redraw()`.

---

## Lesson 13.8 — The SETTINGS window

`options_menu.gd` is a `Control` with **no scene file**. The title does
`add_child(OptionsMenu.new())`; the HUD does the same while paused.

### Tabs that rebuild the list

```gdscript
func _show_tab(index: int) -> void:
	_tab = index
	_stop_listening()
	for i in _tab_buttons.size():
		_tab_buttons[i].modulate = Color.WHITE if i == index else Color(0.75, 0.7, 0.7)
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	match index:
		0:
			_build_audio()
		1:
			_build_video()
		2:
			_build_keyboard()
		3:
			_build_gamepad()
	_scroll.scroll_vertical = 0
	_link_focus()
	_update_hint()
	var first := _first_focusable()
	if first:
		UI.focus_quietly(first)
```
*(from the game)*

* Instead of four hidden panels, we **destroy and rebuild** the list. It's only a few dozen nodes,
  and every value is fresh (e.g. after a RESET).
* **`remove_child` before `queue_free`:** `queue_free` deletes at the end of the frame. Until then
  the old rows would still be in the container and `_first_focusable()` would find them. Removing
  them first avoids that.
* The list sits in a **`ScrollContainer` with `follow_focus = true`**: moving the focus to a row
  below the edge scrolls it into view automatically. That's what makes long tabs usable on a
  gamepad.

```gdscript
func _build_audio() -> void:
	_header("VOLUME")
	_list.add_child(SettingRow.slider("Master", "audio/master"))
	_list.add_child(SettingRow.slider("Music", "audio/music"))
	_list.add_child(SettingRow.slider("Sound effects", "audio/sfx"))
	_list.add_child(SettingRow.slider("Ambience (rain, thunder)", "audio/ambience"))
	_list.add_child(SettingRow.slider("Menu sounds", "audio/ui"))
	...
```
*(from the game)*

This is the payoff of lessons 13.2 and 13.7: a whole tab is a list of one-liners.

### Explicit focus neighbours

```gdscript
func _link_focus() -> void:
	var first := _first_focusable()
	...
	for b in _tab_buttons:
		b.focus_neighbor_bottom = first.get_path()
	first.focus_neighbor_top = _tab_buttons[_tab].get_path()
	var last: Control = focusables[focusables.size() - 1]
	last.focus_neighbor_bottom = _back.get_path()
	_back.focus_neighbor_top = last.get_path()
```
*(from the game)*

Godot guesses focus neighbours from positions on screen, which usually works. Around a
`ScrollContainer` the guesses can skip rows or get stuck. Setting `focus_neighbor_*` (as
`NodePath`s) makes "down from the tabs" and "down from the last row" go exactly where we want.

### Closing with Esc / B / Circle

```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if not _listening.is_empty():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		Audio.ui("ui_back")
		close()
		get_viewport().set_input_as_handled()
	elif _is_tab_switch(event, -1):
		...
```
*(from the game)*

### 🔤 The three input callbacks, in order
For each event Godot calls, in this order:

| Callback | Who gets it | Use it for |
|---|---|---|
| `_input(event)` | every node, **before the GUI** | capturing everything (rebinding), watching (device tracking) |
| `_gui_input(event)` | the focused / hovered `Control` | widget behaviour (left/right on a row) |
| `_unhandled_input(event)` | every node, if nobody handled it yet | game controls, "back" in menus |

Within `_input` and `_unhandled_input`, **deeper and later nodes go first**. The settings window
is a child of the HUD, so its `_unhandled_input` runs before the HUD's. It closes itself and calls
`set_input_as_handled()`, so the HUD never sees that `Esc` and the game stays paused. Remove that
line and pressing `Esc` closes the settings *and* un-pauses the game in one press.

### Capturing a new binding

Each binding box is a `Button` tagged with metadata:

```gdscript
		var b := UI.button("", func() -> void: pass)
		b.set_meta("bind", [action, kind, slot])
		b.pressed.connect(_start_listening.bind(action, kind, slot, b))
```
*(from the game, `_bind_row()`)*

* `set_meta(name, value)` attaches any data to any object. Later,
  `b.get_meta("bind")` tells us which slot this box edits.
* `.bind(...)` (chapter 6) pre-fills the callback's arguments.

```gdscript
func _start_listening(action: String, kind: String, slot: int, button: Button) -> void:
	_stop_listening()
	_listening = {"action": action, "kind": kind, "slot": slot, "button": button}
	_listen_time = LISTEN_TIMEOUT
	_ignore_until = Time.get_ticks_msec() + 250   # ignore the press that started this
	button.text = "..."
	button.grab_focus()
	var what := "key" if kind == "keys" else "button / stick / trigger"
	_hint.text = "Press a %s for  %s\nEsc: cancel   Delete: clear" % [what, Settings.ACTION_NAMES[action].to_upper()]
```
*(from the game)*

* **`_ignore_until`:** you pressed Enter (or Cross) to start listening. That press's *release*, or
  a key repeat, could arrive a moment later and be captured as the new binding. Ignoring input for
  250 ms prevents it.
* `_listen_time` counts down in `_process`. After 6 s with no input, listening stops (useful if a
  gamepad player starts listening for a *key* by mistake).

```gdscript
func _input(event: InputEvent) -> void:
	if _listening.is_empty():
		return
	get_viewport().set_input_as_handled()   # nothing else sees input while listening
	if Time.get_ticks_msec() < _ignore_until:
		return
	var kind: String = _listening.kind
	if event is InputEventKey and event.pressed and not event.echo:
		var code: Key = event.keycode
		if code == KEY_ESCAPE:
			_wizard.clear()
			_wizard_active = false
			Audio.ui("ui_back")
			_stop_listening()
		elif code == KEY_DELETE or code == KEY_BACKSPACE:
			_assign(null)
		elif kind == "keys":
			var k := InputEventKey.new()
			k.physical_keycode = event.physical_keycode
			if event.physical_keycode == KEY_NONE:
				k.keycode = event.keycode
			_assign(k)
	elif kind == "pad" and event is InputEventJoypadButton and event.pressed:
		var b := InputEventJoypadButton.new()
		b.device = -1
		b.button_index = event.button_index
		_assign(b)
	elif kind == "pad" and event is InputEventJoypadMotion and absf(event.axis_value) > 0.6:
		var m := InputEventJoypadMotion.new()
		m.device = -1
		m.axis = event.axis
		m.axis_value = signf(event.axis_value)
		_assign(m)
```
*(from the game)*

* **`_input` + `set_input_as_handled()` on everything**: while listening, the focused button must
  not react to Enter, the HUD must not react to Esc, and nothing else may see the event.
* **`not event.echo`**: holding a key sends repeat events. We only want the first press.
* **A clean event:** we don't store the incoming event itself (it carries the device id, modifier
  state, pressed flag…). We build a fresh one with only what matters.
* **Axes need a threshold** (0.6) so a resting stick doesn't bind itself.

### The guided controller set-up

```gdscript
func _start_wizard() -> void:
	_wizard.assign(Settings.REBINDABLE)
	_wizard_active = true
	_next_wizard_step()


func _next_wizard_step() -> void:
	if _wizard.is_empty():
		_wizard_active = false
		_hint.text = "Controller set up!"
		Audio.ui("ui_select")
		return
	var action: String = _wizard.pop_front()
	...
	if button:
		_start_listening(action, "pad", 0, button)
```
*(from the game)*

A **queue**: `pop_front()` takes the next action, and listening starts on its first pad slot. When
`_assign()` finishes, it waits 0.35 s and calls `_next_wizard_step()` again:

```gdscript
	if _wizard_active:
		await get_tree().create_timer(0.35, true, false, true).timeout
		if is_inside_tree() and _wizard_active:
			_next_wizard_step()
```
*(from the game, end of `_assign()`)*

* `create_timer(0.35, true, false, true)`: the 2nd argument (`process_always`) lets the timer run
  while the game is paused, since this menu also opens from the pause menu. The 4th
  (`ignore_time_scale`) makes it ignore hit-stop slow-motion.
* `is_inside_tree()` after an `await`: the player might have closed the menu during those 0.35 s.
  **Always re-check the world after an `await`.**

This is how a PS2 adapter with scrambled button numbers gets fixed: the game no longer cares
*which* number arrives, only that it arrived when we asked for "JUMP".

---

## Lesson 13.9 — Save games

### What to save

A save is a **snapshot of a few numbers**, not of the scene:

```gdscript
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"player_name": Settings.display_name(),
		"character": Settings.get_value("profile/character"),
		"score": Game.score,
		"run_time": Game.run_time,
		"bosses_defeated": Game.bosses_defeated,
		"hp": player.hp,
		"grenades": player.grenades,
		"x": player.safe_position.x,
		"y": player.safe_position.y,
	}
```
*(from the game, `SaveGame.save_now()`)*

* **`version`**: if the format changes one day, old files can be detected and ignored instead of
  being misread.
* `get_datetime_string_from_system(false, true)`: local time (`false` = not UTC), with a space
  instead of the `T` (`true`), e.g. `2026-11-20 21:04:10`.
* **`safe_position`**: not where the player *is*, but where they last stood on the floor:
  ```gdscript
  func _track_ground(delta: float) -> void:
  	if is_on_floor():
  		if _air_time > 0.25:
  			Audio.sfx("land", global_position)
  		_air_time = 0.0
  		safe_position = global_position
  	else:
  		_air_time += delta
  ```
  *(from the game, `player.gd`)*. Save in mid-jump over a pit and you'd reload… falling into the
  pit. Saving the last solid ground fixes that for free.

### Writing JSON

```gdscript
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true
```
*(from the game)*

* `FileAccess.open` returns `null` on failure (disk full, no permission). **Check it.**
* `JSON.stringify(data, "\t")` indents with tabs, so the file is readable in a text editor.

### Reading defensively

```gdscript
func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		return {}   # missing, corrupted or from an incompatible version
	return data
```
*(from the game)*

`JSON.parse_string` returns `null` for broken text. Checking `data is Dictionary` covers broken
files, files containing a bare number, and so on. Every caller only ever sees "a valid save" or
`{}`. **JSON numbers come back as floats**, which is why loading code wraps values in `int(...)`.

### When saving is refused

```gdscript
func cannot_save_reason() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not Game.running:
		return "Nothing to save"
	if player.dead:
		return "Can't save while dead"
	if Game.in_boss_fight:
		return "Can't save during a boss fight"
	return ""
```
*(from the game)*

Returning a **reason string** instead of a `bool` gives one function two uses: the pause menu
disables SAVE GAME when the string isn't empty, and shows the string as the dialog's info text.
`Game.in_boss_fight` is set to `true` by `boss_arena.gd` when its walls close, and back to `false`
when its boss dies.

### Loading: two steps across a scene change

Loading has a problem: we must change scene (to the level), and changing scene frees everything,
including the code that wanted to restore the player. The solution is to **park the data in an
autoload**:

```gdscript
# game.gd
func continue_game() -> bool:
	var data := SaveGame.read()
	if data.is_empty():
		return false
	score = int(data.get("score", 0))
	bosses_defeated = int(data.get("bosses_defeated", 0))
	run_time = float(data.get("run_time", 0.0))
	SaveGame.pending = data
	loaded_from_save = true
	_enter_level()
	return true
```

```gdscript
# level.gd, _ready()
	if Game.loaded_from_save:
		SaveGame.apply_pending(self)
```
*(from the game)*

`SaveGame.pending` survives the scene change because `SaveGame` is an autoload. When the new level
is ready, it picks the data up.

```gdscript
func apply_pending(level: Node) -> void:
	if pending.is_empty():
		return
	var d := pending
	pending = {}
	var player := get_tree().get_first_node_in_group("player")
	var pos := Vector2(float(d.get("x", player.global_position.x)), float(d.get("y", player.global_position.y)))
	player.global_position = pos
	player.safe_position = pos
	player.hp = clampi(int(d.get("hp", player.max_hp)), 1, player.max_hp)
	player.grenades = clampi(int(d.get("grenades", player.max_grenades)), 0, player.max_grenades)
	player.camera.reset_smoothing()
	for i in Game.bosses_defeated:
		var arena := level.get_node_or_null("BossArena%d" % (i + 1))
		if arena:
			arena.mark_cleared()
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.x < pos.x - 48.0:
			e.queue_free()
	...
	player._emit_stats.call_deferred()
```
*(from the game)*

* `pending = {}` right away, so the data can never be applied twice.
* **`clampi(hp, 1, max_hp)`**: a hand-edited save can't give 999 HP or start you dead.
* **`reset_smoothing()`**: otherwise the camera would glide from the level start to the save point.
* **`for i in Game.bosses_defeated`** loops 0 … N−1. Arenas are named `BossArena1..3`, hence `i + 1`.
  `mark_cleared()` sets the arena's `_triggered = true`, so walking in does nothing, and opens its
  walls.
* Enemies more than 48 px behind the save point are removed (you already passed them). Those
  ahead come back, like a checkpoint in most games.
* `_emit_stats.call_deferred()`: the HUD must show the restored HP and grenades. Deferred, so the
  HUD has finished its own `_ready()`.

### Autosave

```gdscript
		Game.message("AREA CLEAR\nGO  >>>", 2.5)
		Audio.play_music("street", 2.0)
		if SaveGame.save_now():
			Settings.toast("Autosaved")
```
*(from the game, `boss_arena.gd`)*

After a boss (except the last), the arena is open and `in_boss_fight` is `false` again, so
`save_now()` succeeds. Each arena becomes a checkpoint.

### 🧪 Try it
Run `godot --headless --fixed-fps 60 res://tools/playtest.tscn -- save`. The bot walks, saves,
checks that saving is refused mid-fight, loads, and compares. Then open the playtest's save file
(`playtest_save.json` in the user folder) in a text editor.

---

## Lesson 13.10 — The pause menu grows up

```gdscript
func _show_pause_menu(focus_index: int = 0) -> void:
	var buttons: Array[Button] = [
		UI.button("RESUME", _toggle_pause),
		UI.button("SAVE GAME", _save),
		UI.button("LOAD GAME", _confirm_load),
		UI.button("SETTINGS", _open_settings),
		UI.button("RESTART", Game.restart_level),
		UI.button("QUIT TO TITLE", Game.go_to_title),
	]
	var reason := SaveGame.cannot_save_reason()
	if reason != "":
		buttons[1].disabled = true
		buttons[1].focus_mode = Control.FOCUS_NONE
	if not SaveGame.has_save():
		buttons[2].disabled = true
		buttons[2].focus_mode = Control.FOCUS_NONE
	_show_overlay(UI.dialog("PAUSED", reason, buttons, UI.COLOR_ACCENT))
	if focus_index > 0 and buttons[focus_index].focus_mode != Control.FOCUS_NONE:
		UI.focus_quietly(buttons[focus_index])
```
*(from the game, `hud.gd`)*

* **Disabled *and* `FOCUS_NONE`:** a disabled button can still receive keyboard focus, so the
  cursor could land on something that does nothing. Removing focus makes up/down skip it.
* **`focus_index`**: after closing SETTINGS we rebuild the pause menu with the focus back on
  SETTINGS (index 3), not on RESUME. Small, but it's what makes a menu feel right.

```gdscript
func _open_settings() -> void:
	_close_overlay()
	_submenu = OptionsMenu.new()
	add_child(_submenu)
	_submenu.closed.connect(func() -> void:
		_submenu = null
		_show_pause_menu(3))
```
*(from the game)*

The settings window is a **child of the HUD**. The HUD has `process_mode = ALWAYS`, and children
inherit it, so the window works while the tree is paused.

```gdscript
func _toggle_pause() -> void:
	if get_tree().paused:
		get_tree().paused = false
		Audio.set_muffled(false)
		Audio.ui("pause_out")
		_close_overlay()
	else:
		get_tree().paused = true
		Audio.set_muffled(true)   # music goes "behind a wall" while paused
		Audio.ui("pause_in")
		_show_pause_menu()
```
*(from the game)*

---

## Lesson 13.11 — CUSTOMIZE: name, tag and character

### More characters from the same pipeline

The art pack has three officers. Chapter 4's tool already turns a folder of sheets into
`SpriteFrames`, so two lines add the other two:

```gdscript
	build_character("player", "res://asset/Characters/Character_1")
	# Alternative looks for the character-customisation screen.
	build_character("player_2", "res://asset/Characters/Character_2")
	build_character("player_3", "res://asset/Characters/Character_3")
```
*(from the game, `tools/build_resources.gd`)*

All three have the animations the player uses (`idle`, `walk`, `shot`, `walk_shot`, `recharge`,
`cast`, `hurt`, `dead`), so `player.gd` can swap them freely:

```gdscript
const CHARACTERS := [
	{"name": "VEGA", "role": "Heavy SWAT", "frames": "res://resources/frames/player.tres"},
	{"name": "KADE", "role": "Riot officer", "frames": "res://resources/frames/player_2.tres"},
	{"name": "RIX", "role": "Night operator", "frames": "res://resources/frames/player_3.tres"},
]
```
*(from the game, `settings.gd`)*

### Applying the look

```gdscript
func _apply_look() -> void:
	var frames: SpriteFrames = load(Settings.character().frames)
	if frames:
		sprite.sprite_frames = frames
		sprite.play("idle")
	sprite.self_modulate = Settings.tint()
	if Settings.get_value("profile/show_tag"):
		_name_tag = Label.new()
		_name_tag.text = Settings.get_value("profile/name")
		...
		_name_tag.position = Vector2(-40, -42)
		add_child(_name_tag)
```
*(from the game, `player.gd`)*

### 🔤 `modulate` vs `self_modulate`
| | Affects | Used here for |
|---|---|---|
| `modulate` | the node **and all its children** | flashes, fades (other code animates it) |
| `self_modulate` | **only this node** | the colour tint |

Enemies flash white with `sprite.modulate = Color(4, 4, 4)`. If the tint also used `modulate`,
every flash would erase it. Using two separate channels means they never fight: the final colour
is `modulate × self_modulate`.

### The text fields

```gdscript
	e.text_changed.connect(func(t: String) -> void:
		var caret := e.caret_column
		var clean := t.to_upper().replace("[", "").replace("]", "")
		if clean != t:
			e.text = clean
			e.caret_column = caret
		Settings.set_value(key, clean.strip_edges())
		_refresh_preview())
```
*(from the game, `customize_menu.gd`)*

* **Capitals everywhere** (the HUD font style), and no brackets, because the tag is *displayed*
  as `[TAG]`.
* Setting `e.text` moves the caret to the end, which is annoying mid-word. We remember the column
  and restore it.
* **Gamepad players can't type**, so RANDOM CALLSIGN builds a name from two word lists:
  `NAME_PARTS_A.pick_random() + NAME_PARTS_B.pick_random()` gives "NIGHTWOLF", "NEONVIPER"…

### Never an empty name

```gdscript
func close() -> void:
	if String(Settings.get_value("profile/name")).strip_edges() == "":
		Settings.set_value("profile/name", Settings.character().name)
	closed.emit()
	queue_free()
```
*(from the game)*

---

## Lesson 13.12 — Keeping developer tools away from real data

The playtest bot saves the game and changes settings. Run it on the machine where you play and
it would overwrite your save. Two small switches prevent that:

```gdscript
# settings.gd
var persist := true           ## false = never write the file (developer tools)

# save_game.gd
var path := PATH

# tools/playtest.gd, _ready()
	SaveGame.path = "user://playtest_save.json"
	SaveGame.delete()
	Settings.persist = false
```
*(from the game)*

`PATH` stays a `const` (the real location). `path` is a `var` that starts equal to it and can be
redirected. A tiny design choice, but it's exactly what separates "tests I can run anywhere" from
"tests that wreck my save".

---

## 🏋️ Exercises

1. ★ Add a **"Hold to auto-fire"** toggle (`"input/auto_fire": true`). When off, `shoot` fires
   once per press.
2. ★ Add **"Colourblind-friendly bullets"**: when on, enemy bullets are blue instead of red.
3. ★★ Give the save system **three slots**. CONTINUE loads the newest one; LOAD GAME shows the
   three summaries.
4. ★★ Add a **language** choice with English and one other language, using a dictionary of
   strings and a `tr()`-like helper.
5. ★★ The settings window shows *Window size* even in fullscreen (disabled). Instead, hide the row
   completely in fullscreen, and make sure the focus still flows correctly.
6. ★★★ Save **which enemies are dead** so they stay dead after loading. (Hint: give every enemy
   in the level a stable id: its node path.)
7. ★★★ Add a **"Reset to defaults?"** confirmation dialog before each RESET button.

## ✅ Solutions

<details><summary>Exercise 1</summary>

```gdscript
# settings.gd DEFAULTS
"input/auto_fire": true,

# options_menu.gd, _build_keyboard()
_list.add_child(SettingRow.toggle("Hold to auto-fire", "input/auto_fire"))

# player.gd, _handle_combat()
var fire_pressed := Input.is_action_pressed("shoot") if Settings.get_value("input/auto_fire") \
		else Input.is_action_just_pressed("shoot")
if fire_pressed and _fire_timer <= 0.0 and _reload_timer <= 0.0 and _cast_timer <= 0.0:
	...
```
</details>

<details><summary>Exercise 2</summary>

```gdscript
# settings.gd DEFAULTS
"video/cb_bullets": false,

# enemy_base.gd, shoot_bullet()
var cb: bool = Settings.get_value("video/cb_bullets")
b.modulate = Color(0.4, 0.7, 1.0) if cb else Color(1.0, 0.45, 0.4)
b.spark_color = Color(0.3, 0.6, 1.0) if cb else Color(1.0, 0.4, 0.3)
```
</details>

<details><summary>Exercise 3</summary>

```gdscript
# save_game.gd
const SLOTS := 3
func slot_path(i: int) -> String:
	return "user://savegame_%d.json" % i

func newest_slot() -> int:
	var best := -1
	var best_time := ""
	for i in SLOTS:
		path = slot_path(i)
		var d := read()
		if not d.is_empty() and str(d.saved_at) > best_time:
			best_time = str(d.saved_at)
			best = i
	return best
```
`saved_at` strings like `2026-11-20 21:04:10` sort correctly as text, because the biggest unit
comes first. Set `SaveGame.path = slot_path(i)` before `save_now()` / `continue_game()`.
</details>

<details><summary>Exercise 4</summary>

```gdscript
# settings.gd
const STRINGS := {
	"fr": {"NEW GAME": "NOUVELLE PARTIE", "SETTINGS": "OPTIONS", "QUIT": "QUITTER"},
}
func t(text: String) -> String:
	var lang: String = ["en", "fr"][get_value("profile/lang")]
	return STRINGS.get(lang, {}).get(text, text)

# title.gd
var b := UI.button(Settings.t(item[0]), item[1])
```
Godot also has a full system for this (**Project Settings → Localization**, `TranslationServer`,
CSV files and the built-in `tr()`). This exercise shows the idea underneath it.
</details>

<details><summary>Exercise 5</summary>

```gdscript
func _update_resolution_row() -> void:
	if is_instance_valid(_resolution_row):
		_resolution_row.visible = int(Settings.get_value("video/window_mode")) == 0
		_link_focus.call_deferred()
```
Hidden controls never receive focus, so Godot's neighbour search skips them. Re-linking after the
change keeps the explicit top/bottom neighbours valid.
</details>

<details><summary>Exercise 6</summary>

```gdscript
# save_game.gd, save_now()
var dead := []
for e in get_tree().get_nodes_in_group("enemies"):
	if e.dead and not "boss_name" in e:
		dead.append(str(level.get_path_to(e)))
data["dead_enemies"] = dead
```
(Pass the level in, or get it with `get_tree().current_scene`.) Enemies that died earlier have been
freed, so also keep a list in `Game` that `enemy_base.gd` appends to in `die()`, and save that
list. In `apply_pending`, `level.get_node_or_null(path)` and `queue_free()` each one found.
</details>

<details><summary>Exercise 7</summary>

```gdscript
func _confirm(text: String, on_yes: Callable) -> void:
	var dlg: Control
	var yes := UI.button("RESET", func() -> void:
		dlg.queue_free()
		on_yes.call())
	var no := UI.button("CANCEL", func() -> void: dlg.queue_free())
	dlg = UI.dialog("ARE YOU SURE?", text, [yes, no], UI.COLOR_DANGER)
	add_child(dlg)
	UI.focus_quietly(no)   # the safe choice gets the focus
```
Then `_action_button("RESET AUDIO", _confirm.bind("Audio back to defaults?", func(): ...))`.
</details>

## 📝 Recap

* **One dictionary of defaults** drives saving, loading, resetting and the menu. Adding an option
  is two lines.
* **A `changed(key)` signal** lets every system react live without the menu knowing about them.
* **Debounce** bursts of changes with a restarting one-shot `Timer`.
* **`ConfigFile`** for settings, **JSON** for the save, and both read *defensively*: check types,
  versions and ranges.
* **`InputMap` can be rewritten at runtime**, and gameplay code using actions never changes.
  Store events as small dictionaries; compare them as dictionaries.
* **Gamepads share one standard layout.** Only the *names* differ by brand; detect the brand from
  the name and the USB vendor/product IDs. Unknown pads get a guided set-up.
* **One focusable control per row**, with left/right in `_gui_input`, gives menus that work with
  every device.
* **Input order:** `_input` (capture) → `_gui_input` (widgets) → `_unhandled_input` (game, back).
  Children before parents. `set_input_as_handled()` stops the chain.
* **Park data in an autoload** to carry it across a scene change.

Next: **[Chapter 14 — Audio](chapter-14-audio.md)**.
