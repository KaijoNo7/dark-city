extends Node
## Saving and loading a run (one save slot + automatic saves after each boss).
## The save is a small JSON file in user:// (the per-user data folder:
## ~/.local/share/godot/app_userdata/Dark city/ on Linux,
## %APPDATA%\Godot\app_userdata\Dark city\ on Windows).
##
## Flow:  pause menu "SAVE"   -> save_now()  writes the file
##        "CONTINUE" / "LOAD" -> Game.continue_game() reads it, stores it in
##        `pending` and loads the level; level.gd then calls apply_pending().

const PATH := "user://savegame.json"
const VERSION := 1

## Data waiting to be applied when the level scene finishes loading.
var pending := {}
## Where the save lives. Developer tools point this elsewhere so tests never
## overwrite the player's real save.
var path := PATH


func has_save() -> bool:
	return not read().is_empty()


func read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or int(data.get("version", 0)) != VERSION:
		return {}   # missing, corrupted or from an incompatible version
	return data


func delete() -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Returns "" if saving is allowed right now, otherwise the reason it isn't.
func cannot_save_reason() -> String:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not Game.running:
		return "Nothing to save"
	if player.dead:
		return "Can't save while dead"
	if Game.in_boss_fight:
		return "Can't save during a boss fight"
	return ""


## Writes the current run to disk. Returns true on success.
func save_now() -> bool:
	if cannot_save_reason() != "":
		return false
	var player := get_tree().get_first_node_in_group("player")
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(false, true),
		"player_name": Settings.display_name(),
		"character": Settings.get_value("profile/character"),
		"score": Game.score,
		"run_time": Game.run_time,
		"bosses_defeated": Game.bosses_defeated,
		"hp": player.hp,
		"grenades": player.grenades,
		# The last spot where the player stood on solid ground, so loading
		# never drops you in mid-air above a pit.
		"x": player.safe_position.x,
		"y": player.safe_position.y,
	}
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("Could not write save file: %s" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


## One-line summary for menus.
func describe() -> String:
	var d := read()
	if d.is_empty():
		return "No save yet"
	return "%s  -  bosses %d/3  -  %06d pts  -  %s\nsaved %s" % [
		d.get("player_name", "?"), int(d.get("bosses_defeated", 0)), int(d.get("score", 0)),
		Game.format_time(float(d.get("run_time", 0.0))), str(d.get("saved_at", ""))]


## Called by level.gd once the level is in the tree.
func apply_pending(level: Node) -> void:
	if pending.is_empty():
		return
	var d := pending
	pending = {}
	var player := get_tree().get_first_node_in_group("player")
	var pos := Vector2(float(d.get("x", player.global_position.x)), float(d.get("y", player.global_position.y)))
	player.global_position = pos
	player.safe_position = pos
	player.hp = clampi(int(d.get("hp", player.max_hp)), 1, player.max_hp)
	player.grenades = clampi(int(d.get("grenades", player.max_grenades)), 0, player.max_grenades)
	player.camera.reset_smoothing()
	# Boss arenas already beaten stay open and empty.
	for i in Game.bosses_defeated:
		var arena := level.get_node_or_null("BossArena%d" % (i + 1))
		if arena:
			arena.mark_cleared()
	# Enemies and pickups the player already walked past are gone.
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.global_position.x < pos.x - 48.0:
			e.queue_free()
	var pickups := level.get_node_or_null("Pickups")
	if pickups:
		for p in pickups.get_children():
			if p.global_position.x < pos.x - 32.0:
				p.queue_free()
	player._emit_stats.call_deferred()
