extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func freeze_world(world: Node) -> void:
	world.get_node("EnemyActivity").free()
	world.get_node("Original/Player").set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
func run() -> void:
	var saves = root.get_node("SaveManager").list_saves()
	var data: Dictionary = {}
	for save in saves:
		if save.get("inventory", {}).get("equipment", []).has("first_echo"):
			data = save.duplicate(true)
			break
	if data.is_empty():
		data = {"version": 3, "scene_file_path": "res://scenes/world/open_world.tscn", "player": {"position": [20, 7, -213]}, "inventory": {"equipment": ["first_echo"]}}
	# Only memory copies are loaded: existing save files are never edited.
	data.get_or_add("story_flags", {}).erase("story/lake_monster_defeated")
	data.story_flags.erase("relic/primordial_wave")
	data.inventory.equipment.erase("primordial_wave")
	var loaded: bool = await root.get_node("SaveManager").apply_save_data(data)
	check(loaded, "Loads existing post-cave save through real SaveManager")
	await frames(3)
	var world := current_scene
	freeze_world(world)
	var boss = world.get_node("LakeMonster")
	var fragment = boss.get_node("LakeFragment")
	var bag = root.get_node("Inventory")
	check(not fragment.visible and boss.state == "dormant", "Loaded pre-victory save keeps nova locked")
	boss._begin_emerge()
	boss.state = "attack"
	boss.global_position += Vector3(3, 0, 0)
	boss.mouth_area.global_position = Vector3(10, 10, -213)
	boss.health = 1
	boss.take_damage(40, boss.mouth_area.global_position, "fireball")
	check(fragment.flying and fragment.visible, "Killing boss after loading starts visible flight")
	check(fragment.global_position.distance_to(Vector3(10, 8.9, -213)) < 0.01, "Flight originates inside monster mouth")
	check(not fragment.can_interact(), "Flying fragment cannot be collected remotely")
	boss._reset_hidden(true)
	await create_timer(3.0).timeout
	check(not fragment.flying and fragment.is_visible_in_tree(), "Reward remains visible after boss sinks")
	check(fragment.global_position.distance_to(fragment.DOCK_LANDING) < 0.01, "Boss reset cannot drag reward away from dock")
	var point: Vector3 = fragment.global_position
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * 3, point - Vector3.UP, 1))
	check(not hit.is_empty() and absf(hit.position.y - 6.47) < 0.1, "Landing spot is supported by dock deck")
	# Simulate a save made after victory but before collecting, including during flight.
	data.story_flags["story/lake_monster_defeated"] = true
	loaded = await root.get_node("SaveManager").apply_save_data(data)
	await frames(3)
	world = current_scene
	freeze_world(world)
	boss = world.get_node("LakeMonster")
	fragment = boss.get_node("LakeFragment")
	check(loaded and boss.state == "defeated", "Reload preserves defeated boss")
	check(fragment.is_visible_in_tree() and not fragment.flying and fragment.global_position.distance_to(fragment.DOCK_LANDING) < 0.01, "Unclaimed reward restored directly at dock after reload")
	var actor = world.get_node("Original/Player")
	actor.global_position = fragment.global_position
	check(fragment.can_interact(), "Fragment reachable from dock")
	fragment.interact()
	check(bag.equipment.has("primordial_wave") and bag.collected.has("relic/primordial_wave"), "Dock pickup unlocks Q")
	data.story_flags["relic/primordial_wave"] = true
	data.inventory.equipment.append("primordial_wave")
	loaded = await root.get_node("SaveManager").apply_save_data(data)
	await frames(3)
	fragment = current_scene.get_node("LakeMonster/LakeFragment")
	check(loaded and not fragment.visible and not fragment.can_interact(), "Collected reward cannot respawn after load")
	current_scene.queue_free()
	await frames(2)
	print("LAKE_REWARD_LOAD_RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
