class_name EnemyBase
extends CharacterBody2D
## Shared code for every enemy and boss: health, gravity, hit flash,
## contact damage, death, and helpers for aiming and shooting.
## Child scripts override _ai(delta) to give each enemy its behaviour.

const BULLET := preload("res://scenes/projectiles/bullet.tscn")
const PICKUP := preload("res://scenes/pickups/pickup.tscn")

@export var max_hp := 4
@export var gravity := 720.0
@export var score_value := 100
@export var contact_damage := 1
@export var bullet_speed := 150.0

var hp := 0
var facing := -1
var dead := false
var player: Node2D

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var hitbox: Area2D = $Hitbox
@onready var muzzle: Marker2D = $Muzzle


func _ready() -> void:
	add_to_group("enemies")
	hp = max_hp
	collision_layer = 4        # layer 3 "enemies"
	collision_mask = 1 | 16    # world + platforms
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2  # touches the player
	player = get_tree().get_first_node_in_group("player")
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y = minf(velocity.y + gravity * delta, 400.0)
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 300.0 * delta)
		move_and_slide()
		return
	_ai(delta)
	move_and_slide()
	sprite.flip_h = facing < 0
	muzzle.position.x = absf(muzzle.position.x) * facing
	if contact_damage > 0:
		for body in hitbox.get_overlapping_bodies():
			if body.has_method("take_damage"):
				body.take_damage(contact_damage, global_position)
	if global_position.y > 340.0:
		die()


## Override in child scripts.
func _ai(_delta: float) -> void:
	pass


# ---------------------------------------------------------------- helpers

func player_alive() -> bool:
	return is_instance_valid(player) and not player.dead


func to_player() -> Vector2:
	return player.global_position - global_position


func face_player() -> void:
	var dx := to_player().x
	if absf(dx) > 2.0:
		facing = int(signf(dx))


## True if there is floor a few pixels ahead in direction `dir`
## (stops enemies from walking off ledges).
func ground_ahead(dir: int) -> bool:
	var from := global_position + Vector2(dir * 12, -4)
	var q := PhysicsRayQueryParameters2D.create(from, from + Vector2(0, 24), 1 | 16)
	return not get_world_2d().direct_space_state.intersect_ray(q).is_empty()


func play(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func shoot_bullet(dir: Vector2, damage: int = 1, speed: float = -1.0) -> void:
	var b: Area2D = BULLET.instantiate().setup(muzzle.global_position, dir, false, damage,
			bullet_speed if speed < 0.0 else speed)
	b.modulate = Color(1.0, 0.45, 0.4)
	b.spark_color = Color(1.0, 0.4, 0.3)
	get_parent().add_child(b)


## Direction from the muzzle to the player's chest.
func aim_at_player() -> Vector2:
	return (player.global_position + Vector2(0, -10) - muzzle.global_position).normalized()


# ---------------------------------------------------------------- damage

func take_damage(amount: int, from_pos: Vector2) -> void:
	if dead:
		return
	hp -= amount
	_flash()
	_on_hurt(amount, from_pos)
	if hp <= 0:
		die()


func _flash() -> void:
	sprite.modulate = Color(4, 4, 4)
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color.WHITE, 0.12)


## Override for a reaction to being hit (stagger, knockback...).
func _on_hurt(_amount: int, _from_pos: Vector2) -> void:
	pass


func die() -> void:
	if dead:
		return
	dead = true
	hp = 0
	collision_layer = 0
	hitbox.set_deferred("monitoring", false)
	sprite.play("dead")
	Game.add_score(score_value)
	_on_died()


## Override to change what happens on death. Default: maybe drop loot, then fade out.
func _on_died() -> void:
	var roll := randf()
	if roll < 0.25:
		_drop("health")
	elif roll < 0.35:
		_drop("grenade")
	var t := create_tween()
	t.tween_interval(1.2)
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(queue_free)


func _drop(kind: String) -> void:
	var p := PICKUP.instantiate()
	p.kind = kind
	p.global_position = global_position + Vector2(0, -8)
	get_parent().add_child.call_deferred(p)
