# Chapter 15 — The intro, a living title screen & the stage card

🎯 **Goals**
* Direct a **20-second cinematic** in code with `async` functions and `await`.
* Master **tweens**: sequences, parallel groups, `chain()`, `tween_method`, transitions and
  easing, looping tweens, and killing tweens.
* Build classic film tricks: **letterbox bars**, a **typewriter** caption, **silhouettes**, a
  **parallax pan**, a **logo slam** with an RGB-split glitch, and **lightning**.
* Make it **skippable** cleanly, and optional in the settings.
* Bring the **title screen** to life, and give the level a **stage card**.

Before this chapter the game started on a static title. A first impression decides whether
someone keeps playing, and here it costs about 300 lines.

---

## Lesson 15.1 — Storyboard first

Write the intro as a list of *beats* before writing any code:

| # | Beat | Feeling |
|---|---|---|
| 1 | "MADE WITH GODOT 4" on black | calm, a breath |
| 2 | Lightning! The rainy street appears | surprise |
| 3 | "02:47 AM. THE POWER GRID IS DOWN." | setting |
| 4 | "THREE GANGS HAVE TAKEN THE STREETS..." + three bosses flash red | threat |
| 5 | "ONE OFFICER IS STILL ON DUTY." + *your* officer walks in | hope, ownership |
| 6 | Lightning + the logo slams down | energy |
| 7 | Fade to the title | |

Beat 5 uses the character, colour and name chosen in CUSTOMIZE (chapter 13). The intro is
*about the player*, which is a good reason to build it in code rather than as a pre-rendered video.

Make the intro the main scene in **Project Settings → Application → Run → Main Scene**:
`res://scenes/ui/intro.tscn`. Like the HUD and title, the scene is one `Control` node with a
script; everything else is built in `_ready()`.

---

## Lesson 15.2 — A reusable backdrop with parallax

The intro and the title both show the night street, so it gets its own script,
`scripts/ui/city_backdrop.gd`:

```gdscript
extends Control

const TILES := preload("res://asset/Tiled/Tile1.png")
const BUILDING_BURGER := Rect2(16, 144, 128, 192)
const BUILDING_YELLOW := Rect2(192, 192, 176, 144)

@export var width := 384.0   ## how much street to build (wider for panning)

var far: Node2D
var near: Node2D
```
*(from the game)*

* `far` and `near` are **layers**: plain `Node2D`s that we move as a group.
* `width`: the title needs one screen (384 px), but the intro pans 200 px, so it builds 640 px of
  street.

```gdscript
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
```
*(from the game)*

* **Art re-use:** the distant skyline is the *same two building sprites*, tinted almost black.
  `modulate` multiplies colours, so a dark violet tint turns any sprite into a silhouette.
* **`- 18.0`** overlaps neighbours so the skyline has no gaps. `(i % 3) * 6` varies the heights a
  little: 0, 6, 12, 0, 6…
* `far` is built only up to `width * 0.5 + 400` because it scrolls slower (next).

```gdscript
func set_pan(x: float) -> void:
	near.position.x = -x
	far.position.x = -x * 0.3
```
*(from the game)*

**Parallax** in two lines: when the "camera" moves `x` pixels, near things move `x` and far things
move `0.3·x`. Our eyes read that difference as depth. (The level uses `Parallax2D` nodes for the
same effect, chapter 10. Here there's no camera, so we move layers directly.)

```gdscript
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
```
*(from the game)*

* **Position by the feet:** frames are 32 px tall and centred, so the feet are 16 px below the
  centre, ×2 when scaled. Callers just say where the ground is.
* `speed_scale` random 0.8–1.2: four characters breathing in perfect sync looks robotic.
* Returns the sprite so the caller can animate it further.

---

## Lesson 15.3 — Building the shot

```gdscript
const BAR := 24.0   # letterbox bar height

func _ready() -> void:
	Game.running = false
	_started_at = Time.get_ticks_msec()
	if not Settings.get_value("video/intro"):
		get_tree().change_scene_to_file.call_deferred(Game.TITLE_SCENE)
		return
```
*(from the game: `scripts/ui/intro.gd`)*

* **The setting** *Play intro at start* (VIDEO tab). If it's off, go straight to the title.
* **`call_deferred`** on the scene change: changing scene *inside* `_ready()` of the scene that's
  still being set up is unsafe. Deferring it to the end of the frame is the standard fix.

```gdscript
	_backdrop = Backdrop.new()
	_backdrop.width = 640.0
	add_child(_backdrop)
	_weather = Weather.new()
	_weather.auto_lightning = false
	add_child(_weather)
```
*(from the game)*

* `Weather` (lesson 15.7) brings rain, rain sound and lightning. `auto_lightning = false` because
  the intro decides exactly when lightning strikes.
* **Set exported properties before `add_child`**: the child's `_ready()` runs during `add_child`
  and must already see `width = 640`.

### Letterbox

```gdscript
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
```
*(from the game)*

Two black bars turn a 16:9 screen into a "widescreen film" frame. People instantly read it as
*"this is a cutscene, watch"*. The bottom bar is also the perfect place for subtitles: white text
on black is always readable.

### Draw order = child order

```gdscript
	_logo_root = Control.new()        # 1. logo (hidden until the end)
	...
	_black = ColorRect.new()          # 2. full-screen black, on top of the scene
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_black)
	_card = UI.label("", 8, UI.COLOR_LIGHT)   # 3. text card, on top of the black
	...
	var skip := UI.label("any key: skip", 8, Color(1, 1, 1, 0.35), false)   # 4. hint, always visible
```
*(from the game)*

Within one canvas layer, **later children draw on top**. So the black curtain hides everything
added before it, the card text sits on the curtain, and the skip hint is always on top. Fading the
curtain's alpha from 1 to 0 *reveals* the scene; fading it back to 1 *ends* it.

---

## Lesson 15.4 — Directing with `await`

The whole intro is one function that reads like a script:

```gdscript
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
	...
	await _logo_slam()
	await _wait(2.4)
	_finish()
```
*(from the game)*

### 🔤 Coroutines: `await` inside your own functions
A function containing `await` becomes a **coroutine**: it can pause and resume later. When you
`await` a coroutine, you wait until *it* has finished:

```gdscript
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _fade(node: CanvasItem, alpha: float, seconds: float) -> void:
	if _done:
		return
	var t := create_tween()
	t.tween_property(node, "modulate:a", alpha, seconds)
	await t.finished
```
*(from the game)*

* `create_timer(s).timeout` is a signal emitted after `s` seconds. `await` on a signal pauses
  until it fires.
* `Tween.finished` is emitted when the tween ends, so `await _fade(...)` waits for the fade.
* Calling `_run()` **without** `await` (as `_ready()` does) starts it and returns immediately. The
  game keeps running frames while the intro script progresses in the background. Nothing freezes.

You could build the same thing with an `AnimationPlayer` timeline. The `await` version is plain
text you can read top to bottom, diff in git, and branch with `if` and `for`. That's why it suits
an intro whose content depends on the player's profile.

### The lightning reveal

`_reveal` animates the curtain's alpha in **sequence** (each `tween_property` starts when the
previous one ends): almost transparent in 0.08 s (the flash shows the street), back to 0.8 in
0.25 s (darkness again), then slowly to 0 over 2 s (eyes adjusting). Together with the white
flash from `weather.strike()` and the thunder 0.25 s later, that's a convincing lightning reveal.
`_reveal` is kept in a member variable for lesson 15.6.

### 🔤 `tween_method` and easing
`tween_property` animates a *property*. **`tween_method(callable, from, to, duration)`** calls a
*function* every frame with the in-between value. Here it calls `_backdrop.set_pan(x)` with `x`
going 0 → 200 over 17 s, so we can animate two layers at different speeds with one tween.

* **`set_trans(Tween.TRANS_SINE)`** picks the curve's *shape* (sine, quad, cubic, back, elastic,
  bounce…).
* **`set_ease(Tween.EASE_IN_OUT)`** says which end gets the curve: slow start *and* slow end. A
  camera that starts and stops gently feels filmed; a linear one feels mechanical.

---

## Lesson 15.5 — Typewriter, silhouettes and a walking officer

### Typewriter

```gdscript
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
```
*(from the game)*

* **`Label.visible_characters`** shows only the first *n* characters, while the label keeps its
  full text. Because the full text is set from the start, the centring doesn't jump around as
  letters appear. (Setting `text` letter by letter would re-centre the line on every letter.)
* A soft blip per letter, but not for spaces: the rhythm of the sound follows the words.
* 45 ms per letter ≈ 22 letters per second: fast enough not to bore, slow enough to read along.

### Silhouettes that flash red

```gdscript
func _reveal_boss(i: int) -> void:
	if _done:
		return
	var feet := Vector2(262 + i * 44 - _backdrop.near.position.x, 184)
	var a: AnimatedSprite2D = _backdrop.actor(BOSSES[i][0], feet, 2.0, true)
	a.modulate = Color(0, 0, 0, 0)
	...
	Audio.sfx("slam", null, 0.8 + i * 0.1, -6.0)
	var t := create_tween()
	t.tween_property(a, "modulate", Color(1.6, 0.3, 0.3, 1.0), 0.08)
	t.parallel().tween_property(name_label, "modulate:a", 1.0, 0.08)
	t.tween_property(a, "modulate", Color(0.12, 0.05, 0.1, 1.0), 0.6)
	await _wait(0.9)
```
*(from the game)*

* **Screen → layer coordinates:** the street is panning, so `near` has moved left by
  `-near.position.x`. To make a boss *appear* at screen x 262, we place it at
  `262 - near.position.x` inside the layer.
* **`modulate` above 1.0** makes a sprite *brighter* than its texture: `(1.6, 0.3, 0.3)` is a
  glowing red flash. Then it settles to `(0.12, 0.05, 0.1)`, a near-black silhouette. We *see* the
  threat for a split second, then only its shape: more menacing than showing everything.
* **`parallel()`** makes the next tweener run *with* the previous one: the name fades in during
  the flash.
* Each boss's slam is pitched a bit higher (`0.8 + i * 0.1`): three hits that climb, like a drum
  build-up.

### The officer walks in

```gdscript
	var who := Settings.character()
	var a: AnimatedSprite2D = _backdrop.actor(who.frames, Vector2(_backdrop.near.position.x * -1 + 20, 184), 2.0)
	a.self_modulate = Settings.tint()
	a.play("walk")
	var target := a.position.x + 110.0
	var t := create_tween()
	t.tween_property(a, "position:x", target, 1.8)
	t.tween_callback(a.play.bind("idle"))
```
*(from the game)*

* The chosen character and tint from CUSTOMIZE.
* **`tween_callback`** runs a function at that point in the sequence: when the walk ends, switch
  to `idle`. `a.play.bind("idle")` is a `Callable` of `play` with its argument pre-filled.

---

## Lesson 15.6 — The logo slam, and skipping cleanly

```gdscript
	_logo_root.scale = Vector2(3.5, 3.5)
	_logo_root.modulate.a = 0.0
	var t := create_tween().set_parallel()
	t.tween_property(_logo_root, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_logo_root, "modulate:a", 1.0, 0.15)
	await _wait(0.3)
	Audio.sfx("slam")
```
*(from the game)*

* The logo starts 3.5× too big and transparent, and shrinks to normal while fading in. Everything
  is in `_logo_root`, whose `pivot_offset` is the logo's centre, so it scales around the centre
  instead of the top-left corner.
* **`TRANS_BACK` + `EASE_OUT`** overshoots slightly *below* 1.0 and settles back: the logo
  "lands" with a bounce.
* The slam sound plays at 0.3 s, at impact, not at the start of the motion. Sync sound to the
  moment of contact.

### RGB-split glitch

```gdscript
	var ghosts: Array[Label] = []
	for c in [Color(1, 0.1, 0.3, 0.7), Color(0.1, 0.9, 1, 0.7)]:
		var g := UI.label("DARK CITY", 32, c, false)
		...
	for i in 12:
		if _done:
			return
		var s := 4.0 * (1.0 - i / 12.0)
		_logo_root.position = Vector2(randf_range(-s, s), randf_range(-s, s)).round()
		ghosts[0].position = Vector2(randf_range(-3, 0), 60 + randf_range(-1, 1))
		ghosts[1].position = Vector2(randf_range(0, 3), 60 + randf_range(-1, 1))
		await _wait(0.04)
```
*(from the game)*

* Two copies of the logo in red and cyan sit *behind* the gold one. Jittering them a few pixels
  left and right imitates a broken video signal splitting its colour channels.
* **Shake that decays:** `s` goes from 4 px to 0 over 12 steps. `.round()` keeps the logo on
  whole pixels (no blurry sub-pixel positions in pixel art).
* Afterwards the ghosts fade out and the subtitle fades in.

### Skipping

```gdscript
func _input(event: InputEvent) -> void:
	if Time.get_ticks_msec() - _started_at < 400:
		return
	var pressed := (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) \
			and event.is_pressed() and not event.is_echo()
	if pressed:
		get_viewport().set_input_as_handled()
		_finish()


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
```
*(from the game)*

* **Any** key, button or click skips. Not mouse *motion* or stick drift, because those aren't
  `is_pressed()` button events.
* **400 ms grace period:** the key you used to launch the game might still be held down.
* **`_done` guards everything.** `_run()` is still paused somewhere inside an `await`. When it
  resumes, every helper (`_type`, `_fade`, `_reveal_boss`, `_logo_slam`) checks `_done` first and
  returns. That's how one flag stops a long chain of coroutines cleanly. When the scene changes,
  the intro node is freed, and Godot simply never resumes coroutines that belong to a freed
  object.
* **`_reveal.kill()`**: skip during the lightning reveal, and two tweens would animate the same
  alpha in opposite directions (one revealing, one fading out), which flickers. Kill the old one
  first. (The music cross-fade in chapter 14 had the same class of bug.)

### 🧪 Try it
Run the game and skip at different moments: on the card, during the typing, on a boss flash,
during the logo. Every skip should fade smoothly to the title.

---

## Lesson 15.7 — Weather: rain levels and lightning

`scripts/level/weather.gd` is used by the level, the title and the intro.

```gdscript
const RAIN_AMOUNT := [0, 60, 140, 260]
const RAIN_AMBIENCE_DB := [-80.0, -10.0, -4.0, 0.0]

@export var auto_lightning := true
@export var min_gap := 9.0
@export var max_gap := 22.0

var rain: CPUParticles2D
```
*(from the game)*

### Adopting existing rain

The level scene already contains a rain particle node (baked by `build_level.gd` in chapter 10).
Rather than regenerating the level, `level.gd` hands it over:

```gdscript
	var weather := Weather.new()
	weather.rain = get_node_or_null("Rain/Particles")
	add_child(weather)
```
*(from the game, `level.gd`)*

and `weather.gd` only makes its own if none was given:

```gdscript
func _ready() -> void:
	if rain == null:
		rain = _make_rain()
	...
	Settings.changed.connect(_on_setting_changed)
	_apply_rain()
```
*(from the game)*

### Rain from the settings

```gdscript
func _apply_rain() -> void:
	var level: int = clampi(Settings.get_value("video/rain"), 0, 3)
	rain.visible = level > 0
	rain.emitting = level > 0
	if level > 0:
		rain.amount = RAIN_AMOUNT[level]
		rain.initial_velocity_min = 240.0 + 30.0 * level
		rain.initial_velocity_max = 290.0 + 40.0 * level
	if level == 0:
		Audio.ambience("")
	else:
		Audio.ambience("rain_loop", RAIN_AMBIENCE_DB[level])
```
*(from the game)*

Heavier rain = more drops, *faster* drops and louder rain sound. Change the setting from the pause
menu and the rain behind the menu changes immediately, because `weather.gd` listens to
`Settings.changed`.

### Lightning

```gdscript
func strike(thunder_delay: float = -1.0) -> void:
	if Settings.get_value("video/lightning"):
		var t := create_tween()
		t.tween_property(_flash, "color:a", 0.55, 0.04)
		t.tween_property(_flash, "color:a", 0.05, 0.08)
		t.tween_property(_flash, "color:a", 0.35, 0.04)
		t.tween_property(_flash, "color:a", 0.0, 0.5)
	var delay := thunder_delay if thunder_delay >= 0.0 else randf_range(0.3, 1.4)
	get_tree().create_timer(delay).timeout.connect(func() -> void: Audio.sfx("thunder"))
```
*(from the game)*

* `_flash` is a full-screen pale-blue `ColorRect` on canvas layer 6: above the rain (5), below the
  HUD (10), so the HUD stays readable.
* **Double flash:** real lightning flickers. Bright → almost off → medium → slow fade.
* **Thunder comes later**, because light is faster than sound. A random 0.3–1.4 s gap suggests
  strikes at different distances.
* **Accessibility:** with *Lightning flashes* off there is no flash, but the thunder still plays.
  Bright full-screen flashes can be a real problem for photosensitive players.
* `connect(func(): ...)` on a one-shot timer: a lambda as a fire-and-forget callback. The timer
  frees itself after firing.

```gdscript
func _process(delta: float) -> void:
	if not auto_lightning:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(min_gap, max_gap)
		strike()
```
*(from the game)*

A countdown with a random reset: irregular strikes every 9–22 s. In the level, `weather.gd` pauses
with the game (default process mode), so lightning stops while you're in the pause menu.

---

## Lesson 15.8 — A title screen that breathes

The new title (`title.gd`) reuses the backdrop and the weather, then adds motion.

### Neon flicker

```gdscript
	var t := create_tween().set_loops()
	t.tween_interval(2.5)
	t.tween_property(_logo, "modulate", Color(0.5, 0.4, 0.4), 0.05)
	t.tween_property(_logo, "modulate", Color.WHITE, 0.05)
	t.tween_interval(0.1)
	t.tween_property(_logo, "modulate", Color(0.4, 0.3, 0.3), 0.04)
	t.tween_property(_logo, "modulate", Color(1.2, 1.1, 1.0), 0.06)
	t.tween_interval(4.0)
```
*(from the game)*

* **`set_loops()`** with no argument repeats the tween forever.
* `tween_interval(s)` just waits.
* A *faulty neon tube* doesn't blink regularly: it holds, stutters twice quickly, then holds
  longer. The irregular rhythm is what sells it. The last step overshoots to 1.2 brightness, a
  little surge as the tube catches.

A second looping tween slowly scales the logo 1.00 → 1.03 → 1.00 ("breathing"). Two independent
loops with different lengths rarely line up, so the motion never feels repetitive.

### Menu that slides in

```gdscript
	_menu.position.x = -120
	create_tween().tween_property(_menu, "position:x", 14.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
```
*(from the game)*

Start off-screen, slide to x = 14, fast at first and gently stopping (`EASE_OUT`).

### A footer that explains and adapts

```gdscript
	var items := [
		["CONTINUE", _continue, SaveGame.describe() if has_save else "No save yet - start a NEW GAME."],
		["NEW GAME", _new_game, "Start a fresh run from the beginning of the street."],
		["CUSTOMIZE", _open_customize, "Change your name, tag, character and colour."],
		...
	]
	for item in items:
		var b := UI.button(item[0], item[1])
		b.custom_minimum_size = Vector2(100, 14)
		b.set_meta("info", item[2])
		b.focus_entered.connect(_update_footer)
		_menu.add_child(b)
```
*(from the game)*

```gdscript
func _update_footer() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var info: String = focused.get_meta("info") if focused and focused.has_meta("info") else ""
	var p := func(a: String) -> String: return Settings.action_prompt(a)
	var controls := "Move %s/%s  Jump %s  Shoot %s  Grenade %s  Reload %s  Pause %s" % [
		p.call("move_left"), p.call("move_right"), p.call("jump"), p.call("shoot"),
		p.call("grenade"), p.call("reload"), p.call("pause")]
	_footer.text = info + "\n" + controls
```
*(from the game)*

* **Menu items as data** (`[text, action, description]`), like the settings rows in chapter 13.
* `get_viewport().gui_get_focus_owner()` returns the focused control. Its `"info"` metadata becomes
  the first footer line: hover CONTINUE and you see what the save contains.
* **The controls line is live:** `Settings.action_prompt()` returns the *current* binding on the
  *current* device. Rebind Jump to K and the title says "Jump K"; pick up a PlayStation pad and it
  says "Jump Cross". A local lambda `p` keeps the long format call short.

### Reacting to customisation

```gdscript
func _on_setting_changed(key: String) -> void:
	if key.begins_with("profile/"):
		_update_profile()
		_hero.sprite_frames = load(Settings.character().frames)
		_hero.self_modulate = Settings.tint()
		_hero.play("idle")
```
*(from the game)*

Change the character in CUSTOMIZE and the hero behind the window changes as you browse.

---

## Lesson 15.9 — The stage card

When the level starts, the HUD plays a short title card in the same film language as the intro:

```gdscript
func show_stage_card(title: String, subtitle: String) -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var bars: Array[ColorRect] = []
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.size = Vector2(384, 26)
		bar.position = Vector2(0, -26 if i == 0 else 216)
		root.add_child(bar)
		bars.append(bar)
	...
	var t := create_tween()
	t.tween_property(bars[0], "position:y", 0.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(bars[1], "position:y", 190.0, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(t1, "modulate:a", 1.0, 0.3)
	t.tween_property(t2, "modulate:a", 1.0, 0.3)
	t.tween_interval(2.2)
	t.tween_property(t1, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(t2, "modulate:a", 0.0, 0.3)
	t.tween_property(bars[0], "position:y", -26.0, 0.4)
	t.parallel().tween_property(bars[1], "position:y", 216.0, 0.4)
	t.tween_callback(root.queue_free)
```
*(from the game, `hud.gd`)*

* The bars start **just outside** the screen (y −26 and 216) and slide in together (`parallel()`).
* Title, then subtitle, fade in one after the other, hold, fade out together, bars slide out.
* **`tween_callback(root.queue_free)`**: the card cleans itself up. Nothing else has to remember
  to remove it.
* `MOUSE_FILTER_IGNORE` on the root so the card never blocks a click.

`level.gd` decides what to show:

```gdscript
	if Game.loaded_from_save:
		SaveGame.apply_pending(self)
		Game.message("SAVE LOADED\nWelcome back, " + Settings.get_value("profile/name"), 2.5)
	elif hud:
		hud.show_stage_card("STAGE 1  -  DOWNTOWN", "02:51 AM    Officer %s on patrol" % Settings.display_name())
```
*(from the game)*

"02:51 AM": four minutes after the intro's "02:47 AM". A tiny detail that ties the intro to the
game.

---

## 🏋️ Exercises

1. ★ Add a fourth narration line between the bosses and the officer:
   *"THE POLICE RADIO IS SILENT."*
2. ★ Make the intro remember that it has been seen: from the second launch, show a
   "hold any key to skip" prompt and skip only on a 1-second hold.
3. ★★ Add **car headlights** that sweep across the street during the pan (a soft yellow
   `ColorRect` or `PointLight2D` tweened across the screen).
4. ★★ Give the title screen a **"press any key"** state: the menu only appears after a key
   press, with the prompt blinking.
5. ★★★ Replace the hard-coded timeline with **data**: an array of steps like
   `["type", "text"]`, `["wait", 1.3]`, `["boss", 0]`, `["logo"]`, interpreted by a loop. Then
   write a second, shorter intro for the victory screen using the same interpreter.

## ✅ Solutions

<details><summary>Exercise 1</summary>

```gdscript
	for l in _boss_labels:
		create_tween().tween_property(l, "modulate:a", 0.0, 0.5)
	await _type("THE POLICE RADIO IS SILENT.")
	await _wait(1.0)
	await _type("ONE OFFICER IS STILL ON DUTY.")
```
Then move the screenshot time in `tools/menu_shots.gd` if you keep that tool in sync.
</details>

<details><summary>Exercise 2</summary>

```gdscript
# settings.gd DEFAULTS
"video/intro_seen": false,

# intro.gd
var _hold := 0.0

func _process(delta: float) -> void:
	if not Settings.get_value("video/intro_seen"):
		return
	var held := Input.is_anything_pressed()
	_hold = _hold + delta if held else 0.0
	if _hold >= 1.0:
		_finish()

func _input(event: InputEvent) -> void:
	if Settings.get_value("video/intro_seen"):
		return   # skipping is handled by holding, in _process
	... (the old code)

func _finish() -> void:
	...
	Settings.set_value("video/intro_seen", true)
```
`Input.is_anything_pressed()` is true while any key, mouse button or joypad button is down.
</details>

<details><summary>Exercise 3</summary>

```gdscript
func _headlights() -> void:
	var beam := ColorRect.new()
	beam.color = Color(1.0, 0.9, 0.6, 0.18)
	beam.size = Vector2(90, 30)
	beam.position = Vector2(-100, 160)
	beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(beam)
	move_child(beam, _black.get_index())   # below the curtain and the letterbox
	var t := create_tween()
	t.tween_property(beam, "position:x", 400.0, 2.5)
	t.tween_callback(beam.queue_free)
	Audio.sfx("power_on", null, 0.6, -10.0)   # or add a car sound to import_sfx.sh
```
Call `_headlights()` (without `await`) right after the first narration line.
</details>

<details><summary>Exercise 4</summary>

```gdscript
var _waiting := true
var _press: Label

# in _ready(), after _build_menu():
_menu.visible = false
_footer.visible = false
_press = UI.label("PRESS ANY KEY", 8, UI.COLOR_ACCENT)
_press.position = Vector2(0, 120)
_press.size = Vector2(384, 12)
add_child(_press)
var blink := create_tween().set_loops()
blink.tween_property(_press, "modulate:a", 0.2, 0.5)
blink.tween_property(_press, "modulate:a", 1.0, 0.5)

func _input(event: InputEvent) -> void:
	if _waiting and event.is_pressed() and not event.is_echo() and not event is InputEventMouseMotion:
		_waiting = false
		get_viewport().set_input_as_handled()
		_press.queue_free()
		_menu.visible = true
		_footer.visible = true
		UI.focus_quietly(_menu.get_child(1))
```
`queue_free()` on the label also stops its looping tween: tweens made by a node's `create_tween()`
die with that node.
</details>

<details><summary>Exercise 5</summary>

```gdscript
const SCRIPT := [
	["card", "MADE WITH  GODOT 4"],
	["reveal"],
	["wait", 1.4],
	["type", "02:47 AM.   THE POWER GRID IS DOWN."],
	["wait", 1.3],
	["type", "THREE GANGS HAVE TAKEN THE STREETS..."],
	["boss", 0], ["boss", 1], ["boss", 2],
	["type", "ONE OFFICER IS STILL ON DUTY."],
	["officer"],
	["logo"],
	["wait", 2.4],
]

func _run() -> void:
	for step in SCRIPT:
		if _done:
			return
		match step[0]:
			"card":
				_card.text = step[1]
				await _fade(_card, 1.0, 0.8)
				await _wait(1.4)
				await _fade(_card, 0.0, 0.6)
			"reveal":
				_start_reveal()          # the lightning + pan code, moved into a function
			"wait":
				await _wait(step[1])
			"type":
				await _type(step[1])
			"boss":
				await _reveal_boss(step[1])
			"officer":
				await _officer_walks_in()
			"logo":
				await _logo_slam()
	_finish()
```
This is the step from *code* to *data*. With a tiny interpreter, writers and designers can edit
cutscenes without touching the engine code. Big games do exactly this with their own scripting
formats.
</details>

## 📝 Recap

* **Storyboard the beats** before coding. Each beat has one job and one feeling.
* **`await` turns a function into a timeline** you can read top to bottom. Calling it without
  `await` runs it in the background.
* **Tweens:** sequential by default; `parallel()` for "at the same time"; `chain()` to go back to
  sequential; `set_loops()` to repeat; `tween_method` to animate a function; `tween_callback` for
  events; transitions + easing for character.
* **Film language is cheap:** letterbox bars, a typewriter caption, silhouettes, a parallax pan,
  sound on impact, a shake that decays.
* **One `_done` flag** stops a chain of coroutines cleanly, and **kill tweens** that would fight
  over the same property.
* **Respect the player:** skippable, optional in the settings, and no lightning flashes for those
  who turn them off.

🎓 That completes the additions to the course. You now have everything a small commercial game
ships with: menus, options, controller support, saves, sound, and a first impression. Go make
your own!
