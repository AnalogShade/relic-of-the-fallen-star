extends Node3D

func _ready() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	world.get_node("Original/HUD").hide()
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	for i in range(25): await get_tree().physics_frame
	
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.current = true
	add_child(cam)
	
	# Testing North-West view
	cam.position = Vector3(80, 85, 120)
	cam.look_at(Vector3(-80, 10, -60))
	for i in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path1 = ProjectSettings.globalize_path("res://tests/test_nw_view.png")
	get_viewport().get_texture().get_image().save_png(path1)
	print("TEST_NW_SAVED: ", path1)
	get_tree().quit()
