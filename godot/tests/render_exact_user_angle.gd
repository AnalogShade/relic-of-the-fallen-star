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
	
	# Standing North of Rabbit, elevated, looking South-Southwest over the clearing
	# Rabbit is at (-8.3, 3.5, 10.4)
	# Camera at (10, 55, -55) looking towards (-25, 5, 55)
	cam.position = Vector3(8.0, 48.0, -50.0)
	cam.look_at(Vector3(-25.0, 5.0, 45.0), Vector3.UP)
	
	for i in range(25): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://render_exact_user_angle.png")
	print("EXACT ANGLE SAVED")
	get_tree().quit()
