extends SceneTree
## Diagnostic only: no gameplay assets or scripts are changed.
var report := {"surfaces": [], "queries": [], "frames": [], "crossings": []}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := load("res://scenes/world/open_world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	for i in 30: await process_frame
	var player := world.get_node("Original/Player") as CharacterBody3D
	var sampler: Node = player.water_surface
	sampler.rebuild()
	for surface in sampler.surfaces:
		var bounds: AABB = surface.bounds
		var row := {"bounds": str(bounds), "triangles": surface.triangles.size() / 3}
		report.surfaces.append(row)
		print("SURFACE ", JSON.stringify(row))
	player.set_physics_process(false)
	player.get_node("WaterFootsteps").set_physics_process(false)
	for z in [85.0, 87.99, 88.01, 90.0, 110.0, 150.0]:
		for x in [0.0, 8.0, 20.0]:
			var point := Vector3(x, 3.0, z)
			var tested := 0
			for surface in sampler.surfaces:
				var b: AABB = surface.bounds
				if x >= b.position.x and x <= b.end.x and z >= b.position.z and z <= b.end.z:
					if surface.has("grids"):
						for size in surface.grids:
							var cells: Dictionary = surface.grids[size]
							tested += cells.get(Vector2i(floori(x / size), floori(z / size)), []).size()
					else:
						tested += surface.triangles.size() / 3
			var start := Time.get_ticks_usec()
			var height := -INF
			for repeat in 8: height = sampler.height_at(point)
			var row := {"x": x, "z": z, "triangles_per_query": tested, "query_ms": float(Time.get_ticks_usec() - start) / 8000.0, "height": str(height)}
			report.queries.append(row)
			print("QUERY ", JSON.stringify(row))
			await process_frame
	# Same position, same render, all gameplay active: remove only water data in memory.
	var saved: Array = sampler.surfaces.duplicate()
	player.set_physics_process(true)
	player.get_node("WaterFootsteps").set_physics_process(true)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var after := OS.get_cmdline_user_args().has("--after")
	var sample_count := 12 if OS.get_cmdline_user_args().has("--quick") else (240 if after else 60)
	for z in [87.9, 88.1]:
		for enabled in [true, false, true]:
			sampler.surfaces.assign(saved if enabled else [])
			player.global_position = Vector3(8.0, 3.0, z)
			player.velocity = Vector3.ZERO
			for i in 10: await process_frame
			var samples: Array[float] = []
			var physics := 0.0
			for i in sample_count:
				player.global_position = Vector3(8.0, 3.0, z)
				player.velocity = Vector3.ZERO
				var start := Time.get_ticks_usec()
				await process_frame
				samples.append(float(Time.get_ticks_usec() - start) / 1000.0)
				physics += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			samples.sort()
			var total := 0.0
			for value in samples: total += value
			var row := {"z": z, "water_sampling": enabled, "sample_count": sample_count, "mean_ms": total / samples.size(), "p95_ms": samples[ceili(samples.size() * 0.95) - 1], "physics_ms_last_monitor_mean": physics / samples.size(), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)}
			row["max_ms"] = samples[-1]
			report.frames.append(row)
			print("FRAMES ", JSON.stringify(row))
	if after:
		sampler.surfaces.assign(saved)
		for x in [-9.0, 8.0]:
			var samples: Array[float] = []
			var over_33 := 0
			var over_50 := 0
			for pass_index in 3:
				for frame in 180:
					var t := float(frame) / 179.0
					var z := lerpf(84.0, 94.0, t if pass_index != 1 else 1.0 - t)
					player.global_position = Vector3(x, 3, z)
					player.velocity = Vector3.ZERO
					var start := Time.get_ticks_usec()
					await process_frame
					var ms := float(Time.get_ticks_usec() - start) / 1000.0
					samples.append(ms)
					if ms > 33.333: over_33 += 1
					if ms > 50.0: over_50 += 1
			var total := 0.0
			for ms in samples: total += ms
			samples.sort()
			var row := {"x": x, "sample_count": samples.size(), "passes": 3, "mean_ms": total / samples.size(), "p95_ms": samples[ceili(samples.size() * 0.95) - 1], "max_ms": samples[-1], "over_33_ms": over_33, "over_50_ms": over_50}
			report.crossings.append(row)
			print("CROSSINGS ", JSON.stringify(row))
	var mode := "headless" if DisplayServer.get_name() == "headless" else "rendered"
	var suffix := "_after" if OS.get_cmdline_user_args().has("--after") else ""
	var file := FileAccess.open("res://../diagnostics/beach_performance_20261027/" + mode + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	world.queue_free()
	await process_frame
	quit()
