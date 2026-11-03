extends SceneTree
var failures: Array[String] = []
func _initialize():
	call_deferred("run")
func check(ok: bool, message: String):
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)
func run():
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	var guard_start = world.get_node("Sectors/Bandit_Garde").position
	root.add_child(world)
	current_scene = world
	await process_frame
	# This placement check deliberately simulates every encounter at once.
	world.get_node("EnemyActivity").free()
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	var spawn = player.global_position
	player.global_position = Vector3(200,40,180)
	var bandits = world.get_node("Sectors/BanditsForestiers").get_children()
	var spiders = world.get_node("Sectors/AraigneesForestieres").get_children()
	check(bandits.size() == 24,"24 forest bandits: 4 original + 20 added")
	check(spiders.size() == 10,"10 additional forest spiders")
	check(world.get_node("ForetMalefique/Araignees").get_child_count() == 6,"6 original spiders preserved")
	check(guard_start.is_equal_approx(Vector3(17,2.35,-56)),"Original stream/camp guard preserved")
	for enemy in get_nodes_in_group("enemies"):
		if not str(enemy.name).begins_with("Bandit_Renfort_") and not enemy in spiders: enemy.set_physics_process(false)
	for i in 20:
		await physics_frame
		await process_frame
	for enemy in bandits + spiders:
		if not str(enemy.name).begins_with("Bandit_Renfort_") and not enemy in spiders: continue
		check(enemy.is_on_floor(),str(enemy.name)+": grounded")
		check(enemy.health > 0 and enemy.is_in_group("enemies"),str(enemy.name)+": living combat enemy")
		check(enemy.global_position.distance_to(spawn)>20.0,str(enemy.name)+": outside player start")
		check(enemy.global_position.x > -170 or enemy in spiders,str(enemy.name)+": castle threshold clear")
		if str(enemy.name).begins_with("Bandit_Renfort_"):
			check(not enemy.use_navigation,str(enemy.name)+": forest pursuit enabled")
	world.queue_free()
	await process_frame
	print("ENEMY_DENSITY_RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

