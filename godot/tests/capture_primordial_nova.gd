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
	actor.global_position = Vector3(-182, 12.3, -156)
	actor.get_node("Nael").rotation.y = PI
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = Vector3(-170, 23, -138)
	camera.look_at(actor.global_position + Vector3(0, 0.6, -2.0))
	camera.current = true
	root.get_node("Inventory").add_item("primordial_wave")
	await create_timer(0.4).timeout
	actor.nova_ability.try_cast()
	var nova = get_first_node_in_group("primordial_novas")
	nova.set_physics_process(false)
	for step in [0.16, 0.38, 0.58]:
		nova.elapsed = step
		nova._update_visuals()
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/primordial_nova_%02d.png" % int(step * 100))
		print("CAPTURED nova ", step)
	print("FRAGMENT_SHORE ", world.get_node("LakeMonster/LakeFragment").global_position)
	world.queue_free()
	await process_frame
	quit()
