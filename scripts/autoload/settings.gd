extends Node
## Player preferences: audio, video, controls (key + gamepad bindings) and
## the player profile (name, tag, character). Saved to user://settings.cfg.
##
## Other scripts read values with  Settings.get_value("video/rain")  and
## listen to the `changed` signal to react live, e.g. the rain turns off the
## moment you flip the option, even while the game is paused behind the menu.
## This autoload also owns the post-processing overlay (brightness, contrast,
## gamma, scanlines, vignette), the FPS counter and small "toast" popups.

signal changed(key: String)
signal bindings_changed
signal input_device_changed(using_pad: bool)

const PadInfo := preload("res://scripts/input/pad_info.gd")
const PATH := "user://settings.cfg"

## Actions the player may rebind, in menu order, with their display names.
const REBINDABLE := ["move_left", "move_right", "move_down", "jump", "shoot", "grenade", "reload", "pause"]
const ACTION_NAMES := {
	"move_left": "Move left", "move_right": "Move right", "move_down": "Down / drop",
	"jump": "Jump", "shoot": "Shoot", "grenade": "Grenade", "reload": "Reload", "pause": "Pause",
}
const KEY_SLOTS := 3   ## keyboard keys per action
const PAD_SLOTS := 2   ## gamepad inputs per action

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(768, 432), Vector2i(1152, 648), Vector2i(1536, 864), Vector2i(1920, 1080),
	Vector2i(2304, 1296), Vector2i(2688, 1512), Vector2i(3072, 1728), Vector2i(3840, 2160),
]
const WINDOW_MODES := ["Windowed", "Borderless full", "Exclusive full"]
const FPS_CAPS := [0, 30, 60, 120, 144, 240]
const RAIN_LEVELS := ["Off", "Light", "Normal", "Heavy"]
const GLYPH_STYLES := ["Auto", "Xbox", "PlayStation"]

## Playable looks. `frames` is built by tools/build_resources.gd.
const CHARACTERS := [
	{"name": "VEGA", "role": "Heavy SWAT", "frames": "res://resources/frames/player.tres"},
	{"name": "KADE", "role": "Riot officer", "frames": "res://resources/frames/player_2.tres"},
	{"name": "RIX", "role": "Night operator", "frames": "res://resources/frames/player_3.tres"},
]
const TINTS := [
	{"name": "Standard", "color": Color(1, 1, 1)},
	{"name": "Crimson", "color": Color(1.0, 0.72, 0.72)},
	{"name": "Cobalt", "color": Color(0.72, 0.82, 1.0)},
	{"name": "Toxic", "color": Color(0.78, 1.0, 0.7)},
	{"name": "Gold", "color": Color(1.0, 0.9, 0.6)},
	{"name": "Violet", "color": Color(0.9, 0.75, 1.0)},
	{"name": "Ghost", "color": Color(0.75, 0.75, 0.8)},
]

## Every preference and its default. Anything in here is saved and loaded
## automatically, so adding a new option is a one-line change.
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
## action -> {"keys": [InputEvent or null, ...], "pad": [...], "mouse": [...]}
var binds := {}
var persist := true           ## false = never write the file (developer tools)
var using_pad := false        ## was the last input from a gamepad?
var last_pad := 0             ## device id of the last gamepad used
var _default_binds := {}
var _save_timer: Timer
var _post: ColorRect
var _fps_label: Label
var _toast: Label
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.4
	_save_timer.timeout.connect(save)
	add_child(_save_timer)
	_build_overlay()

	# Remember the bindings from project.godot so "Reset" can restore them.
	for action in REBINDABLE:
		_default_binds[action] = _split_events(InputMap.action_get_events(action))
	binds = _copy_binds(_default_binds)
	load_file()
	apply_bindings()
	_apply_video()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)


func _process(_delta: float) -> void:
	if _fps_label.visible:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()


func _input(event: InputEvent) -> void:
	# Track which kind of device the player is using, for button prompts.
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


# ---------------------------------------------------------------- values

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


func reset_section(prefix: String) -> void:
	for key in DEFAULTS:
		if key.begins_with(prefix):
			set_value(key, DEFAULTS[key])


func character() -> Dictionary:
	return CHARACTERS[clampi(get_value("profile/character"), 0, CHARACTERS.size() - 1)]


func tint() -> Color:
	return TINTS[clampi(get_value("profile/tint"), 0, TINTS.size() - 1)].color


## "[SWAT] VEGA" (or just "VEGA" without a tag).
func display_name() -> String:
	var tag: String = get_value("profile/tag")
	var player_name: String = get_value("profile/name")
	return ("[%s] %s" % [tag, player_name]) if tag != "" else player_name


# ---------------------------------------------------------------- saving

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
	for action in REBINDABLE:
		var d: Variant = cfg.get_value("bindings", action, null)
		if d is Dictionary and d.has("keys") and d.has("pad"):
			binds[action]["keys"] = _fit((d["keys"] as Array).map(dict_to_event), KEY_SLOTS)
			binds[action]["pad"] = _fit((d["pad"] as Array).map(dict_to_event), PAD_SLOTS)


# ---------------------------------------------------------------- input bindings

## Rewrites the InputMap from `binds`. Gamepad events use device -1, which
## means "any controller", so every connected pad can play.
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


## Puts `event` in a slot. If another action already uses it, it is removed
## there (so one key never does two things). Returns that action's name, or "".
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


func reset_bindings(kind: String) -> void:
	for action in REBINDABLE:
		binds[action][kind] = _default_binds[action][kind].duplicate()
	apply_bindings()
	_save_timer.start()


## Human-readable name of one bound event.
func event_name(e: InputEvent) -> String:
	if e == null:
		return "---"
	if e is InputEventKey:
		var code: Key = e.keycode
		if e.physical_keycode != KEY_NONE:
			# Show the label of the user's keyboard layout (AZERTY "Q" for the
			# QWERTY "A" position). The headless server can't do this lookup.
			code = e.physical_keycode
			if DisplayServer.get_name() != "headless":
				code = DisplayServer.keyboard_get_keycode_from_physical(e.physical_keycode)
		return OS.get_keycode_string(code)
	if e is InputEventJoypadButton:
		return PadInfo.button_name(e.button_index, glyph_family())
	if e is InputEventJoypadMotion:
		return PadInfo.axis_name(e.axis, e.axis_value, glyph_family())
	if e is InputEventMouseButton:
		return ["?", "Left click", "Right click", "Middle click"][clampi(e.button_index, 0, 3)]
	return e.as_text()


## Short prompt for an action on the device the player is using right now,
## e.g. "Space" on keyboard or "Cross" on a PlayStation pad.
func action_prompt(action: String) -> String:
	var b: Dictionary = binds.get(action, {})
	if b.is_empty():
		return "?"
	for e in (b["pad"] if using_pad else b["keys"]):
		if e != null:
			return event_name(e)
	return "---"


## Which button names to show: forced by the player, or from the last pad used.
func glyph_family() -> int:
	match int(get_value("input/glyphs")):
		1:
			return PadInfo.Family.XBOX
		2:
			return PadInfo.Family.PS4
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		return PadInfo.Family.XBOX
	return PadInfo.detect(last_pad if last_pad in pads else pads[0])


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


static func dict_to_event(d: Variant) -> InputEvent:
	if not d is Dictionary:
		return null
	match d.get("t", ""):
		"key":
			var k := InputEventKey.new()
			if d.get("phys", true):
				k.physical_keycode = int(d.code)
			else:
				k.keycode = int(d.code)
			return k
		"btn":
			var b := InputEventJoypadButton.new()
			b.device = -1
			b.button_index = int(d.i)
			return b
		"axis":
			var m := InputEventJoypadMotion.new()
			m.device = -1
			m.axis = int(d.i)
			m.axis_value = float(d.v)
			return m
	return null


## Sorts the events of one action into keyboard / gamepad / mouse slots.
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


## Pads with nulls / trims an array to exactly n entries.
static func _fit(list: Array, n: int) -> Array:
	var out := list.slice(0, n)
	while out.size() < n:
		out.append(null)
	return out


static func _copy_binds(src: Dictionary) -> Dictionary:
	var out := {}
	for action in src:
		out[action] = {
			"keys": src[action]["keys"].duplicate(),
			"pad": src[action]["pad"].duplicate(),
			"mouse": src[action]["mouse"].duplicate(),
		}
	return out


# ---------------------------------------------------------------- gamepads

func _on_joy_connection_changed(device: int, connected: bool) -> void:
	if connected:
		toast("Controller connected:\n" + PadInfo.FAMILY_NAMES[PadInfo.detect(device)])
		last_pad = device
	else:
		toast("Controller disconnected")
	bindings_changed.emit()   # button names in menus may change


## Rumble on the pad being used. weak/strong are 0..1 motor speeds.
func rumble(weak: float, strong: float, seconds: float) -> void:
	var k: float = get_value("input/vibration") / 100.0
	if k <= 0.0 or not using_pad:
		return
	Input.start_joy_vibration(last_pad, clampf(weak * k, 0, 1), clampf(strong * k, 0, 1), seconds)


# ---------------------------------------------------------------- video

func available_resolutions() -> Array[Vector2i]:
	if DisplayServer.get_name() == "headless":
		return RESOLUTIONS
	var screen := DisplayServer.screen_get_size(DisplayServer.window_get_current_screen())
	var out: Array[Vector2i] = []
	for r in RESOLUTIONS:
		if r.x <= screen.x and r.y <= screen.y:
			out.append(r)
	return out if not out.is_empty() else RESOLUTIONS.slice(0, 1)


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


func _resize_window() -> void:
	var list := available_resolutions()
	var size := RESOLUTIONS[clampi(get_value("video/resolution"), 0, RESOLUTIONS.size() - 1)]
	if not size in list:
		size = list[list.size() - 1]
	DisplayServer.window_set_size(size)
	var screen := DisplayServer.window_get_current_screen()
	var area := DisplayServer.screen_get_usable_rect(screen)
	DisplayServer.window_set_position(area.position + (area.size - size) / 2)


# ---------------------------------------------------------------- overlay

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

	_fps_label = Label.new()
	_fps_label.position = Vector2(2, 204)
	_fps_label.add_theme_font_size_override("font_size", 8)
	_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps_label.add_theme_constant_override("outline_size", 3)
	_fps_label.visible = false
	layer.add_child(_fps_label)

	_toast = Label.new()
	_toast.position = Vector2(184, 36)
	_toast.size = Vector2(196, 24)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_toast.add_theme_font_size_override("font_size", 8)
	_toast.add_theme_color_override("font_color", Color(1.0, 0.72, 0.2))
	_toast.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	_toast.add_theme_constant_override("outline_size", 3)
	_toast.modulate.a = 0.0
	layer.add_child(_toast)


func _update_post() -> void:
	var b: float = get_value("video/brightness") / 100.0
	var c: float = get_value("video/contrast") / 100.0
	var g: float = get_value("video/gamma") / 100.0
	var scan: bool = get_value("video/scanlines")
	var vig: bool = get_value("video/vignette")
	var mat := _post.material as ShaderMaterial
	mat.set_shader_parameter("brightness", b)
	mat.set_shader_parameter("contrast", c)
	mat.set_shader_parameter("gamma", g)
	mat.set_shader_parameter("scanlines", 0.25 if scan else 0.0)
	mat.set_shader_parameter("vignette", 0.6 if vig else 0.0)
	# Skip the full-screen pass entirely when it would change nothing.
	_post.visible = not (is_equal_approx(b, 1) and is_equal_approx(c, 1) and is_equal_approx(g, 1)
			and not scan and not vig)


## Small notification in the top-right corner (works in every scene).
func toast(text: String, seconds: float = 2.5) -> void:
	_toast.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5)
