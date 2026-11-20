extends Node
## Music, sound effects and ambience.
##   Audio.play_music("boss")              cross-fades to a new track
##   Audio.sfx("shoot", global_position)   positional sound effect
##   Audio.ui("ui_select")                 menu sound (never positional)
##   Audio.ambience("rain_loop")           looping background layer
##
## Sounds go to separate buses (Music, SFX, Ambience, UI) so each one has its
## own volume slider in the settings menu. All files live in asset/audio/.

const MUSIC_DIR := "res://asset/audio/music/"
const SFX_DIR := "res://asset/audio/sfx/"
const BUSES := ["Music", "SFX", "Ambience", "UI"]
const LOOPING_MUSIC := ["title", "street", "boss", "intro"]
const POOL_SIZE := 12

## Per-sound mix: volume in dB and random pitch variation (+/-), so repeated
## sounds like gunshots don't sound like a machine.
const SFX := {
	"shoot": {"db": -8.0, "pitch": 0.08},
	"enemy_shoot": {"db": -10.0, "pitch": 0.1},
	"reload": {"db": -6.0, "pitch": 0.0},
	"empty": {"db": -6.0, "pitch": 0.0},
	"throw": {"db": -8.0, "pitch": 0.1},
	"explosion": {"db": -2.0, "pitch": 0.12},
	"boss_explode": {"db": 0.0, "pitch": 0.05},
	"impact": {"db": -14.0, "pitch": 0.2},
	"enemy_hurt": {"db": -10.0, "pitch": 0.15},
	"player_hurt": {"db": -4.0, "pitch": 0.05},
	"enemy_die": {"db": -9.0, "pitch": 0.15},
	"player_die": {"db": -4.0, "pitch": 0.0},
	"jump": {"db": -14.0, "pitch": 0.08},
	"land": {"db": -12.0, "pitch": 0.1},
	"pickup_health": {"db": -6.0, "pitch": 0.0},
	"pickup_grenade": {"db": -8.0, "pitch": 0.0},
	"alarm": {"db": -10.0, "pitch": 0.0},
	"enrage": {"db": -6.0, "pitch": 0.0},
	"boss_win": {"db": -4.0, "pitch": 0.0},
	"shockwave": {"db": -6.0, "pitch": 0.1},
	"slam": {"db": -2.0, "pitch": 0.0},
	"thunder": {"db": -6.0, "pitch": 0.15},
	"type": {"db": -18.0, "pitch": 0.15},
	"power_on": {"db": -8.0, "pitch": 0.0},
	"save": {"db": -8.0, "pitch": 0.0},
}

var _streams := {}
var _music: Array[AudioStreamPlayer] = []   # two players for cross-fading
var _music_index := 0
var _music_name := ""
var _music_tween: Tween
var _pool: Array[AudioStreamPlayer] = []
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_next := 0
var _ui_players: Array[AudioStreamPlayer] = []
var _ui_next := 0
var _ambience: AudioStreamPlayer
var _ambience_name := ""
var _ambience_tween: Tween
var _ui_mute_until := 0
var _music_bus := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # menu sounds and music work while paused
	_make_buses()
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		add_child(m)
		_music.append(m)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
		var p2 := AudioStreamPlayer2D.new()
		p2.bus = "SFX"
		p2.max_distance = 520.0
		p2.attenuation = 1.4
		p2.panning_strength = 0.7
		add_child(p2)
		_pool_2d.append(p2)
	for i in 4:
		var u := AudioStreamPlayer.new()
		u.bus = "UI"
		add_child(u)
		_ui_players.append(u)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)
	Settings.changed.connect(_on_setting_changed)
	apply_volumes()


## Creates the buses in code (instead of a default_bus_layout.tres file) so
## the whole audio setup can be read in one place.
func _make_buses() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
	# A low-pass filter on the music, switched on while the game is paused:
	# the music sounds muffled, "behind a wall", instead of stopping.
	_music_bus = AudioServer.get_bus_index("Music")
	if AudioServer.get_bus_effect_count(_music_bus) == 0:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 900.0
		AudioServer.add_bus_effect(_music_bus, lp)
	AudioServer.set_bus_effect_enabled(_music_bus, 0, false)


func apply_volumes() -> void:
	_set_bus_volume("Master", Settings.get_value("audio/master"))
	_set_bus_volume("Music", Settings.get_value("audio/music"))
	_set_bus_volume("SFX", Settings.get_value("audio/sfx"))
	_set_bus_volume("Ambience", Settings.get_value("audio/ambience"))
	_set_bus_volume("UI", Settings.get_value("audio/ui"))


func _set_bus_volume(bus_name: String, percent: int) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	AudioServer.set_bus_mute(i, percent <= 0)
	# Sliders are linear (0-100 %), but loudness is logarithmic (decibels).
	AudioServer.set_bus_volume_db(i, linear_to_db(percent / 100.0) if percent > 0 else -80.0)


func _on_setting_changed(key: String) -> void:
	if key.begins_with("audio/"):
		apply_volumes()


func _stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path]


# ---------------------------------------------------------------- music

func play_music(track: String, fade: float = 1.0) -> void:
	if track == _music_name:
		return
	_music_name = track
	var stream := _stream(MUSIC_DIR + track + ".ogg")
	if stream is AudioStreamOggVorbis:
		stream.loop = track in LOOPING_MUSIC
	# A fade still running would stop the player we are about to reuse.
	if _music_tween:
		_music_tween.kill()
	var old := _music[_music_index]
	_music_index = 1 - _music_index
	var new := _music[_music_index]
	new.stream = stream
	new.volume_db = -40.0
	new.play()
	_music_tween = create_tween().set_parallel()
	_music_tween.tween_property(new, "volume_db", 0.0, fade)
	_music_tween.tween_property(old, "volume_db", -60.0, fade)
	_music_tween.chain().tween_callback(old.stop)


func stop_music(fade: float = 1.0) -> void:
	_music_name = ""
	if _music_tween:
		_music_tween.kill()
	_music[1 - _music_index].stop()
	var p := _music[_music_index]
	_music_tween = create_tween()
	_music_tween.tween_property(p, "volume_db", -60.0, fade)
	_music_tween.tween_callback(p.stop)


func current_music() -> String:
	return _music_name


## Muffles the music while a pause menu is open.
func set_muffled(on: bool) -> void:
	AudioServer.set_bus_effect_enabled(_music_bus, 0, on)


# ---------------------------------------------------------------- effects

## Plays a sound effect. Pass a world position to make it positional (it
## pans left/right and gets quieter far from the camera).
func sfx(sound: String, at: Variant = null, pitch: float = 1.0, extra_db: float = 0.0) -> void:
	var stream := _stream(SFX_DIR + sound + ".wav")
	if stream == null:
		return
	var mix: Dictionary = SFX.get(sound, {"db": -6.0, "pitch": 0.0})
	var p: Node
	if at is Vector2 and get_viewport().get_camera_2d() != null:
		var p2 := _pool_2d[_pool_next]
		p2.global_position = at
		p = p2
	else:
		p = _pool[_pool_next]
	_pool_next = (_pool_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = mix.db + extra_db
	p.pitch_scale = pitch * (1.0 + randf_range(-mix.pitch, mix.pitch))
	p.play()


## Menu sounds go to the UI bus.
func ui(sound: String) -> void:
	if Time.get_ticks_msec() < _ui_mute_until:
		return
	var p := _ui_players[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_players.size()
	p.stream = _stream(SFX_DIR + sound + ".wav")
	p.volume_db = -6.0
	p.play()


## Silences menu sounds briefly, e.g. so opening a menu (which focuses its
## first button) doesn't make a "move" blip.
func mute_ui(seconds: float = 0.15) -> void:
	_ui_mute_until = Time.get_ticks_msec() + int(seconds * 1000)


# ---------------------------------------------------------------- ambience

func ambience(sound: String, db: float = 0.0) -> void:
	if _ambience_tween:
		_ambience_tween.kill()   # same reason as in play_music()
	if sound == "":
		_ambience_name = ""
		_ambience_tween = create_tween()
		_ambience_tween.tween_property(_ambience, "volume_db", -60.0, 1.0)
		_ambience_tween.tween_callback(_ambience.stop)
		return
	if sound != _ambience_name:
		_ambience_name = sound
		var stream := _stream(SFX_DIR + sound + ".ogg")
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		_ambience.stream = stream
		_ambience.volume_db = -40.0
	if not _ambience.playing:
		_ambience.play()
	_ambience_tween = create_tween()
	_ambience_tween.tween_property(_ambience, "volume_db", db, 1.5)
