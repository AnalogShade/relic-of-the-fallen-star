extends "res://tests/test_ogre_quest.gd"

func finish() -> void:
	var report := {"checks":checks,"failures":failures,"passed":failures.is_empty()}
	var file := FileAccess.open("res://../diagnostics/ogre_quest_20261021/edge_tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	print("OGRE EDGE RESULTS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)

func passage_sweep() -> float:
	var query := PhysicsShapeQueryParameters3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.32
	query.shape = shape
	var frame := cave.get_node("EntranceFrame") as Node3D
	query.transform = Transform3D(Basis.IDENTITY,frame.to_global(Vector3(1.35,2.2,0)))
	# Stop at the portal approach: further inside is the existing mountain collider,
	# since this entrance uses a scene-transition interaction, not a continuous tunnel.
	query.motion = frame.global_basis * Vector3(0,0,-1.7)
	query.collision_mask = 1
	query.exclude = [guardian.get_rid()]
	var fraction: float = world.get_world_3d().direct_space_state.cast_motion(query)[0]
	print("PASSAGE SWEEP ", fraction, " state=", guardian.state)
	return fraction

func run() -> void:
	bag = root.get_node("Inventory")
	dm = root.get_node("DialogueManager")
	bag.stacks.clear()
	bag.equipment.clear()
	bag.collected.clear()
	world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(8)
	player = get_first_node_in_group("player")
	player.set_physics_process(false)
	cave = world.get_node("GrotteEntree")
	guardian = cave.get_node("OgreGuardian")
	for enemy in get_nodes_in_group("enemies"):
		if enemy != guardian: enemy.set_physics_process(false)
	check(passage_sweep() < 0.8, "A swept player-sized sphere physically cannot cross the awake gate")
	print("GROUND ALIGNED ", guardian.global_position, " sleep=", cave.to_global(guardian.sleep_position))
	player.global_position = guardian.global_position + cave.global_basis.z*2.5 + Vector3.UP*.4
	guardian.interact()
	check(dm.current_choices.size() == 2, "Only the two requested responses appear without a dart")
	await key(KEY_ESCAPE)
	check(not dm.is_open and guardian.state == "guard", "Closing the conversation is peaceful")
	guardian.take_damage(5000,player.global_position)
	check(guardian.health == guardian.max_health and guardian.state == "kick", "Even excessive conventional damage triggers territorial recoil instead of killing the ogre")
	await frames(190)
	player.guardian_knockback = 0
	check(guardian.state == "guard", "Guardian returns to idle after a conventional attack")
	bag.add_item(Access.DART,2)
	player.global_position = guardian.global_position + cave.global_basis.z*12
	check(bag.use_item(Access.DART) and bag.get_item_count(Access.DART) == 2, "Darts can be equipped away from the ogre without consuming ammunition")
	await throw_dart_at(player.global_position + Vector3(0, 20, -20))
	check(guardian.state == "guard" and bag.get_item_count(Access.DART) == 1 and not Access.has_fact(world, Access.SEDATED), "A missed aimed throw consumes one dart without resolving the encounter")
	bag.add_item(Access.DART)
	player.global_position = cave.to_global(Vector3(0,0.5,-3))
	player.cancel_claw()
	player.fireball_cooldown = 0
	await throw_dart_at(guardian.global_position + Vector3.UP * 1.8)
	check(guardian.state == "guard" and bag.get_item_count(Access.DART) == 1, "A thrown dart stops at the gate/wall and spends only one projectile")
	bag.stacks.clear()
	Access.remember(world, Access.RECIPE)
	bag.add_item(Access.FERN,4)
	bag.add_item("mushroom",2)
	for i in 22: bag.stacks.append({"id":"blueberry","quantity":99})
	var before: Array = bag.stacks.duplicate(true)
	check(not bag.craft_recipe(Access.DART) and bag.stacks == before, "Full inventory rolls crafting back without losing ingredients")
	bag.stacks[0].quantity = 99 # No room even in an existing fern stack.
	var fern: Node3D = get_first_node_in_group("dream_fern")
	check(await near(fern,.65), "Full-inventory harvest uses a reachable existing fern")
	fern.interact()
	check(not bag.collected.has(fern.pickup_id) and fern.visible, "Failed harvest neither spends the plant nor hides it")
	bag.stacks.clear()
	fern.interact()
	check(bag.get_item_count(Access.FERN) == 2, "Harvest succeeds once inventory space is available")
	bag.collected[fern.pickup_id] = Time.get_unix_time_from_system()-1
	check(not fern.is_harvested() and fern.visible, "Expired harvest cooldown allows more fronds while plant remains visible")
	check(not bag.consume_item(Access.FERN), "Medicinal fern is not accidentally treated as ordinary food")
	var save_mgr := root.get_node("SaveManager")
	var awake_path: String = save_mgr.save_game("Awake guardian test","user://saves/ogre_awake_test.json")
	check(await save_mgr.load_game_from_file(awake_path), "Awake encounter can be saved and loaded")
	world = current_scene
	player = get_first_node_in_group("player")
	player.set_physics_process(false)
	cave = world.get_node("GrotteEntree")
	guardian = cave.get_node("OgreGuardian")
	check(guardian.state == "guard" and passage_sweep() < .8, "Awake save restores a guarded physical passage")
	check(Access.has_fact(world,Access.MET) and Access.has_fact(world,Access.REPELLED) and Access.has_fact(world,Access.RECIPE), "Encounter and recipe facts survive before resolution")
	for enemy in get_nodes_in_group("enemies"):
		if enemy != guardian: enemy.set_physics_process(false)
	bag.add_item(Access.DART,2)
	player.global_position = guardian.global_position+cave.global_basis.z*2.5+Vector3.UP*.4
	guardian.interact()
	await key(KEY_3)
	check(guardian.state == "guard" and bag.equipped == Access.DART and bag.get_item_count(Access.DART) == 2, "Third dialogue choice prepares darts without automatically hitting the ogre")
	await throw_dart_at(guardian.global_position + Vector3.UP * 1.8)
	check(guardian.state == "drowsy" and bag.get_item_count(Access.DART) == 1, "Aimed dart impact starts sedation and consumes exactly one dart")
	var flight_path: String = save_mgr.save_game("Dart impact test","user://saves/ogre_flight_test.json")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(flight_path))
	check(data.story_flags.get(Access.SEDATED,false), "Save after actual impact retains the resolved encounter")
	await frames(25)
	check(not guardian.receive_sleep_dart() and bag.get_item_count(Access.DART) == 1, "Already-sedated guardian cannot consume another dart")
	check(not guardian.passage_open(), "Live passage stays closed until the sleep animation completes")
	check(await save_mgr.load_game_from_file(flight_path), "A save from the sleep transition reloads successfully")
	world = current_scene
	cave = world.get_node("GrotteEntree")
	guardian = cave.get_node("OgreGuardian")
	await frames(3)
	check(guardian.state == "sleeping" and passage_sweep() > .95, "Reload restores sleep and a physically traversable entrance")
	check(bag.get_item_count(Access.DART) == 1, "Flight reload preserves the remaining dart count")
	for path in [awake_path,flight_path]: DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	finish()
