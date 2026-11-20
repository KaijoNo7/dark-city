extends Node
## Global game state + an "event bus" of signals.
## Gameplay nodes emit these signals; the HUD and camera listen to them,
## so nodes never need direct references to each other.

signal player_hp_changed(hp: int, max_hp: int)
signal player_ammo_changed(ammo: int, mag_size: int, grenades: int, reloading: bool)
signal player_died
signal boss_started(boss_name: String, max_hp: int)
signal boss_hp_changed(hp: int)
signal boss_defeated(boss_name: String, is_final: bool)
signal show_message(text: String, seconds: float)
signal score_changed(score: int)
signal shake_requested(strength: float)

const INTRO_SCENE := "res://scenes/ui/intro.tscn"
const TITLE_SCENE := "res://scenes/ui/title.tscn"
const LEVEL_SCENE := "res://scenes/level/level_1.tscn"

var score := 0
var bosses_defeated := 0
var run_time := 0.0
var running := false
var in_boss_fight := false   ## true while an arena is locked (saving is disabled)
var loaded_from_save := false


func _process(delta: float) -> void:
	if running:
		run_time += delta


func start_game() -> void:
	score = 0
	bosses_defeated = 0
	run_time = 0.0
	SaveGame.pending = {}
	loaded_from_save = false
	_enter_level()


func restart_level() -> void:
	start_game()


## Loads the save file and starts the level from it. Returns false if there
## is no usable save.
func continue_game() -> bool:
	var data := SaveGame.read()
	if data.is_empty():
		return false
	score = int(data.get("score", 0))
	bosses_defeated = int(data.get("bosses_defeated", 0))
	run_time = float(data.get("run_time", 0.0))
	SaveGame.pending = data
	loaded_from_save = true
	_enter_level()
	return true


func _enter_level() -> void:
	running = true
	in_boss_fight = false
	get_tree().paused = false
	Audio.set_muffled(false)
	get_tree().change_scene_to_file(LEVEL_SCENE)


func go_to_title() -> void:
	running = false
	in_boss_fight = false
	get_tree().paused = false
	Audio.set_muffled(false)
	get_tree().change_scene_to_file(TITLE_SCENE)


func add_score(amount: int) -> void:
	score += amount
	score_changed.emit(score)


## Screen shake, scaled by the "Screen shake" setting (0 % turns it off).
func shake(strength: float = 3.0) -> void:
	var k: float = Settings.get_value("video/screen_shake") / 100.0
	if k > 0.0:
		shake_requested.emit(strength * k)


func message(text: String, seconds: float = 2.0) -> void:
	show_message.emit(text, seconds)


## Short "hit-stop" freeze that makes big hits feel heavy.
func hit_stop(seconds: float = 0.05) -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	Engine.time_scale = 1.0


func format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	return "%02d:%02d" % [m, s]
