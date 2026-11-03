extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var terrain := MeshInstance3D.new()
	terrain.name = "Terrain"
	var plane := PlaneMesh.new()
	plane.size = Vector2(10, 10)
	terrain.mesh = plane
	terrain.position.y = -0.6
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/ground.gdshader")
	terrain.material_override = ground
	scene.add_child(terrain)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var water_plane := PlaneMesh.new()
	water_plane.size = Vector2(3, 5)
	water.mesh = water_plane
	scene.add_child(water)
	load("res://scripts/stream_water.gd").apply(water)
	await process_frame
	await process_frame
	var seal := water.get_node("BankSeal") as MeshInstance3D
	assert(seal.mesh.get_aabb().position.y <= -0.6)
	assert(seal.mesh.get_aabb().end.y < -0.006)
	assert(seal.mesh.get_aabb().end.x > 1.5)
	assert(seal.mesh.get_aabb().position.x < -1.5)
	assert(seal.get_child_count() == 1, "Bank needs collision")
	await physics_frame
	await physics_frame
	for start in [Vector3(3, -0.15, 0), Vector3(-3, -0.15, 0), Vector3(0, -0.15, 4), Vector3(0, -0.15, -4), Vector3(3, -0.15, 4)]:
		var ray := PhysicsRayQueryParameters3D.create(start, Vector3(0, -0.15, 0))
		assert(not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(), "Side/corner opening must be blocked by terrain")
	print("BANK_GAP_CHECK opaque shores join terrain below unchanged water")
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0.5, 0.6, 0.7)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.position = Vector3(3, -0.15, 3)
	camera.look_at(Vector3(0, -0.1, 0))
	camera.current = true
	root.size = Vector2i(1000, 600)
	if DisplayServer.get_name() != "headless":
		seal.hide()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/stream_gap_before.png")
		seal.show()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/stream_gap_after.png")
	# A neighboring sector must keep the channel open across their shared edge.
	var neighbor := MeshInstance3D.new()
	neighbor.name = "WaterNeighbor"
	neighbor.mesh = water_plane
	neighbor.position.x = 3.0
	scene.add_child(neighbor)
	seal.free()
	load("res://scripts/stream_bank_seal.gd").apply(water)
	await physics_frame
	await physics_frame
	var seam_ray := PhysicsRayQueryParameters3D.create(Vector3(1.2, -0.15, 0), Vector3(1.8, -0.15, 0))
	assert(scene.get_world_3d().direct_space_state.intersect_ray(seam_ray).is_empty(), "Sector seam must remain open")
	print("BANK_GAP_CHECK side_and_corner_rays_blocked sector_seam_open")
	scene.queue_free()
	await process_frame
	quit()
