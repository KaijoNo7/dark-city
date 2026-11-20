extends Node2D
## Level root. Sets the camera bounds and shows the opening message.

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
	Game.message("DARK CITY\nTake back the streets.", 3.0)
