extends Control
## Draws a twinkling star field for the night sky (no texture needed).

var _stars: Array[Vector3] = []  # x, y, phase
var _time := 0.0


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 70:
		_stars.append(Vector3(rng.randf_range(0, 384), rng.randf_range(0, 130), rng.randf() * TAU))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# Moon
	draw_circle(Vector2(300, 38), 14, Color(0.95, 0.92, 0.8))
	draw_circle(Vector2(306, 34), 13, Color(0.08, 0.07, 0.16))
	for s in _stars:
		var a := 0.4 + 0.6 * absf(sin(_time * 1.5 + s.z))
		draw_rect(Rect2(s.x, s.y, 1, 1), Color(1, 1, 1, a))
