extends SceneTree

func _initialize() -> void:
	call_deferred("survey")

func survey() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var art: Node3D = load("res://assets/environment/world/tile_02_vallee_des_sources.glb").instantiate()
	world.add_child(art)
	for m in art.find_children("*", "MeshInstance3D", true, false):
		print(m.name, " ", m.global_transform, " ", m.get_aabb())
	await physics_frame
	await physics_frame
	for z in [-55, -60, -65, -70, -75]:
		for x in [9, 12, 15, 18, 21]:
			var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -5, z)))
			print("GROUND ", x, ",", z, " ", hit.get("position"), " ", hit.get("normal"))
	quit()
