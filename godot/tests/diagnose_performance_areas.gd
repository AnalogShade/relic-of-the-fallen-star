@tool
extends SceneTree

func _init() -> void:
	print("=== DIAGNOSTIC PERFORMANCES & COLLIDERS ===")
	var world_scene: PackedScene = load("res://scenes/world/open_world.tscn")
	var world: Node3D = world_scene.instantiate()
	root.add_child(world)

	for i in range(10):
		await process_frame

	var player := world.find_child("Player", true, false) as CharacterBody3D
	if player == null:
		printerr("Player not found!")
		quit(1)
		return

	var test_points := {
		"Camp Bandits": Vector3(17.0, 2.35, -56.0),
		"Riviere (Milieu)": Vector3(0.0, 1.0, -100.0),
		"Maison de Maelor": Vector3(-55.0, 12.0, 1.0),
		"Spawn Foret Originale": Vector3(-7.0, 3.5, 12.0)
	}

	for zone_name in test_points.keys():
		var pos: Vector3 = test_points[zone_name]
		player.global_position = pos
		player.velocity = Vector3.ZERO
		
		# Let physics settle
		for i in range(10):
			await process_frame

		print("\n------------------------------------------------------------")
		print("ZONE : %s à %s" % [zone_name, str(pos)])
		print("------------------------------------------------------------")

		# 1. Collect all colliders within 35m
		var shape_counts := {}
		var total_colliders := 0
		var trimesh_faces := 0
		var concave_count := 0
		var bodies_near: Array[Node] = []

		var all_bodies := world.find_children("*", "CollisionObject3D", true, false)
		for body: CollisionObject3D in all_bodies:
			var body_pos := body.global_position
			if body_pos.distance_to(pos) <= 35.0:
				bodies_near.append(body)
				for child in body.find_children("*", "CollisionShape3D", true, false):
					var col_shape := child as CollisionShape3D
					if col_shape.disabled:
						continue
					total_colliders += 1
					var s := col_shape.shape
					if s != null:
						var type_name := s.get_class()
						shape_counts[type_name] = shape_counts.get(type_name, 0) + 1
						if s is ConcavePolygonShape3D:
							concave_count += 1
							var data: PackedVector3Array = (s as ConcavePolygonShape3D).get_faces()
							trimesh_faces += data.size() / 3

		print("  Total CollisionShape3D actifs dans un rayon de 35m : %d" % total_colliders)
		print("  Repartition des types de formes : ", shape_counts)
		if concave_count > 0:
			print("  ⚠️ CONCAVE (Trimesh) détectés : %d shapes, TOTAL FACES : %d polygones de collision !" % [concave_count, trimesh_faces])

		# 2. Mesure du temps par frame sur 30 frames
		var frame_times: Array[float] = []
		for f in range(30):
			var t0 := Time.get_ticks_usec()
			await process_frame
			var t1 := Time.get_ticks_usec()
			frame_times.append(float(t1 - t0) / 1000.0)

		var avg_time := 0.0
		var max_time := 0.0
		for t in frame_times:
			avg_time += t
			if t > max_time: max_time = t
		avg_time /= float(frame_times.size())
		print("  Temps moyen par frame : %.2f ms (Max : %.2f ms | FPS approx : %.0f)" % [avg_time, max_time, 1000.0 / maxf(avg_time, 0.001)])

		# 3. Mesure spécifique des CharacterBody3D et raycasts actifs dans la zone
		var chars_near := 0
		for c in world.find_children("*", "CharacterBody3D", true, false):
			if (c as CharacterBody3D).global_position.distance_to(pos) <= 35.0:
				chars_near += 1
		print("  CharacterBody3D actifs à proximité : %d" % chars_near)

	world.queue_free()
	print("\n=== FIN DU DIAGNOSTIC ===")
	quit(0)
