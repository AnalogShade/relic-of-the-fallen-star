extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	world.get_node("Original/HUD").hide()
	world.get_node("Original/Player").set_physics_process(false)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(8.5, 3.0, -96.0)
	camera.look_at(Vector3(6.4, 1.0, -108.0))
	camera.fov = 60.0
	camera.far = 1000.0
	camera.current = true
	for i in range(45):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/stream_source_preview.png")
	quit()
