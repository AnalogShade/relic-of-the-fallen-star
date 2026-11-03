extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 5:
		await process_frame
	var population := world.get_node("StreamTrout")
	var fish := population.get_children()
	assert(fish.size() >= 9, "Trout must populate the stream")
	var sizes := {}
	var sections := {}
	var lake := world.get_node("Sectors/OasisDuNord/Truites")
	assert(lake.get_child_count() == 7, "Keep all seven original lake trout")
	for trout in lake.get_children():
		assert(trout.get_script().resource_path == "res://scripts/truite.gd")
	for trout in fish:
		trout.set_physics_process(false)
		sizes[trout.fish_scale] = true
		sections[floori((trout.home.z+104.0)/64.0)] = true
		assert(trout.animator != null and trout.animator.is_playing())
		assert(trout.animator.current_animation == "truite_swim")
		assert(trout.get_node("Model").scene_file_path == "res://assets/animals/truite.glb")
		assert(population.can_occupy(trout.global_position,trout.upstream,trout.fish_scale))
		print("STREAM_TROUT ",trout.name," size=",trout.fish_scale," home=",trout.home)
	assert(sizes.size() >= 3, "Use varied fish sizes")
	assert(sections.size() == 3, "Populate all three stream sections")
	var holding_frames := 0
	var moving_frames := 0
	var relocated := false
	for frame in 2700:
		for trout in fish:
			trout._physics_process(1.0/30.0)
			assert(population.can_occupy(trout.global_position,trout.upstream,trout.fish_scale), "Entire fish must stay between bed and surface")
			assert(trout.global_position.distance_to(trout.home) < 0.72, "No drifting out of the holding station")
			assert((-trout.global_basis.z).normalized().dot(trout.upstream) > 0.99, "Always face upstream")
			if trout.moving:
				moving_frames += 1
			else:
				holding_frames += 1
			if trout.station.distance_to(trout.home) > 0.12:
				relocated = true
	assert(relocated and moving_frames > 0, "Occasional small relocations must occur")
	assert(holding_frames > moving_frames*2, "Spend most of the time holding against the current")
	print("STREAM_TROUT_CHECK count=",fish.size()," sizes=",sizes.size()," sections=",sections.size()," simulated_seconds=90 holding_fraction=",float(holding_frames)/(holding_frames+moving_frames)," lake_trout_unchanged=7")
	world.queue_free()
	await process_frame
	quit()
