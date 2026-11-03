extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	root.size = Vector2i(1280, 720)
	for i in range(10): await physics_frame
	world.get_node("EnemyActivity").free()
	var actor = world.get_node("Original/Player")
	actor.set_physics_process(false)
	var center := Vector3(-168, 0, -135)
	var query := PhysicsRayQueryParameters3D.create(center + Vector3.UP * 100.0, center - Vector3.UP * 100.0, 1)
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	actor.global_position = hit.position + Vector3.UP * 0.08
	actor.get_node("Nael").rotation.y = PI
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = actor.global_position + Vector3(12, 14, 17)
	camera.look_at(actor.global_position + Vector3(0, 0.6, -2.0))
	camera.current = true
	root.get_node("Inventory").add_item("primordial_wave")
	await create_timer(0.4).timeout
	seed(123)
	actor.nova_ability.try_cast()
	var nova = get_first_node_in_group("primordial_novas")
	nova.set_physics_process(false)
	for step in [0.22, 0.42, 0.62]:
		nova.elapsed = step
		nova._update_visuals()
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/nova_visual_trials/world_%02d.png" % roundi(step * 100))
		print("CAPTURED textured world ", step)
	world.queue_free()
	await process_frame
	quit()
