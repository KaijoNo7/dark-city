extends CharacterBody2D
## The player. Its look (one of three characters + a colour tint) and the
## name tag above its head come from the CUSTOMIZE screen (Settings profile).
## Controls: move, jump, shoot (hold for auto-fire), throw grenade, reload.

const BULLET := preload("res://scenes/projectiles/bullet.tscn")
const GRENADE := preload("res://scenes/projectiles/grenade.tscn")

@export var speed := 95.0
@export var acceleration := 900.0
@export var jump_velocity := -265.0
@export var gravity := 720.0
@export var max_fall_speed := 380.0
@export var max_hp := 10
@export var mag_size := 12
@export var fire_cooldown := 0.14
@export var reload_time := 0.9
@export var max_grenades := 3

var hp := 0
var ammo := 0
var grenades := 0
var facing := 1
var dead := false
## Last position standing on solid ground (used by save files).
var safe_position := Vector2.ZERO

var _fire_timer := 0.0
var _shoot_anim_timer := 0.0
var _reload_timer := 0.0
var _cast_timer := 0.0
var _hurt_timer := 0.0
var _invuln_timer := 0.0
var _coyote_timer := 0.0
var _jump_buffer := 0.0
var _drop_timer := 0.0
var _air_time := 0.0
var _name_tag: Label

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var muzzle: Marker2D = $Muzzle
@onready var camera: Camera2D = $Camera


func _ready() -> void:
	add_to_group("player")
	hp = max_hp
	ammo = mag_size
	grenades = max_grenades
	safe_position = global_position
	_apply_look()
	# Let the HUD draw the starting values once it is ready.
	_emit_stats.call_deferred()


func _physics_process(delta: float) -> void:
	if dead:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)
		velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		return

	_tick_timers(delta)
	_apply_gravity(delta)
	_handle_movement(delta)
	_handle_jump()
	_handle_combat()
	move_and_slide()
	_update_animation()
	_track_ground(delta)

	# Fell into a pit.
	if global_position.y > 320.0:
		hp = 0
		_die()


func _tick_timers(delta: float) -> void:
	_fire_timer -= delta
	_shoot_anim_timer -= delta
	_cast_timer -= delta
	_hurt_timer -= delta
	_jump_buffer -= delta
	_coyote_timer = 0.1 if is_on_floor() else _coyote_timer - delta
	if _invuln_timer > 0.0:
		_invuln_timer -= delta
		sprite.visible = fmod(_invuln_timer, 0.12) > 0.05  # flicker while invulnerable
		if _invuln_timer <= 0.0:
			sprite.visible = true
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			ammo = mag_size
			_emit_stats()
	if _drop_timer > 0.0:
		_drop_timer -= delta
		if _drop_timer <= 0.0:
			set_collision_mask_value(5, true)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var g := gravity
		# Releasing jump early = shorter hop (variable jump height).
		if velocity.y < 0.0 and not Input.is_action_pressed("jump"):
			g *= 2.2
		velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _handle_movement(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	if _hurt_timer > 0.0:
		dir = 0.0  # knocked back, no control for a moment
	var target := dir * speed
	velocity.x = move_toward(velocity.x, target, acceleration * delta)
	if dir != 0.0:
		facing = int(signf(dir))
	sprite.flip_h = facing < 0
	muzzle.position.x = absf(muzzle.position.x) * facing


func _handle_jump() -> void:
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = 0.12
	if _jump_buffer > 0.0 and _coyote_timer > 0.0 and _hurt_timer <= 0.0:
		_jump_buffer = 0.0
		_coyote_timer = 0.0
		if Input.is_action_pressed("move_down") and is_on_floor():
			# Down + jump drops through one-way platforms.
			set_collision_mask_value(5, false)
			_drop_timer = 0.25
		else:
			velocity.y = jump_velocity
			Audio.sfx("jump", global_position)


func _handle_combat() -> void:
	if _hurt_timer > 0.0:
		return
	if Input.is_action_just_pressed("reload") and ammo < mag_size:
		_start_reload()
	if Input.is_action_just_pressed("grenade") and grenades > 0 and _cast_timer <= 0.0 and _reload_timer <= 0.0:
		_throw_grenade()
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0 and _reload_timer <= 0.0 and _cast_timer <= 0.0:
		if ammo > 0:
			_shoot()
		else:
			_start_reload()


func _shoot() -> void:
	_fire_timer = fire_cooldown
	_shoot_anim_timer = 0.25
	ammo -= 1
	var spread := randf_range(-0.04, 0.04)
	var b: Area2D = BULLET.instantiate().setup(muzzle.global_position, Vector2(facing, spread), true, 1)
	get_parent().add_child(b)
	velocity.x -= facing * 8.0  # tiny recoil
	Game.shake(0.8)
	Audio.sfx("shoot", global_position)
	_emit_stats()
	if ammo == 0:
		_start_reload()


func _start_reload() -> void:
	if _reload_timer > 0.0:
		return
	_reload_timer = reload_time
	sprite.play("recharge")
	Audio.sfx("reload", global_position)
	_emit_stats()


func _throw_grenade() -> void:
	grenades -= 1
	_cast_timer = 0.3
	sprite.play("cast")
	var g := GRENADE.instantiate()
	g.global_position = global_position + Vector2(6 * facing, -16)
	g.velocity = Vector2(150 * facing + velocity.x * 0.5, -190)
	g.from_player = true
	get_parent().add_child(g)
	Audio.sfx("throw", global_position)
	_emit_stats()


func _update_animation() -> void:
	var anim := "idle"
	var moving := absf(velocity.x) > 10.0
	if _hurt_timer > 0.0:
		anim = "hurt"
	elif _cast_timer > 0.0:
		anim = "cast"
	elif _reload_timer > 0.0:
		anim = "recharge"
	elif _shoot_anim_timer > 0.0:
		anim = "walk_shot" if moving else "shot"
	elif not is_on_floor():
		anim = "walk"
	elif moving:
		anim = "walk"
	if sprite.animation != anim:
		sprite.play(anim)
	# In the air: freeze on a "legs apart" walk frame.
	if anim == "walk" and not is_on_floor():
		sprite.pause()
		sprite.frame = 1
	elif not sprite.is_playing() and anim in ["idle", "walk", "shot", "walk_shot"]:
		sprite.play(anim)


## Called by bullets, explosions and enemy attacks.
func take_damage(amount: int, from_pos: Vector2) -> void:
	if dead or _invuln_timer > 0.0:
		return
	hp = maxi(hp - amount, 0)
	_invuln_timer = 1.0
	_hurt_timer = 0.25
	var push := signf(global_position.x - from_pos.x)
	if push == 0.0:
		push = -facing
	velocity = Vector2(push * 140.0, -140.0)
	Game.shake(4.0)
	Game.hit_stop(0.06)
	Audio.sfx("player_hurt", global_position)
	Settings.rumble(0.5, 0.8, 0.25)
	_emit_stats()
	if hp <= 0:
		_die()


## Called by pickups. Returns true if the item was used.
func collect(kind: String) -> bool:
	match kind:
		"health":
			if hp >= max_hp:
				return false
			hp = mini(hp + 3, max_hp)
		"grenade":
			if grenades >= max_grenades:
				return false
			grenades += 1
	Audio.sfx("pickup_" + kind, global_position)
	_emit_stats()
	return true


func _die() -> void:
	if dead:
		return
	dead = true
	sprite.visible = true
	sprite.play("dead")
	collision_layer = 0
	velocity = Vector2(-facing * 60.0, -160.0)
	Audio.sfx("player_die", global_position)
	Settings.rumble(1.0, 1.0, 0.6)
	if is_instance_valid(_name_tag):
		_name_tag.visible = false
	_emit_stats()
	Game.player_died.emit()


## Landing sound after a real fall, and remembering safe ground for saves.
func _track_ground(delta: float) -> void:
	if is_on_floor():
		if _air_time > 0.25:
			Audio.sfx("land", global_position)
		_air_time = 0.0
		safe_position = global_position
	else:
		_air_time += delta


## Character frames, colour tint and the floating name tag.
func _apply_look() -> void:
	var frames: SpriteFrames = load(Settings.character().frames)
	if frames:
		sprite.sprite_frames = frames
		sprite.play("idle")
	# self_modulate tints only this sprite; `modulate` stays free for effects.
	sprite.self_modulate = Settings.tint()
	if Settings.get_value("profile/show_tag"):
		_name_tag = Label.new()
		_name_tag.text = Settings.get_value("profile/name")
		_name_tag.add_theme_font_size_override("font_size", 8)
		_name_tag.add_theme_color_override("font_color", Color(1.0, 0.85, 0.5, 0.85))
		_name_tag.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08, 0.85))
		_name_tag.add_theme_constant_override("outline_size", 3)
		_name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_name_tag.size = Vector2(80, 10)
		_name_tag.position = Vector2(-40, -42)
		add_child(_name_tag)


func _emit_stats() -> void:
	Game.player_hp_changed.emit(hp, max_hp)
	Game.player_ammo_changed.emit(ammo, mag_size, grenades, _reload_timer > 0.0)
