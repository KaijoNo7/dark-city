extends "res://scripts/bosses/boss_base.gd"
## BOSS 3 (FINAL) - THE PLAGUE DOCTOR (Enimies_2, shown at 2x size).
## Ruler of the dark city. Attacks:
##   spread   - volleys of 5-bullet fans
##   grenades - lobs grenades that land around the player
##   dash     - leaps over to the other side of the arena
##   summon   - (phase 2) calls two gunmen as backup

const GRENADE := preload("res://scenes/projectiles/grenade.tscn")
const MOOK := preload("res://scenes/enemies/mook_gunner.tscn")

var _volleys_left := 0
var _volley_timer := 0.0
var _summon_cooldown := 0.0


func _boss_ai(delta: float) -> void:
	if not player_alive():
		velocity.x = 0.0
		play("idle")
		return
	var p2 := in_phase2()
	_summon_cooldown -= delta
	match state:
		"idle":
			face_player()
			velocity.x = move_toward(velocity.x, 0.0, 600.0 * delta)
			play("idle")
			if state_time > (0.5 if p2 else 0.8):
				_choose_attack()

		"spread":
			velocity.x = 0.0
			face_player()
			play("shot")
			_volley_timer -= delta
			if _volley_timer <= 0.0 and _volleys_left > 0:
				_volleys_left -= 1
				_volley_timer = 0.45
				var base := aim_at_player().angle()
				for i in 5:
					shoot_bullet(Vector2.from_angle(base + (i - 2) * 0.2), 1, 140.0)
			if _volleys_left == 0 and _volley_timer <= 0.2:
				set_state("idle")

		"grenades":
			velocity.x = 0.0
			play("cast")
			if state_time > 0.25:
				_throw_grenades(3 if p2 else 2)
				set_state("idle")
				state_time = -0.4  # a little extra pause after throwing

		"dash":
			play("walk")
			if state_time > 0.2 and is_on_floor():
				velocity.x = 0.0
				set_state("idle")

		"summon":
			velocity.x = 0.0
			play("cast")
			if state_time > 0.6:
				_summon()
				set_state("idle")


func _choose_attack() -> void:
	var p2 := in_phase2()
	if p2 and _summon_cooldown <= 0.0 and get_tree().get_nodes_in_group("summons").size() < 2:
		set_state("summon")
		return
	var roll := randf()
	if absf(to_player().x) < 60.0 or roll < 0.25:
		_start_dash()
	elif roll < 0.62:
		_volleys_left = 3 if p2 else 2
		_volley_timer = 0.2
		set_state("spread")
	else:
		set_state("grenades")


func _start_dash() -> void:
	# Jump to the side of the arena the player is NOT on.
	var target := arena_left + 50.0
	if player.global_position.x < arena_center():
		target = arena_right - 50.0
	velocity = Vector2((target - global_position.x) / 1.0, -320.0)
	facing = int(signf(velocity.x)) if velocity.x != 0.0 else facing
	set_state("dash")


func _throw_grenades(count: int) -> void:
	for i in count:
		var target_x := player.global_position.x + randf_range(-50.0, 50.0)
		var t := 0.9
		var g := GRENADE.instantiate()
		g.global_position = global_position + Vector2(facing * 10, -40)
		g.velocity = Vector2((target_x - g.global_position.x) / t, -0.5 * 600.0 * t + 15.0)
		g.from_player = false
		g.damage = 2
		g.fuse = 1.1 + i * 0.15
		get_parent().add_child(g)


func _summon() -> void:
	_summon_cooldown = 9.0
	Game.message("BACKUP INCOMING!", 1.2)
	for x in [arena_left + 30.0, arena_right - 30.0]:
		var m := MOOK.instantiate()
		m.global_position = Vector2(x, global_position.y - 150.0)
		m.add_to_group("summons")
		m.score_value = 50
		get_parent().add_child(m)
