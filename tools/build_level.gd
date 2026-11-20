extends Node
## Asset pipeline step 2: builds res://scenes/level/level_1.tscn.
##
## Run AFTER build_resources.gd (as a scene, so the Game autoload exists):
##   godot --headless res://tools/build_level.tscn
##
## The layout lives in the arrays below (in 16px tile units), so the level
## can be re-tuned and rebuilt quickly. The saved scene is a normal Godot
## scene: open it in the editor to paint more tiles or move things by hand.
## WARNING: re-running this script overwrites manual edits to level_1.tscn.

const T := 16
const GROUND_ROW := 11          # top of the ground = y 176
const LEVEL_TILES := 236        # 236 * 16 = 3776 px
const OUT := "res://scenes/level/level_1.tscn"

const TILES := preload("res://asset/Tiled/Tile1.png")
const TILESET := preload("res://resources/city_tileset.tres")
const PLAYER := preload("res://scenes/player/player.tscn")
const GUNNER := preload("res://scenes/enemies/mook_gunner.tscn")
const BRUTE := preload("res://scenes/enemies/mook_brute.tscn")
const ARENA := preload("res://scenes/level/boss_arena.tscn")
const PICKUP := preload("res://scenes/pickups/pickup.tscn")
const HUD := preload("res://scenes/ui/hud.tscn")

# Gaps in the ground: [first_tile, last_tile_exclusive]
const PITS := [[34, 37], [100, 103], [178, 181]]

# One-way platforms: [first_tile, row, length]
const PLATFORMS := [
	[20, 9, 5], [33, 9, 5], [41, 7, 4],                        # street 1
	[57, 9, 4], [70, 9, 4],                                    # arena 1
	[84, 9, 5], [92, 7, 5], [99, 9, 5], [110, 9, 4], [116, 7, 4], [122, 9, 4],  # street 2
	[135, 9, 4], [147, 9, 4],                                  # arena 2
	[160, 9, 5], [168, 7, 4], [177, 9, 5], [188, 9, 4], [194, 7, 5], [202, 9, 4],  # street 3
	[215, 9, 4], [227, 9, 4],                                  # arena 3
]

# Boss arenas: [left_tile, boss scene, reward]
const ARENAS := [
	[52, "res://scenes/bosses/boss_rook.tscn", "health"],
	[130, "res://scenes/bosses/boss_bonecrusher.tscn", "health"],
	[210, "res://scenes/bosses/boss_plague_doctor.tscn", "health"],
]

# Enemies: [type, x_px, y_px]
const ENEMIES := [
	["gunner", 300, 176], ["brute", 470, 176], ["brute", 620, 176], ["gunner", 690, 112],
	["gunner", 1300, 176], ["brute", 1400, 176], ["gunner", 1510, 112], ["brute", 1660, 176],
	["gunner", 1790, 176], ["brute", 1900, 176], ["gunner", 1984, 144],
	["brute", 2520, 176], ["gunner", 2600, 176], ["gunner", 2720, 112], ["brute", 2820, 176],
	["brute", 2960, 176], ["gunner", 3140, 112], ["gunner", 3250, 176], ["brute", 3200, 176],
]

# Free pickups: [kind, x_px, y_px]
const PICKUPS := [
	["health", 760, 176], ["grenade", 1475, 112], ["health", 2040, 176],
	["grenade", 2700, 112], ["health", 3300, 176],
]

# Regions inside Tile1.png
const BUILDING_BURGER := Rect2(16, 144, 128, 192)
const BUILDING_YELLOW := Rect2(192, 192, 176, 144)
const SIGN_VIDEO := Rect2(176, 448, 128, 16)
const SIGN_BURGERS := Rect2(320, 448, 128, 16)
const PROPS := {
	"dumpster": Rect2(432, 192, 48, 32), "dumpster_open": Rect2(384, 176, 48, 48),
	"crate": Rect2(400, 288, 16, 16), "crate2": Rect2(416, 288, 16, 16), "crate3": Rect2(432, 288, 16, 16),
	"tire": Rect2(384, 320, 16, 16), "cone": Rect2(400, 320, 16, 16), "barrel": Rect2(448, 240, 16, 16),
	"bottle": Rect2(384, 224, 16, 16), "trash": Rect2(400, 224, 16, 16), "paper": Rect2(384, 288, 16, 16),
}
const POSTERS := [Rect2(192, 416, 16, 16), Rect2(208, 416, 16, 16), Rect2(224, 416, 16, 16),
	Rect2(240, 416, 16, 16), Rect2(256, 416, 16, 16), Rect2(384, 416, 16, 16), Rect2(400, 416, 16, 16)]

var rng := RandomNumberGenerator.new()
var level_root: Node2D


func _ready() -> void:
	rng.seed = 2026
	level_root = Node2D.new()
	level_root.name = "Level1"
	level_root.set_script(load("res://scripts/level/level.gd"))
	level_root.level_width = LEVEL_TILES * T

	_build_sky()
	_build_parallax()
	_build_street_decor()
	_build_tiles()
	_build_bounds()
	_build_rain()

	var tint := CanvasModulate.new()
	tint.name = "NightTint"
	tint.color = Color(0.8, 0.77, 0.95)
	_add(level_root, tint)

	var player := PLAYER.instantiate()
	player.position = Vector2(40, GROUND_ROW * T)
	_add(level_root, player)

	for a in ARENAS:
		var arena := ARENA.instantiate()
		arena.name = "BossArena%d" % (ARENAS.find(a) + 1)
		arena.position = Vector2(a[0] * T, GROUND_ROW * T)
		arena.boss_scene = load(a[1])
		arena.reward = a[2]
		_add(level_root, arena)

	var enemies := _add(level_root, Node2D.new(), "Enemies")
	for e in ENEMIES:
		var n := (GUNNER if e[0] == "gunner" else BRUTE).instantiate()
		n.position = Vector2(e[1], e[2])
		_add(enemies, n)

	var pickups := _add(level_root, Node2D.new(), "Pickups")
	for p in PICKUPS:
		var n := PICKUP.instantiate()
		n.kind = p[0]
		n.expires = false
		n.position = Vector2(p[1], p[2])
		_add(pickups, n)

	_add(level_root, HUD.instantiate())

	var packed := PackedScene.new()
	var err := packed.pack(level_root)
	if err == OK:
		err = ResourceSaver.save(packed, OUT)
	print("build_level: saved %s (error code %d)" % [OUT, err])
	level_root.free()
	get_tree().quit()


## Adds a node and sets its owner so it gets saved into the scene file.
func _add(parent: Node, node: Node, node_name: String = "") -> Node:
	if node_name != "":
		node.name = node_name
	parent.add_child(node, true)
	node.owner = level_root
	return node


func _sprite(parent: Node, region: Rect2, bottom_left: Vector2, tint := Color.WHITE) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = TILES
	s.region_enabled = true
	s.region_rect = region
	s.centered = false
	s.position = bottom_left - Vector2(0, region.size.y)
	s.modulate = tint
	_add(parent, s)
	return s


func _build_sky() -> void:
	var layer := _add(level_root, CanvasLayer.new(), "Sky")
	layer.layer = -20
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, Color(0.04, 0.03, 0.1))
	grad.gradient.set_color(1, Color(0.25, 0.13, 0.27))
	grad.fill_to = Vector2(0, 1)
	var rect := TextureRect.new()
	rect.texture = grad
	rect.size = Vector2(384, 216)
	_add(layer, rect, "Gradient")
	var stars := Control.new()
	stars.set_script(load("res://scripts/level/stars.gd"))
	stars.size = Vector2(384, 216)
	_add(layer, stars, "Stars")


func _build_parallax() -> void:
	# Two layers of distant buildings that scroll slower than the camera.
	var layers := [
		["FarCity", 0.2, Color(0.07, 0.06, 0.16), 0.0, 150.0],
		["MidCity", 0.45, Color(0.14, 0.12, 0.26), 90.0, 166.0],
	]
	for l in layers:
		var p := Parallax2D.new()
		p.scroll_scale = Vector2(l[1], 1.0)
		p.repeat_size = Vector2(384, 0)
		p.repeat_times = 3
		p.z_index = -10 if l[0] == "FarCity" else -9  # behind the street buildings (-5)
		_add(level_root, p, l[0])
		var x: float = l[3]
		var i := 0
		while x < l[3] + 384.0:
			var region := BUILDING_YELLOW if i % 2 == 0 else BUILDING_BURGER
			_sprite(p, region, Vector2(x - 40.0 if x > 300 else x, l[4]), l[2])
			x += region.size.x - 10.0
			i += 1


func _build_street_decor() -> void:
	var back := _add(level_root, Node2D.new(), "Buildings")
	back.z_index = -5
	var front := _add(level_root, Node2D.new(), "Props")
	front.z_index = -2
	var ground_y := float(GROUND_ROW * T)
	var x := -20.0
	var i := 0
	while x < LEVEL_TILES * T:
		var burger := rng.randf() < 0.45
		var region := BUILDING_BURGER if burger else BUILDING_YELLOW
		var tint := Color.WHITE.darkened(rng.randf_range(0.0, 0.12))
		_sprite(back, region, Vector2(x, ground_y), tint)
		if not burger and rng.randf() < 0.6:
			_sprite(back, SIGN_VIDEO if rng.randf() < 0.5 else SIGN_BURGERS,
				Vector2(x + 24, ground_y - region.size.y), tint)
		# A couple of posters on the wall.
		for k in rng.randi_range(0, 2):
			_sprite(back, POSTERS[rng.randi() % POSTERS.size()],
				Vector2(x + rng.randf_range(10, region.size.x - 26), ground_y - rng.randf_range(20, 40)), tint)
		# Street junk in front.
		var junk: Array = PROPS.keys()
		for k in rng.randi_range(0, 2):
			var key: String = junk[rng.randi() % junk.size()]
			_sprite(front, PROPS[key], Vector2(x + rng.randf_range(0, region.size.x - 40), ground_y))
		x += region.size.x + rng.randf_range(50.0, 130.0)
		i += 1


func _build_tiles() -> void:
	var ground := TileMapLayer.new()
	ground.tile_set = TILESET
	ground.modulate = Color(0.78, 0.76, 0.85)
	_add(level_root, ground, "Ground")
	var platforms := TileMapLayer.new()
	platforms.tile_set = TILESET
	_add(level_root, platforms, "Platforms")

	for tx in range(-2, LEVEL_TILES + 2):
		var in_pit := false
		for p in PITS:
			if tx >= p[0] and tx < p[1]:
				in_pit = true
		if in_pit:
			continue
		ground.set_cell(Vector2i(tx, GROUND_ROW), 0, Vector2i(1 + rng.randi() % 4, 22))
		ground.set_cell(Vector2i(tx, GROUND_ROW + 1), 0, Vector2i(6 + rng.randi() % 4, 26 + rng.randi() % 3))
		ground.set_cell(Vector2i(tx, GROUND_ROW + 2), 0, Vector2i(1 + rng.randi() % 4, 26 + rng.randi() % 3))

	for p in PLATFORMS:
		var length: int = p[2]
		for k in length:
			var atlas := Vector2i(13 + rng.randi() % 8, 15)
			if k == 0:
				atlas = Vector2i(12, 15)
			elif k == length - 1:
				atlas = Vector2i(22, 15)
			platforms.set_cell(Vector2i(p[0] + k, p[1]), 0, atlas)


func _build_bounds() -> void:
	# Invisible walls at both ends of the level.
	for side in [[-8.0, "BoundLeft"], [LEVEL_TILES * T + 8.0, "BoundRight"]]:
		var body := StaticBody2D.new()
		body.position = Vector2(side[0], 0)
		_add(level_root, body, side[1])
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 1000)
		shape.shape = rect
		_add(body, shape, "Shape")


func _build_rain() -> void:
	var layer := _add(level_root, CanvasLayer.new(), "Rain")
	layer.layer = 5
	var drop := GradientTexture2D.new()
	drop.width = 1
	drop.height = 7
	drop.gradient = Gradient.new()
	drop.gradient.set_color(0, Color(0.7, 0.8, 1.0, 0.0))
	drop.gradient.set_color(1, Color(0.7, 0.8, 1.0, 0.6))
	drop.fill_to = Vector2(0, 1)
	var p := CPUParticles2D.new()
	p.texture = drop
	p.amount = 140
	p.lifetime = 0.9
	p.preprocess = 1.0
	p.position = Vector2(220, -12)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(240, 2)
	p.direction = Vector2(-0.25, 1)
	p.spread = 2.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 260.0
	p.initial_velocity_max = 320.0
	p.particle_flag_align_y = true
	p.modulate = Color(1, 1, 1, 0.5)
	_add(layer, p, "Particles")
