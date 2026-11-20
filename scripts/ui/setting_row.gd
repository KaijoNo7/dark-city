class_name SettingRow
extends Button
## One line of the settings menu, e.g.   Music volume  [=====---]  70%
##
## It is a single focusable Button, so it works the same with every device:
##   keyboard / gamepad : up/down moves between rows, left/right changes value
##   mouse              : click = next value, right-click = previous,
##                        click on a slider bar = jump to that value
## If `key` is set, the row reads and writes that Settings value by itself.

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

var _name_label: Label
var _value_label: Label


## Factory helpers: Row.slider("Music", "audio/music") etc.
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


static func choice(text: String, settings_key: String, options: Array) -> Button:
	var r := SettingRow.new()
	r.kind = Kind.CHOICE
	r.choices = options
	r._setup(text, settings_key)
	return r


static func toggle(text: String, settings_key: String) -> Button:
	var r := SettingRow.new()
	r.kind = Kind.TOGGLE
	r._setup(text, settings_key)
	return r


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

	if key != "":
		value = Settings.get_value(key)
	pressed.connect(func() -> void: change(1))
	focus_entered.connect(_refresh)
	focus_exited.connect(_refresh)
	UI.add_sounds(self)
	_refresh()


func _highlight(alpha: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(UI.COLOR_ACCENT, alpha)
	s.set_corner_radius_all(2)
	return s


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


## Moves the value one step left (-1) or right (+1).
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


func set_row_disabled(on: bool) -> void:
	disabled = on
	modulate.a = 0.45 if on else 1.0


func _refresh() -> void:
	var text_value := ""
	match kind:
		Kind.SLIDER:
			text_value = "%d%s" % [int(value), suffix]
		Kind.CHOICE:
			text_value = str(choices[clampi(int(value), 0, choices.size() - 1)]) if not choices.is_empty() else ""
		Kind.TOGGLE:
			text_value = "ON" if value else "OFF"
	# Arrows hint that left/right change the focused row.
	_value_label.text = ("<  %s  >" % text_value) if has_focus() and kind != Kind.SLIDER else text_value
	queue_redraw()


func _bar_rect() -> Rect2:
	return Rect2(size.x * 0.56, size.y * 0.5 - 2, size.x * 0.23, 4)


func _draw() -> void:
	if kind != Kind.SLIDER:
		return
	var r := _bar_rect()
	var t := inverse_lerp(min_value, max_value, float(value))
	draw_rect(r, Color(UI.COLOR_TEXT, 0.25))
	draw_rect(Rect2(r.position, Vector2(r.size.x * t, r.size.y)), Color(0.85, 0.45, 0.12))
	draw_rect(r, UI.COLOR_TEXT, false, 1.0)
