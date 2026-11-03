extends SceneTree

var failures: Array[String] = []
var tests := 0
var world: Node3D
var player: CharacterBody3D
var maelor: CharacterBody3D
var grotte: Node3D
var portal: Node3D
var quest_mgr: Node
var dialogue_mgr: Node
var save_mgr: Node
var inv: Node

func check(ok: bool, msg: String) -> void:
	tests += 1
	if ok:
		print("PASS: %s" % msg)
	else:
		failures.append(msg)
		print("FAIL: %s" % msg)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("==================================================")
	print("TEST SUITE: CAVE QUEST DIRECT ENTRY & EXIT WAITING")
	print("==================================================")

	quest_mgr = root.get_node_or_null("QuestManager")
	check(quest_mgr != null, "QuestManager is available")
	dialogue_mgr = root.get_node_or_null("DialogueManager")
	check(dialogue_mgr != null, "DialogueManager is available")
	save_mgr = root.get_node_or_null("SaveManager")
	check(save_mgr != null, "SaveManager is available")
	inv = root.get_node_or_null("Inventory")
	check(inv != null, "Inventory is available")

	if not quest_mgr or not dialogue_mgr or not save_mgr or not inv:
		_finish()
		return

	# Reset quest and inventory state
	inv.equipment.clear()
	inv.stacks.clear()
	inv.collected.clear()
	quest_mgr.quests["echo_depths"].state = 0
	quest_mgr.quests["echo_depths"]["skipped_intro"] = false
	for obj in quest_mgr.quests["echo_depths"].objectives:
		obj.completed = false
	quest_mgr.active_quest_id = ""

	# Load the actual OpenWorld scene containing GrotteEntree and Maelor
	var open_world_scene := load("res://scenes/world/open_world.tscn") as PackedScene
	check(open_world_scene != null, "OpenWorld scene loaded")
	world = open_world_scene.instantiate()
	root.add_child(world)
	current_scene = world

	await frames(15)

	grotte = world.get_node_or_null("GrotteEntree")
	check(grotte != null, "GrotteEntree exists in open world")
	portal = grotte.get_node_or_null("Portal") if grotte else null
	check(portal != null, "Grotte portal exists")

	maelor = world.get_node_or_null("MaelorHerboriste")
	check(maelor != null, "Maelor exists in open world")

	player = world.find_child("Player", true, false) as CharacterBody3D
	check(player != null, "Player exists in open world")

	# Initial state: Player has NOT talked to Maëlor
	check(not quest_mgr.is_quest_active("echo_depths"), "Quest is initially NOT active")
	check(not quest_mgr.is_quest_completed("echo_depths"), "Quest is initially NOT completed")
	check(not maelor.is_at_cave, "Maëlor is not at cave exit initially")

	# --- PART 1: PLAYER HEADS DIRECTLY TO CAVE ENTRANCE WITHOUT TALKING TO MAELOR ---
	print("\n--- TEST: Player approaches cave entrance directly ---")
	# Move player to cave entrance
	player.global_position = grotte.global_position + Vector3(0, 0, 1.5)
	await frames(10)

	check(quest_mgr.is_quest_active("echo_depths"), "Quest 'echo_depths' automatically started upon approaching cave")
	check(quest_mgr.is_quest_intro_skipped("echo_depths"), "Quest intro is flagged as skipped_intro")
	check(quest_mgr.is_objective_completed("echo_depths", 0), "Objective 0 is automatically completed")
	check(quest_mgr.is_objective_completed("echo_depths", 1), "Objective 1 (find_cave) is automatically completed")
	check(not quest_mgr.is_objective_completed("echo_depths", 2), "Objective 2 (sentinels) is still pending")
	check(not quest_mgr.is_objective_completed("echo_depths", 3), "Objective 3 (retrieve_echo) is still pending")

	# Verify journal text reflects cave start
	quest_mgr.refresh_journal_ui()
	check("falaise" in quest_mgr.quests["echo_depths"].description.to_lower(), "Quest description updated to cave origin")

	# --- PART 2: PLAYER RETRIEVES THE RELIC IN THE CAVE ---
	print("\n--- TEST: Player retrieves relic in cave depths ---")
	inv.add_item("first_echo")
	inv.collected["cave/first_echo"] = true
	quest_mgr.complete_objective("echo_depths", 2)
	quest_mgr.complete_objective("echo_depths", 3)
	check(inv.has_fireball_relic(), "Inventory confirms relic possession")

	await frames(5)

	# --- PART 3: MAELOR WAITS AT CAVE EXIT ---
	print("\n--- TEST: Maëlor waiting at cave exit ---")
	check(maelor.is_at_cave, "Maëlor transitions to waiting at the cave exit")
	var dist_maelor_to_wait_pos: float = maelor.global_position.distance_to(maelor.CAVE_WAIT_POS)
	check(dist_maelor_to_wait_pos < 0.5, "Maëlor is positioned right outside the cave entrance (dist: %.2f)" % dist_maelor_to_wait_pos)

	# Simulate player exiting cave
	player.global_position = grotte.global_position + Vector3(0, 0, 1.0)
	await frames(10)

	var dist_player_to_maelor: float = player.global_position.distance_to(maelor.global_position)
	print("Distance player to Maëlor at cave exit: ", dist_player_to_maelor)
	check(dist_player_to_maelor <= maelor.TALK_PROXIMITY + 1.0, "Player is within talk proximity of Maëlor upon exiting cave")
	check(maelor.can_interact(), "Player can immediately talk to Maëlor at cave exit")

	# --- PART 4: TALKING TO MAELOR AT CAVE EXIT COMPLETES QUEST ON FIRST TALK ---
	print("\n--- TEST: Interaction with Maëlor at cave exit ---")
	maelor.interact()
	await frames(5)

	check(dialogue_mgr.is_open, "Dialogue opens with Maëlor at cave exit")
	check(dialogue_mgr.current_pages.size() == 3, "Maëlor has 3-page revelation dialogue for direct cave explore")
	check("accouru" in dialogue_mgr.current_pages[0].to_lower(), "Dialogue recognizes Maëlor rushed to cave exit")

	# Advance pages
	dialogue_mgr._on_next_pressed()
	await frames(2)
	dialogue_mgr._on_next_pressed()
	await frames(2)
	dialogue_mgr._on_next_pressed()
	await frames(5)

	check(not dialogue_mgr.is_open, "Dialogue finishes")
	check(quest_mgr.is_quest_completed("echo_depths"), "Quest 'echo_depths' is marked COMPLETED")
	check(quest_mgr.is_objective_completed("echo_depths", 4), "Objective 4 (report_maelor) is completed")
	check(maelor.is_at_cave, "Maëlor remains at cave entrance after quest completion")

	# --- PART 5: SAVE & LOAD PERSISTENCE ---
	print("\n--- TEST: Save and Load persistence ---")
	var save_path: String = save_mgr.save_game("TestBypassQuestSave")
	check(not save_path.is_empty(), "Save game created")

	# Clear quest state
	quest_mgr.quests["echo_depths"].state = 0
	quest_mgr.quests["echo_depths"]["skipped_intro"] = false
	for obj in quest_mgr.quests["echo_depths"].objectives:
		obj.completed = false

	# Reload save
	var loaded: bool = await save_mgr.load_game_from_file(save_path)
	await frames(10)

	check(loaded, "Save game reloaded successfully")
	check(quest_mgr.is_quest_completed("echo_depths"), "Quest state restored to COMPLETED")
	check(quest_mgr.is_quest_intro_skipped("echo_depths"), "skipped_intro flag restored after load")

	var reloaded_maelor = current_scene.find_child("MaelorHerboriste", true, false)
	if reloaded_maelor:
		check(reloaded_maelor.is_at_cave, "Reloaded Maëlor remains at cave exit")

	save_mgr.delete_save(save_path)
	_finish()

func _finish() -> void:
	print("==================================================")
	print("TEST RESULTS: %d Passed, %d Failed" % [tests - failures.size(), failures.size()])
	if not failures.is_empty():
		for f in failures:
			print(" - %s" % f)
	print("==================================================")
	if is_instance_valid(world):
		world.queue_free()
	quit(0 if failures.is_empty() else 1)
