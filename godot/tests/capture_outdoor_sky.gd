extends SceneTree
## Real Open World captures. Run with -- before to capture the original lighting.
const OUT := "../diagnostics/outdoor_sky_20261030/"

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	for frame in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("SKY_CAPTURE ", label)

func benchmark(cycle: Node, original_env: Environment, outdoor_env: Environment) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var result := {}
	# Same frozen Open World / camera, alternating the previous and new environment.
	for label in ["original", "outdoor", "original_repeat", "outdoor_repeat"]:
		var outdoor: bool = label.begins_with("outdoor")
		cycle.world_environment.environment = outdoor_env if outdoor else original_env
		cycle.is_paused = false
		for frame in 30:
			if outdoor:
				cycle._process(1.0 / 60.0)
			await process_frame
		var start := Time.get_ticks_usec()
		for frame in 100:
			if outdoor:
				cycle._process(1.0 / 60.0)
			await process_frame
		var ms := (Time.get_ticks_usec() - start) / 100000.0
		result[label + "_frame_ms"] = ms
		print("SKY_BENCH ", label, " frame_ms=", ms)
	cycle.world_environment.environment = outdoor_env
	cycle.is_paused = true
	FileAccess.open(OUT + "performance.json", FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))

func run() -> void:
	root.size = Vector2i(1440, 900)
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for frame in 20:
		await process_frame
	var cycle = world.get_node("Original/DayNightCycle")
	cycle.is_paused = true
	for layer in root.find_children("*", "CanvasLayer", true, false):
		layer.visible = false
	world.process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("Original/Player").hide()
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	camera.far = 1400.0
	camera.fov = 70.0
	# Forest / stream overlook: enough sky to assess clouds and terrain together.
	camera.position = Vector3(26, 29, 31)
	camera.look_at(Vector3(-8, 29, -55))
	var suffix := "before" if "before" in OS.get_cmdline_user_args() else "after"
	for entry in [["day", 12.0], ["sunset", 18.5], ["night", 0.0], ["dawn", 6.0]]:
		cycle.time_of_day = entry[1]
		await capture(entry[0] + "_" + suffix)
	if suffix == "after":
		cycle.time_of_day = 12.0
		cycle.is_paused = false
		var start_hour: float = cycle.time_of_day
		# Advance clouds independently of a full day/night cycle for visual proof.
		cycle._process(40.0)
		cycle.is_paused = true
		cycle.time_of_day = start_hour
		await capture("clouds_moved_after")
		# Ground-level view from the playable forest, with the player still present.
		world.get_node("Original/Player").show()
		camera.position = Vector3(4, 6.2, 17)
		camera.look_at(Vector3(-8, 12, -45))
		await capture("forest_day_after")
		cycle.time_of_day = 0.0
		await capture("forest_night_after")
		if "benchmark" in OS.get_cmdline_user_args():
			cycle.time_of_day = 12.0
			camera.position = Vector3(26, 29, 31)
			camera.look_at(Vector3(-8, 29, -55))
			var original: Node3D = load("res://experiments/arbres_20261014/playable_forest.tscn").instantiate()
			var original_env: Environment = original.get_node("WorldEnvironment").environment.duplicate(true)
			original.free()
			await benchmark(cycle, original_env, cycle.world_environment.environment)
	world.queue_free()
	camera.queue_free()
	for frame in 3:
		await process_frame
	quit()
