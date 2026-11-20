extends SceneTree
## Asset pipeline step 1: converts the raw sprite sheets in res://asset into
## Godot resources (SpriteFrames + TileSet).
##
## Run from the project folder:
##   godot --headless --import
##   godot --headless --script res://tools/build_resources.gd
##
## Every sheet in the pack is a single row of 32x32 frames, so the number of
## frames is simply image_width / 32. Each PNG becomes one animation whose
## name is the file name in snake_case ("Walk+Shot.png" -> "walk_shot").

const FRAME_DIR := "res://resources/frames/"

# Which animations loop, and their playback speed (frames per second).
const LOOPING := ["idle", "walk", "walk_shot", "shot", "walk_attack", "run_attack"]
const FPS := {
	"idle": 6.0, "walk": 10.0, "walk_shot": 12.0, "shot": 14.0, "recharge": 9.0,
	"cast": 12.0, "hurt": 14.0, "dead": 8.0, "attack": 14.0, "attack_1": 12.0,
	"attack_2": 12.0, "walk_attack": 12.0, "run_attack": 12.0,
}

# Ground tiles (solid) and platform tiles (one-way) in asset/Tiled/Tile1.png.
const GROUND_TILES := [
	Vector2i(1, 22), Vector2i(2, 22), Vector2i(3, 22), Vector2i(4, 22),
	Vector2i(1, 23), Vector2i(2, 23), Vector2i(3, 23), Vector2i(4, 23),
	Vector2i(1, 24), Vector2i(2, 24), Vector2i(3, 24), Vector2i(4, 24),
	Vector2i(1, 26), Vector2i(2, 26), Vector2i(3, 26), Vector2i(4, 26),
	Vector2i(1, 27), Vector2i(2, 27), Vector2i(3, 27), Vector2i(4, 27),
	Vector2i(1, 28), Vector2i(2, 28), Vector2i(3, 28), Vector2i(4, 28),
	Vector2i(6, 26), Vector2i(7, 26), Vector2i(8, 26), Vector2i(9, 26),
	Vector2i(6, 27), Vector2i(7, 27), Vector2i(8, 27), Vector2i(9, 27),
	Vector2i(6, 28), Vector2i(7, 28), Vector2i(8, 28), Vector2i(9, 28),
]
# Roof ledge of the yellow building: left cap, middle pieces, right cap.
const PLATFORM_TILES := [
	Vector2i(12, 15), Vector2i(13, 15), Vector2i(14, 15), Vector2i(15, 15),
	Vector2i(16, 15), Vector2i(17, 15), Vector2i(18, 15), Vector2i(19, 15),
	Vector2i(20, 15), Vector2i(22, 15),
]


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(FRAME_DIR)

	build_character("player", "res://asset/Characters/Character_1")
	# Alternative looks for the character-customisation screen.
	build_character("player_2", "res://asset/Characters/Character_2")
	build_character("player_3", "res://asset/Characters/Character_3")
	build_character("mook_gunner", "res://asset/Enimies/Enimies_1")
	build_character("mook_brute", "res://asset/Enimies/Enimies_4")
	build_character("boss_rook", "res://asset/Enimies/Enimies_3")
	build_character("boss_bonecrusher", "res://asset/Enimies/Enimies_5")
	build_character("boss_plague_doctor", "res://asset/Enimies/Enimies_2")

	build_single("grenade", "res://asset/Characters/Other/Granate_Cast.png", 32, 16.0, true)
	build_single("explosion", "res://asset/Characters/Other/Granate_Explosion.png", 64, 18.0, false)

	build_tileset()
	print("build_resources: done")
	quit()


func build_character(id: String, dir_path: String) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var dir := DirAccess.open(dir_path)
	for file in dir.get_files():
		if not file.ends_with(".png"):
			continue
		var anim := file.get_basename().to_lower().replace("+", "_").replace(" ", "_")
		var tex: Texture2D = load(dir_path + "/" + file)
		if tex.get_height() != 32:
			continue  # e.g. Sleeve.png (bullet casings) is not a character pose
		add_strip(frames, anim, tex, 32, FPS.get(anim, 10.0), anim in LOOPING)
	save(frames, FRAME_DIR + id + ".tres")


func build_single(id: String, path: String, frame_w: int, fps: float, loop: bool) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	add_strip(frames, "default", load(path), frame_w, fps, loop)
	save(frames, FRAME_DIR + id + ".tres")


func add_strip(frames: SpriteFrames, anim: String, tex: Texture2D, frame_w: int, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var h := tex.get_height()
	for i in tex.get_width() / frame_w:
		var atlas := AtlasTexture.new()
		atlas.atlas = tex
		atlas.region = Rect2(i * frame_w, 0, frame_w, h)
		frames.add_frame(anim, atlas)


func build_tileset() -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	# Physics layer 0 = solid ground (collision layer 1 "world").
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)
	# Physics layer 1 = one-way platforms (collision layer 5 "platforms").
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 1 << 4)
	ts.set_physics_layer_collision_mask(1, 0)

	var src := TileSetAtlasSource.new()
	src.texture = load("res://asset/Tiled/Tile1.png")
	src.texture_region_size = Vector2i(16, 16)
	ts.add_source(src, 0)

	var full := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	var top := PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, -2), Vector2(-8, -2)])
	for c in GROUND_TILES:
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full)
	for c in PLATFORM_TILES:
		src.create_tile(c)
		var td := src.get_tile_data(c, 0)
		td.add_collision_polygon(1)
		td.set_collision_polygon_points(1, 0, top)
		td.set_collision_polygon_one_way(1, 0, true)
	save(ts, "res://resources/city_tileset.tres")


func save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Failed to save %s (error %d)" % [path, err])
	else:
		print("  saved ", path)
