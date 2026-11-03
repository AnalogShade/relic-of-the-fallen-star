extends SceneTree
func _initialize() -> void:
	var model = load("res://assets/characters/nael.glb").instantiate()
	var ap: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	print("NAEL_ANIMATIONS: ", ap.get_animation_list())
	for clip in ap.get_animation_list():
		var a = ap.get_animation(clip)
		print(clip, " duration=", a.length, " tracks=", a.get_track_count(), " loop=", a.loop_mode)
	model.free()
	quit()
