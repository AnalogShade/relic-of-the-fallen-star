extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	var player = world.get_node("Original/Player")
	var guard = world.get_node("Sectors/Bandit_Garde")
	player.set_physics_process(false)
	var home: Vector3 = guard.home
	var report: Array = []
	var all_passed := true
	for target in [Vector3(12, 0, -53), Vector3(22, 0, -53), Vector3(27, 0, -59), Vector3(17, 0, -66), Vector3(12, 0, -61)]:
		guard.global_position = home
		guard.velocity = Vector3.ZERO
		guard.state = "chase"
		guard.cooldown = 0.0
		guard.path_destination = Vector3.INF
		guard.path_timer = 0
		guard.sight_memory = 0
		guard.sight_timer = 0
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(target + Vector3.UP * 30, target - Vector3.UP * 5, 1))
		if hit.is_empty(): continue
		player.global_position = hit.position + Vector3.UP * 0.425
		player.health = 100
		player.damage_invulnerability = 0
		var minimum := INF
		var micros := 0
		for i in range(600):
			var start := Time.get_ticks_usec()
			await physics_frame
			micros += Time.get_ticks_usec() - start
			minimum = minf(minimum, guard.global_position.distance_to(player.global_position))
			if player.health < 100: break
		var collisions: Array = []
		for j in range(guard.get_slide_collision_count()):
			var c = guard.get_slide_collision(j)
			collisions.append({"node": str(c.get_collider().get_path()), "normal": str(c.get_normal())})
		var reached: bool = player.health < 100
		var entry := {"target": str(target), "closest": minimum, "health": player.health, "state": guard.state, "position": str(guard.global_position), "elapsed_us": micros, "collisions": collisions}
		player.global_position = Vector3(-20, 4, -20)
		for i in range(1500):
			await physics_frame
			if guard.state == "idle" and guard.global_position.distance_to(home) < 0.5: break
		entry["return_distance"] = guard.global_position.distance_to(home)
		entry["passed"] = reached and guard.global_position.distance_to(home) < 0.5
		all_passed = all_passed and entry["passed"]
		report.append(entry)
	print("ROUTE_REPORT ", JSON.stringify(report))
	var file := FileAccess.open("res://tests/bandit_routes_latest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	world.queue_free()
	await process_frame
	quit(0 if all_passed else 1)
