extends SceneTree
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(15): await physics_frame
	var npc: CharacterBody3D = world.get_node("MaelorHerboriste")
	var player: CharacterBody3D = world.get_node("Original/Player")
	player.set_physics_process(false)
	npc.set_physics_process(false)
	var failures: Array[String] = []
	if npc.walk_clip.is_empty(): failures.append("Missing walking clip")
	if not npc.collider.shape is CapsuleShape3D: failures.append("Not a capsule")
	if npc.find_children("*", "CollisionShape3D", true, false).size() != 1: failures.append("Extra colliders")
	print("CLIPS ", npc.animator.get_animation_list())
	print("MODEL ", npc.visual.get_child(0).get_children())
	for clip in npc.animator.get_animation_list():
		var anim: Animation = npc.animator.get_animation(clip)
		print("ANIMATION ",clip," duration=",anim.length," tracks=",anim.get_track_count())
	var seconds := 0.0
	var max_error := 0.0
	while npc.laps < 3 and seconds < npc.route_length * 3.0 / npc.walk_speed + 60.0:
		player.global_position = npc.global_position + Vector3(0,0,8)
		npc._physics_process(1.0 / 60.0)
		seconds += 1.0 / 60.0
		var p: Vector3 = npc.route.sample_baked(npc.distance)
		max_error = maxf(max_error,Vector2(p.x-npc.global_position.x,p.z-npc.global_position.z).length())
		if npc.blocked_time > 4.9:
			failures.append("Blocked at %s distance %.2f" % [npc.global_position,npc.distance])
			break
		if npc.global_position.y < -1.0:
			failures.append("Fell through ground")
			break
		if int(seconds*60) % 120 == 0: await physics_frame
	if npc.laps < 3: failures.append("Did not reach house, cave, then house")
	# Player ahead: yield, then resume.
	var next: Vector3 = npc.route.sample_baked(clampf(npc.distance + npc.direction_sign * 0.6, 0.0, npc.route_length))
	var forward := (next-npc.global_position).normalized()
	player.global_position = npc.global_position + forward * 0.8
	var before := npc.global_position
	for i in range(60): npc._physics_process(1.0/60.0)
	if Vector2(before.x-npc.global_position.x,before.z-npc.global_position.z).length() > 0.15: failures.append("Does not yield")
	player.global_position = Vector3(180,20,180)
	for i in range(120): npc._physics_process(1.0/60.0)
	await physics_frame
	if not npc.distant or npc.animator.active or not npc.collider.disabled: failures.append("Distant LOD not sleeping")
	var old_distance: float = npc.distance
	for i in range(120): npc._physics_process(1.0/60.0)
	if is_equal_approx(npc.distance,old_distance): failures.append("Distant route frozen")
	player.global_position = npc.global_position + Vector3(0,0,8)
	for i in range(60): npc._physics_process(1.0/60.0)
	await physics_frame
	if npc.distant or not npc.animator.active or npc.collider.disabled: failures.append("LOD did not wake")
	var qm = root.get_node("QuestManager")
	npc._update_quest_marker()
	if not npc.quest_marker.visible: failures.append("Intro marker missing")
	qm.start_quest("echo_depths")
	npc._update_quest_marker()
	if npc.quest_marker.visible: failures.append("Intro marker remains after quest accepted")
	qm.complete_quest("echo_depths")
	npc._update_quest_marker()
	if npc.quest_marker.visible: failures.append("Intro marker remains after quest completed")
	if npc.route.get_point_position(0).distance_to(Vector3(-55,12,7)) > 3.0: failures.append("Route does not start by house")
	if npc.route.get_point_position(npc.route.point_count-1).distance_to(Vector3(34,2,-40)) > 3.0: failures.append("Route does not reach cave approach")
	print("HERBALIST_TEST ",JSON.stringify({"failures":failures,"laps":npc.laps,"simulated_seconds":seconds,"max_route_error":max_error,"length":npc.route_length}))
	FileAccess.open("res://tests/herbalist_report.json",FileAccess.WRITE).store_string(JSON.stringify({"failures":failures,"laps":npc.laps,"max_route_error":max_error,"length":npc.route_length},"\t"))
	world.queue_free()
	for i in range(4): await process_frame
	quit(0 if failures.is_empty() else 1)
