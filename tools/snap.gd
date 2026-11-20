extends Node
## Developer tool: opens a scene, waits a moment and saves a screenshot.
##   godot res://tools/snap.tscn -- res://scenes/ui/title.tscn out_name
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	add_child(load(args[0]).instantiate())
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("res://tools/screenshots")
	get_viewport().get_texture().get_image().save_png("res://tools/screenshots/%s.png" % args[1])
	get_tree().quit()
