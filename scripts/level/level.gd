extends Node2D
## Level root. Sets the camera bounds, starts the weather and the music,
## restores a loaded save, and shows the opening stage card.

const Weather := preload("res://scripts/level/weather.gd")

@export var level_width := 3776
@export var ground_bottom := 210


func _ready() -> void:
	var player := get_tree().get_first_node_in_group("player")
	var cam: Camera2D = player.camera
	cam.limit_left = 0
	cam.limit_right = level_width
	cam.limit_top = -400
	cam.limit_bottom = ground_bottom
	cam.reset_smoothing()

	# Rain (baked into the scene by tools/build_level.gd) + lightning, both
	# following the video settings.
	var weather := Weather.new()
	weather.rain = get_node_or_null("Rain/Particles")
	add_child(weather)

	Audio.play_music("street", 1.0)
	var hud := get_node_or_null("HUD")
	if Game.loaded_from_save:
		SaveGame.apply_pending(self)
		Game.message("SAVE LOADED\nWelcome back, " + Settings.get_value("profile/name"), 2.5)
	elif hud:
		hud.show_stage_card("STAGE 1  -  DOWNTOWN", "02:51 AM    Officer %s on patrol" % Settings.display_name())
	else:
		Game.message("DARK CITY\nTake back the streets.", 3.0)
