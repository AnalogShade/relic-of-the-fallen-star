extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(2)
	world.get_node("EnemyActivity").free()
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	var bandits = world.get_node("Sectors/BanditsForestiers").get_children()
	check(bandits.size() == 24, "24 forest bandits, original guard preserved")
	check(world.get_node("Sectors/Bandit_Garde").temperament == "equilibre", "Camp guard keeps original balanced behaviour")
	var spawn: Vector3 = player.global_position
	var space = world.get_world_3d().direct_space_state
	for bandit in bandits:
		check(bandit.global_position.distance_to(spawn) > bandit.leash_radius + 12, str(bandit.name) + ": safe distance from player spawn")
		bandit.set_physics_process(true)
		await frames(30)
		check(bandit.is_on_floor(), str(bandit.name) + ": grounded")
		var target := Vector3.INF
		for i in range(8):
			var candidate: Vector3 = bandit.home + Vector3(cos(i*TAU/8),0,sin(i*TAU/8))*3.5
			var ground = space.intersect_ray(PhysicsRayQueryParameters3D.create(candidate + Vector3.UP*3,candidate-Vector3.UP*4,1))
			if ground.is_empty(): continue
			if ground.normal.y < 0.85: continue
			var ray = PhysicsRayQueryParameters3D.create(bandit.global_position+Vector3.UP,ground.position+Vector3.UP,1)
			if space.intersect_ray(ray).is_empty():
				target = ground.position + Vector3.UP*0.425
				break
		check(target != Vector3.INF, str(bandit.name) + ": clear approach")
		if target != Vector3.INF:
			player.global_position = target
			player.health = 100
			player.damage_invulnerability = 0
			bandit.sight_timer = 0
			for i in range(240):
				await frames(1)
				if player.health < 100: break
			check(player.health < 100, str(bandit.name) + ": reaches and attacks player outside camp navigation")
			if player.health >= 100:
				print("DIAG target=", target, " position=", bandit.global_position, " state=", bandit.state, " sees=", bandit.sees_player, " velocity=", bandit.velocity)
				for i in range(bandit.get_slide_collision_count()):
					print("BLOCKER ", bandit.get_slide_collision(i).get_collider().get_path())
			player.global_position = spawn
			for i in range(360):
				await frames(1)
				if bandit.global_position.distance_to(bandit.home) < 0.5: break
			check(bandit.global_position.distance_to(bandit.home) < 0.6, str(bandit.name) + ": returns to its own encounter")
		bandit.set_physics_process(false)
	world.queue_free()
	await frames(2)
	print("FOREST_BANDITS_RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
