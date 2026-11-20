extends Area2D
## Grenade explosion: plays the 8-frame blast animation and damages
## everything inside the circle once.

var from_player := true
var damage := 6


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4 if from_player else 2
	$Sprite.play("default")
	$Sprite.animation_finished.connect(queue_free)
	Game.shake(5.0)
	# Wait two physics frames so the Area2D knows what overlaps it.
	await get_tree().physics_frame
	await get_tree().physics_frame
	for body in get_overlapping_bodies():
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
