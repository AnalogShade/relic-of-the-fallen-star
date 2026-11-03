extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func approach(player: Node3D, plant: Node3D) -> bool:
	for offset in [Vector3(0.5, 0.3, 0), Vector3(-0.5, 0.3, 0), Vector3(0, 0.3, 0.5), Vector3(0, 0.3, -0.5)]:
		player.global_position = plant.global_position + offset
		await physics_frame
		if plant.can_interact(): return true
	return false

func run() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await physics_frame
	var bag := root.get_node("Inventory")
	bag.collected.clear()
	var player := get_first_node_in_group("player")
	player.set_physics_process(false)
	var harvest := world.get_node("HarvestWorld")
	var cave := world.get_node("GrotteEntree")
	var fern: Node3D
	var distance := INF
	for plant in get_nodes_in_group("dream_fern"):
		var d: float = plant.global_position.distance_to(cave.global_position)
		if plant.get_parent() == harvest and d < distance:
			fern = plant
			distance = d
	assert(fern != null, "Additional visible ferns must have harvest anchors")
	print("FERNS ", get_nodes_in_group("dream_fern").size(), " nearest cave ", distance)
	assert(await approach(player, fern), "Fern must be reachable")
	var before: int = bag.get_item_count("dream_fern")
	fern.interact()
	assert(bag.get_item_count("dream_fern") == before + 2)
	assert(fern.visible and not fern.can_interact(), "Fronds stay visible during cooldown")
	bag.collected[fern.pickup_id] = Time.get_unix_time_from_system() - 1
	assert(fern.can_interact(), "Fern becomes harvestable after cooldown")
	var mushrooms: Array = []
	for plant in harvest.get_children():
		if plant.is_in_group("interactable") and plant.pickup_id.begins_with("cave/"):
			mushrooms.append(plant)
	assert(mushrooms.size() == 18)
	var mushroom: Node3D = mushrooms[0]
	assert(await approach(player, mushroom), "Entrance mushroom must be reachable")
	mushroom.respawn_time = 0.1
	before = bag.get_item_count("mushroom")
	mushroom.interact()
	assert(bag.get_item_count("mushroom") == before + 1)
	assert(not mushroom.is_visible_in_tree())
	assert(not mushroom.get_child(0).is_visible_in_tree(), "Actual mushroom art must disappear")
	assert(mushrooms[1].is_visible_in_tree(), "Unpicked mushrooms remain")
	assert(not mushroom.can_interact())
	await create_timer(0.2).timeout
	assert(mushroom.is_visible_in_tree() and mushroom.can_interact())
	print("PASS: fern fronds, cave mushrooms, inventory, cooldown and regrowth")
	quit()
