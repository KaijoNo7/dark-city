extends Area2D
## Health or grenade pickup. The icon is cut out of the city tilesheet.

const TILES := preload("res://asset/Tiled/Tile1.png")
const GRENADE_TEX := preload("res://asset/Characters/Other/Granate_Cast.png")

@export_enum("health", "grenade") var kind := "health"
@export var expires := true     ## Dropped pickups vanish after a while.

var _life := 10.0


func _ready() -> void:
	collision_layer = 8   # layer 4 "pickups"
	collision_mask = 2    # only the player can collect it
	var tex := AtlasTexture.new()
	if kind == "health":
		tex.atlas = TILES
		tex.region = Rect2(26 * 16, 15 * 16, 16, 16)  # red soda can
	else:
		tex.atlas = GRENADE_TEX
		tex.region = Rect2(8, 8, 16, 16)
	$Sprite.texture = tex
	body_entered.connect(_on_body_entered)
	# Bob up and down forever.
	var t := create_tween().set_loops()
	t.tween_property($Sprite, "position:y", -3.0, 0.5).set_trans(Tween.TRANS_SINE)
	t.tween_property($Sprite, "position:y", 0.0, 0.5).set_trans(Tween.TRANS_SINE)


func _process(delta: float) -> void:
	if not expires:
		return
	_life -= delta
	if _life < 3.0:
		visible = fmod(_life, 0.2) > 0.1  # blink before disappearing
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body.has_method("collect") and body.collect(kind):
		queue_free()
