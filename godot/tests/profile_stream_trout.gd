extends SceneTree

func _initialize() -> void:
	call_deferred("profile")

func profile() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 5:
		await process_frame
	var population := world.get_node("StreamTrout")
	var fish := population.get_children()
	for trout in fish:
		trout.set_physics_process(false)
	var times: Array[float] = []
	for frame in 180:
		var start := Time.get_ticks_usec()
		for trout in fish:
			trout._physics_process(1.0/60.0)
		times.append(float(Time.get_ticks_usec()-start)/1000.0)
	times.sort()
	var total := 0.0
	for value in times:
		total += value
	print("TROUT_CPU count=",fish.size()," mean_ms=",total/times.size()," p95_ms=",times[int(times.size()*0.95)]," max_ms=",times[-1])
	var mesh := fish[0].find_child("Mesh_0",true,false) as MeshInstance3D
	if mesh:
		var vertices := 0
		for surface in mesh.mesh.get_surface_count():
			vertices += mesh.mesh.surface_get_array_len(surface)
		print("TROUT_MODEL vertices_per_fish=",vertices)
	world.queue_free()
	await process_frame
	quit()
