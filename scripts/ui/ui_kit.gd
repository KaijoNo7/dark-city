extends RefCounted
## Small helper library for building UI from the pack's UI art.
## Usage:  const UI := preload("res://scripts/ui/ui_kit.gd")

const UI_SHEET := preload("res://asset/UI/UI.png")
const PANEL_REGION := Rect2(112, 108, 48, 48)

const COLOR_TEXT := Color(0.16, 0.11, 0.11)
const COLOR_LIGHT := Color(0.96, 0.92, 0.85)
const COLOR_ACCENT := Color(1.0, 0.72, 0.2)
const COLOR_DANGER := Color(0.85, 0.2, 0.25)


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
