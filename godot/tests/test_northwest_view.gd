extends Node3D

func _ready() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	world.get_node("Original/HUD").hide()
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	
	for i in range(25): await get_tree().physics_frame
	
	var cam = Camera3D.new()
	cam.far = 3000.0
	cam.fov = 70.0
	cam.current = true
	add_child(cam)
	
	# Try northwest camera
	cam.position = Vector3(-270.0, 75.0, -170.0)
	cam.look_at(Vector3(-140.0, 15.0, -60.0), Vector3.UP)
	
	for i in range(25): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://test_northwest_view.png")
	print("NORTHWEST VIEW SAVED")
	get_tree().quit()
