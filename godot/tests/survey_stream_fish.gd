extends SceneTree

func _initialize() -> void:
	call_deferred("survey")

func survey() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 4:
		await process_frame
	for water: MeshInstance3D in world.find_children("Water", "MeshInstance3D", true, false):
		print("WATER ", water.get_path(), " ", water.global_transform * water.get_aabb())
	var fish = load("res://scenes/truite.tscn").instantiate()
	root.add_child(fish)
	for mesh: MeshInstance3D in fish.find_children("*", "MeshInstance3D", true, false):
		print("FISH_MESH ", mesh.name, " bounds=", fish.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb())
	print("ANIMATIONS ", fish.animator.get_animation_list())
	world.queue_free()
	fish.queue_free()
	await process_frame
	quit()
