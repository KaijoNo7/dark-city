extends "res://scripts/bosses/boss_base.gd"
## BOSS 2 - BONECRUSHER (Enimies_5, shown at 2x size).
## A heavy melee bruiser. Attacks:
##   charge - flashes red, then rushes across the arena; gets stunned on hitting a wall
##   leap   - jumps at the player and sends shockwaves along the floor (jump over them!)
##   swipe  - close-range hit

const SHOCKWAVE := preload("res://scenes/projectiles/shockwave.tscn")

var _hit_done := false
var _leaps_left := 0


func _boss_ai(delta: float) -> void:
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return
	var p2 := in_phase2()
	match state:
		"idle":
			contact_damage = 1
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			play("idle")
			if state_time > (0.45 if p2 else 0.8):
				_choose_attack()

		"windup":
			velocity.x = 0.0
			play("idle")
			# Blink red as a warning.
			sprite.modulate = Color(2.5, 0.6, 0.6) if fmod(state_time, 0.16) < 0.08 else Color.WHITE
			if state_time > (0.45 if p2 else 0.65):
				sprite.modulate = Color.WHITE
				set_state("charge")

		"charge":
			contact_damage = 2
			play("walk_attack")
			velocity.x = facing * (240.0 if p2 else 190.0)
			if state_time > 0.1 and (is_on_wall() or state_time > 2.5):
				Game.shake(6.0)
				velocity.x = -facing * 60.0
				velocity.y = -120.0
				set_state("stunned")

		"stunned":
			contact_damage = 0
			play("hurt" if state_time < 0.2 else "idle")
			sprite.rotation = sin(state_time * 30.0) * 0.08
			if state_time > (0.7 if p2 else 1.1):
				sprite.rotation = 0.0
				set_state("idle")

		"leap":
			play("cast")
			if state_time > 0.2 and is_on_floor():
				velocity.x = 0.0
				Game.shake(5.0)
				_spawn_shockwaves()
				_leaps_left -= 1
				if _leaps_left > 0:
					_start_leap()
				else:
					set_state("idle")

		"swipe":
			velocity.x = 0.0
			if not _hit_done and state_time > 0.2:
				_hit_done = true
				var d := to_player()
				if absf(d.x) < 46.0 and absf(d.y) < 40.0:
					player.take_damage(2, global_position)
			if state_time > 0.5:
				set_state("idle")


func _choose_attack() -> void:
	var d := to_player()
	if absf(d.x) < 44.0:
		_hit_done = false
		sprite.play("attack_1")
		set_state("swipe")
	elif randf() < 0.55:
		face_player()
		set_state("windup")
	else:
		_leaps_left = 2 if in_phase2() else 1
		_start_leap()


func _start_leap() -> void:
	face_player()
	var dx := clampf(to_player().x, -160.0, 160.0)
	velocity = Vector2(dx / 0.8, -300.0)
	set_state("leap")


func _spawn_shockwaves() -> void:
	for dir in [-1, 1]:
		var w: Area2D = SHOCKWAVE.instantiate().setup(global_position + Vector2(dir * 20, 0), Vector2(dir, 0), false, 1, 140.0)
		get_parent().add_child(w)

