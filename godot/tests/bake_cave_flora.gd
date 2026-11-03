extends SceneTree

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	await physics_frame
	await physics_frame
	var cave: Node3D = world.get_node("GrotteEntree")
	var original_uid := ResourceLoader.get_resource_uid("res://scenes/world/grotte_entree.tscn")
	var scene: Node3D = load("res://scenes/world/grotte_entree.tscn").instantiate()
	var flora := scene.get_node("Flora")
	for child in flora.get_children():
		flora.remove_child(child)
		child.free()
	var positions := [Vector2(-2.3, 1.4), Vector2(-2.7, 1.7), Vector2(-3.1, 1.2), Vector2(-4.4, 2.4), Vector2(-4.0, 2.9), Vector2(-4.6, 3.1), Vector2(-2.0, 3.4), Vector2(-2.4, 3.8), Vector2(-3.1, 4.6), Vector2(2.5, 1.3), Vector2(2.9, 1.5), Vector2(3.4, 1.2), Vector2(4.3, 2.5), Vector2(4.7, 2.8), Vector2(3.8, 3.1), Vector2(2.2, 4.0), Vector2(2.6, 4.4), Vector2(4.1, 4.7)]
	var samples: Array[Dictionary] = []
	for i in range(positions.size()):
		var p: Vector2 = positions[i]
		var global := cave.to_global(Vector3(p.x, 0, p.y))
		# Terrain-only ray: ignore the cave body and foliage for exact grounding.
		var query := PhysicsRayQueryParameters3D.create(global + Vector3.UP * 30, global - Vector3.UP * 15, 1)
		var excluded: Array[RID] = []
		for body in cave.find_children("*", "CollisionObject3D", true, false): excluded.append(body.get_rid())
		query.exclude = excluded
		var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
		while not hit.is_empty():
			var ancestor: Node = hit.collider
			var is_terrain := false
			while ancestor != world and ancestor != null:
				if str(ancestor.name).begins_with("Terrain"): is_terrain = true
				ancestor = ancestor.get_parent()
			if is_terrain: break
			excluded.append(hit.rid)
			query.exclude = excluded
			hit = world.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not hit.is_empty(), "Missing terrain under mushroom")
		var mushroom: Node3D = load("res://assets/items/cave_mushroom.glb").instantiate()
		mushroom.name = "GroundedMushroom%02d" % i
		flora.add_child(mushroom)
		mushroom.owner = scene
		mushroom.position = cave.to_local(hit.position) - Vector3.UP * 0.025
		mushroom.rotation.y = i * 2.399
		mushroom.scale = Vector3.ONE * (0.65 + float(i % 5) * 0.085)
		samples.append({"name": mushroom.name, "world_ground_y": hit.position.y, "local_position": str(mushroom.position)})
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/world/grotte_entree.tscn") == OK)
	if original_uid != ResourceUID.INVALID_ID:
		ResourceSaver.set_uid("res://scenes/world/grotte_entree.tscn", original_uid)
	FileAccess.open("res://tests/cave_flora_grounding.json", FileAccess.WRITE).store_string(JSON.stringify(samples, "\t"))
	scene.free()
	world.queue_free()
	await process_frame
	quit()
