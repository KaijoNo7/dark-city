extends Control
## The SETTINGS window, used from the title screen and from the pause menu.
## Four tabs: AUDIO, VIDEO, CONTROLS (keyboard) and GAMEPAD.
## Everything is applied immediately and saved automatically by Settings.
##
## Rebinding: press a binding button, then press the new key/button. While
## "listening", _input() grabs every event before the GUI sees it.

signal closed

const UI := preload("res://scripts/ui/ui_kit.gd")
const PadInfo := preload("res://scripts/input/pad_info.gd")
const TABS := ["AUDIO", "VIDEO", "CONTROLS", "GAMEPAD"]
const LISTEN_TIMEOUT := 6.0

var _tab := 0
var _tab_buttons: Array[Button] = []
var _scroll: ScrollContainer
var _list: VBoxContainer
var _hint: Label
var _back: Button
var _resolution_row: SettingRow
## While capturing a new binding: {action, kind, slot, button}
var _listening := {}
var _listen_time := 0.0
var _ignore_until := 0
var _wizard: Array[String] = []   ## actions left in the guided gamepad set-up
var _wizard_active := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := UI.panel(Vector2(368, 206))
	panel.position = Vector2(8, 5)
	add_child(panel)

	var title := UI.label("SETTINGS", 16, UI.COLOR_ACCENT)
	title.position = Vector2(0, 2)
	title.size = Vector2(368, 22)
	panel.add_child(title)

	var tabs := HBoxContainer.new()
	tabs.position = Vector2(10, 24)
	tabs.size = Vector2(348, 14)
	tabs.add_theme_constant_override("separation", 4)
	panel.add_child(tabs)
	for i in TABS.size():
		var b := UI.button(TABS[i], _show_tab.bind(i))
		b.custom_minimum_size = Vector2(84, 14)
		tabs.add_child(b)
		_tab_buttons.append(b)

	_scroll = ScrollContainer.new()
	_scroll.position = Vector2(10, 41)
	_scroll.size = Vector2(348, 137)
	_scroll.follow_focus = true
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 1)
	_scroll.add_child(_list)

	_hint = UI.label("", 8, UI.COLOR_TEXT, false)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_hint.position = Vector2(12, 180)
	_hint.size = Vector2(270, 18)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	_hint.add_theme_constant_override("line_spacing", -3)
	panel.add_child(_hint)
	_back = UI.button("BACK", close)
	_back.custom_minimum_size = Vector2(70, 14)
	_back.position = Vector2(288, 186)
	panel.add_child(_back)

	Settings.bindings_changed.connect(_on_bindings_changed)
	Settings.input_device_changed.connect(func(_p: bool) -> void: _update_hint())
	_show_tab(0)


func close() -> void:
	_stop_listening()
	closed.emit()
	queue_free()


# ---------------------------------------------------------------- tabs

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


func _link_focus() -> void:
	# Tabs -> first row, last row -> BACK, so up/down never gets stuck.
	var first := _first_focusable()
	var focusables := _list.find_children("*", "BaseButton", true, false).filter(
		func(c: Control) -> bool: return c.focus_mode != Control.FOCUS_NONE)
	if first == null:
		return
	for b in _tab_buttons:
		b.focus_neighbor_bottom = first.get_path()
	first.focus_neighbor_top = _tab_buttons[_tab].get_path()
	var last: Control = focusables[focusables.size() - 1]
	last.focus_neighbor_bottom = _back.get_path()
	_back.focus_neighbor_top = last.get_path()


func _first_focusable() -> Control:
	for c in _list.find_children("*", "BaseButton", true, false):
		if c.focus_mode != Control.FOCUS_NONE:
			return c
	return null


func _unhandled_input(event: InputEvent) -> void:
	if not _listening.is_empty():
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		Audio.ui("ui_back")
		close()
		get_viewport().set_input_as_handled()
	elif _is_tab_switch(event, -1):
		_show_tab(wrapi(_tab - 1, 0, TABS.size()))
		get_viewport().set_input_as_handled()
	elif _is_tab_switch(event, 1):
		_show_tab(wrapi(_tab + 1, 0, TABS.size()))
		get_viewport().set_input_as_handled()


## Shoulder buttons, Q/E or Page Up/Down switch tabs.
func _is_tab_switch(event: InputEvent, direction: int) -> bool:
	if event is InputEventJoypadButton and event.pressed:
		return event.button_index == (JOY_BUTTON_LEFT_SHOULDER if direction < 0 else JOY_BUTTON_RIGHT_SHOULDER)
	if event is InputEventKey and event.pressed and not event.echo:
		var keys := [KEY_Q, KEY_PAGEUP] if direction < 0 else [KEY_E, KEY_PAGEDOWN]
		return event.keycode in keys
	return false


func _update_hint() -> void:
	if not _listening.is_empty():
		return
	var fam := Settings.glyph_family()
	if Settings.using_pad:
		_hint.text = "D-pad: select  Left/Right: change\n%s/%s: tabs   %s: back" % [
			PadInfo.button_name(JOY_BUTTON_LEFT_SHOULDER, fam), PadInfo.button_name(JOY_BUTTON_RIGHT_SHOULDER, fam),
			PadInfo.button_name(JOY_BUTTON_B, fam)]
	else:
		_hint.text = "Arrows: select / change   Q/E: tabs\nEsc: back   (mouse: click / right-click)"


# ---------------------------------------------------------------- helpers

func _header(text: String) -> void:
	var l := UI.label(text, 8, Color(0.55, 0.25, 0.1), false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(0, 12)
	_list.add_child(l)


func _note(text: String) -> void:
	var l := UI.label(text, 8, Color(0.35, 0.28, 0.26), false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.custom_minimum_size = Vector2(340, 0)
	l.add_theme_constant_override("line_spacing", -3)
	_list.add_child(l)


func _action_button(text: String, on_pressed: Callable) -> Button:
	var b := UI.button(text, on_pressed)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(160, 14)
	_list.add_child(b)
	return b


# ---------------------------------------------------------------- AUDIO

func _build_audio() -> void:
	_header("VOLUME")
	_list.add_child(SettingRow.slider("Master", "audio/master"))
	_list.add_child(SettingRow.slider("Music", "audio/music"))
	_list.add_child(SettingRow.slider("Sound effects", "audio/sfx"))
	_list.add_child(SettingRow.slider("Ambience (rain, thunder)", "audio/ambience"))
	_list.add_child(SettingRow.slider("Menu sounds", "audio/ui"))
	_note("Music is original. Sound effects: \"512 Sound Effects\" by Juhani Junkala (CC0).")
	_action_button("RESET AUDIO", func() -> void:
		Settings.reset_section("audio/")
		_show_tab(0))


# ---------------------------------------------------------------- VIDEO

func _build_video() -> void:
	_header("DISPLAY")
	var mode := SettingRow.choice("Window mode", "video/window_mode", Settings.WINDOW_MODES)
	_list.add_child(mode)
	var labels := []
	for r in Settings.available_resolutions():
		labels.append("%d x %d" % [r.x, r.y])
	_resolution_row = SettingRow.choice("Window size", "video/resolution", labels)
	_resolution_row.value = clampi(int(Settings.get_value("video/resolution")), 0, labels.size() - 1)
	_resolution_row._refresh()
	_list.add_child(_resolution_row)
	mode.value_changed.connect(func(_v: Variant) -> void: _update_resolution_row())
	_update_resolution_row()
	_list.add_child(SettingRow.toggle("Pixel-perfect scaling", "video/pixel_perfect"))
	_list.add_child(SettingRow.toggle("V-Sync", "video/vsync"))
	var caps := ["Unlimited"]
	for f in Settings.FPS_CAPS.slice(1):
		caps.append(str(f))
	_list.add_child(SettingRow.choice("Frame rate limit", "video/fps_cap", caps))
	_list.add_child(SettingRow.toggle("Show FPS", "video/show_fps"))

	_header("PICTURE")
	_list.add_child(SettingRow.slider("Brightness", "video/brightness", 50, 150))
	_list.add_child(SettingRow.slider("Contrast", "video/contrast", 50, 150))
	_list.add_child(SettingRow.slider("Gamma", "video/gamma", 50, 150))
	_list.add_child(SettingRow.toggle("Scanlines (CRT look)", "video/scanlines"))
	_list.add_child(SettingRow.toggle("Vignette", "video/vignette"))

	_header("EFFECTS")
	_list.add_child(SettingRow.choice("Rain", "video/rain", Settings.RAIN_LEVELS))
	_list.add_child(SettingRow.toggle("Lightning flashes", "video/lightning"))
	_list.add_child(SettingRow.slider("Screen shake", "video/screen_shake", 0, 100, 10))
	_list.add_child(SettingRow.toggle("Play intro at start", "video/intro"))
	_action_button("RESET VIDEO", func() -> void:
		Settings.reset_section("video/")
		_show_tab(1))


func _update_resolution_row() -> void:
	if is_instance_valid(_resolution_row):
		_resolution_row.set_row_disabled(int(Settings.get_value("video/window_mode")) != 0)


# ---------------------------------------------------------------- CONTROLS

func _build_keyboard() -> void:
	_header("KEYBOARD                      KEY 1          KEY 2          KEY 3")
	for action in Settings.REBINDABLE:
		_bind_row(action, "keys", Settings.KEY_SLOTS)
	_note("Mouse: left click = Shoot, right click = Grenade. Press a box, then the new key. "
		+ "Esc cancels, Delete/Backspace clears. A key used elsewhere moves here.")
	_action_button("RESET KEYBOARD", func() -> void:
		Settings.reset_bindings("keys")
		_show_tab(2))


func _bind_row(action: String, kind: String, slots: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 3)
	var name_label := UI.label(Settings.ACTION_NAMES[action], 8, UI.COLOR_TEXT, false)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.custom_minimum_size = Vector2(92, 14)
	row.add_child(name_label)
	var width := (340.0 - 92.0) / slots - 4.0
	for slot in slots:
		var b := UI.button("", func() -> void: pass)
		b.custom_minimum_size = Vector2(width, 14)
		b.clip_text = true
		b.set_meta("bind", [action, kind, slot])
		b.pressed.connect(_start_listening.bind(action, kind, slot, b))
		row.add_child(b)
	_list.add_child(row)
	_refresh_bind_row(row)


func _refresh_bind_row(row: Node) -> void:
	for b in row.get_children():
		if b is Button and b.has_meta("bind"):
			var m: Array = b.get_meta("bind")
			b.text = Settings.event_name(Settings.binds[m[0]][m[1]][m[2]])


func _on_bindings_changed() -> void:
	for b in _list.find_children("*", "Button", true, false):
		if b.has_meta("bind") and b != _listening.get("button"):
			var m: Array = b.get_meta("bind")
			b.text = Settings.event_name(Settings.binds[m[0]][m[1]][m[2]])


# ---------------------------------------------------------------- GAMEPAD

func _build_gamepad() -> void:
	_header("CONNECTED CONTROLLERS")
	var pads := Input.get_connected_joypads()
	if pads.is_empty():
		_note("No controller detected. Plug in (or pair) an Xbox, PlayStation 2/3/4/5 or any "
			+ "USB / Bluetooth gamepad - it is picked up automatically.")
	for d in pads:
		_note("#%d  %s" % [d, PadInfo.describe(d)])
	_header("OPTIONS")
	_list.add_child(SettingRow.choice("Button names", "input/glyphs", Settings.GLYPH_STYLES))
	_list.add_child(SettingRow.slider("Stick dead zone", "input/deadzone", 5, 60))
	_list.add_child(SettingRow.slider("Vibration", "input/vibration", 0, 100, 10))
	var test := _action_button("TEST VIBRATION", func() -> void:
		var k: float = Settings.get_value("input/vibration") / 100.0
		for d in Input.get_connected_joypads():
			Input.start_joy_vibration(d, 0.6 * k, 1.0 * k, 0.5))
	test.disabled = pads.is_empty()
	_action_button("SET UP CONTROLLER (GUIDED)", _start_wizard)
	_header("GAMEPAD BUTTONS               BUTTON 1               BUTTON 2")
	for action in Settings.REBINDABLE:
		_bind_row(action, "pad", Settings.PAD_SLOTS)
	_note("PS2 pads on USB adapters and other unknown pads may number their buttons differently: "
		+ "use SET UP CONTROLLER to teach the game each button.")
	_action_button("RESET GAMEPAD", func() -> void:
		Settings.reset_bindings("pad")
		_show_tab(3))
	if not Input.joy_connection_changed.is_connected(_on_joy_changed):
		Input.joy_connection_changed.connect(_on_joy_changed)


func _on_joy_changed(_device: int, _connected: bool) -> void:
	if _tab == 3 and _listening.is_empty():
		_show_tab(3)


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
	var button: Button = null
	for b in _list.find_children("*", "Button", true, false):
		if b.has_meta("bind") and b.get_meta("bind") == [action, "pad", 0]:
			button = b
	if button:
		_start_listening(action, "pad", 0, button)


# ---------------------------------------------------------------- listening

func _start_listening(action: String, kind: String, slot: int, button: Button) -> void:
	_stop_listening()
	_listening = {"action": action, "kind": kind, "slot": slot, "button": button}
	_listen_time = LISTEN_TIMEOUT
	_ignore_until = Time.get_ticks_msec() + 250   # ignore the press that started this
	button.text = "..."
	button.grab_focus()
	var what := "key" if kind == "keys" else "button / stick / trigger"
	_hint.text = "Press a %s for  %s\nEsc: cancel   Delete: clear" % [what, Settings.ACTION_NAMES[action].to_upper()]


func _stop_listening() -> void:
	if _listening.is_empty():
		return
	var b: Button = _listening.button
	_listening = {}
	if is_instance_valid(b):
		var m: Array = b.get_meta("bind")
		b.text = Settings.event_name(Settings.binds[m[0]][m[1]][m[2]])
	_update_hint()


func _process(delta: float) -> void:
	if _listening.is_empty():
		return
	_listen_time -= delta
	if _listen_time <= 0.0:
		_wizard.clear()
		_wizard_active = false
		_stop_listening()


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


func _assign(event: InputEvent) -> void:
	var l := _listening
	_listening = {}
	var stolen := Settings.rebind(l.action, l.kind, l.slot, event)
	(l.button as Button).text = Settings.event_name(event)
	Audio.ui("ui_select")
	_update_hint()
	if stolen != "":
		_hint.text = "%s was removed from %s" % [Settings.event_name(event), Settings.ACTION_NAMES[stolen].to_upper()]
	# A short pause before the next input counts, so one press = one binding.
	_ignore_until = Time.get_ticks_msec() + 350
	if _wizard_active:
		await get_tree().create_timer(0.35, true, false, true).timeout
		if is_inside_tree() and _wizard_active:
			_next_wizard_step()
