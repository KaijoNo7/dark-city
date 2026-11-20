extends Area2D
## A projectile that flies in a straight line and damages the first thing it hits.
## The same script is used for the player's bullets, enemy bullets and the
## boss shockwave. `from_player` decides who it is allowed to hurt.

@export var speed := 260.0
@export var damage := 1
@export var lifetime := 1.6
@export var hits_world := true      ## false = passes through walls/ground (shockwave)
@export var spark_color := Color(1, 0.85, 0.3)

var direction := Vector2.RIGHT
var from_player := true


## Call before add_child(). Returns self so calls can be chained.
func setup(pos: Vector2, dir: Vector2, is_player: bool, dmg: int = 1, spd: float = -1.0) -> Area2D:
	global_position = pos
	direction = dir.normalized()
	from_player = is_player
	damage = dmg
	if spd > 0.0:
		speed = spd
	return self


func _ready() -> void:
	collision_layer = 0
	# Layer bits: 1 = world, 2 = player, 4 = enemies.
	collision_mask = (1 if hits_world else 0) | (4 if from_player else 2)
	rotation = direction.angle()
	if direction.x < 0.0 and abs(direction.y) < 0.01:
		# Keep sprites upright when flying left (rotation would flip them upside down).
		rotation = 0.0
		scale.x = -absf(scale.x)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage, global_position)
	elif not hits_world:
		return
	else:
		Audio.sfx("impact", global_position)   # bullet hit a wall / the ground
	_spawn_spark()
	queue_free()


func _spawn_spark() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = true
	p.amount = 6
	p.lifetime = 0.25
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 70.0
	p.gravity = Vector2(0, 200)
	p.color = spark_color
	p.global_position = global_position
	p.finished.connect(p.queue_free)
	get_parent().add_child.call_deferred(p)
