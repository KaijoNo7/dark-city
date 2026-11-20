extends CharacterBody2D
## A thrown grenade: flies in an arc, bounces, then explodes after its fuse
## runs out (or immediately if it touches a target).

const EXPLOSION := preload("res://scenes/projectiles/explosion.tscn")

@export var fuse := 1.1
@export var gravity := 600.0
@export var damage := 6

var from_player := true
var _exploded := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 16  # world + platforms, so it can bounce on them
	$Hitbox.collision_layer = 0
	$Hitbox.collision_mask = 4 if from_player else 2
	$Hitbox.body_entered.connect(func(_b: Node2D) -> void: explode())
	$Sprite.play()


func _physics_process(delta: float) -> void:
	velocity.y += gravity * delta
	var hit := move_and_collide(velocity * delta)
	if hit:
		velocity = velocity.bounce(hit.get_normal()) * 0.45
		if hit.get_normal().y < -0.5:
			velocity.x *= 0.7  # ground friction
	fuse -= delta
	if fuse <= 0.0:
		explode()


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var e := EXPLOSION.instantiate()
	e.global_position = global_position
	e.from_player = from_player
	e.damage = damage
	get_parent().add_child.call_deferred(e)
	queue_free()
