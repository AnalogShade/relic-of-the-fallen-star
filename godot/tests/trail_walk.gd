extends SceneTree

func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in range(12): await physics_frame
	var player: CharacterBody3D = world.get_node("Original/Player")
	player.set_physics_process(false)
	var excluded: Array[RID] = []
	for b in world.find_children("*", "CollisionObject3D", true, false):
		if not "Terrain" in str(b.get_path()): excluded.append(b.get_rid())
	var routes = {
		"camp": [Vector2(43,-35),Vector2(40,-36),Vector2(37,-39),Vector2(34,-43),Vector2(32,-47),Vector2(32,-51),Vector2(28,-54),Vector2(23,-54),Vector2(19,-53),Vector2(15,-53),Vector2(15,-56),Vector2(17,-56)],
		"cave": [Vector2(37,-39),Vector2(39.5,-41),Vector2(37,-43),Vector2(38,-46),Vector2(39.42,-48.26)],
		"uphill": [Vector2(39.5,-41),Vector2(42,-39),Vector2(46,-38),Vector2(48,-42),Vector2(49,-47)]
	}
	var failures: Array[String] = []
	for label in routes:
		var first: Vector2 = routes[label][0]
		var hit = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(first.x,80,first.y),Vector3(first.x,-5,first.y),1,excluded))
		player.global_position = hit.position + Vector3.UP * 0.3
		player.velocity = Vector3.ZERO
		for waypoint in routes[label]:
			var arrived := false
			for i in range(360):
				await physics_frame
				var delta := Vector3(waypoint.x-player.global_position.x,0,waypoint.y-player.global_position.z)
				if delta.length() < 0.22:
					arrived = true
					break
				var direction = delta.normalized()
				player.velocity = Vector3(direction.x*3,player.velocity.y-20.0/60.0,direction.z*3)
				player.move_and_slide()
			if not arrived:
				for j in range(player.get_slide_collision_count()):
					print("BLOCKER ", player.get_slide_collision(j).get_collider().get_path())
				failures.append("%s blocked toward %s at %s" % [label,waypoint,player.global_position])
				break
		print("ROUTE ", label, " ended at ", player.global_position)
	print("TRAIL_WALK_FAILURES ", failures)
	FileAccess.open("res://tests/trail_walk_report.json", FileAccess.WRITE).store_string(JSON.stringify({"failures":failures},"\t"))
	world.queue_free()
	for i in range(4): await process_frame
	quit(0 if failures.is_empty() else 1)



