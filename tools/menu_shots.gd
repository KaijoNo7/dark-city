extends Node
## Developer tool: walks through the intro and every menu, saving a
## screenshot of each into tools/screenshots/ (also a quick UI smoke test).
##   godot res://tools/menu_shots.tscn
## Needs a real window (not --headless), because it reads the rendered frame.

const DIR := "res://tools/screenshots/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	# Screenshots use the default settings and profile, without saving them.
	Settings.persist = false
	Settings.values = Settings.DEFAULTS.duplicate()
	Settings.values["video/intro"] = true
	Settings._apply_video()
	SaveGame.path = "user://screenshot_save.json"
	# Scene changes free the *current scene*. Hand that role to a dummy node,
	# so this tool survives while it changes scenes.
	var dummy := Node.new()
	get_tree().root.add_child.call_deferred(dummy)
	await get_tree().process_frame
	get_tree().current_scene = dummy
	await _run()
	get_tree().quit()


func _run() -> void:
	# Intro: a few frames along the sequence.
	get_tree().change_scene_to_file("res://scenes/ui/intro.tscn")
	for shot in [[5.0, "08_intro_city"], [10.5, "09_intro_bosses"], [19.6, "10_intro_logo"]]:
		await _wait_until(shot[0])
		await _shot(shot[1])
	get_tree().change_scene_to_file("res://scenes/ui/title.tscn")
	await _wait(1.5)
	await _shot("00_title")

	var title := get_tree().current_scene
	title._open_settings()
	await _wait(0.4)
	var menu: Control = title._submenu
	for i in 4:
		menu._show_tab(i)
		await _wait(0.3)
		await _shot("11_settings_%s" % menu.TABS[i].to_lower())
	menu.close()
	await _wait(0.3)
	title._open_customize()
	await _wait(0.6)
	await _shot("12_customize")
	title._submenu.close()

	Game.start_game()
	await _wait(1.2)
	await _shot("13_stage_card")
	await _wait(3.0)
	get_tree().current_scene.get_node("HUD")._toggle_pause()
	await _wait(0.4)
	await _shot("14_pause_menu")


var _t0 := Time.get_ticks_msec()


func _wait_until(seconds: float) -> void:
	while (Time.get_ticks_msec() - _t0) / 1000.0 < seconds:
		await get_tree().process_frame


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DIR + shot_name + ".png")
	print("[shots] ", shot_name)
