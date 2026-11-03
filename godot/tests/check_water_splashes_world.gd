extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	root.size = Vector2i(1280, 720)
	await create_timer(1.0).timeout
	var player = world.find_child("Player", true, false)
	var sampler = player.water_surface
	var target := Vector3.INF
	var space = world.get_world_3d().direct_space_state
	for surface in sampler.surfaces:
		var triangles: PackedVector3Array = surface.triangles
		for i in range(0, triangles.size(), 3):
			var point := (triangles[i] + triangles[i + 1] + triangles[i + 2]) / 3.0
			var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point - Vector3.UP * 2, 1)
			var hit: Dictionary = space.intersect_ray(query)
			if not hit.is_empty():
				var depth: float = point.y - hit.position.y
				if depth > 0.08 and depth < 0.3:
					target = hit.position + Vector3.UP * 0.43
					break
		if target.is_finite():
			break
	assert(target.is_finite(), "Find a real shallow bank")
	player.global_position = target
	player.velocity = Vector3.ZERO
	player.world_bounds = Rect2(-2000, -2000, 4000, 4000)
	player.water_footsteps.reset()
	await create_timer(0.25).timeout
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = player.global_position + Vector3(2.0, 1.6, 3.0)
	cam.look_at(player.global_position + Vector3(0, 0.2, 0))
	cam.current = true
	player.water_footsteps.step(0)
	assert(player.water_footsteps.splash_count > 0, "Real bank must emit")
	await create_timer(0.13).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/water_splash_world.png")
	print("PRODUCTION_BANK_PASS: ", target)
	await create_timer(1.2).timeout
	world.free()
	await process_frame
	quit()
