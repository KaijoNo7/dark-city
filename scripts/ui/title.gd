extends Control
## Title screen: the rainy street diorama (with lightning), a flickering neon
## logo, the player's officer facing the three bosses, and the main menu:
## CONTINUE / NEW GAME / CUSTOMIZE / SETTINGS / CREDITS / QUIT.
## A footer explains the focused menu item and shows control prompts for the
## device the player is using (keyboard or the detected gamepad).

const UI := preload("res://scripts/ui/ui_kit.gd")
const Backdrop := preload("res://scripts/ui/city_backdrop.gd")
const Weather := preload("res://scripts/level/weather.gd")
const OptionsMenu := preload("res://scripts/ui/options_menu.gd")
const CustomizeMenu := preload("res://scripts/ui/customize_menu.gd")

var _backdrop: Control
var _hero: AnimatedSprite2D
var _logo: Label
var _menu: VBoxContainer
var _footer: Label
var _profile: Label
var _submenu: Control
var _last_focus: Control


func _ready() -> void:
	Game.running = false
	_backdrop = Backdrop.new()
	add_child(_backdrop)
	var weather := Weather.new()
	add_child(weather)
	_hero = _backdrop.actor(Settings.character().frames, Vector2(178, 184), 2.0)
	_hero.self_modulate = Settings.tint()
	_backdrop.actor("res://resources/frames/boss_rook.tres", Vector2(250, 184), 2.0, true)
	_backdrop.actor("res://resources/frames/boss_bonecrusher.tres", Vector2(292, 184), 2.0, true)
	_backdrop.actor("res://resources/frames/boss_plague_doctor.tres", Vector2(334, 184), 2.0, true)
	_build_logo()
	_build_menu()
	Settings.input_device_changed.connect(func(_p: bool) -> void: _update_footer())
	Settings.changed.connect(_on_setting_changed)
	Audio.play_music("title", 1.5)
	# Menu slides in from the left.
	_menu.position.x = -120
	create_tween().tween_property(_menu, "position:x", 14.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _build_logo() -> void:
	_logo = UI.label("DARK CITY", 32, UI.COLOR_ACCENT)
	_logo.position = Vector2(0, 8)
	_logo.size = Vector2(384, 40)
	_logo.pivot_offset = Vector2(192, 20)
	add_child(_logo)
	var sub := UI.label("one night  -  one street  -  three bosses", 8, UI.COLOR_LIGHT)
	sub.position = Vector2(0, 44)
	sub.size = Vector2(384, 12)
	add_child(sub)
	# Neon flicker: mostly on, with occasional quick stutters.
	var t := create_tween().set_loops()
	t.tween_interval(2.5)
	t.tween_property(_logo, "modulate", Color(0.5, 0.4, 0.4), 0.05)
	t.tween_property(_logo, "modulate", Color.WHITE, 0.05)
	t.tween_interval(0.1)
	t.tween_property(_logo, "modulate", Color(0.4, 0.3, 0.3), 0.04)
	t.tween_property(_logo, "modulate", Color(1.2, 1.1, 1.0), 0.06)
	t.tween_interval(4.0)
	# Slow "breathing" scale.
	var b := create_tween().set_loops()
	b.tween_property(_logo, "scale", Vector2(1.03, 1.03), 1.8).set_trans(Tween.TRANS_SINE)
	b.tween_property(_logo, "scale", Vector2.ONE, 1.8).set_trans(Tween.TRANS_SINE)

	_profile = UI.label("", 8, UI.COLOR_ACCENT)
	_profile.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_profile.position = Vector2(184, 2)
	_profile.size = Vector2(196, 10)
	add_child(_profile)
	_update_profile()


func _build_menu() -> void:
	_menu = VBoxContainer.new()
	_menu.position = Vector2(14, 62)
	_menu.size = Vector2(100, 110)
	_menu.add_theme_constant_override("separation", 3)
	add_child(_menu)
	var has_save := SaveGame.has_save()
	var items := [
		["CONTINUE", _continue, SaveGame.describe() if has_save else "No save yet - start a NEW GAME."],
		["NEW GAME", _new_game, "Start a fresh run from the beginning of the street."],
		["CUSTOMIZE", _open_customize, "Change your name, tag, character and colour."],
		["SETTINGS", _open_settings, "Audio, video (resolution, brightness, rain...), keys and gamepads."],
		["CREDITS", _show_credits, "Who made what."],
		["QUIT", get_tree().quit, "Leave the city."],
	]
	for item in items:
		var b := UI.button(item[0], item[1])
		b.custom_minimum_size = Vector2(100, 14)
		b.set_meta("info", item[2])
		b.focus_entered.connect(_update_footer)
		_menu.add_child(b)
	var cont: Button = _menu.get_child(0)
	cont.disabled = not has_save
	cont.focus_mode = Control.FOCUS_ALL if has_save else Control.FOCUS_NONE

	_footer = UI.label("", 8, UI.COLOR_LIGHT)
	_footer.position = Vector2(0, 188)
	_footer.size = Vector2(384, 26)
	_footer.add_theme_constant_override("line_spacing", -3)
	add_child(_footer)
	UI.focus_quietly(cont if has_save else _menu.get_child(1))
	_update_footer()


func _update_footer() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var info: String = focused.get_meta("info") if focused and focused.has_meta("info") else ""
	var p := func(a: String) -> String: return Settings.action_prompt(a)
	var controls := "Move %s/%s  Jump %s  Shoot %s  Grenade %s  Reload %s  Pause %s" % [
		p.call("move_left"), p.call("move_right"), p.call("jump"), p.call("shoot"),
		p.call("grenade"), p.call("reload"), p.call("pause")]
	_footer.text = info + "\n" + controls


func _update_profile() -> void:
	_profile.text = "OFFICER " + Settings.display_name()


func _on_setting_changed(key: String) -> void:
	if key.begins_with("profile/"):
		_update_profile()
		_hero.sprite_frames = load(Settings.character().frames)
		_hero.self_modulate = Settings.tint()
		_hero.play("idle")


# ---------------------------------------------------------------- actions

func _continue() -> void:
	if not Game.continue_game():
		Audio.ui("error")


func _new_game() -> void:
	Audio.stop_music(0.6)
	Game.start_game()


func _open_settings() -> void:
	_open_submenu(OptionsMenu.new())


func _open_customize() -> void:
	_open_submenu(CustomizeMenu.new())


func _open_submenu(menu: Control) -> void:
	_last_focus = get_viewport().gui_get_focus_owner()
	_menu.visible = false
	_footer.visible = false
	_submenu = menu
	add_child(menu)
	menu.closed.connect(_on_submenu_closed)


func _on_submenu_closed() -> void:
	_menu.visible = true
	_footer.visible = true
	_submenu = null
	_update_footer()
	if is_instance_valid(_last_focus):
		UI.focus_quietly(_last_focus)


func _show_credits() -> void:
	var back := UI.button("BACK", func() -> void: pass)
	var dlg := UI.dialog("CREDITS",
		"Made with Godot 4.7 and GDScript\nArt: Craftpix city pack (asset/Licens.txt)\n"
		+ "Sound effects: Juhani Junkala, \"512 Sound Effects\" (CC0)\nMusic: original, synthesised by tools/audio/",
		[back], UI.COLOR_ACCENT, 300.0)
	add_child(dlg)
	_last_focus = get_viewport().gui_get_focus_owner()
	_menu.visible = false
	_footer.visible = false
	back.pressed.connect(func() -> void:
		dlg.queue_free()
		_on_submenu_closed())
	UI.focus_quietly(back)
