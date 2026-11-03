extends SceneTree

var failures: Array[String] = []
var tests := 0
var level: Node3D
var player: CharacterBody3D
var maelor: CharacterBody3D
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
	print("TEST SUITE: QUEST SYSTEM, MAELOR NPC & DIALOGUES")
	print("==================================================")

	quest_mgr = root.get_node_or_null("QuestManager")
	check(quest_mgr != null, "QuestManager autoload is present")
	dialogue_mgr = root.get_node_or_null("DialogueManager")
	check(dialogue_mgr != null, "DialogueManager autoload is present")
	save_mgr = root.get_node_or_null("SaveManager")
	check(save_mgr != null, "SaveManager autoload is present")
	inv = root.get_node_or_null("Inventory")
	check(inv != null, "Inventory autoload is present")

	if not quest_mgr or not dialogue_mgr or not save_mgr or not inv:
		_finish()
		return

	# Setup simple environment
	level = Node3D.new()
	root.add_child(level)
	current_scene = level

	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	col.shape = box
	floor_body.add_child(col)
	level.add_child(floor_body)

	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.5, 10.0)
	level.add_child(player)

	maelor = load("res://scenes/herbalist.tscn").instantiate()
	maelor.position = Vector3(0, 0.5, 0)
	level.add_child(maelor)

	await frames(10)

	# 0. Test initial journal visibility at startup
	check(not quest_mgr.is_journal_open, "Journal is closed initially")
	check(not quest_mgr.journal_panel.visible, "Journal panel is hidden at startup")
	check(not quest_mgr.journal_shade.visible, "Journal shade is hidden at startup")
	check(not quest_mgr.has_quest_alert, "No quest alert sparkles initially")

	# 1. Test Maëlor distance and interaction readiness
	check(not maelor.can_interact(), "Maëlor cannot interact when player is 10m away")
	check(maelor.is_in_group("interactable"), "Maëlor is in interactable group")

	# Move player close to Maëlor (2.5m)
	player.global_position = maelor.global_position + Vector3(0, 0, 2.5)
	await frames(10)

	check(maelor.can_interact(), "Maëlor can interact when player is within proximity")
	check(maelor.interaction_text() == "Parler à Maëlor", "Maëlor interaction text is 'Parler à Maëlor'")

	# 2. Trigger Dialogue
	maelor.interact()
	await frames(5)

	check(dialogue_mgr.is_open, "DialogueManager opens on interaction")
	check(dialogue_mgr.current_pages.size() == 3, "Maëlor has 3 introduction dialogue pages")
	check(dialogue_mgr.current_page_idx == 0, "Dialogue starts on page 1")

	# Advance pages
	dialogue_mgr._on_next_pressed()
	await frames(2)
	check(dialogue_mgr.current_page_idx == 1, "Dialogue advances to page 2")

	dialogue_mgr._on_next_pressed()
	await frames(2)
	check(dialogue_mgr.current_page_idx == 2, "Dialogue advances to page 3")

	# Finish dialogue
	dialogue_mgr._on_next_pressed()
	await frames(5)
	check(not dialogue_mgr.is_open, "Dialogue closes after final page")
	check(quest_mgr.is_quest_active("echo_depths"), "Quest 'echo_depths' is now active")
	check(quest_mgr.is_objective_completed("echo_depths", 0), "Objective 0 (Parler à Maëlor) is completed")
	check(quest_mgr.has_quest_alert, "Sparkle alert activates around HUD button upon quest start")

	# 3. Test Journal UI toggle [ J ]
	quest_mgr.set_journal_open(true)
	await frames(2)
	check(quest_mgr.is_journal_open, "Journal opens with set_journal_open(true)")
	check(quest_mgr.journal_panel.visible, "Journal panel is visible when open")
	check(not quest_mgr.has_quest_alert, "Sparkle alert subsides once player views the journal")
	quest_mgr.set_journal_open(false)
	await frames(2)
	check(not quest_mgr.is_journal_open, "Journal closes with set_journal_open(false)")
	check(not quest_mgr.journal_panel.visible, "Journal panel is hidden after closing")

	# 4. Progress Objectives
	quest_mgr.complete_objective("echo_depths", 1)
	check(quest_mgr.is_objective_completed("echo_depths", 1), "Objective 1 (find_cave) is completed")

	quest_mgr.complete_objective("echo_depths", 2)
	quest_mgr.complete_objective("echo_depths", 3)
	check(quest_mgr.is_objective_completed("echo_depths", 3), "Objective 3 (retrieve_echo) is completed")

	# Add first_echo relic to inventory
	inv.add_item("first_echo")
	check(inv.has_fireball_relic(), "Inventory confirms relic possession")

	# 5. Return to Maëlor for quest completion
	maelor.interact()
	await frames(5)
	check(dialogue_mgr.is_open, "Completion dialogue opens")
	# Finish victory dialogue
	dialogue_mgr._on_next_pressed()
	await frames(5)

	check(quest_mgr.is_quest_completed("echo_depths"), "Quest 'echo_depths' is marked COMPLETED")
	check(quest_mgr.is_objective_completed("echo_depths", 4), "Objective 4 (report_maelor) is completed")

	# 6. Test Persistence (Save / Load)
	var save_path: String = save_mgr.save_game("TestQuestSave")
	check(not save_path.is_empty(), "Save file created with quest data")

	# Tamper state
	quest_mgr.quests["echo_depths"].state = 0
	for obj in quest_mgr.quests["echo_depths"].objectives:
		obj.completed = false
	check(not quest_mgr.is_quest_completed("echo_depths"), "Quest state temporarily cleared")

	# Load save
	var loaded: bool = await save_mgr.load_game_from_file(save_path)
	await frames(10)
	check(loaded, "Save game loaded successfully")
	check(quest_mgr.is_quest_completed("echo_depths"), "Quest state restored to COMPLETED after load")
	check(quest_mgr.is_objective_completed("echo_depths", 3), "Objective 3 restored to completed")

	# Clean up save file
	save_mgr.delete_save(save_path)

	_finish()

func _finish() -> void:
	print("==================================================")
	print("TEST RESULTS: %d Passed, %d Failed" % [tests - failures.size(), failures.size()])
	if not failures.is_empty():
		for f in failures:
			print(" - %s" % f)
	print("==================================================")
	if is_instance_valid(level):
		level.queue_free()
	quit(0 if failures.is_empty() else 1)
