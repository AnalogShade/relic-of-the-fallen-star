extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(4): await physics_frame
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		var n := str(mesh.name).to_lower()
		if "pier" in n or "dock" in n or "jetty" in n or "quai" in n or "ponton" in n:
			print("DOCK ", mesh.get_path(), " transform ", mesh.global_transform, " bounds ", mesh.get_aabb())
	var saves = root.get_node("SaveManager").list_saves()
	for save in saves:
		print("SAVE ", save.get("save_name"), " scene ", save.get("scene_file_path"), " flags ", save.get("story_flags", {}).get("story/lake_monster_defeated", false))
	world.queue_free()
	await process_frame
	quit()
