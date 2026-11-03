extends SceneTree

func _initialize() -> void:
	print("--- STARTING TEST: RESPAWN SYSTEM (BERRIES & MUSHROOMS) ---")
	call_deferred("run_test")

func run_test() -> void:
	var scene: PackedScene = load("res://scenes/world/open_world.tscn")
	assert(scene != null, "Failed to load open_world.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	await process_frame
	await process_frame
	
	var inventory = root.get_node_or_null("/root/Inventory")
	var player: CharacterBody3D = world.find_child("Player", true, false) as CharacterBody3D
	
	# TEST 1: Bush Respawn
	print("\n[TEST 1] Testing Berry Bush Respawn...")
	var bushes_node = world.get_node_or_null("ArbustesABaies")
	var bush = bushes_node.get_child(0)
	var bush_harvest = bush.get_node("Harvest")
	bush_harvest.respawn_time = 0.5 # Fast respawn for test
	
	player.global_position = bush_harvest.global_position + Vector3(0.5, 0.0, 0.5)
	await process_frame
	
	assert(bush_harvest.can_interact() == true, "Bush should be interactable initially")
	bush_harvest.interact()
	await process_frame
	
	assert(bush_harvest.can_interact() == false, "Bush should NOT be interactable immediately after harvest")
	if bush_harvest.berry_mesh:
		assert(bush_harvest.berry_mesh.visible == false, "Berries should be hidden after harvest")
	print("  ✓ Harvested bush: berries hidden, interaction disabled")
	
	# Wait for respawn (0.5s timer)
	print("  Waiting 0.6s for bush respawn...")
	var t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 650:
		await process_frame
		
	assert(bush_harvest.can_interact() == true, "Bush should be interactable again after respawn timer!")
	if bush_harvest.berry_mesh:
		assert(bush_harvest.berry_mesh.visible == true, "Berries mesh must be visible again after respawn!")
	print("  ✓ Bush fully respawned! Berries are visible and can be picked again.")

	# TEST 2: Mushroom Respawn
	print("\n[TEST 2] Testing Mushroom Colony Respawn...")
	var harvest_world_node = world.find_child("HarvestWorld", true, false)
	assert(harvest_world_node != null, "HarvestWorld node must exist")
	
	var mushroom_colony = null
	for child in harvest_world_node.get_children():
		if child.is_in_group("interactable") and child.item_id == "mushroom":
			mushroom_colony = child
			break
			
	assert(mushroom_colony != null, "Mushroom colony collectible must exist")
	mushroom_colony.respawn_time = 0.5 # Fast respawn for test
	player.global_position = mushroom_colony.global_position + Vector3(0.5, 0.0, 0.5)
	await process_frame
	
	assert(mushroom_colony.can_interact() == true, "Mushroom colony should be interactable initially")
	mushroom_colony.interact()
	await process_frame
	
	assert(mushroom_colony.can_interact() == false, "Mushroom colony should NOT be interactable immediately after harvest")
	assert(mushroom_colony.visible == false, "Mushroom colony must be hidden after harvest")
	print("  ✓ Harvested mushrooms: colony hidden, interaction disabled")
	
	# Wait for respawn (0.5s timer)
	print("  Waiting 0.6s for mushroom respawn...")
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 650:
		await process_frame
		
	assert(mushroom_colony.can_interact() == true, "Mushroom colony should be interactable again after respawn timer!")
	assert(mushroom_colony.visible == true, "Mushroom colony must be visible again after respawn!")
	print("  ✓ Mushrooms fully respawned! Colony is visible and can be picked again.")
	
	# TEST 3: Cross-area timestamp verification
	print("\n[TEST 3] Testing timestamp persistence logic...")
	# Mark collected with timestamp in the past
	inventory.collected["test_pickup"] = Time.get_unix_time_from_system() - 10.0
	bush_harvest.pickup_id = "test_pickup"
	bush_harvest._check_harvest_state()
	assert(bush_harvest.is_harvested() == false, "Expired timestamp should count as regrown")
	assert(inventory.collected.has("test_pickup") == false, "Expired timestamp should be cleared from inventory")
	print("  ✓ Expired timestamp correctly cleans up and regrows plants after area reload")

	print("\n=== ALL RESPAWN TESTS PASSED! ===")
	world.queue_free()
	quit(0)
