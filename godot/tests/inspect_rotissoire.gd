extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var camp_scene = load("res://scenes/world/camp_bandits.tscn")
	var camp = camp_scene.instantiate()
	root.add_child(camp)
	
	var cam = Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(21.8, 3.6, -56.8)
	cam.look_at(Vector3(21.8, 2.9, -59.0))
	cam.current = true
	
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	root.add_child(light)
	
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/rotissoire_detail.png")
	print("SAVED rotissoire_detail.png")
	camp.free()
	quit(0)
