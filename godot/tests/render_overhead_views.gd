extends Node3D

func _ready() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	world.get_node("Original/HUD").hide()
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	
	for i in range(20): await get_tree().physics_frame
	
	var cam := Camera3D.new()
	cam.far = 3000.0
	cam.fov = 65.0
	cam.current = true
	add_child(cam)
	
	var target := Vector3(-215.0, 12.0, -35.0)
	var angles := [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
	var dist := 180.0
	var height := 160.0
	
	for idx in range(angles.size()):
		var rad := deg_to_rad(angles[idx])
		var pos := target + Vector3(sin(rad) * dist, height, cos(rad) * dist)
		cam.position = pos
		cam.look_at(target, Vector3.UP)
		
		for f in range(5): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		
		var img = get_viewport().get_texture().get_image()
		var out_path = "res://tests/overhead_angle_%d.png" % int(angles[idx])
		img.save_png(ProjectSettings.globalize_path(out_path))
		print("Saved angle: ", angles[idx])
		
	get_tree().quit()
