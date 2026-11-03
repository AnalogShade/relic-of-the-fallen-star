extends SceneTree

var failures: Array[String] = []
var tests := 0
var level: Node3D
var player: CharacterBody3D
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
	print("TEST SUITE: SAVE & LOAD SYSTEM (PROGRESSION)")
	print("==================================================")
	
	save_mgr = root.get_node_or_null("SaveManager")
	check(save_mgr != null, "SaveManager autoload is present")
	if not save_mgr:
		_finish()
		return
	
	inv = root.get_node_or_null("Inventory")
	check(inv != null, "Inventory autoload is present")
	if not inv:
		_finish()
		return
	
	# Setup test level
	level = Node3D.new()
	root.add_child(level)
	current_scene = level
	level.scene_file_path = "res://scenes/world/open_world.tscn"
	
	# Sol
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(50, 1, 50)
	col.shape = box
	floor_body.add_child(col)
	level.add_child(floor_body)
	
	# Player
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(10.5, 0.5, -15.2)
	level.add_child(player)
	player.health = 72.0 # Custom HP
	
	await frames(10)
	
	# 1. Setup inventory with items, berries and relic
	inv.equipment.clear()
	inv.stacks.clear()
	inv.collected.clear()
	
	inv.add_item("first_echo") # Relic
	inv.add_item("blueberry", 15) # Harvested berries
	inv.add_item("mushroom", 4) # Harvested mushrooms
	inv.toggle_equipment("first_echo") # Equipped
	
	# Add story flag and harvest flag to collected
	inv.collected["cave/echo_chest_open"] = true
	inv.collected["cave/first_echo"] = true
	inv.collected["berry_bush_test_123"] = 9999999999 # Natural berry bush harvest key
	inv.collected["mushroom_test_456"] = true # Natural mushroom harvest key
	
	check(inv.has_fireball_relic() == true, "Player has fireball relic before saving")
	check(inv.stacks.size() == 2, "Player has 2 resource stacks before saving")
	
	# 2. Save game with custom name
	print("\n[Step 1] Saving game with custom name...")
	var test_save_name := "Aventure de Naël - Test Automatisé"
	var save_path: String = save_mgr.save_game(test_save_name)
	check(FileAccess.file_exists(save_path), "Save file created on disk: %s" % save_path)
	
	# Inspect JSON content on disk
	var json_str := FileAccess.get_file_as_string(save_path)
	var data: Dictionary = JSON.parse_string(json_str)
	check(data.get("save_name") == test_save_name, "Saved name matches input: '%s'" % test_save_name)
	check(data.get("player", {}).get("health") == 72.0, "Saved player health is 72.0")
	check(data.get("location_name") == "Forêt des lueurs", "Location name recognized as 'Forêt des lueurs'")
	
	# Verify that natural harvest keys are EXCLUDED from story_flags
	var saved_story: Dictionary = data.get("story_flags", {})
	check(saved_story.has("cave/echo_chest_open"), "Permanent chest flag is saved")
	check(saved_story.has("cave/first_echo"), "Permanent relic flag is saved")
	check(not saved_story.has("berry_bush_test_123"), "Natural berry bush harvest key is NOT saved (allows respawn)")
	check(not saved_story.has("mushroom_test_456"), "Natural mushroom harvest key is NOT saved (allows respawn)")
	
	# 3. Modify game state (simulate dying, losing items, moving)
	print("\n[Step 2] Mutating game state before load...")
	player.health = 15.0
	player.global_position = Vector3(0, 0, 0)
	inv.equipment.clear()
	inv.stacks.clear()
	inv.collected.clear()
	check(inv.has_fireball_relic() == false, "State cleared: relic missing")
	check(inv.stacks.is_empty(), "State cleared: inventory empty")
	check(player.health == 15.0, "State modified: player damaged to 15 PV")
	
	# 4. Load the game back
	print("\n[Step 3] Loading game from file...")
	var load_success: bool = await save_mgr.load_game_from_file(save_path)
	check(load_success == true, "Game load succeeded")
	
	await frames(10)
	
	# Verify inventory restored
	check(inv.equipment.has("first_echo"), "Relic 'first_echo' restored in equipment")
	check(inv.has_fireball_relic() == true, "Player has fireball relic after load")
	check(inv.stacks.size() == 2, "Player has 2 resource stacks restored")
	
	var total_blueberries := 0
	for stack in inv.stacks:
		if stack.id == "blueberry": total_blueberries += int(stack.quantity)
	check(total_blueberries == 15, "Player retained 15 blueberries in bag")
	
	# Verify natural berries & mushrooms respawn
	check(not inv.collected.has("berry_bush_test_123"), "Nature berry bush is ready to harvest again")
	check(not inv.collected.has("mushroom_test_456"), "Nature mushroom is ready to harvest again")
	
	# Verify permanent chest flag is kept
	check(inv.collected.has("cave/echo_chest_open"), "Chest stays opened in cave")
	
	# Verify PauseMenu integration
	print("\n[Step 4] Testing PauseMenu UI components...")
	var pause_menu := root.get_node_or_null("PauseMenu")
	check(pause_menu != null, "PauseMenu autoload is present")
	if pause_menu:
		pause_menu.open()
		check(pause_menu.is_open == true, "Pause menu opens")
		check(pause_menu.main_view.visible == true, "Main view visible initially")
		
		# Test Save View
		pause_menu.show_save_view()
		check(pause_menu.save_view.visible == true, "Save view visible")
		check(pause_menu.save_name_input.text.length() > 0, "Default save name prefilled")
		
		# Test Load View
		pause_menu.show_load_view()
		check(pause_menu.load_view.visible == true, "Load view visible")
		check(pause_menu.load_saves_list_container.get_child_count() > 0, "Saves list populated in Load view")
		
		pause_menu.resume()
		check(pause_menu.is_open == false, "Pause menu resumes")
	
	# Régressions : anciennes sauvegardes, limites de vie et validation avant mutation.
	player = get_first_node_in_group("player")
	check(player.health == 72.0, "Loaded health restored on the current player")
	check(player.health_label.text == "Vie : 72 / 100", "HUD refreshed immediately after load")
	player.restore_health(0.4)
	check(player.health == 0.4 and player.health_label.text == "Vie : 1 / 100", "Positive fractional HP never displays zero")
	player.damage_invulnerability = 0.0
	player.take_damage(1.0, player.global_position + Vector3.RIGHT)
	check(player.health == 100.0, "Lethal damage respawns player")
	player.global_position += Vector3(5, 0, 0)
	player.restore_health(0.0)
	check(player.health == 100.0 and player.global_position == player.spawn_position, "Zero saved HP respawns at scene start")
	player.health = 0.0
	await frames(1)
	check(player.health == 100.0, "Direct zero HP assignment cannot leave a living zero HP player")
	var legacy := {"player": {"health": -5.0}}
	var migrated: Dictionary = save_mgr.normalize_save_data(legacy)
	check(migrated.version == save_mgr.SAVE_VERSION and migrated.player.health == 0.0, "Unversioned legacy save migrates and clamps HP")
	check(not legacy.has("version"), "Migration preserves original data")
	check(save_mgr.normalize_save_data({"version": 999}).is_empty(), "Future version rejected")
	check(save_mgr.normalize_save_data({"player": {"health": "broken"}}).is_empty(), "Malformed health rejected")
	check(save_mgr.normalize_save_data({"player": {"position": [1, "broken", 3]}}).is_empty(), "Malformed position rejected")
	var old_scene := current_scene
	check(not await save_mgr.apply_save_data({"inventory": []}), "Invalid save fails gracefully")
	check(current_scene == old_scene and inv.has_fireball_relic(), "Rejected save leaves game state intact")
	# Exercise the full legacy loading path at zero HP.
	data.version = 1
	data.player.health = 0.0
	check(await save_mgr.apply_save_data(data), "Version 1 save with zero HP loads successfully")
	player = get_first_node_in_group("player")
	check(player.health == 100.0 and player.global_position == player.spawn_position, "Legacy zero HP load resolves death instead of restoring a living zero HP player")

	var quests := root.get_node("QuestManager")
	quests.load_from_dict({"quests": {"echo_depths": {"state": 1, "objectives": [true, false]}}})
	check(quests.quests.echo_depths.objectives[0].completed, "Legacy quest objective array remains supported")
	var quest_save: Dictionary = quests.save_to_dict()
	check(quest_save.quests.echo_depths.objectives.has("talk_maelor"), "New objectives saved by stable ID")
	quests.quests.echo_depths.objectives.reverse()
	quests.load_from_dict(quest_save)
	check(quests.quests.echo_depths.objectives[-1].completed and not quests.quests.echo_depths.objectives[0].completed, "Objective progress survives definition reordering")
	quests.quests.echo_depths.objectives.reverse()
	quests.load_from_dict({})
	check(not quests.quests.echo_depths.objectives[0].completed and quests.quests.echo_depths.state == 0, "Missing legacy quests reset previous session progress")

	# 5. Clean up test save file
	save_mgr.delete_save(save_path)
	check(not FileAccess.file_exists(save_path), "Test save cleaned up via delete_save()")
	
	_finish()

func _finish() -> void:
	print("\n==================================================")
	print("TOTAL TESTS: %d | FAILURES: %d" % [tests, failures.size()])
	print("==================================================")
	quit(1 if failures.size() > 0 else 0)
