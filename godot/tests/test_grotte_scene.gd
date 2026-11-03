@tool
extends SceneTree

func _init() -> void:
	print("--- TESTING GROTTE SCENE LOAD ---")
	var scene_res := load("res://scenes/world/grotte_entree.tscn") as PackedScene
	if scene_res == null:
		printerr("FAILED to load res://scenes/world/grotte_entree.tscn")
		quit(1)
		return
	var inst := scene_res.instantiate()
	if inst == null:
		printerr("FAILED to instantiate grotte scene")
		quit(1)
		return
	print("SUCCESS: Grotte scene instantiated. Children count: ", inst.get_child_count())
	for child in inst.get_children():
		print(" - Child: ", child.name, " (", child.get_class(), ")")
	inst.free()
	print("TEST COMPLETED OK")
	quit(0)
