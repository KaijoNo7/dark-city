extends Camera2D
## Follows the player (it is a child of the player) and adds screen shake.
## Boss arenas change the limit_* values to lock the view to the arena.

var _shake := 0.0


func _ready() -> void:
	Game.shake_requested.connect(func(s: float) -> void: _shake = maxf(_shake, s))


func _process(delta: float) -> void:
	if _shake > 0.0:
		offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()
		_shake = move_toward(_shake, 0.0, 20.0 * delta)
	else:
		offset = Vector2.ZERO
