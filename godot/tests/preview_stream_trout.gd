extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 5:
		await process_frame
	world.get_node("Original/HUD").hide()
	world.get_node("Original/Player").set_physics_process(false)
	for layer in world.find_children("*", "CanvasLayer", true, false):
		layer.hide()
	var fish := world.get_node("StreamTrout/StreamTrout10") as Node3D
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = fish.global_position + Vector3(1.5,2.2,2.0)
	camera.look_at(fish.global_position)
	camera.fov = 52.0
	camera.current = true
	root.size = Vector2i(1280,720)
	for i in 45:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/stream_trout_preview.png")
	quit()
