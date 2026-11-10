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
func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(4)
	var bag = root.get_node("Inventory")
	var actor = world.get_node("Original/Player")
	var boss = world.get_node("LakeMonster")
	var fragment = boss.get_node("LakeFragment")
	world.get_node("EnemyActivity").free()
	actor.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	check(InputMap.action_get_events("primordial_nova")[0].physical_keycode == KEY_Q, "Q bound to nova")
	check(not actor.nova_ability.try_cast(), "Ability locked before collecting second fragment")
	check(not fragment.visible, "Fragment absent before lake boss defeat")
	boss._begin_emerge()
	boss.state = "attack"
	boss.mouth_area.global_position = Vector3(7, 9, -213)
	boss.health = 1
	boss.take_damage(40, boss.mouth_area.global_position, "fireball")
	await frames(2)
	check(bag.collected.has("story/lake_monster_defeated") and fragment.visible, "Real boss death releases fragment")
	check(fragment.flying and not fragment.can_interact(), "Fragment visibly flies from boss before collection")
	await create_timer(2.8).timeout
	var restored = load("res://scripts/lake_fragment.gd").new()
	world.add_child(restored)
	await frames(2)
	check(restored.visible, "Unclaimed reward restored from defeat flag, including older saves")
	restored.queue_free()
	actor.global_position = fragment.global_position
	check(fragment.global_position.distance_to(Vector3(19, 6.52, -212.7)) < 0.01, "Reward lands at end of lake dock")
	fragment.interact()
	check(bag.equipment.has("primordial_wave") and bag.collected.has("relic/primordial_wave"), "F pickup permanently grants nova")
	fragment.interact()
	check(bag.equipment.count("primordial_wave") == 1, "Reward cannot duplicate")
	var saved_path: String = root.get_node("SaveManager").save_game("Nova automated test", "user://saves/nova_automated_test.json")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(saved_path))
	check(saved.inventory.equipment.has("primordial_wave") and saved.story_flags.has("relic/primordial_wave"), "Save includes fragment and permanent pickup flag")
	DirAccess.remove_absolute(saved_path)
	var forest = world.get_node("ForetMalefique")
	print("BROOD_COUNT ", forest.brood_count)
	check(forest.brood_count >= 18, "At least 18 extra brood spiders grounded in corrupted forest")
	var leader = forest.get_node("Araignees/Araignee_Gardienne_Est")
	var original_health: float = leader.health
	leader.take_damage(999, leader.global_position + Vector3.RIGHT, "fireball")
	check(leader.health == original_health, "Corrupted leader withstands fire until nova purifies it")
	# Controlled open arena above terrain, real enemies and damage handlers.
	actor.global_position = Vector3(0, 50, 0)
	leader.global_position = Vector3(4, 50, 0)
	var fodder = forest.get_node("Broods").get_child(0)
	fodder.global_position = Vector3(-4, 50, 0)
	var distant = forest.get_node("Broods").get_child(1)
	distant.global_position = Vector3(11, 50, 0)
	var high = forest.get_node("Broods").get_child(2)
	high.global_position = Vector3(1, 56, 0)
	var occluded = forest.get_node("Broods").get_child(3)
	occluded.global_position = Vector3(0, 50, -4)
	var wall := StaticBody3D.new()
	wall.position = Vector3(0, 51, -2)
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 4, 0.5)
	collision.shape = box
	wall.add_child(collision)
	world.add_child(wall)
	await frames(2)
	bag.set_open(true)
	check(not actor.nova_ability.try_cast(), "Inventory blocks nova")
	bag.set_open(false)
	bag.equipped = "axe"
	var press := InputEventKey.new()
	press.physical_keycode = KEY_Q
	press.pressed = true
	actor._unhandled_input(press)
	check(not get_nodes_in_group("primordial_novas").is_empty(), "Real Q key handler casts while holding axe")
	check(actor.nova_ability.hint.is_visible_in_tree(), "Nova HUD visible without taking damage first")
	check(not actor.nova_ability.try_cast(), "Cooldown prevents repeated casting")
	check(leader.health == original_health, "Damage waits for wavefront")
	await frames(35)
	check(not leader.corrupted_carapace and leader.health < original_health, "Wave breaks shield and damages leader")
	check(float(leader.get_meta("hit_recoil", Vector3.ZERO).length()) > 10, "Survivor receives strong outward recoil")
	check(not is_instance_valid(fodder) or fodder.health == 0, "Nova kills ordinary brood spider")
	check(distant.health == distant.max_health, "Enemy beyond radius untouched")
	check(high.health == high.max_health, "Enemies on another floor untouched")
	check(occluded.health == occluded.max_health, "Wall blocks wave damage")
	var after_health: float = leader.health
	await frames(40)
	check(leader.health == after_health, "One hit per enemy and nova")
	check(get_nodes_in_group("primordial_novas").is_empty(), "Effect cleans up after its lifetime")
	check(actor.nova_ability.cooldown > 0, "Cooldown remains visible after effect")
	world.queue_free()
	await frames(2)
	print("PRIMORDIAL_NOVA_RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
