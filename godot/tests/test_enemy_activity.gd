extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, message: String):
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1
func frames(count: int):
	for i in count:
		await physics_frame
		await process_frame
func run():
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(4)
	var activity = world.get_node("EnemyActivity")
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	var spawn: Vector3 = player.global_position
	var space = world.get_world_3d().direct_space_state
	check(activity.entries.size() == 41, "All 25 bandits and 16 spiders registered")
	check(activity.sleeping_count >= 30, "Distant encounters sleep near starting area")
	var actors = [world.get_node("Sectors/BanditsForestiers/Bandit_Renfort_20"),world.get_node("Sectors/AraigneesForestieres/Araignee_Forestiere_06")]
	for actor in actors:
		var original_health = actor.health
		var temperament = actor.combat.temperament
		player.global_position = spawn
		activity.update_activity(true)
		check(actor.process_mode == Node.PROCESS_MODE_DISABLED, str(actor.name)+": sleeps far away")
		var home: Vector3 = actor.home if "home" in actor else actor.home_position
		player.global_position = home + Vector3(20,1,0)
		activity.update_activity()
		check(actor.process_mode != Node.PROCESS_MODE_DISABLED, str(actor.name)+": awake before detection distance")
		await frames(25)
		check(actor.is_on_floor(), str(actor.name)+": settles on ground after waking")
		var target := Vector3.INF
		for i in 8:
			var candidate = actor.global_position + Vector3(cos(i*TAU/8),0,sin(i*TAU/8))*3.5
			var ground = space.intersect_ray(PhysicsRayQueryParameters3D.create(candidate+Vector3.UP*3,candidate-Vector3.UP*4,1))
			if ground.is_empty() or ground.normal.y < 0.85: continue
			var capsule := CapsuleShape3D.new()
			capsule.radius = 0.35
			capsule.height = 1.6
			var sweep := PhysicsShapeQueryParameters3D.new()
			sweep.shape = capsule
			sweep.collision_mask = 1
			sweep.transform.origin = actor.global_position + Vector3.UP*0.9
			sweep.motion = ground.position - actor.global_position
			if space.cast_motion(sweep)[0] < 0.99: continue
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP,ground.position+Vector3.UP,1)).is_empty():
				target = ground.position + Vector3.UP*0.425
				break
		check(target != Vector3.INF,str(actor.name)+": clear combat approach")
		if target != Vector3.INF:
			var actions: Array = []
			actor.combat.action_started.connect(func(action): actions.append(action))
			player.global_position = target
			player.health = 1000
			actor.sight_timer = 0
			activity.update_activity()
			for i in 240:
				await frames(1)
				if "windup" in actions: break
			check("windup" in actions,str(actor.name)+": pursues and attacks after waking")
			if "windup" not in actions:
				print("COMBAT_DIAG position=",actor.global_position," target=",target," state=",actor.state," sees=",actor.sees_player," mode=",actor.process_mode," actions=",actions)
				for i in actor.get_slide_collision_count(): print("COMBAT_BLOCKER ",actor.get_slide_collision(i).get_collider().get_path())
		check(actor.health == original_health and actor.combat.temperament == temperament,str(actor.name)+": health and personality preserved")
		actor.combat._reset()
		player.global_position = spawn
		activity.update_activity(true)
		check(actor.process_mode == Node.PROCESS_MODE_DISABLED,str(actor.name)+": sleeps after player leaves")
	activity.free()
	for actor in actors:
		check(actor.process_mode != Node.PROCESS_MODE_DISABLED and actor.visible, str(actor.name)+": manager removal restores encounter")
	world.queue_free()
	await process_frame
	print("ENEMY_ACTIVITY_RESULT: ",failures," failures")
	quit(0 if failures == 0 else 1)
