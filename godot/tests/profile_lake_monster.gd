extends SceneTree
var report := {}

func _initialize() -> void:
	call_deferred("run")

func summarize(values: Array[float]) -> Dictionary:
	values.sort()
	var total := 0.0
	for value in values: total += value
	return {"mean_ms": total / values.size(), "p95_ms": values[int((values.size() - 1) * 0.95)], "max_ms": values[-1]}

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(30): await physics_frame
	var player = world.get_node("Original/Player")
	var boss = world.get_node("LakeMonster")
	player.set_physics_process(false)
	player.global_position = Vector3(32, 8, -216)
	boss.set_physics_process(false)
	boss.player = player
	boss._begin_emerge()
	boss.animator.seek(5.0, true)
	var timings: Array[float] = []
	for i in range(60):
		var start := Time.get_ticks_usec()
		player.water_surface.height_at(Vector3(7 + i * 0.005, 5.5, -213))
		timings.append((Time.get_ticks_usec() - start) / 1000.0)
	report["water_height"] = summarize(timings)
	timings.clear()
	for i in range(60):
		boss.velocity = Vector3(0.45, -0.5, 0)
		var start := Time.get_ticks_usec()
		boss.move_and_slide()
		timings.append((Time.get_ticks_usec() - start) / 1000.0)
	report["move_and_slide"] = summarize(timings)
	if "--radii" in OS.get_cmdline_user_args():
		var radius_results := {}
		for radius in [3.0, 1.5, 0.75, 0.5]:
			boss.body_collision.shape.radius = radius
			await physics_frame
			timings.clear()
			for i in range(40):
				boss.velocity = Vector3(0.45, -0.5, 0)
				var start := Time.get_ticks_usec()
				boss.move_and_slide()
				timings.append((Time.get_ticks_usec() - start) / 1000.0)
			radius_results[str(radius)] = summarize(timings)
		report["radii"] = radius_results
		print("RADIUS_PROFILE ", JSON.stringify(radius_results))
	timings.clear()
	for i in range(60):
		var start := Time.get_ticks_usec()
		boss._walk_towards(player.global_position, 1.0 / 60.0)
		timings.append((Time.get_ticks_usec() - start) / 1000.0)
	report["walk_callback"] = summarize(timings)
	if boss.has_method("_water_height"):
		timings.clear()
		for i in range(60):
			var start := Time.get_ticks_usec()
			boss._water_height(Vector3(7 + i * 0.005, 5.5, -213))
			timings.append((Time.get_ticks_usec() - start) / 1000.0)
		report["boss_water_lookup"] = summarize(timings)
	var candidates := []
	for surface in player.water_surface.surfaces:
		var bounds: AABB = surface.bounds
		if 7 >= bounds.position.x and 7 <= bounds.end.x and -213 >= bounds.position.z and -213 <= bounds.end.z:
			candidates.append(surface.triangles.size() / 3)
	report["water_candidates_triangles"] = candidates
	print("CPU_PROFILE ", JSON.stringify(report))
	if "--frames" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = Vector3(37, 18, -184)
		camera.look_at(Vector3(7, 10, -213))
		camera.current = true
		var phases := ["hidden", "idle", "walk_animation", "walk_full"]
		if "--effects" in OS.get_cmdline_user_args(): phases.append("walk_full_splashes")
		for phase in phases:
			boss.visual.visible = phase != "hidden"
			boss._play("Walk" if "walk" in phase else "Idle")
			if phase == "walk_full_splashes": boss._splash(boss.global_position, true)
			for i in range(20): await process_frame
			var frames: Array[float] = []
			var callbacks: Array[float] = []
			var last := Time.get_ticks_usec()
			for i in range(60):
				await process_frame
				var now := Time.get_ticks_usec()
				frames.append((now - last) / 1000.0)
				last = now
				if phase.begins_with("walk_full"):
					var start := Time.get_ticks_usec()
					boss._walk_towards(player.global_position, 1.0 / 60.0)
					callbacks.append((Time.get_ticks_usec() - start) / 1000.0)
				if phase == "walk_full_splashes" and i % 24 == 0:
					boss._splash(boss.global_position, true)
					boss._splash(boss.global_position + Vector3(3, 0, 2), false)
			report[phase] = summarize(frames)
			if not callbacks.is_empty(): report[phase]["callback"] = summarize(callbacks)
			print("FRAME_PROFILE ", phase, " ", JSON.stringify(report[phase]))
			# GPU readback / PNG encoding is excluded from frame measurements.
			if phase == "walk_full_splashes":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://tests/lake_monster_splash_cards.png")
	var out := "res://tests/lake_monster_profile_after.json" if "--after" in OS.get_cmdline_user_args() else "res://tests/lake_monster_profile_radii.json" if "--radii" in OS.get_cmdline_user_args() else "res://tests/lake_monster_profile_before.json"
	FileAccess.open(out, FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	world.queue_free()
	await process_frame
	quit()
