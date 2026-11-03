extends SceneTree

func _initialize() -> void:
	print("--- STARTING TEST: HARVEST & HEAL SYSTEM ---")
	call_deferred("run_tests")

func run_tests() -> void:
	var open_world_scene: PackedScene = load("res://scenes/world/open_world.tscn")
	assert(open_world_scene != null, "Could not load open_world.tscn")
	var world: Node3D = open_world_scene.instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	await process_frame
	
	var inventory = root.get_node_or_null("/root/Inventory")
	assert(inventory != null, "Inventory autoload must exist")
	var player: CharacterBody3D = world.find_child("Player", true, false) as CharacterBody3D
	assert(player != null, "Player node must exist")
	
	# 1. Verify items definition in Inventory
	print("\n[TEST 1] Verifying Inventory.ITEMS dictionary...")
	for item_id in ["mushroom", "trout", "blueberry", "raspberry", "golden_berry", "chicken", "hunter_stew"]:
		assert(inventory.ITEMS.has(item_id), "Item %s missing from ITEMS" % item_id)
		var d = inventory.ITEMS[item_id]
		assert(d.get("consumable", false) == true, "Item %s must be consumable" % item_id)
		assert(d.has("heal") and d.heal > 0, "Item %s must have positive heal value" % item_id)
		var tex = load(d.icon)
		assert(tex != null, "Icon for %s must load cleanly: %s" % [item_id, d.icon])
		print("  ✓ Item %s: %s (Heal: +%d PV)" % [item_id, d.name, int(d.heal)])
	
	# 2. Verify ArbustesABaies node and berry bush harvest components
	print("\n[TEST 2] Verifying ArbustesABaies and BerryHarvest components...")
	var bushes_node = world.get_node_or_null("ArbustesABaies")
	assert(bushes_node != null, "ArbustesABaies node missing from world")
	assert(bushes_node.get_child_count() > 0, "ArbustesABaies has no bushes")
	
	var found_harvest := 0
	var first_bush_harvest = null
	for bush in bushes_node.get_children():
		var harvest = bush.get_node_or_null("Harvest")
		if harvest:
			found_harvest += 1
			if first_bush_harvest == null:
				first_bush_harvest = harvest
			var txt = harvest.interaction_text()
			assert(txt.begins_with("Cueillir "), "Interaction text invalid: %s" % txt)
			
	print("  ✓ Total bushes with harvest component: %d / %d" % [found_harvest, bushes_node.get_child_count()])
	assert(found_harvest == bushes_node.get_child_count(), "Every bush must have a Harvest child")
	
	# 3. Test bush interaction & berry picking
	print("\n[TEST 3] Testing berry picking on bush '%s'..." % first_bush_harvest.get_parent().name)
	var initial_item_id = first_bush_harvest.item_id
	var initial_qty = first_bush_harvest.quantity
	print("  Bush type: %s, Item: %s, Qty: %d" % [first_bush_harvest.get_parent().name, initial_item_id, initial_qty])
	
	# Place player near the bush to satisfy distance and can_interact
	player.global_position = first_bush_harvest.global_position + Vector3(0.5, 0.0, 0.5)
	await process_frame
	
	var can = first_bush_harvest.can_interact()
	print("  can_interact() before picking: ", can)
	assert(can == true, "Player right next to bush should be able to interact")
	
	# Interact!
	first_bush_harvest.interact()
	await process_frame
	
	# Check inventory received berries
	var found_in_bag := false
	for s in inventory.stacks:
		if s.id == initial_item_id and s.quantity == initial_qty:
			found_in_bag = true
			break
	assert(found_in_bag, "Picked berries must be added to inventory stacks")
	print("  ✓ Berries successfully added to inventory: %d %s" % [initial_qty, inventory.ITEMS[initial_item_id].name])
	
	# Check cannot interact again (already harvested)
	var can_again = first_bush_harvest.can_interact()
	assert(can_again == false, "Harvested bush should not allow interaction again")
	if first_bush_harvest.berry_mesh:
		assert(first_bush_harvest.berry_mesh.visible == false, "Berry mesh must be hidden after picking")
	print("  ✓ Bush berries hidden and registered in inventory.collected")
	
	# 4. Test Player Damage and Item Healing
	print("\n[TEST 4] Testing Damage & Food Consumption Healing...")
	# Inflict 35 damage to player
	player.take_damage(35.0, Vector3.ZERO)
	print("  Player damaged. Health: %d / 100" % int(player.health))
	assert(abs(player.health - 65.0) < 0.1, "Player health should be 65 after 35 damage")
	
	# Add test consumable items to inventory
	inventory.add_item("mushroom", 2)
	inventory.add_item("trout", 1)
	inventory.add_item("golden_berry", 1)
	
	# Consume mushroom (+3 PV)
	var ok_shroom = inventory.consume_item("mushroom")
	assert(ok_shroom, "Should be able to consume mushroom")
	assert(abs(player.health - 68.0) < 0.1, "Player health should be 68 (+3 from mushroom)")
	print("  ✓ Consumed 1 mushroom: Health is now %d / 100" % int(player.health))
	
	# Consume golden berry (+5 PV)
	var ok_berry = inventory.consume_item("golden_berry")
	assert(ok_berry, "Should be able to consume golden berry")
	assert(abs(player.health - 73.0) < 0.1, "Player health should be 73 (+5 from golden berry)")
	print("  ✓ Consumed 1 golden berry: Health is now %d / 100" % int(player.health))
	
	# Consume trout (+8 PV)
	var ok_trout = inventory.consume_item("trout")
	assert(ok_trout, "Should be able to consume trout")
	assert(abs(player.health - 81.0) < 0.1, "Player health should be 81 (+8 from trout)")
	print("  ✓ Consumed 1 trout: Health is now %d / 100" % int(player.health))
	
	# Consume picked berries (+4 PV)
	var ok_picked = inventory.consume_item(initial_item_id)
	assert(ok_picked, "Should be able to consume picked berries")
	print("  ✓ Consumed picked berries: Health is now %d / 100" % int(player.health))
	
	# 5. Test Healing Cap at 100 and Prevention when Full
	print("\n[TEST 5] Testing Max Health Cap and Full Health Protection...")
	player.heal(50.0)
	assert(player.health == 100.0, "Player health must be capped at 100.0")
	print("  Player fully healed to: %d / 100" % int(player.health))
	
	var initial_mushrooms = 0
	for s in inventory.stacks:
		if s.id == "mushroom":
			initial_mushrooms = s.quantity
			break
			
	var eat_when_full = inventory.consume_item("mushroom")
	assert(eat_when_full == false, "Consuming when health is full must return false")
	
	var current_mushrooms = 0
	for s in inventory.stacks:
		if s.id == "mushroom":
			current_mushrooms = s.quantity
			break
	assert(current_mushrooms == initial_mushrooms, "Mushroom count must not decrease when full health")
	print("  ✓ Items are protected from being wasted when player is already at full health (100 PV)")
	
	# 6. Test Bandit Campfire Chicken Harvest
	print("\n[TEST 6] Testing Bandit Campfire Chicken Harvest...")
	var camp: Node3D = world.get_node_or_null("Sectors/CampBandits")
	assert(camp != null, "CampBandits node must exist in Sectors")
	var rotissoire: Node3D = camp.get_node_or_null("Camp_Feu_Camp_Rotissoire")
	assert(rotissoire != null, "Camp_Feu_Camp_Rotissoire must exist in CampBandits")
	assert(rotissoire.is_in_group("interactable"), "Camp_Feu_Camp_Rotissoire must be in interactable group")
	
	player.global_position = rotissoire.global_position + Vector3(0.0, 0.2, -1.4)
	await process_frame
	assert(rotissoire.can_interact() == true, "Player near campfire must be able to take chicken")
	assert(rotissoire.interaction_text().begins_with("Prendre une cuisse de poulet"), "Unexpected chicken prompt: " + rotissoire.interaction_text())
	
	rotissoire.interact()
	await process_frame
	assert(inventory.get_item_count("chicken") == 1, "1 chicken leg must be added to inventory")
	assert(rotissoire.visible == true, "Campfire chicken 3D model must remain visible after taking a leg")
	print("  ✓ Harvested 1 Cuisse de poulet rôti; 3D model stays visible on spit")
	
	# 7. Test Bandit Cauldron Recipe System (Poulet + Champignon + Fruit -> Ragoût forestier)
	print("\n[TEST 7] Testing Bandit Cauldron Recipe Crafting & Stew Healing...")
	var cauldron: Node3D = rotissoire.get_node_or_null("Chaudron")
	assert(cauldron != null, "Cauldron interaction must be on the pot at the end of the spit")
	assert(not camp.get_node("Camp_Caisse_Rochers").is_in_group("interactable"), "The crate must not offer cooking")
	assert(not camp.get_node("Camp_Caisse_Chope").is_in_group("interactable"), "The mug must not offer cooking")
	assert(cauldron.is_in_group("interactable"), "Cauldron must be in interactable group")
	assert(cauldron.is_in_group("cauldron"), "Cauldron must be in cauldron group")
	
	player.global_position = cauldron.global_position + Vector3(-0.4, -0.7, 0.4)
	await process_frame
	inventory._physics_process(0.0)
	assert(inventory.target == cauldron, "F must select cooking when standing in front of the pot")
	assert(cauldron.can_interact() == true, "Player near cauldron must be able to interact")
	assert(inventory.can_craft("hunter_stew") == true, "Player with chicken, mushroom, and berries must be able to craft hunter_stew")
	assert("recettes" in cauldron.interaction_text(), "Cauldron prompt should open the existing recipe menu")
	
	var pre_chicken: int = inventory.get_item_count("chicken")
	var pre_mushroom: int = inventory.get_item_count("mushroom")
	var pre_fruits: int = inventory.get_any_item_count(inventory.FRUIT_IDS)
	
	cauldron.interact()
	await process_frame
	var dialogue = root.get_node("DialogueManager")
	if dialogue.is_open:
		dialogue.hide_dialogue()
		await process_frame
	assert(inventory.cooking_ui.visible, "Cauldron must open the recipe menu")
	var stew_button: Button
	for child in inventory.cooking_ui.recipes.get_children():
		if child is Button and child.text == "Cuisiner": stew_button = child
	assert(stew_button != null and not stew_button.disabled, "Existing stew recipe must remain craftable")
	stew_button.pressed.emit()
	inventory.set_open(false)
	
	assert(inventory.get_item_count("hunter_stew") == 1, "1 hunter_stew must be added to inventory after cooking")
	assert(inventory.get_item_count("chicken") == pre_chicken - 1, "1 chicken must be consumed by recipe")
	assert(inventory.get_item_count("mushroom") == pre_mushroom - 1, "1 mushroom must be consumed by recipe")
	assert(inventory.get_any_item_count(inventory.FRUIT_IDS) == pre_fruits - 1, "1 fruit must be consumed by recipe")
	print("  ✓ Crafted 1 Ragoût forestier au poulet (+35 PV) at the cauldron")
	assert(not inventory.can_craft("hunter_stew"), "Cooking must require chicken")
	cauldron.interact()
	assert(inventory.get_item_count("hunter_stew") == 1, "Missing chicken must not produce another stew")
	inventory.set_open(false)
	
	# Test consuming the crafted stew when damaged
	player.damage_invulnerability = 0.0
	player.take_damage(50.0, Vector3.ZERO)
	assert(abs(player.health - 50.0) < 0.1, "Player health should be 50 after 50 damage")
	var ate_stew: bool = inventory.consume_item("hunter_stew")
	assert(ate_stew == true, "Should be able to consume crafted hunter_stew")
	assert(abs(player.health - 85.0) < 0.1, "Player health should be 85 (+35 PV from hunter_stew)")
	print("  ✓ Consumed 1 Ragoût forestier au poulet: Health restored from 50 to %d / 100" % int(player.health))
	
	print("\n=== ALL TESTS PASSED SUCCESSFULLY! ===")
	world.queue_free()
	quit(0)
