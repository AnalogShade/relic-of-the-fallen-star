extends Node3D

func _ready() -> void:
	# Build preview scene
	var cave_scene: PackedScene = load("res://scenes/interiors/cave_depths.tscn")
	var cave: Node3D = cave_scene.instantiate()
	add_child(cave)

	for i in range(15): await get_tree().physics_frame

	var golems = cave.get_node("Golems")
	var player = cave.get_node("Player")
	player.set_physics_process(false)

	# Find a golem in room 1 or room 2
	var target_golem = golems.get_node_or_null("Golem_Balcon_1")
	if target_golem == null and golems.get_child_count() > 0:
		target_golem = golems.get_child(0)

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = target_golem.global_position + Vector3(2.5, 1.8, 2.5)
	camera.look_at(target_golem.global_position + Vector3.UP * 0.7)
	camera.current = true

	for i in range(30): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/cave_golem_patrol.png")

	# Move player close to engage combat
	player.global_position = target_golem.global_position + Vector3(1.2, 0, 0)
	player.set_physics_process(true)
	for i in range(60): await get_tree().physics_frame

	camera.position = (player.global_position + target_golem.global_position) * 0.5 + Vector3(-2.0, 1.6, 2.0)
	camera.look_at((player.global_position + target_golem.global_position) * 0.5 + Vector3.UP * 0.6)

	for i in range(10): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/cave_golem_combat.png")

	print("CAPTURES_SAVED")
	get_tree().quit(0)
