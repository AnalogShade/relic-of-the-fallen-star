extends SceneTree
var world: Node3D
var terrain_excluded: Array[RID] = []
var failures: Array = []
func _initialize(): call_deferred("run")
func ground(p: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x,120,p.y),Vector3(p.x,-10,p.y),1,terrain_excluded)
	return root.get_world_3d().direct_space_state.intersect_ray(q)
func run():
	world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 5: await physics_frame
	var terrain_rids: Array[RID] = []
	for n in world.find_children("*", "CollisionObject3D", true, false):
		if "/Terrain" in str(n.get_path()): terrain_rids.append(n.get_rid())
		else: terrain_excluded.append(n.get_rid())
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://../diagnostics/paths_20261021/routes.json"))
	var walking_routes: Dictionary = data.reworked_routes.duplicate(true)
	var forest_edges: Array = []
	for edge in data.segments:
		if edge[0][0] > -100 and edge[1][0] > -100 and edge[0][0] < 96 and edge[1][0] < 96 and edge[0][1] > -104 and edge[1][1] > -104:
			forest_edges.append(edge)
	for i in forest_edges.size():
		data.reworked_routes["forest_%d" % i] = forest_edges[i]
	var sphere := SphereShape3D.new()
	sphere.radius = .32
	var sampled := 0
	var max_grade := 0.0
	var route_reports := {}
	for route_name in data.reworked_routes:
		var points: Array = data.reworked_routes[route_name]
		var grades := []
		var obstacles := {}
		var previous := Vector3.ZERO
		for k in range(points.size()-1):
			var a := Vector2(points[k][0],points[k][1])
			var b := Vector2(points[k+1][0],points[k+1][1])
			var steps := ceili(a.distance_to(b)*2)
			for step in steps:
				var p := a.lerp(b,float(step)/steps)
				var hit := ground(p)
				if hit.is_empty():
					failures.append({"route":route_name,"hole":str(p)})
					continue
				var pos: Vector3 = hit.position
				if previous != Vector3.ZERO:
					var grade := absf(pos.y-previous.y)/maxf(Vector2(pos.x,pos.z).distance_to(Vector2(previous.x,previous.z)),.001)
					grades.append(grade)
				previous = pos
				var q := PhysicsShapeQueryParameters3D.new()
				q.shape = sphere
				q.transform.origin = pos+Vector3.UP*.6
				q.collision_mask = 1
				q.exclude = terrain_rids
				for obstacle in root.get_world_3d().direct_space_state.intersect_shape(q,16):
					var path := str(world.get_path_to(obstacle.collider))
					if "/Player" in path or "Rabbit" in path or "Maelor" in path: continue
					obstacles[path] = str(p)
				sampled += 1
		var max_route: float = grades.max() if not grades.is_empty() else 0.0
		route_reports[route_name] = {"max_grade":max_route,"obstacles":obstacles}
		max_grade = maxf(max_grade,max_route)
	var player := world.get_node("Original/Player") as CharacterBody3D
	player.set_physics_process(false)
	player.set_process(false)
	Engine.time_scale = 4.0
	var walked := {}
	for route_name in walking_routes:
		var points: Array = walking_routes[route_name]
		var start := ground(Vector2(points[0][0],points[0][1]))
		player.global_position = start.position + Vector3.UP*.65
		player.velocity = Vector3.ZERO
		var passed := true
		for k in range(1,points.size()):
			var target := Vector2(points[k][0],points[k][1])
			var reached := false
			for frame in 220:
				await physics_frame
				var delta := player.get_physics_process_delta_time()
				var direction := target-Vector2(player.global_position.x,player.global_position.z)
				if direction.length()<.4:
					reached = true
					break
				var velocity := direction.normalized()*3.0
				player.velocity.x = velocity.x
				player.velocity.z = velocity.y
				player.velocity.y -= 20.0*delta
				player.move_and_slide()
			if not reached:
				passed = false
				failures.append({"walking_route":route_name,"waypoint":k,"position":str(player.global_position)})
				break
		walked[route_name] = passed
	Engine.time_scale = 1.0
	print("WALKED_ROUTES ",JSON.stringify(walked))
	print("ROUTE_AUDIT ",JSON.stringify(route_reports))
	var report := {"routes":route_reports,"samples":sampled,"walked":walked,"failures":failures,"variant_trees_removed":world.get_meta("trail_variant_trees_removed",0),"instanced_obstacles_removed":world.get_meta("trail_instance_obstacles_removed",0),"groundcover_removed":world.get_meta("trail_groundcover_removed",0)}
	var f := FileAccess.open("res://../diagnostics/paths_20261021/validation.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"\t"))
	world.queue_free()
	for i in 3: await process_frame
	quit()
