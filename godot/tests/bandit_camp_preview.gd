extends Node3D

func _ready() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var player = world.get_node("Original/Player")
	var bandit = world.get_node("Sectors/Bandit_Garde")
	player.set_physics_process(false)
	player.position = Vector3(12.0, 3.0, -53.0)
	player.hide()
	bandit.set_physics_process(false)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(13.2, 4.5, -51.5)
	camera.look_at(bandit.global_position + Vector3(0, 0.9, 0))
	camera.current = true
	for i in range(40): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/bandit_at_camp.png")
	# Check the real terrain and approach lane using the normal enemy physics.
	bandit.set_physics_process(true)
	player.show()
	player.set_physics_process(true)
	for i in range(300): await get_tree().physics_frame
	print("CAMP_COMBAT health=", player.health, " bandit=", bandit.global_position, " player=", player.global_position, " state=", bandit.state)
	camera.position = player.global_position + Vector3(-3, 2.3, 4)
	camera.look_at((player.global_position + bandit.global_position) * 0.5 + Vector3.UP * 0.7)
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/bandit_combat.png")
	var passed: bool = player.health < 100 and bandit.is_on_floor()
	player.set_physics_process(false)
	player.position = Vector3(-20, 5, -20)
	for i in range(420): await get_tree().physics_frame
	print("CAMP_RETURN distance=", bandit.global_position.distance_to(bandit.home))
	passed = passed and bandit.global_position.distance_to(bandit.home) < 0.65
	world.queue_free()
	camera.queue_free()
	for i in range(5): await get_tree().process_frame
	get_tree().quit(0 if passed else 1)
