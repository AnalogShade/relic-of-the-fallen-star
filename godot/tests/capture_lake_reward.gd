extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func capture(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/" + file + ".png")
func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(5): await physics_frame
	world.get_node("EnemyActivity").free()
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var actor = world.get_node("Original/Player")
	actor.set_physics_process(false)
	actor.global_position = Vector3(24, 6.5, -213)
	var boss = world.get_node("LakeMonster")
	boss._begin_emerge()
	boss._play("Idle", 0.0)
	boss._sync_mouth()
	boss.state = "attack"
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = Vector3(28, 12, -199)
	camera.look_at(Vector3(15, 7.5, -213))
	camera.current = true
	await create_timer(0.3).timeout
	boss.take_damage(5000, boss.mouth_area.global_position, "fireball")
	await create_timer(1.1).timeout
	await capture("lake_fragment_flight")
	boss._reset_hidden(true)
	await create_timer(1.8).timeout
	await capture("lake_fragment_dock")
	print("LAKE_REWARD_CAPTURED")
	world.queue_free()
	await process_frame
	quit()
