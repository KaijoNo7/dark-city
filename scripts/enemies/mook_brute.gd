extends "res://scripts/enemies/enemy_base.gd"
## Bald brute with an axe (Enimies_4). Runs at the player and swings.

@export var walk_speed := 45.0
@export var run_speed := 80.0
@export var aggro_range := 200.0
@export var attack_damage := 2

var _attack_timer := 0.0
var _hit_done := false
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

	# Mid-swing: the hit lands ~0.2s into the animation.
	if _attack_timer > 0.0:
		_attack_timer -= delta
		velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
		if not _hit_done and _attack_timer < 0.25:
			_hit_done = true
			if absf(d.x) < 30.0 and absf(d.y) < 24.0 and signf(d.x) == facing:
				player.take_damage(attack_damage, global_position)
		return

	if absf(d.x) > aggro_range or absf(d.y) > 90.0:
		velocity.x = 0.0
		play("idle")
		return

	face_player()
	if absf(d.x) < 22.0 and absf(d.y) < 24.0:
		_attack_timer = 0.45
		_hit_done = false
		velocity.x = 0.0
		sprite.play("attack_1")
	elif ground_ahead(facing):
		var fast := absf(d.x) < 110.0
		velocity.x = facing * (run_speed if fast else walk_speed)
		play("run_attack" if fast else "walk")
	else:
		velocity.x = 0.0
		play("idle")


func _on_hurt(_amount: int, from_pos: Vector2) -> void:
	_stun = 0.12
	_attack_timer = 0.0
	velocity.x = signf(global_position.x - from_pos.x) * 40.0
	sprite.play("hurt")
