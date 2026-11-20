extends Node
## Rain + lightning + thunder, controlled by the video settings.
## Used by the level, the title screen and the intro.
##
##   var w := Weather.new()        (preload this script)
##   w.rain = $Rain/Particles      optional: adopt an existing particle node
##   add_child(w)
##   w.strike()                    scripted lightning (the intro uses this)

## Particles per rain level: Off, Light, Normal, Heavy.
const RAIN_AMOUNT := [0, 60, 140, 260]
const RAIN_AMBIENCE_DB := [-80.0, -10.0, -4.0, 0.0]

@export var auto_lightning := true
@export var min_gap := 9.0     ## seconds between random strikes
@export var max_gap := 22.0

var rain: CPUParticles2D
var _flash: ColorRect
var _timer := 0.0


func _ready() -> void:
	if rain == null:
		rain = _make_rain()
	var layer := CanvasLayer.new()
	layer.layer = 6   # over the world and the rain, under the HUD (10)
	add_child(layer)
	_flash = ColorRect.new()
	_flash.color = Color(0.85, 0.9, 1.0, 0.0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_flash)
	_timer = randf_range(3.0, max_gap * 0.5)
	Settings.changed.connect(_on_setting_changed)
	_apply_rain()


func _process(delta: float) -> void:
	if not auto_lightning:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(min_gap, max_gap)
		strike()


## A lightning strike: a double flash, then thunder a moment later
## (light travels faster than sound, so the delay sells the distance).
func strike(thunder_delay: float = -1.0) -> void:
	if Settings.get_value("video/lightning"):
		var t := create_tween()
		t.tween_property(_flash, "color:a", 0.55, 0.04)
		t.tween_property(_flash, "color:a", 0.05, 0.08)
		t.tween_property(_flash, "color:a", 0.35, 0.04)
		t.tween_property(_flash, "color:a", 0.0, 0.5)
	var delay := thunder_delay if thunder_delay >= 0.0 else randf_range(0.3, 1.4)
	get_tree().create_timer(delay).timeout.connect(func() -> void: Audio.sfx("thunder"))


func _on_setting_changed(key: String) -> void:
	if key == "video/rain":
		_apply_rain()


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


## Same look as the rain baked into the level (see tools/build_level.gd).
func _make_rain() -> CPUParticles2D:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
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
	p.particle_flag_align_y = true
	p.modulate = Color(1, 1, 1, 0.5)
	layer.add_child(p)
	return p
