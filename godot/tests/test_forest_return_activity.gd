extends SceneTree
## Exercise real cave travel and the forest's enemy suspension lifecycle.
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func snapshot(activity: Node) -> Dictionary:
	var sleeping := 0
	var disabled := 0
	var mismatches := 0
	for entry in activity.entries:
		var actor: Node3D = entry.actor
		if not is_instance_valid(actor) or actor.health <= 0.0: continue
		if entry.sleeping: sleeping += 1
		if actor.process_mode == Node.PROCESS_MODE_DISABLED: disabled += 1
		if entry.sleeping != (actor.process_mode == Node.PROCESS_MODE_DISABLED): mismatches += 1
	return {"sleeping": sleeping, "disabled": disabled, "mismatches": mismatches}

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(4)
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	var activity = world.get_node("EnemyActivity")
	var baseline := snapshot(activity)
	print("BEFORE_RETURN: ", baseline)
	check(baseline.sleeping >= 30 and baseline.mismatches == 0, "Distant enemies initially suspended")
	var inventory = root.get_node("Inventory")
	var qm = root.get_node("QuestManager")
	var travel = root.get_node("CabinTravel")
	for visit in 3:
		# First visit without loot, then with fireball, then completed quest.
		await travel.enter_cabin(world.get_node("GrotteEntree"), "res://scenes/interiors/cave_room.tscn")
		check(travel.inside and not world.is_inside_tree(), "Visit %d: forest parked inside cave" % visit)
		if visit == 1:
			await travel.enter_subroom("res://scenes/interiors/cave_depths.tscn")
			inventory.add_item("first_echo")
			inventory.collected["cave/first_echo"] = true
			await travel.leave_subroom()
		if visit == 2:
			qm.start_quest_from_cave("echo_depths")
			qm.complete_quest("echo_depths")
		await travel.leave_cabin()
		check(current_scene == world and not travel.inside, "Visit %d: original forest restored" % visit)
		await frames(20)
		var after := snapshot(activity)
		print("AFTER_RETURN_", visit, ": ", after)
		check(after.mismatches == 0, "Visit %d: sleeping flags match actual processing" % visit)
		check(after.disabled == baseline.disabled, "Visit %d: distant enemies remain suspended" % visit)
		# A nearby enemy must still wake and sleep normally after returning.
		var entry: Dictionary = activity.entries[-1]
		var actor: Node3D = entry.actor
		var origin: Vector3 = player.global_position
		var home: Vector3 = actor.home if "home" in actor else actor.home_position
		player.global_position = home + Vector3.UP
		activity.update_activity()
		check(not entry.sleeping and actor.process_mode != Node.PROCESS_MODE_DISABLED, "Visit %d: nearby encounter wakes" % visit)
		player.global_position = origin
		activity.update_activity(true)
		check(entry.sleeping and actor.process_mode == Node.PROCESS_MODE_DISABLED, "Visit %d: encounter sleeps again" % visit)
	# Preserve restoration when the manager is removed independently.
	var entries: Array = activity.entries.duplicate()
	activity.free()
	for entry in entries:
		if is_instance_valid(entry.actor):
			check(entry.actor.process_mode == entry.mode and entry.actor.visible == entry.visible, "Manager removal restores " + str(entry.actor.name))
	world.queue_free()
	await process_frame
	print("FOREST_RETURN_ACTIVITY_RESULT: %d failures" % failures)
	quit(1 if failures else 0)
