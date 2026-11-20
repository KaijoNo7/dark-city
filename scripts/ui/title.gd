extends Control
## Title screen: a small night-street diorama made from the asset pack,
## the game title, the three bosses lined up, controls and menu buttons.

const UI := preload("res://scripts/ui/ui_kit.gd")
const TILES := preload("res://asset/Tiled/Tile1.png")


func _ready() -> void:
	Game.running = false
	_build_backdrop()
	_build_menu()


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
