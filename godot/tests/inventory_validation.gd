extends Node3D
var failures: Array[String] = []
var checks := 0
var bag: Node

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
	print(("PASS " if ok else "FAIL ") + message)

func frames(n := 5) -> void:
	for i in range(n): await get_tree().physics_frame

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await frames()
	event = InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	Input.parse_input_event(event)
	await frames()

func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)

func _ready() -> void:
	bag = get_node("/root/Inventory")
	await frames(40)
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	await frames(40)
	var player: CharacterBody3D = world.get_node("Original/Player")
	check(world.get_node("HarvestWorld").get_child_count() == 5, "Four harvest colonies added")
	var colony := world.get_node("HarvestWorld/HarvestColony_00") as Node3D
	player.global_position = colony.global_position + Vector3(0, 0.6, 1.1)
	await frames(25)
	check(colony.can_interact(), "Mushroom colony within reach")
	await press(KEY_F)
	check(bag.stacks.size() == 1 and bag.stacks[0].quantity == 6, "F collects a colony into one stack")
	check(not is_instance_valid(colony), "Harvested geometry disappears")
	await press(KEY_F)
	check(bag.stacks[0].quantity == 6, "Repeated F does not duplicate the harvest")
	await press(KEY_I)
	check(bag.is_open and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "I opens inventory and releases mouse")
	var position_before := player.global_position
	Input.action_press("move_forward")
	await frames(20)
	Input.action_release("move_forward")
	check(Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(position_before.x, position_before.z)) < 0.02, "Inventory blocks player movement")
	await press(KEY_ESCAPE)
	check(not bag.is_open, "Escape closes inventory")
	# Keep world intact while exercising the real cabin travel implementation.
	world.reparent(get_tree().root)
	get_tree().current_scene = world
	player.global_position = Vector3(-56.55, 12.04, 4.15)
	player.velocity = Vector3.ZERO
	await frames(35)
	await press(KEY_F)
	await get_tree().create_timer(1.0).timeout
	var travel := get_node("/root/CabinTravel")
	check(travel.inside, "F still enters cabin using shared interaction selection")
	if not travel.inside:
		finish()
		return
	var room: Node3D = travel.room
	var actor: CharacterBody3D = room.get_node("Player")
	var pickup := room.get_node("FishingRodPickup") as Node3D
	actor.global_position = Vector3(-0.8, 0.46, -1.4)
	actor.velocity = Vector3.ZERO
	actor.pivot.rotation.y = 0.0
	actor.arm.rotation.x = -0.12
	await frames(25)
	check(pickup.can_interact(), "Wall-mounted rod is reachable from inside")
	await capture("res://tests/inventory_cabin_rod.png")
	await press(KEY_F)
	check(bag.equipment.has("fishing_rod"), "F takes rod into equipment section")
	check(not is_instance_valid(pickup), "Rod disappears from wall")
	await press(KEY_I)
	# Emit the actual slot button signal to exercise the UI connection.
	bag.ui.tools_grid.get_child(0).pressed.emit()
	await frames()
	check(bag.equipped == "fishing_rod", "Click equipment slot equips rod")
	check(actor.get_node("HeldEquipment").rod.visible, "Equipped rod appears in hand")
	await capture("res://tests/inventory_ui.png")
	bag.ui.tools_grid.get_child(0).pressed.emit()
	check(bag.equipped == "", "Click again unequips")
	bag.ui.tools_grid.get_child(0).pressed.emit()
	await press(KEY_I)
	actor.pivot.rotation.y = PI * 0.8
	await capture("res://tests/inventory_held_rod.png")
	actor.global_position = Vector3(-0.6875, 0.46, 2.1)
	actor.velocity = Vector3.ZERO
	await frames(20)
	await press(KEY_F)
	await get_tree().create_timer(1.0).timeout
	check(not travel.inside and world.is_inside_tree(), "F returns to forest")
	check(bag.equipped == "fishing_rod" and player.get_node("HeldEquipment").rod.visible, "Equipment follows character outside")
	check(bag.stacks[0].quantity == 6, "Harvest survives cabin visit")
	# Test the equipped tool outdoors, then restore the cabin doorway position.
	var doorway_position := player.global_position
	player.global_position = Vector3(3.7, 2.0, 0.0)
	player.velocity = Vector3.ZERO
	player.pivot.rotation.y = PI / 2.0
	player.arm.spring_length = 4.0
	await frames(50)
	var fishing := world.get_node("StreamFishing")
	print("FISHING_DIAGNOSTIC player=", player.global_position, " floor=", player.is_on_floor(), " points=", fishing.water_points.size(), " rod=", player.get_node("HeldEquipment").rod.global_transform)
	check(fishing.can_interact(), "Equipped rod can fish at stream edge")
	await capture("res://tests/inventory_held_outside.png")
	await press(KEY_F)
	check(fishing.state == "waiting", "F casts fishing line")
	await capture("res://tests/inventory_fishing.png")
	if fishing.state == "waiting":
		fishing.remaining = 0.01
		await frames(3)
		check(fishing.state == "bite", "Waiting leads to bite window")
		await press(KEY_F)
		check(bag.stacks.size() == 2 and bag.stacks[1].id == "trout", "F during bite adds caught trout")
		await frames(45)
		await press(KEY_F)
		bag.set_open(true)
		await frames(3)
		check(fishing.state == "idle", "Opening inventory cancels fishing")
		bag.set_open(false)
	player.global_position = doorway_position
	player.velocity = Vector3.ZERO
	await frames(20)
	await press(KEY_F)
	await get_tree().create_timer(1.0).timeout
	check(travel.inside and travel.room.get_node_or_null("FishingRodPickup") == null, "Reentering cabin does not respawn rod")
	# Capacity failure must be atomic, preserving existing item counts.
	bag.stacks.clear()
	check(bag.add_item("mushroom", 99 * 24), "All resource slots can be filled")
	check(not bag.add_item("mushroom", 1) and bag.stacks.size() == 24 and bag.stacks[23].quantity == 99, "Full inventory rejects items without loss or overflow")
	check(not bag.add_item("fishing_rod"), "Unique rod cannot be duplicated")
	finish()

func finish() -> void:
	var report := {"checks": checks, "failures": failures}
	FileAccess.open("res://tests/inventory_validation_report.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("INVENTORY_VALIDATION " + JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
