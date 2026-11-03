extends SceneTree
## Offline only: fit a generous capsule to the actual forest before shipping the route.
func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in range(12): await physics_frame
	var space := world.get_world_3d().direct_space_state
	var terrain: Array[RID] = []
	var others: Array[RID] = []
	for body in world.find_children("*", "CollisionObject3D", true, false):
		if "Terrain" in str(body.get_path()): terrain.append(body.get_rid())
		else: others.append(body.get_rid())
	var graph := AStar3D.new()
	var ids := {}
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.48
	capsule.height = 1.85
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.exclude = terrain
	for gz in range(-140, 61):
		for gx in range(-88, 64):
			var x := gx * 0.75
			var z := gz * 0.75
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 25, z), Vector3(x, -3, z), 1, others))
			if not hit.is_empty():
				var support := space.intersect_ray(PhysicsRayQueryParameters3D.create(hit.position + Vector3.UP * 2.0, hit.position - Vector3.UP * 0.1, 1))
				if not support.is_empty() and support.normal.y > 0.82: hit = support
			if hit.is_empty() or hit.normal.y < 0.82 or hit.position.y < -0.5: continue
			var p: Vector3 = hit.position
			query.transform = Transform3D(Basis.IDENTITY, p + Vector3.UP * 1.02)
			if not space.intersect_shape(query, 1).is_empty(): continue
			var id := graph.get_available_point_id()
			graph.add_point(id, p)
			ids[Vector2i(gx, gz)] = id
	for key: Vector2i in ids:
		for step in [Vector2i(1,0), Vector2i(0,1), Vector2i(1,1), Vector2i(-1,1)]:
			var next: Vector2i = key + step
			if not ids.has(next): continue
			var a := graph.get_point_position(ids[key])
			var b := graph.get_point_position(ids[next])
			if absf(a.y - b.y) > 0.35: continue
			query.transform.origin = a + Vector3.UP * 1.02
			query.motion = b - a
			if space.cast_motion(query)[0] < 0.999: continue
			graph.connect_points(ids[key], ids[next])
	var anchors := [Vector3(-55,12,7), Vector3(-13,1,8), Vector3(34,2,-40)]
	var route: Array = []
	var length := 0.0
	for i in range(anchors.size()-1):
		var path := graph.get_point_path(graph.get_closest_point(anchors[i]), graph.get_closest_point(anchors[i+1]))
		if path.is_empty():
			push_error("Disconnected herbalist route at %d" % i)
			quit(1)
			return
		print("ROUTE_ANCHORS ", path[0], " -> ", path[path.size()-1])
		for j in range(path.size()):
			if j + 1 < path.size(): length += path[j].distance_to(path[j+1])
			if j == 0 and not route.is_empty(): continue
			route.append([path[j].x,path[j].y,path[j].z])
	FileAccess.open("res://assets/characters/maelor_route.json", FileAccess.WRITE).store_string(JSON.stringify({"points":route,"length_m":length}, "\t"))
	var curve := Curve3D.new()
	curve.bake_interval = 0.25
	for point in route: curve.add_point(Vector3(point[0],point[1],point[2]))
	ResourceSaver.save(curve, "res://assets/characters/maelor_route.tres")
	print("START_DISTANCE ", curve.get_closest_offset(Vector3(-13,1,8)))
	print("HERBALIST_ROUTE points=", route.size(), " length=", length)
	world.queue_free()
	for i in range(4): await process_frame
	quit()
