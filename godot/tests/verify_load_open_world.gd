extends SceneTree

func _initialize() -> void:
	print("--- VERIFYING OPEN_WORLD.TSCN LOADING ---")
	var scene: PackedScene = load("res://scenes/world/open_world.tscn")
	if scene == null:
		print("FAILED to load open_world.tscn")
		quit(1)
		return
	var inst = scene.instantiate()
	if inst == null:
		print("FAILED to instantiate open_world.tscn")
		quit(1)
		return
	root.add_child(inst)
	print("SUCCESS: open_world.tscn instantiated cleanly!")
	var bushes = inst.get_node_or_null("ArbustesABaies")
	if bushes:
		print("ArbustesABaies found with ", bushes.get_child_count(), " bushes.")
	else:
		print("ERROR: ArbustesABaies node missing!")
	inst.queue_free()
	quit(0)
