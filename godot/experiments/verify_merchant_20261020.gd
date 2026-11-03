extends SceneTree
var failures: Array[String] = []
var world: Node3D
const OUT := "C:/Users/Utilisateur/Documents/Dev/Jeux/Relic of the fallen star/3D MODELS/marchand/integration_20261020/"
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func run() -> void:
	world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(40): await physics_frame
	var merchant = world.get_node("Sectors/WesternPlains/Merrick")
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	check(merchant.clips.size() == 3, "Three Blender animations imported")
	check(merchant.is_on_floor(), "Merchant standing on market ground")
	var home: Vector3 = merchant.home
	player.global_position = home + Vector3(0, 0.2, 4.2)
	for i in range(160): await physics_frame
	check(merchant.engaged and merchant.global_position.distance_to(home) > 0.4, "Merchant walks to nearby player")
	check(Vector2(merchant.position.x-home.x, merchant.position.z-home.z).length() < 2.4, "Approach stays inside market aisle")
	player.global_position = merchant.global_position + Vector3(0, 0, 1.8)
	for i in range(20): await physics_frame
	check(merchant.animator.current_animation.ends_with("Merchant_Talk"), "Nearby player triggers conversation gestures")
	var bag = root.get_node("Inventory")
	check(merchant.can_interact(), "F interaction available")
	merchant.interact()
	check(merchant.shop.visible and bag.is_open, "Shop opens and blocks player controls")
	var count_before: int = bag.get_item_count("mushroom")
	check(not bag.buy_item("mushroom", 3), "Cannot buy without gold")
	bag.add_gold(10)
	check(bag.buy_item("mushroom", 3) and bag.gold == 7 and bag.get_item_count("mushroom") == count_before + 1, "Purchase spends gold and adds inventory item")
	var original_stacks: Array = bag.stacks.duplicate(true)
	bag.stacks.clear()
	for i in range(bag.CAPACITY): bag.stacks.append({"id":"blueberry", "quantity":99})
	check(not bag.buy_item("mushroom", 3) and bag.gold == 7, "Full inventory never consumes gold")
	bag.stacks.assign(original_stacks)
	merchant.shop.close_shop()
	var bandits := get_nodes_in_group("enemies").filter(func(n): return n.get_script() and n.get_script().resource_path.ends_with("bandit.gd"))
	check(not bandits.is_empty(), "Bandits found in world")
	if not bandits.is_empty():
		var bandit = bandits[0]
		bandit.health = 0
		bandit._die()
		bandit._die()
		check(get_nodes_in_group("gold_pickups").size() == 1, "Bandit death produces exactly one gold reward")
		var drop = get_nodes_in_group("gold_pickups")[0]
		player.global_position = drop.global_position + Vector3(0, 0, 1)
		var reward: int = drop.amount
		check(drop.can_interact(), "Gold can be collected near corpse")
		drop.interact()
		drop.interact()
		check(bag.gold == 7 + reward, "F pickup credits gold exactly once")
	var save_manager = root.get_node("SaveManager")
	var save_path: String = save_manager.save_game("Merchant validation", "user://merchant_validation_temp.json")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(saved.inventory.gold == bag.gold, "Gold written into save data")
	check(save_manager.normalize_save_data({"version":2,"inventory":{}}).inventory.gold == 0, "Older saves default to zero gold")
	check(save_manager.normalize_save_data({"version":2,"inventory":{"gold":-1}}).is_empty(), "Invalid saved gold is rejected")
	DirAccess.remove_absolute(save_path)
	player.global_position = home + Vector3(0, 0.2, 12)
	for i in range(240): await physics_frame
	check(merchant.global_position.distance_to(home) < 0.25, "Merchant returns home when player leaves")
	print("MERCHANT_VALIDATION ", JSON.stringify({"failures":failures,"home":str(home),"position":str(merchant.global_position),"clips":merchant.clips}))
	if DisplayServer.get_name() != "headless":
		for ui in world.find_children("*", "CanvasLayer", true, false): ui.hide()
		var camera := Camera3D.new()
		root.add_child(camera)
		camera.current = true
		camera.fov = 47
		camera.global_position = home + Vector3(7, 8, 11)
		camera.look_at(home + Vector3.UP)
		player.global_position = home + Vector3(0, 0, 1.8)
		world.get_node("Original/WorldEnvironment").environment.fog_enabled = false
		for i in range(30): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "merchant_market.png")
		merchant.interact()
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT + "merchant_shop.png")
		merchant.shop.close_shop()
		if bandits.size() > 1 and is_instance_valid(bandits[1]):
			var other = bandits[1]
			other.health = 0
			other._die()
			player.global_position = other.global_position + Vector3(0, 0, 1.5)
			camera.global_position = other.global_position + Vector3(3, 2.8, 4)
			camera.look_at(other.global_position + Vector3.UP * 0.6)
			for i in range(90): await physics_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT + "bandit_gold.png")
		camera.queue_free()
	world.queue_free()
	for i in range(4): await process_frame
	quit(0 if failures.is_empty() else 1)
