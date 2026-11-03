extends SceneTree
var failures := 0
var player: CharacterBody3D
var bag: Node
var level: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok: failures += 1

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func right(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = pressed
	player._unhandled_input(event)

func reset_throw() -> void:
	player.cancel_claw()
	player.fireball_cooldown = 0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func picture(filename: String) -> void:
	await frames(2)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://../diagnostics/sleep_dart_20261023/" + filename + ".png")

func run() -> void:
	var dart_script = preload("res://scripts/sleep_dart.gd")
	check(dart_script.SPEED * dart_script.LIFETIME >= 400.0, "Dart flight covers every distance offered by the shared aiming reticle")
	bag = root.get_node("Inventory")
	bag.stacks.clear()
	bag.equipment.clear()
	bag.collected.clear()
	level = Node3D.new()
	root.add_child(level)
	current_scene = level
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45, -30, 0)
	level.add_child(light)
	player = load("res://scenes/player.tscn").instantiate()
	player.gravity = 0
	player.position = Vector3(0, 1, 5)
	level.add_child(player)
	await frames(4)
	bag.collected["story/cave_guardian/recipe"] = true
	bag.add_item("dream_fern", 2)
	bag.add_item("mushroom")
	check(bag.craft_recipe("sleep_dart") and bag.get_item_count("sleep_dart") == 10, "Recipe makes ten stackable darts")
	bag.set_open(true)
	bag.ui.resources.get_child(0).pressed.emit()
	await frames(2)
	check(bag.equipped == "sleep_dart" and player.get_node("HeldEquipment").dart.visible, "Inventory slot equips a visible dart in the hand")
	await picture("inventory_equipped")
	bag.set_open(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	right(true)
	check(player.fireball_aiming and player.fireball_reticle.visible, "Right hold shows the shared aiming reticle without a relic")
	var yaw: float = player.pivot.rotation.y
	var pitch: float = player.arm.rotation.x
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, -60)
	player._unhandled_input(motion)
	await frames(5)
	check(player.fireball_cursor == root.get_visible_rect().size * 0.5 + motion.relative, "Dart cursor moves freely with the mouse")
	check(player.pivot.rotation.y == yaw and player.arm.rotation.x == pitch, "Aiming keeps the camera stationary")
	check(bag.get_item_count("sleep_dart") == 10 and get_nodes_in_group("sleep_dart_projectiles").is_empty(), "Holding never consumes or launches ammunition")
	await picture("dart_aim")
	bag.set_open(true)
	await frames(2)
	check(not player.fireball_aiming and not player.fireball_reticle.visible, "Opening inventory cancels aiming")
	bag.set_open(false)
	right(false)
	await frames(25)
	check(bag.get_item_count("sleep_dart") == 10, "Releasing after cancellation consumes nothing")
	bag.add_item("axe")
	reset_throw()
	right(true)
	bag.toggle_equipment("axe")
	await frames(2)
	check(not player.fireball_aiming, "Changing equipment cancels the pending dart")
	right(false)
	bag.toggle_equipment("sleep_dart")
	bag.add_item("first_echo")
	reset_throw()
	right(true)
	check(player.ranged_item == "sleep_dart", "Equipped darts take priority even when the fireball relic is owned")
	right(false)
	await frames(25)
	check(bag.get_item_count("sleep_dart") == 9 and not get_nodes_in_group("sleep_dart_projectiles").is_empty(), "Release launches exactly one physical dart")
	bag.remove_item("sleep_dart", 8)
	reset_throw()
	right(true)
	right(false)
	await frames(25)
	check(bag.get_item_count("sleep_dart") == 0 and bag.equipped == "" and not player.get_node("HeldEquipment").dart.visible, "Last dart launches successfully and clears the empty hand")
	bag.equipment.erase("first_echo")
	reset_throw()
	check(not player.begin_fireball_aim(), "No ammunition and no relic cannot begin aiming")
	# Loading a prior encounter creates the mini-quest without requiring a second kick.
	bag.collected["story/cave_guardian/repelled"] = true
	var qm := root.get_node("QuestManager")
	qm.load_from_dict({})
	check(qm.is_quest_active("cave_way_in"), "Older repelled save gains the exploration mini-quest")
	qm.start_quest("echo_depths")
	qm.active_quest_id = "cave_way_in"
	qm.set_journal_open(true)
	await picture("mini_quest")
	check(qm.quest_picker.item_count == 2, "Journal keeps both the mini-quest and main quest accessible")
	qm.set_journal_open(false)
	bag.collected["story/cave_guardian/sedated"] = true
	qm.load_from_dict(qm.save_to_dict())
	check(qm.is_quest_completed("cave_way_in"), "Reload after sedation completes the mini-quest")
	print("DART CONTROL FAILURES ", failures)
	level.queue_free()
	await frames(2)
	quit(1 if failures else 0)
