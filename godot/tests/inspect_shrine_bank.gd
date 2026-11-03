extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 30: await physics_frame
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var water := world.get_node("Sectors/Tile_07_meandres_du_sud").find_child("Water", true, false) as MeshInstance3D
	var rows := {}
	for v in water.mesh.get_faces():
		var p: Vector3 = water.global_transform * v
		var key := snappedf(p.z, 0.001)
		if not rows.has(key): rows[key] = [p.x, p.x, p.y]
		rows[key][0] = minf(rows[key][0], p.x)
		rows[key][1] = maxf(rows[key][1], p.x)
	for key in rows:
		if absf(key - 4.0) < 0.15 or absf(key) < 0.15:
			print("SHORE ", key, " ", rows[key])
	for z in [26.0, 30.0, 34.0, 38.0]:
		var samples := []
		for x in range(-7, 8):
			var p := Vector3(x, 0, z)
			var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 10, p - Vector3.UP * 5, 1))
			if not hit.is_empty(): samples.append([x, snappedf(hit.position.y, 0.001), str(hit.collider.get_path())])
		print("PROFILE z=", z, " ", samples)
	if DisplayServer.get_name() != "headless":
		world.get_node("Original/HUD").hide()
		player.hide()
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.transform = str_to_var(JSON.parse_string(FileAccess.get_file_as_string("res://tests/shrine_editor_camera.json")).transform)
		camera.fov = 70.01
		camera.current = true
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/shrine_bank_current.png")
	world.queue_free()
	await process_frame
	quit()



