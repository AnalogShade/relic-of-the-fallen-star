extends SceneTree

func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 10:
		await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var population := world.get_node("StreamTrout") as Node3D
	var player := world.get_node("Original/Player") as Node3D
	player.set_physics_process(false)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(3.0,2.0,-3.0)
	camera.look_at(Vector3(1.4,-0.2,-6.5))
	camera.current = true
	root.size = Vector2i(1280,720)
	for enabled in [true,false,true]:
		population.process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
		population.visible = enabled
		for i in 45:
			await process_frame
		var frames: Array[float] = []
		var physics := 0.0
		for i in 120:
			var start := Time.get_ticks_usec()
			await process_frame
			frames.append(float(Time.get_ticks_usec()-start)/1000.0)
			physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0
		frames.sort()
		var total := 0.0
		for time in frames:
			total += time
		print("TROUT_RENDER enabled=",enabled," mean_frame_ms=",total/frames.size()," p95_ms=",frames[114]," physics_ms=",physics/frames.size())
	world.queue_free()
	await process_frame
	quit()
