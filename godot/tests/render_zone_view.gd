extends Node3D

func _ready() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	world.get_node("Original/HUD").hide()
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	for i in range(30): await get_tree().physics_frame
	
	var cam := Camera3D.new()
	cam.far = 2500.0
	cam.current = true
	add_child(cam)
	
	# Shot 1: Perspective matching user screenshot media_1789829851924.jpg
	# Near rabbit (-8.3, 3.5, 10.4), looking South across the clearing towards the clearing & southern ocean
	cam.position = Vector3(-6.0, 22.0, -10.0)
	cam.look_at(Vector3(2.0, 2.5, 52.0))
	for i in range(25): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path1 = ProjectSettings.globalize_path("res://tests/foret_malefique_overview.png")
	get_viewport().get_texture().get_image().save_png(path1)
	print("SHOT1_SAVED: ", path1)
	
	# Shot 2: Eye-level walking from rabbit into the corrupted grove
	cam.position = Vector3(-6.0, 4.0, 16.0)
	cam.look_at(Vector3(0.0, 3.0, 40.0))
	for i in range(25): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path2 = ProjectSettings.globalize_path("res://tests/foret_malefique_eye_level.png")
	get_viewport().get_texture().get_image().save_png(path2)
	print("SHOT2_SAVED: ", path2)
	
	# Shot 3: Monoliths, stumps and corrupted pines in the clearing
	cam.position = Vector3(14.0, 4.5, 68.0)
	cam.look_at(Vector3(-2.0, 2.5, 42.0))
	for i in range(25): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path3 = ProjectSettings.globalize_path("res://tests/foret_malefique_monolith.png")
	get_viewport().get_texture().get_image().save_png(path3)
	print("SHOT3_SAVED: ", path3)

	# Shot 4: High aerial overview showing the organic ground color modulation
	cam.position = Vector3(0.0, 65.0, 20.0)
	cam.look_at(Vector3(0.0, 2.0, 52.0))
	for i in range(25): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path4 = ProjectSettings.globalize_path("res://tests/foret_malefique_south_view.png")
	get_viewport().get_texture().get_image().save_png(path4)
	print("SHOT4_SAVED: ", path4)
	
	for i in range(10): await get_tree().process_frame
	get_tree().quit()
