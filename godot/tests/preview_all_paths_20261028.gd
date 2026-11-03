extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
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
	for body in world.find_children("*", "CollisionObject3D", true, false):
		if not "Terrain" in str(body.get_path()): excluded.append(body.get_rid())
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.far = 1000.0
	cam.fov = 60.0
	root.size = Vector2i(1280,720)
	var views := [
		["forest_east",Vector2(53,0)],
		["cabin",Vector2(-54,11)],
		["western_hills",Vector2(-130,-17)],
		["mountain",Vector2(120,-71)],
		["dunes",Vector2(37,-184)],
		["corrupted_forest",Vector2(-218,-158)],
		["village",Vector2(-218,-35)],
		["stream",Vector2(-14,1)]
	]
	for view in views:
		var p: Vector2 = view[1]
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,150,p.y),Vector3(p.x,-10,p.y),1,excluded)
		var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			push_error("No terrain at preview " + view[0])
			continue
		var target: Vector3 = hit.position
		cam.position = target+Vector3(7,9,12)
		cam.look_at(target)
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../diagnostics/all_paths_20261028/"+view[0]+".png")
		print("PATH_VIEW ",view[0]," ",target)
	print("ALL_PATH_PREVIEWS_DONE")
	quit()
