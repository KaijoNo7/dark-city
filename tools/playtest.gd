extends Node
## Automated playtest bot (developer tool, not part of the game).
##   godot --fixed-fps 60 res://tools/playtest.tscn            (with screenshots)
##   godot --headless --fixed-fps 60 res://tools/playtest.tscn (logic only)
##   ... res://tools/playtest.tscn -- death   (falls into a pit, checks game over)
##   ... res://tools/playtest.tscn -- save    (saves, reloads, checks the restore)
## It plays the level with simulated input, fights all three bosses and
## prints a report. The player is kept alive (hp refilled) so the run
## always reaches the end, but damage taken is still counted.

const LEVEL := preload("res://scenes/level/level_1.tscn")
const SHOT_DIR := "res://tools/screenshots/"
const ARENA_X := [832.0, 2080.0, 3360.0]

var level: Node
var player: CharacterBody2D
var hits_taken := 0
var log_lines: PackedStringArray = []
var _keep_alive := true
var _headless := DisplayServer.get_name() == "headless"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	# Never touch the player's own save or settings.
	SaveGame.path = "user://playtest_save.json"
	SaveGame.delete()
	Settings.persist = false
	Game.running = true
	level = LEVEL.instantiate()
	add_child(level)
	player = get_tree().get_first_node_in_group("player")
	Game.player_hp_changed.connect(func(hp: int, max_hp: int) -> void:
		if hp < max_hp: hits_taken += 1)
	Game.boss_defeated.connect(func(n: String, f: bool) -> void: _log("signal boss_defeated: %s final=%s" % [n, f]))
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if _keep_alive and is_instance_valid(player) and not player.dead and player.hp < player.max_hp:
		player.hp = player.max_hp


func _run() -> void:
	if "death" in OS.get_cmdline_user_args():
		await _death_test()
		return
	if "save" in OS.get_cmdline_user_args():
		await _save_test()
		return
	await _wait(0.5)
	await _shot("01_start")

	# --- Street section: walk right and shoot for a while.
	_log("street 1: walking right + shooting")
	Input.action_press("move_right")
	Input.action_press("shoot")
	for i in 8:
		await _wait(0.5)
		if i % 2 == 0:
			_tap("jump")
		if i == 3:
			await _shot("02_street_fight")
	Input.action_release("move_right")
	Input.action_release("shoot")
	_log("  player x=%d, enemies alive=%d, score=%d" % [player.global_position.x, _alive_enemies(), Game.score])

	_tap("grenade")
	await _wait(0.15)
	await _shot("03_grenade")
	await _wait(1.0)

	# --- Three boss fights.
	for b in 3:
		await _boss_fight(b)

	# --- Victory screen.
	await _wait(4.0)
	await _shot("06_victory")
	var overlay_found := not level.find_children("*", "Button", true, false).is_empty()
	_log("victory overlay shown: %s" % overlay_found)
	_log("TOTAL: score=%d time=%s bosses=%d hits_taken=%d" % [Game.score, Game.format_time(Game.run_time), Game.bosses_defeated, hits_taken])

	# --- Death test: stop healing, drop the player into a pit.
	get_tree().paused = false
	_log("PLAYTEST DONE")
	print("\n".join(log_lines))
	get_tree().quit()


func _boss_fight(index: int) -> void:
	var ax: float = ARENA_X[index]
	# Clear stray enemies near the arena so the test focuses on the boss.
	player.global_position = Vector2(ax + 60.0, 160.0)
	player.velocity = Vector2.ZERO
	await _wait(0.3)
	Input.action_press("move_right")
	await _wait(0.6)
	Input.action_release("move_right")
	await _wait(0.4)
	var boss: Node2D = _find_boss()
	if boss == null:
		_log("BOSS %d: FAILED TO SPAWN" % (index + 1))
		return
	_log("boss %d '%s' spawned (hp %d). Camera limits: %d..%d" % [index + 1, boss.boss_name, boss.max_hp, player.camera.limit_left, player.camera.limit_right])
	await _shot("04_boss%d_intro" % (index + 1))
	await _wait(2.0)
	_log("  active=%s" % boss.active)

	var t := 0.0
	var states := {}
	var shot_taken := false
	var jump_timer := 0.0
	var grenade_timer := 2.0
	while is_instance_valid(boss) and not boss.dead and t < 90.0:
		states[boss.state] = true
		var dx: float = boss.global_position.x - player.global_position.x
		Input.action_release("move_left")
		Input.action_release("move_right")
		if absf(dx) > 150.0:
			Input.action_press("move_right" if dx > 0 else "move_left")
		elif absf(dx) < 70.0 and player.global_position.x > ax + 30 and player.global_position.x < ax + 354:
			Input.action_press("move_left" if dx > 0 else "move_right")
		elif signi(int(dx)) != player.facing:
			Input.action_press("move_right" if dx > 0 else "move_left")
		Input.action_press("shoot")
		jump_timer -= 0.1
		grenade_timer -= 0.1
		if jump_timer <= 0.0:
			jump_timer = randf_range(0.6, 1.4)
			_tap("jump")
		if grenade_timer <= 0.0:
			grenade_timer = 4.0
			player.grenades = 3
			_tap("grenade")
		if not shot_taken and t > 4.0:
			shot_taken = true
			await _shot("05_boss%d_fight" % (index + 1))
		await _wait(0.1)
		t += 0.1
	for a in ["move_left", "move_right", "shoot"]:
		Input.action_release(a)
	var killed: bool = not is_instance_valid(boss) or boss.dead
	_log("  boss %d %s after %.1fs. states seen: %s" % [index + 1, "KILLED" if killed else "NOT KILLED", t, ", ".join(states.keys())])
	await _wait(2.0)
	var arena := level.get_node("BossArena%d" % (index + 1))
	_log("  walls open: %s, camera limits: %d..%d" % [arena.get_node("WallRight/Shape").disabled, player.camera.limit_left, player.camera.limit_right])


func _death_test() -> void:
	_keep_alive = false
	await _wait(0.5)
	player.global_position = Vector2(35 * 16, 150)  # above the first pit
	await _wait(2.5)
	_log("player dead after falling in pit: %s" % player.dead)
	var buttons := level.find_children("*", "Button", true, false)
	_log("game over buttons: %s" % ", ".join(buttons.map(func(b: Button) -> String: return b.text)))
	await _shot("07_game_over")
	# This node is freed by the scene change, so the quit timer lives on the root.
	var t := Timer.new()
	t.wait_time = 1.5
	t.autostart = true
	t.timeout.connect(get_tree().quit)
	get_tree().root.add_child(t)
	get_tree().scene_changed.connect(Game.message.bind("retry ok", 1.0))
	Game.show_message.connect(func(text: String, _s: float) -> void: pass)
	(buttons[0] as Button).pressed.emit()


func _save_test() -> void:
	await _wait(0.5)
	# Walk a little, then save on solid ground.
	Input.action_press("move_right")
	await _wait(1.5)
	Input.action_release("move_right")
	await _wait(0.6)
	player.hp = 7
	player.grenades = 1
	Game.score = 1234
	var saved_x: float = player.safe_position.x
	_log("save allowed: '%s' (empty = yes)" % SaveGame.cannot_save_reason())
	_log("save_now() -> %s, file exists: %s" % [SaveGame.save_now(), SaveGame.has_save()])
	_log("describe: %s" % SaveGame.describe().replace("\n", " | "))
	Game.in_boss_fight = true
	_log("during boss fight: '%s'" % SaveGame.cannot_save_reason())
	Game.in_boss_fight = false
	# Load it back: this changes scene, so check from a timer on the root.
	var root := get_tree().root
	var t := Timer.new()
	t.wait_time = 1.0
	t.one_shot = true
	t.autostart = true
	t.timeout.connect(func() -> void:
		var p := root.get_tree().get_first_node_in_group("player")
		print("[playtest] after load: x=%d (saved %d) hp=%d grenades=%d score=%d from_save=%s" % [
			p.global_position.x, saved_x, p.hp, p.grenades, Game.score, Game.loaded_from_save])
		print("[playtest] SAVE TEST %s" % ("PASSED" if absf(p.global_position.x - saved_x) < 2.0
			and p.hp == 7 and p.grenades == 1 and Game.score == 1234 else "FAILED"))
		root.get_tree().quit())
	root.add_child(t)
	_keep_alive = false
	Game.continue_game()


func _find_boss() -> Node2D:
	for e in get_tree().get_nodes_in_group("enemies"):
		if "boss_name" in e and not e.dead:
			return e
	return null


func _alive_enemies() -> int:
	var n := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			n += 1
	return n


func _tap(action: String) -> void:
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release(action)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, false).timeout


func _shot(shot_name: String) -> void:
	if _headless:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(SHOT_DIR + shot_name + ".png")


func _log(s: String) -> void:
	log_lines.append(s)
	print("[playtest] ", s)
