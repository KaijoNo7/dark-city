extends Control
## A night-street diorama built from the asset pack: gradient sky, stars and
## moon, two layers of distant skyline, street buildings and the sidewalk.
## Shared by the intro (which pans across it) and the title screen.
##
## `far` and `near` are separate layers so the intro can move them at
## different speeds (parallax): set_pan(x) moves near by x and far by x * 0.3.

const TILES := preload("res://asset/Tiled/Tile1.png")
const BUILDING_BURGER := Rect2(16, 144, 128, 192)
const BUILDING_YELLOW := Rect2(192, 192, 176, 144)

@export var width := 384.0   ## how much street to build (wider for panning)

var far: Node2D
var near: Node2D


func _ready() -> void:
	size = Vector2(384, 216)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sky := TextureRect.new()
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.04, 0.03, 0.1))
	grad.gradient.set_color(1, Color(0.22, 0.12, 0.25))
	grad.fill_to = Vector2(0, 1)
	sky.texture = grad
	sky.size = Vector2(384, 216)
	add_child(sky)
	var stars := preload("res://scripts/level/stars.gd").new()
	stars.size = Vector2(384, 216)
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stars)

	far = Node2D.new()
	add_child(far)
	near = Node2D.new()
	add_child(near)
	# Distant skyline: the same building art, darkened to silhouettes.
	var x := -40.0
	var i := 0
	while x < width * 0.5 + 400.0:
		var r := BUILDING_YELLOW if i % 2 == 0 else BUILDING_BURGER
		_tile(far, r, Vector2(x, 160 + (i % 3) * 6), Color(0.08, 0.07, 0.17))
		x += r.size.x - 18.0
		i += 1
	x = 30.0
	i = 1
	while x < width + 200.0:
		var r := BUILDING_YELLOW if i % 2 == 0 else BUILDING_BURGER
		_tile(far, r, Vector2(x, 172), Color(0.15, 0.13, 0.28))
		x += r.size.x + 20.0
		i += 1
	# Street buildings.
	x = -20.0
	i = 0
	while x < width:
		var r := BUILDING_BURGER if i % 2 == 0 else BUILDING_YELLOW
		_tile(near, r, Vector2(x, 168), Color(0.55, 0.5, 0.7))
		x += r.size.x + 150.0
		i += 1
	# Sidewalk.
	for t in int(width / 16) + 2:
		_tile(near, Rect2((1 + t % 4) * 16, 22 * 16, 16, 16), Vector2(t * 16, 184), Color(0.7, 0.68, 0.8))
		_tile(near, Rect2((1 + (t + 2) % 4) * 16, 26 * 16, 16, 16), Vector2(t * 16, 200), Color(0.7, 0.68, 0.8))


func set_pan(x: float) -> void:
	near.position.x = -x
	far.position.x = -x * 0.3


func _tile(parent: Node, region: Rect2, bottom_left: Vector2, tint: Color) -> Sprite2D:
	var s := Sprite2D.new()
	var tex := AtlasTexture.new()
	tex.atlas = TILES
	tex.region = region
	s.texture = tex
	s.centered = false
	s.position = bottom_left - Vector2(0, region.size.y)
	s.modulate = tint
	parent.add_child(s)
	return s


## Adds an animated character standing with its feet at `feet` (on `near`).
func actor(frames_path: String, feet: Vector2, scale_factor: float = 2.0, flip: bool = false) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = load(frames_path)
	a.scale = Vector2(scale_factor, scale_factor)
	a.position = feet - Vector2(0, 16 * scale_factor)
	a.flip_h = flip
	a.play("idle")
	a.speed_scale = randf_range(0.8, 1.2)
	near.add_child(a)
	return a
