@tool
extends SceneTree

func _init() -> void:
	print("=== PROFILING DES SACCADES ET DU MOUVEMENT ===")
	var world_scene: PackedScene = load("res://scenes/world/open_world.tscn")
	var world: Node3D = world_scene.instantiate()
	root.add_child(world)

	for i in range(10):
		await process_frame

	var player := world.find_child("Player", true, false) as CharacterBody3D
	if player == null:
		printerr("Player not found!")
		quit(1)
		return

	var routes := [
		{"name": "Camp des bandits (patrouille/marche)", "start": Vector3(17.0, 2.35, -56.0), "dir": Vector3(-1, 0, 1).normalized()},
		{"name": "Berge de la riviere (le long de l'eau)", "start": Vector3(2.5, 1.5, -60.0), "dir": Vector3(0, 0, 1).normalized()},
		{"name": "Maison de Maelor (abords et marches)", "start": Vector3(-55.0, 12.0, 4.0), "dir": Vector3(0, 0, -1).normalized()},
		{"name": "Pleine foret (zone temoin)", "start": Vector3(-15.0, 3.5, 12.0), "dir": Vector3(1, 0, 0).normalized()}
	]

	for r in routes:
		player.global_position = r["start"]
		player.velocity = Vector3.ZERO
		
		# Settle
		for i in range(10):
			await process_frame

		var spike_count := 0
		var max_frame_ms := 0.0
		var max_physics_ms := 0.0
		var collision_counts: Array[int] = []
		var frame_durations: Array[float] = []

		# Simulate 120 frames of active player movement (2 seconds of running)
		for f in range(120):
			var t_start := Time.get_ticks_usec()
			
			# Apply input / move
			var run_dir: Vector3 = r["dir"]
			player.velocity.x = run_dir.x * 6.0
			player.velocity.z = run_dir.z * 6.0
			if not player.is_on_floor():
				player.velocity.y -= 20.0 * (1.0 / 60.0)

			await physics_frame
			
			var t_end := Time.get_ticks_usec()
			var dur_ms := float(t_end - t_start) / 1000.0
			frame_durations.append(dur_ms)
			if dur_ms > max_frame_ms:
				max_frame_ms = dur_ms
			if dur_ms > 20.0: # Any frame longer than 20ms at 60fps
				spike_count += 1
			
			collision_counts.append(player.get_slide_collision_count())

		var avg_ms := 0.0
		for d in frame_durations: avg_ms += d
		avg_ms /= float(frame_durations.size())

		var avg_col := 0.0
		var max_col := 0
		for c in collision_counts:
			avg_col += c
			if c > max_col: max_col = c
		avg_col /= float(collision_counts.size())

		print("\nRESULTATS : %s" % r["name"])
		print("  Moyenne : %.2f ms | Max frame : %.2f ms | Spikes (>20ms) : %d / 120" % [avg_ms, max_frame_ms, spike_count])
		print("  Collisions par frame (move_and_slide) : Moyenne=%.1f, Max=%d" % [avg_col, max_col])

	world.queue_free()
	print("\n=== FIN DU PROFILING ===")
	quit(0)
