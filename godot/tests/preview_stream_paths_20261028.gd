extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var label := "before"
	if not OS.get_cmdline_user_args().is_empty():
		label = OS.get_cmdline_user_args()[0]
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 8: await process_frame
	var cycle = world.get_node("Original/DayNightCycle")
	cycle.is_paused = true
	cycle.time_of_day = 12.0
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	for layer in root.find_children("*", "CanvasLayer", true, false): layer.hide()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.far = 1000.0
	cam.fov = 60.0
	root.size = Vector2i(1280,720)
	for water in world.find_children("Water", "MeshInstance3D", true, false):
		print("STREAM_BOUNDS ", water.global_transform * water.get_aabb())
	var views := [
		["junction", Vector3(-12,6,16), Vector3(-14,0,1)],
		["riverside", Vector3(16,5,-43), Vector3(15,0,-57)],
		["overview", Vector3(-14,28,22), Vector3(-10,0,-5)]
	]
	for view in views:
		cam.position = view[1]
		cam.look_at(view[2])
		for i in 20: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../diagnostics/stream_paths_20261028/" + label + "_" + view[0] + ".png")
	print("STREAM_PATH_PREVIEW_DONE ", label)
	quit()
