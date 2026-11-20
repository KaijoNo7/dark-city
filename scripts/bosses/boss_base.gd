class_name BossBase
extends "res://scripts/enemies/enemy_base.gd"
## Shared boss logic. A boss waits until its arena calls activate(),
## runs a simple state machine (state + state_time), and enters
## "phase 2" (faster, more aggressive) below half health.

const EXPLOSION := preload("res://scenes/projectiles/explosion.tscn")

@export var boss_name := "BOSS"
@export var is_final := false

var active := false
var state := "idle"
var state_time := 0.0
var arena_left := -INF   ## Set by the arena so bosses know where the walls are.
var arena_right := INF
var _phase2_announced := false


func _ready() -> void:
	super._ready()
	# Bosses are heavy: they ignore one-way platforms and stay on the street,
	# so the platforms are only an escape route for the player.
	collision_mask = 1


func activate() -> void:
	active = true
	Game.boss_started.emit(boss_name, max_hp)
	set_state("idle")


func in_phase2() -> bool:
	return hp <= max_hp / 2


func set_state(new_state: String) -> void:
	state = new_state
	state_time = 0.0


func arena_center() -> float:
	return (arena_left + arena_right) * 0.5


func _ai(delta: float) -> void:
	if not active:
		velocity.x = 0.0
		play("idle")
		return
	state_time += delta
	_boss_ai(delta)


## Override in each boss.
func _boss_ai(_delta: float) -> void:
	pass


func take_damage(amount: int, from_pos: Vector2) -> void:
	if not active or dead:
		return
	super.take_damage(amount, from_pos)
	Game.boss_hp_changed.emit(maxi(hp, 0))
	if not dead and in_phase2() and not _phase2_announced:
		_phase2_announced = true
		Game.message(boss_name + " IS ENRAGED!", 1.5)
		Game.shake(4.0)


func _on_died() -> void:
	active = false
	Game.bosses_defeated += 1
	Game.hit_stop(0.15)
	Game.shake(8.0)
	# Chain of explosions (damage 0, purely visual).
	for i in 4:
		var e := EXPLOSION.instantiate()
		e.damage = 0
		e.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(-30, 0))
		get_tree().create_timer(0.2 * i).timeout.connect(func() -> void: get_parent().add_child(e))
	for m in get_tree().get_nodes_in_group("summons"):
		m.die()
	Game.boss_defeated.emit(boss_name, is_final)
	var t := create_tween()
	t.tween_interval(2.5)
	t.tween_property(self, "modulate:a", 0.0, 1.0)
	t.tween_callback(queue_free)
