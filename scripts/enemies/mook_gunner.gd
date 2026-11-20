extends "res://scripts/enemies/enemy_base.gd"
## Street thug with a rifle (Enimies_1). Keeps his distance and fires
## 3-round bursts. Bullets are slow enough to jump over.

@export var walk_speed := 40.0
@export var aggro_range := 230.0
@export var burst_size := 3
@export var burst_cooldown := 1.8

var _cooldown := 1.0
var _burst_left := 0
var _burst_timer := 0.0
var _stun := 0.0


func _ai(delta: float) -> void:
	_stun -= delta
	if _stun > 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		return
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return

	var d := to_player()
	if absf(d.x) > aggro_range or absf(d.y) > 90.0:
		velocity.x = 0.0
		play("idle")
		return

	face_player()
	_cooldown -= delta

	# Firing a burst: stand still and shoot every 0.18s.
	if _burst_left > 0:
		velocity.x = 0.0
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_left -= 1
			_burst_timer = 0.18
			shoot_bullet(Vector2(facing, 0))
		play("shot")
		return

	# Keep a comfortable distance from the player.
	var move := 0
	if absf(d.x) > 150.0:
		move = facing
	elif absf(d.x) < 60.0:
		move = -facing
	if move != 0 and ground_ahead(move):
		velocity.x = move * walk_speed
		play("walk")
	else:
		velocity.x = 0.0
		play("idle")

	if _cooldown <= 0.0 and absf(d.y) < 40.0:
		_cooldown = burst_cooldown + randf_range(0.0, 0.6)
		_burst_left = burst_size
		_burst_timer = 0.15


func _on_hurt(_amount: int, from_pos: Vector2) -> void:
	_stun = 0.15
	_burst_left = 0
	velocity.x = signf(global_position.x - from_pos.x) * 50.0
	sprite.play("hurt")
