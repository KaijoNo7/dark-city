extends Node2D
## A one-screen boss arena. Place its origin at the left edge, on the ground.
## When the player walks in: walls close, the camera locks to the arena,
## the boss drops in and after a short intro the fight starts.
## When the boss dies: walls open and the camera is released.

@export var boss_scene: PackedScene
@export var width := 384.0
@export var reward := "health"  ## Pickup dropped when the boss dies.

var _triggered := false
var _boss: Node2D
var _saved_limits := []

@onready var trigger: Area2D = $Trigger
@onready var wall_shapes: Array[CollisionShape2D] = [$WallLeft/Shape, $WallRight/Shape]


func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)
	Game.boss_defeated.connect(_on_boss_defeated)


func _on_trigger_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player") or boss_scene == null:
		return
	_triggered = true
	Game.in_boss_fight = true
	_set_walls(true)
	_lock_camera(body.camera)
	Audio.stop_music(0.8)
	Audio.sfx("alarm")

	_boss = boss_scene.instantiate()
	_boss.global_position = $BossSpawn.global_position
	_boss.arena_left = global_position.x + 8.0
	_boss.arena_right = global_position.x + width - 8.0
	get_parent().add_child.call_deferred(_boss)

	Game.message("WARNING!\n" + _boss.boss_name, 2.0)
	Game.shake(3.0)
	await get_tree().create_timer(2.0).timeout
	if is_instance_valid(_boss):
		_boss.activate()
		Audio.play_music("boss", 0.3)


func _on_boss_defeated(boss_name: String, is_final: bool) -> void:
	if not is_instance_valid(_boss) or boss_name != _boss.boss_name:
		return
	_set_walls(false)
	Game.in_boss_fight = false
	Audio.stop_music(0.5)
	Audio.sfx("boss_win")
	var player := get_tree().get_first_node_in_group("player")
	if player:
		_unlock_camera(player.camera)
	if not is_final:
		var p := preload("res://scenes/pickups/pickup.tscn").instantiate()
		p.kind = reward
		p.expires = false
		p.global_position = Vector2(global_position.x + width * 0.5, global_position.y)
		get_parent().add_child.call_deferred(p)
		await get_tree().create_timer(1.5).timeout
		Game.message("AREA CLEAR\nGO  >>>", 2.5)
		Audio.play_music("street", 2.0)
		# Checkpoint: save automatically after every boss but the last.
		if SaveGame.save_now():
			Settings.toast("Autosaved")


## Used when loading a save: this arena's boss is already beaten.
func mark_cleared() -> void:
	_triggered = true
	_set_walls(false)


func _set_walls(closed: bool) -> void:
	for s in wall_shapes:
		s.set_deferred("disabled", not closed)


func _lock_camera(cam: Camera2D) -> void:
	_saved_limits = [cam.limit_left, cam.limit_right]
	cam.limit_left = int(global_position.x)
	cam.limit_right = int(global_position.x + width)


func _unlock_camera(cam: Camera2D) -> void:
	if _saved_limits.size() == 2:
		cam.limit_left = _saved_limits[0]
		cam.limit_right = _saved_limits[1]
