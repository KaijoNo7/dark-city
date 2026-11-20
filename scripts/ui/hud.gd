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


func _process(_delta: float) -> void:
	_time_label.text = Game.format_time(Game.run_time)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not _game_over:
		_toggle_pause()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------ build

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


# ------------------------------------------------------------ signal handlers

func _on_hp_changed(hp: int, max_hp: int) -> void:
	for i in _hearts.size():
		_hearts[i].visible = i < max_hp
		_hearts[i].modulate = UI.COLOR_DANGER if i < hp else Color(0.3, 0.25, 0.25)


func _on_ammo_changed(ammo: int, mag: int, grenades: int, reloading: bool) -> void:
	_ammo_label.text = "RELOAD..." if reloading else "%d/%d" % [ammo, mag]
	for i in _grenade_icons.size():
		_grenade_icons[i].modulate = Color(0.35, 0.45, 0.2) if i < grenades else Color(0, 0, 0, 0.2)


func _show_message(text: String, seconds: float) -> void:
	_message.text = text
	if _message_tween:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.15)
	_message_tween.tween_interval(seconds)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.4)


func _on_boss_started(boss_name: String, max_hp: int) -> void:
	_boss_max = max_hp
	_boss_name.text = boss_name
	_boss_fill.size.x = BOSS_BAR_W
	_boss_box.visible = true


func _on_boss_hp_changed(hp: int) -> void:
	var t := create_tween()
	t.tween_property(_boss_fill, "size:x", BOSS_BAR_W * hp / float(_boss_max), 0.15)


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


# ------------------------------------------------------------ overlays

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
