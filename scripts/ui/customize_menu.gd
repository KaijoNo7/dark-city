extends Control
## CUSTOMIZE screen (title menu): player name, tag, character look and colour.
## A live preview on the left shows the chosen officer cycling through poses.
## Values are stored in Settings ("profile/..."), so they persist and the
## player, HUD, intro and save files can all read them.

signal closed

const UI := preload("res://scripts/ui/ui_kit.gd")
const POSES := ["idle", "walk", "shot", "walk_shot", "recharge", "cast"]
const NAME_PARTS_A := ["NIGHT", "IRON", "GHOST", "NEON", "STEEL", "RAVEN", "VOLT", "ASH", "ECHO", "NOVA", "RUST", "COLD"]
const NAME_PARTS_B := ["WOLF", "HAWK", "FANG", "BLADE", "FOX", "VIPER", "SHADE", "STORM", "JACK", "RAIN"]
const TAGS := ["SWAT", "NYPD", "K9", "ACE", "ZERO", "R0GU", "DCPD", "NITE", "AXE", "UNIT"]

var _preview: AnimatedSprite2D
var _who: Label
var _name_edit: LineEdit
var _tag_edit: LineEdit
var _pose := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var panel := UI.panel(Vector2(330, 190))
	panel.position = Vector2(27, 13)
	add_child(panel)
	var title := UI.label("CUSTOMIZE OFFICER", 16, UI.COLOR_ACCENT)
	title.size = Vector2(330, 22)
	title.position = Vector2(0, 2)
	panel.add_child(title)

	# --- Preview "stage" on the left.
	var stage := ColorRect.new()
	stage.color = Color(0.1, 0.07, 0.16)
	stage.position = Vector2(10, 26)
	stage.size = Vector2(110, 120)
	panel.add_child(stage)
	var floor_line := ColorRect.new()
	floor_line.color = Color(0.3, 0.25, 0.4)
	floor_line.position = Vector2(0, 104)
	floor_line.size = Vector2(110, 16)
	stage.add_child(floor_line)
	_preview = AnimatedSprite2D.new()
	_preview.scale = Vector2(3, 3)
	_preview.position = Vector2(55, 104 - 48)
	stage.add_child(_preview)
	_who = UI.label("", 8, UI.COLOR_TEXT, false)
	_who.position = Vector2(10, 148)
	_who.size = Vector2(110, 22)
	_who.add_theme_constant_override("line_spacing", -3)
	panel.add_child(_who)
	var pose_timer := Timer.new()
	pose_timer.wait_time = 1.6
	pose_timer.autostart = true
	pose_timer.timeout.connect(_next_pose)
	add_child(pose_timer)

	# --- Options on the right.
	var box := VBoxContainer.new()
	box.position = Vector2(128, 26)
	box.size = Vector2(192, 150)
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	_name_edit = _line_edit(box, "NAME", "profile/name", 12)
	_tag_edit = _line_edit(box, "TAG", "profile/tag", 4)
	var character_names := []
	for c in Settings.CHARACTERS:
		character_names.append(c.name)
	var char_row := SettingRow.choice("Character", "profile/character", character_names)
	char_row.value_changed.connect(func(_v: Variant) -> void: _refresh_preview())
	box.add_child(char_row)
	var tint_names := []
	for t in Settings.TINTS:
		tint_names.append(t.name)
	var tint_row := SettingRow.choice("Colour", "profile/tint", tint_names)
	tint_row.value_changed.connect(func(_v: Variant) -> void: _refresh_preview())
	box.add_child(tint_row)
	box.add_child(SettingRow.toggle("Name above head", "profile/show_tag"))
	var random := UI.button("RANDOM CALLSIGN", _randomize)
	random.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	random.custom_minimum_size = Vector2(130, 14)
	box.add_child(random)
	var done := UI.button("DONE", close)
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	done.custom_minimum_size = Vector2(130, 14)
	box.add_child(done)
	var hint := UI.label("On a gamepad? Use RANDOM CALLSIGN.", 8, Color(0.35, 0.28, 0.26), false)
	hint.position = Vector2(0, 174)
	hint.size = Vector2(330, 12)
	panel.add_child(hint)

	_refresh_preview()
	UI.focus_quietly(_name_edit)


func _line_edit(parent: Node, caption: String, key: String, max_len: int) -> LineEdit:
	var row := HBoxContainer.new()
	var l := UI.label(caption, 8, UI.COLOR_TEXT, false)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(60, 14)
	row.add_child(l)
	var e := LineEdit.new()
	e.text = Settings.get_value(key)
	e.max_length = max_len
	e.custom_minimum_size = Vector2(128, 14)
	e.add_theme_font_size_override("font_size", 8)
	e.add_theme_color_override("font_color", UI.COLOR_LIGHT)
	e.add_theme_color_override("caret_color", UI.COLOR_ACCENT)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.12, 0.08, 0.14)
	normal.content_margin_left = 4
	normal.set_border_width_all(1)
	normal.border_color = UI.COLOR_TEXT
	var focus := normal.duplicate()
	focus.border_color = UI.COLOR_ACCENT
	e.add_theme_stylebox_override("normal", normal)
	e.add_theme_stylebox_override("focus", focus)
	e.text_changed.connect(func(t: String) -> void:
		# Names are shown in capitals everywhere; keep the caret where it was.
		var caret := e.caret_column
		var clean := t.to_upper().replace("[", "").replace("]", "")
		if clean != t:
			e.text = clean
			e.caret_column = caret
		Settings.set_value(key, clean.strip_edges())
		_refresh_preview())
	UI.add_sounds(e)
	row.add_child(e)
	parent.add_child(row)
	return e


func _randomize() -> void:
	var n: String = NAME_PARTS_A.pick_random() + NAME_PARTS_B.pick_random()
	var t: String = TAGS.pick_random()
	_name_edit.text = n.left(12)
	_tag_edit.text = t
	Settings.set_value("profile/name", _name_edit.text)
	Settings.set_value("profile/tag", t)
	_refresh_preview()


func _refresh_preview() -> void:
	var c := Settings.character()
	_preview.sprite_frames = load(c.frames)
	_preview.self_modulate = Settings.tint()
	_preview.play(POSES[_pose])
	_who.text = "%s\n%s" % [Settings.display_name(), c.role]


func _next_pose() -> void:
	_pose = (_pose + 1) % POSES.size()
	_preview.play(POSES[_pose])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Audio.ui("ui_back")
		close()
		get_viewport().set_input_as_handled()


func close() -> void:
	# Never leave the name empty.
	if String(Settings.get_value("profile/name")).strip_edges() == "":
		Settings.set_value("profile/name", Settings.character().name)
	closed.emit()
	queue_free()
