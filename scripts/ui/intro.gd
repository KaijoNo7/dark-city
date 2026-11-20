extends Control
## Opening cinematic (about 20 seconds, skippable with any key/button/click):
##   1. "MADE WITH GODOT" card on black
##   2. lightning reveals the rainy city, the camera slowly pans
##   3. typewriter narration in a letterbox, the three bosses flash in red
##   4. the player's officer walks in, the logo slams down, glitch flicker
##   5. fade to the title screen
## Everything is driven by one async function, _run(), using `await`.

const UI := preload("res://scripts/ui/ui_kit.gd")
const Backdrop := preload("res://scripts/ui/city_backdrop.gd")
const Weather := preload("res://scripts/level/weather.gd")
const BOSSES := [
	["res://resources/frames/boss_rook.tres", "DEADEYE ROOK"],
	["res://resources/frames/boss_bonecrusher.tres", "BONECRUSHER"],
	["res://resources/frames/boss_plague_doctor.tres", "THE PLAGUE DOCTOR"],
]
const BAR := 24.0   # letterbox bar height

var _backdrop: Control
var _weather: Node
var _black: ColorRect
var _caption: Label
var _card: Label
var _logo_root: Control
var _boss_labels: Array[Label] = []
var _reveal: Tween
var _done := false
var _started_at := 0


func _ready() -> void:
	Game.running = false
	_started_at = Time.get_ticks_msec()
	if not Settings.get_value("video/intro"):
		get_tree().change_scene_to_file.call_deferred(Game.TITLE_SCENE)
		return
	_backdrop = Backdrop.new()
	_backdrop.width = 640.0
	add_child(_backdrop)
	_weather = Weather.new()
	_weather.auto_lightning = false
	add_child(_weather)

	# Letterbox bars (cinema look) and the caption that lives in the bottom bar.
	for y in [0.0, 216.0 - BAR]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.position = Vector2(0, y)
		bar.size = Vector2(384, BAR)
		add_child(bar)
	_caption = UI.label("", 8, UI.COLOR_LIGHT)
	_caption.position = Vector2(0, 216 - BAR)
	_caption.size = Vector2(384, BAR)
	add_child(_caption)

	_logo_root = Control.new()
	_logo_root.size = Vector2(384, 216)
	_logo_root.pivot_offset = Vector2(192, 80)
	_logo_root.visible = false
	add_child(_logo_root)

	# Full-screen black on top, faded out to reveal the scene.
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_card = UI.label("", 8, UI.COLOR_LIGHT)
	_card.size = Vector2(384, 216)
	_card.modulate.a = 0.0
	add_child(_card)
	var skip := UI.label("any key: skip", 8, Color(1, 1, 1, 0.35), false)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.position = Vector2(0, 2)
	skip.size = Vector2(380, 10)
	add_child(skip)

	Audio.play_music("intro", 2.0)
	_run()


func _input(event: InputEvent) -> void:
	# Skip on any key / button / click (but not in the first moment, so a key
	# still held from launching the game doesn't skip by accident).
	if Time.get_ticks_msec() - _started_at < 400:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) \
			and event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		_finish()


# ---------------------------------------------------------------- the sequence

func _run() -> void:
	# 1. Card on black.
	_card.text = "MADE WITH  GODOT 4"
	_card.add_theme_color_override("font_color", Color(0.6, 0.75, 1.0))
	await _fade(_card, 1.0, 0.8)
	await _wait(1.4)
	await _fade(_card, 0.0, 0.6)
	if _done:
		return

	# 2. Lightning reveal + slow pan across the street.
	_weather.strike(0.25)
	_reveal = create_tween()
	_reveal.tween_property(_black, "color:a", 0.15, 0.08)
	_reveal.tween_property(_black, "color:a", 0.8, 0.25)
	_reveal.tween_property(_black, "color:a", 0.0, 2.0)
	var pan := create_tween()
	pan.tween_method(_backdrop.set_pan, 0.0, 200.0, 17.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _wait(1.4)

	# 3. Narration.
	await _type("02:47 AM.   THE POWER GRID IS DOWN.")
	await _wait(1.3)
	await _type("THREE GANGS HAVE TAKEN THE STREETS...")
	await _wait(0.5)
	for i in BOSSES.size():
		await _reveal_boss(i)
	await _wait(0.6)
	for l in _boss_labels:
		create_tween().tween_property(l, "modulate:a", 0.0, 0.5)
	await _type("ONE OFFICER IS STILL ON DUTY.")
	await _officer_walks_in()
	await _wait(0.8)

	# 4. Logo.
	_caption.text = ""
	await _logo_slam()
	await _wait(2.4)
	_finish()


func _reveal_boss(i: int) -> void:
	if _done:
		return
	# Bosses stand on the right, in silhouette, and flash red when named.
	# The street is panning, so convert a screen x into the layer's local x.
	var feet := Vector2(262 + i * 44 - _backdrop.near.position.x, 184)
	var a: AnimatedSprite2D = _backdrop.actor(BOSSES[i][0], feet, 2.0, true)
	a.modulate = Color(0, 0, 0, 0)
	var name_label := UI.label(BOSSES[i][1], 8, UI.COLOR_DANGER)
	name_label.position = Vector2(0, 30 + i * 12)
	name_label.size = Vector2(384, 12)
	name_label.modulate.a = 0.0
	add_child(name_label)
	_boss_labels.append(name_label)
	Audio.sfx("slam", null, 0.8 + i * 0.1, -6.0)
	var t := create_tween()
	t.tween_property(a, "modulate", Color(1.6, 0.3, 0.3, 1.0), 0.08)
	t.parallel().tween_property(name_label, "modulate:a", 1.0, 0.08)
	t.tween_property(a, "modulate", Color(0.12, 0.05, 0.1, 1.0), 0.6)
	await _wait(0.9)


func _officer_walks_in() -> void:
	if _done:
		return
	var who := Settings.character()
	var a: AnimatedSprite2D = _backdrop.actor(who.frames, Vector2(_backdrop.near.position.x * -1 + 20, 184), 2.0)
	a.self_modulate = Settings.tint()
	a.play("walk")
	var target := a.position.x + 110.0
	var t := create_tween()
	t.tween_property(a, "position:x", target, 1.8)
	t.tween_callback(a.play.bind("idle"))
	var tag := UI.label("OFFICER  " + Settings.display_name(), 8, UI.COLOR_ACCENT)
	tag.position = Vector2(0, 216 - BAR - 14)
	tag.size = Vector2(384, 12)
	tag.modulate.a = 0.0
	add_child(tag)
	create_tween().tween_property(tag, "modulate:a", 1.0, 0.6).set_delay(1.0)
	await _wait(2.0)


func _logo_slam() -> void:
	if _done:
		return
	_weather.strike(0.1)
	_logo_root.visible = true
	# Two coloured "ghost" copies behind the logo give a glitchy RGB split.
	var ghosts: Array[Label] = []
	for c in [Color(1, 0.1, 0.3, 0.7), Color(0.1, 0.9, 1, 0.7)]:
		var g := UI.label("DARK CITY", 32, c, false)
		g.size = Vector2(384, 40)
		g.position = Vector2(0, 60)
		_logo_root.add_child(g)
		ghosts.append(g)
	var logo := UI.label("DARK CITY", 32, UI.COLOR_ACCENT)
	logo.size = Vector2(384, 40)
	logo.position = Vector2(0, 60)
	_logo_root.add_child(logo)
	var sub := UI.label("one night  -  one street  -  three bosses", 8, UI.COLOR_LIGHT)
	sub.size = Vector2(384, 12)
	sub.position = Vector2(0, 100)
	sub.modulate.a = 0.0
	_logo_root.add_child(sub)

	_logo_root.scale = Vector2(3.5, 3.5)
	_logo_root.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_logo_root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_logo_root, "modulate:a", 1.0, 0.15)
	await _wait(0.3)
	Audio.sfx("slam")
	# Shake the logo and jitter the ghosts for a moment.
	for i in 12:
		if _done:
			return
		var s := 4.0 * (1.0 - i / 12.0)
		_logo_root.position = Vector2(randf_range(-s, s), randf_range(-s, s)).round()
		ghosts[0].position = Vector2(randf_range(-3, 0), 60 + randf_range(-1, 1))
		ghosts[1].position = Vector2(randf_range(0, 3), 60 + randf_range(-1, 1))
		await _wait(0.04)
	_logo_root.position = Vector2.ZERO
	for g in ghosts:
		create_tween().tween_property(g, "modulate:a", 0.0, 0.4)
	create_tween().tween_property(sub, "modulate:a", 1.0, 0.8)


# ---------------------------------------------------------------- helpers

## Typewriter effect: reveals the caption one character at a time.
func _type(text: String) -> void:
	if _done:
		return
	_caption.text = text
	_caption.visible_characters = 0
	for i in text.length():
		if _done:
			return
		_caption.visible_characters = i + 1
		if text[i] != " ":
			Audio.sfx("type")
		await _wait(0.045)


func _fade(node: CanvasItem, alpha: float, seconds: float) -> void:
	if _done:
		return
	var t := create_tween()
	t.tween_property(node, "modulate:a", alpha, seconds)
	await t.finished


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _finish() -> void:
	if _done:
		return
	_done = true
	if _reveal:
		_reveal.kill()   # it animates the same black overlay we fade in now
	var t := create_tween()
	t.tween_property(_black, "color:a", 1.0, 0.5)
	await t.finished
	get_tree().change_scene_to_file(Game.TITLE_SCENE)
