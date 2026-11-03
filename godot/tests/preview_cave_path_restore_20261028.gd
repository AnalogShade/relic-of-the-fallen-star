extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 8: await process_frame
	await physics_frame
	var cycle = world.get_node("Original/DayNightCycle")
	cycle.is_paused = true
	cycle.time_of_day = 12.0
	world.get_node("Original/Player").set_physics_process(false)
	for layer in root.find_children("*", "CanvasLayer", true, false): layer.hide()
	var excluded: Array[RID] = []
	var terrain_rids: Array[RID] = []
	for body in world.find_children("*", "CollisionObject3D", true, false):
		if "Terrain" in str(body.get_path()): terrain_rids.append(body.get_rid())
		else: excluded.append(body.get_rid())
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://../diagnostics/paths_20261021/routes.json"))
	var points: Array = data.reworked_routes["Ruisseau vers la caverne"]
	var obstacles := {}
	var holes := []
	var samples := []
	var sphere := SphereShape3D.new()
	sphere.radius = .32
	for z in range(-9,11):
		var row := ""
		for x in range(0,15):
			var ray := PhysicsRayQueryParameters3D.create(Vector3(x,100,z),Vector3(x,-10,z),1,excluded)
			var h := root.get_world_3d().direct_space_state.intersect_ray(ray)
			if h.is_empty():
				row += "?"
				continue
			var q := PhysicsShapeQueryParameters3D.new()
			q.shape = sphere
			q.transform.origin = h.position+Vector3.UP*.65
			q.collision_mask = 1
			q.exclude = terrain_rids
			var blocked := false
			for obstacle in root.get_world_3d().direct_space_state.intersect_shape(q,16):
				if obstacle.collider is StaticBody3D: blocked = true
			row += "#" if blocked else "."
		print("BANK_GRID z=",z," ",row)
	for k in points.size()-1:
		var a := Vector2(points[k][0],points[k][1])
		var b := Vector2(points[k+1][0],points[k+1][1])
		var steps := ceili(a.distance_to(b)*2)
		for i in steps+1:
			var p := a.lerp(b,float(i)/steps)
			var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,100,p.y),Vector3(p.x,-10,p.y),1,excluded)
			var hit := root.get_world_3d().direct_space_state.intersect_ray(ray)
			if hit.is_empty():
				holes.append(str(p))
				continue
			var pos: Vector3 = hit.position
			samples.append([pos.x,pos.y,pos.z])
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = sphere
			query.transform.origin = pos+Vector3.UP*.65
			query.collision_mask = 1
			query.exclude = terrain_rids
			for h in root.get_world_3d().direct_space_state.intersect_shape(query,16):
				if h.collider is StaticBody3D:
					obstacles[str(world.get_path_to(h.collider))] = str(pos)
	var report := {"samples":samples,"holes":holes,"obstacles":obstacles}
	FileAccess.open("res://../diagnostics/cave_path_restore_20261028/validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CAVE_PATH_AUDIT samples=",samples.size()," holes=",holes," obstacles=",obstacles)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.far = 1000
	cam.fov = 60
	root.size = Vector2i(1280,720)
	var views := [
		["approach",Vector3(32,6.5,14),Vector3(31,1,-23)],
		["overview",Vector3(16,29,17),Vector3(15,0,-14)],
		["crossing",Vector3(-8,6,7),Vector3(13,0,-6)]
	]
	for view in views:
		cam.position = view[1]
		cam.look_at(view[2])
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../diagnostics/cave_path_restore_20261028/"+view[0]+".png")
	print("CAVE_PATH_PREVIEWS_DONE")
	quit()
