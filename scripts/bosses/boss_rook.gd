extends "res://scripts/bosses/boss_base.gd"
## BOSS 1 - "DEADEYE" ROOK (Enimies_3, shown at 2x size).
## A gunslinger. Attacks:
##   burst   - aimed rapid bursts (3 shots, 5 in phase 2)
##   hop_fan - hops away from the player, then fires a fan of bullets on landing
##   walk    - closes the distance
##   reload  - every 3rd attack he must reload: free damage window

var _attacks_since_reload := 0
var _shots_left := 0
var _shot_timer := 0.0


func _boss_ai(delta: float) -> void:
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return
	var p2 := in_phase2()
	match state:
		"idle":
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			play("idle")
			if state_time > (0.45 if p2 else 0.75):
				_choose_attack()

		"burst":
			velocity.x = 0.0
			face_player()
			play("shot")
			_shot_timer -= delta
			if _shot_timer <= 0.0 and _shots_left > 0:
				_shots_left -= 1
				_shot_timer = 0.12 if p2 else 0.16
				shoot_bullet(aim_at_player(), 1, 170.0)
			if _shots_left == 0 and _shot_timer <= 0.0:
				set_state("idle")

		"hop_fan":
			play("walk")
			if state_time > 0.15 and is_on_floor():
				velocity.x = 0.0
				face_player()
				var count := 5 if p2 else 3
				var base := aim_at_player().angle()
				for i in count:
					var a := base + (i - (count - 1) / 2.0) * 0.22
					shoot_bullet(Vector2.from_angle(a), 1, 150.0)
				sprite.play("shot")
				set_state("idle")

		"walk":
			face_player()
			play("walk")
			velocity.x = facing * (75.0 if p2 else 55.0)
			if state_time > 1.0 or absf(to_player().x) < 60.0:
				set_state("burst")
				_shots_left = 2
				_shot_timer = 0.1

		"reload":
			velocity.x = 0.0
			play("recharge")
			if state_time > (0.9 if p2 else 1.3):
				set_state("idle")


func _choose_attack() -> void:
	_attacks_since_reload += 1
	if _attacks_since_reload > 3:
		_attacks_since_reload = 0
		set_state("reload")
		return
	var roll := randf()
	var dist := absf(to_player().x)
	if dist < 70.0 or roll < 0.35:
		# Hop away from the player, but toward the arena centre if a wall is behind.
		var away := -facing
		if (away < 0 and global_position.x - arena_left < 70.0) or (away > 0 and arena_right - global_position.x < 70.0):
			away = facing
		velocity = Vector2(away * 120.0, -260.0)
		set_state("hop_fan")
	elif roll < 0.8 or dist < 140.0:
		_shots_left = 5 if in_phase2() else 3
		_shot_timer = 0.25  # short wind-up so the player can react
		set_state("burst")
	else:
		set_state("walk")
