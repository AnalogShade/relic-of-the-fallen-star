extends SceneTree
## Automated test suite for Cavern Golems: export, variations, patrol, combat, and cave distribution.

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
	print(("PASS " if condition else "FAIL ") + message)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func run() -> void:
	print("=== RUNNING CAVE GOLEMS VALIDATION ===")

	# 1. Test Archetypes and Variations
	_test_archetypes()

	# 2. Test Cave Depths Golem Deployment
	await _test_cave_deployment()

	# 3. Test Combat Interaction (Damage, Health Label, Elimination Message)
	await _test_combat_mechanics()

	print("=== CAVE GOLEMS TEST SUMMARY ===")
	print("FAILURES: ", failures.size())
	if not failures.is_empty():
		for f in failures:
			print(" - ", f)

	quit(0 if failures.is_empty() else 1)

func _test_archetypes() -> void:
	var golem_scene: PackedScene = load("res://scenes/golem.tscn")
	check(golem_scene != null, "golem.tscn loaded successfully")

	# Petit
	var petit: CharacterBody3D = golem_scene.instantiate()
	petit.golem_type = "petit"
	var world := Node3D.new()
	root.add_child(world)
	world.add_child(petit)
	check(petit.enemy_name == "Petit Golem", "Petit archetype sets enemy_name")
	check(is_equal_approx(petit.custom_scale, 0.80), "Petit archetype sets custom_scale to 0.80")
	check(petit.max_health == 70.0, "Petit archetype max_health is 70")
	check(petit.damage == 8.0, "Petit archetype damage is 8")
	check(petit.is_in_group("enemies"), "Petit is in enemies group")

	# Grand
	var grand: CharacterBody3D = golem_scene.instantiate()
	grand.golem_type = "grand"
	world.add_child(grand)
	check(grand.enemy_name == "Grand Golem", "Grand archetype sets enemy_name")
	check(is_equal_approx(grand.custom_scale, 1.42), "Grand archetype sets custom_scale to 1.42")
	check(grand.max_health == 175.0, "Grand archetype max_health is 175")
	check(grand.damage == 18.0, "Grand archetype damage is 18")

	# Standard
	var standard: CharacterBody3D = golem_scene.instantiate()
	standard.golem_type = "standard"
	world.add_child(standard)
	check(standard.enemy_name == "Golem", "Standard archetype sets enemy_name")
	check(is_equal_approx(standard.custom_scale, 1.05), "Standard archetype sets custom_scale to 1.05")
	check(standard.max_health == 100.0, "Standard archetype max_health is 100")
	check(standard.damage == 12.0, "Standard archetype damage is 12")

	# Animations check
	var anim: AnimationPlayer = standard.find_child("AnimationPlayer", true, false)
	check(anim != null, "Golem has AnimationPlayer")
	if anim:
		check(anim.has_animation("marche"), "AnimationPlayer has 'marche'")
		check(anim.has_animation("attaque"), "AnimationPlayer has 'attaque'")
		check(anim.has_animation("rest_position"), "AnimationPlayer has 'rest_position'")

	world.queue_free()
	await process_frame

func _test_cave_deployment() -> void:
	var cave_scene: PackedScene = load("res://scenes/interiors/cave_depths.tscn")
	check(cave_scene != null, "cave_depths.tscn loaded successfully")

	var cave: Node3D = cave_scene.instantiate()
	root.add_child(cave)
	await frames(10)

	var golems_node: Node3D = cave.get_node_or_null("Golems") as Node3D
	check(golems_node != null, "Golems container node created in CaveDepths")

	if golems_node:
		var golem_count := golems_node.get_child_count()
		print("TOTAL GOLEMS IN CAVE: ", golem_count)
		check(golem_count >= 10, "At least 10 golems deployed in cave (found %d)" % golem_count)

		var petits := 0
		var standards := 0
		var grands := 0

		for child in golems_node.get_children():
			if child is CharacterBody3D:
				check(child.is_in_group("enemies"), "Golem %s is in enemies group" % child.name)
				check(child.collision_layer == 4, "Golem %s has collision_layer 4" % child.name)
				check(child.collision_mask == 7, "Golem %s has collision_mask 7" % child.name)
				check(not child.patrol_points.is_empty(), "Golem %s has patrol points defined" % child.name)

				match child.golem_type:
					"petit": petits += 1
					"standard": standards += 1
					"grand": grands += 1

		print("VARIATIONS: Petits=%d, Standards=%d, Grands=%d" % [petits, standards, grands])
		check(petits >= 3, "Multiple Petits Golems present (%d)" % petits)
		check(standards >= 3, "Multiple Standards Golems present (%d)" % standards)
		check(grands >= 2, "Multiple Grands Golems present (%d)" % grands)

		# Check dispersion: player at entrance only triggers nearby enemies, not distant ones
		var player: CharacterBody3D = cave.get_node_or_null("Player") as CharacterBody3D
		check(player != null, "Player present in cave")
		await frames(20)

		var chasing := 0
		for child in golems_node.get_children():
			if child is CharacterBody3D and child.state == "chase":
				chasing += 1
		print("ENEMIES CHASING AT ENTRANCE: ", chasing)
		check(chasing <= 1, "Enemies are dispersed; player is not swarmed at entrance (chasing=%d)" % chasing)

	cave.queue_free()
	await process_frame

func _test_combat_mechanics() -> void:
	var arena := Node3D.new()
	root.add_child(arena)

	# Ground floor
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	col.shape = box
	floor_body.add_child(col)
	floor_body.position.y = -0.5
	arena.add_child(floor_body)

	# Player
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate()
	player.position = Vector3(0, 0.5, 0)
	arena.add_child(player)
	player.set_physics_process(false)

	# Golem
	var golem_scene: PackedScene = load("res://scenes/golem.tscn")
	var golem: CharacterBody3D = golem_scene.instantiate()
	golem.golem_type = "standard"
	golem.position = Vector3(0, 0.5, 1.2)
	arena.add_child(golem)

	await frames(10)

	# Player deals claw damage to golem
	var initial_hp: float = golem.health
	golem.take_damage(25.0, player.global_position)
	check(golem.health == initial_hp - 25.0, "Golem takes 25 damage (health is now %d)" % int(golem.health))
	check(golem.health_label.visible, "Golem health label becomes visible upon damage")
	check(golem.health_label.text.contains("75 / 100"), "Golem health label displays correct remaining HP")

	# Test elimination message in player
	# Simulate player claw hit logic
	var target_name: String = golem.enemy_name if "enemy_name" in golem else "Bandit"
	player.attack_feedback.text = "%s éliminé !" % target_name if golem.health <= 0.0 else "Coup de griffe : −%d PV" % 25
	check(player.attack_feedback.text.contains("25 PV"), "Intermediate claw hit feedback correct")

	# Fatal blow
	golem.take_damage(75.0, player.global_position)
	check(golem.health <= 0.0, "Golem reaches 0 HP")
	check(golem.state == "dead", "Golem state is dead")
	player.attack_feedback.text = "%s éliminé !" % target_name if golem.health <= 0.0 else "Coup de griffe : −%d PV" % 25
	check(player.attack_feedback.text == "Golem éliminé !", "Player elimination feedback shows 'Golem éliminé !'")

	# Test Petit Golem elimination message
	var petit: CharacterBody3D = golem_scene.instantiate()
	petit.golem_type = "petit"
	arena.add_child(petit)
	await frames(5)
	petit.take_damage(100.0, player.global_position)
	var petit_name: String = petit.enemy_name if "enemy_name" in petit else "Bandit"
	var feedback: String = "%s éliminé !" % petit_name if petit.health <= 0.0 else "Coup de griffe"
	check(feedback == "Petit Golem éliminé !", "Petit Golem produces 'Petit Golem éliminé !'")

	arena.queue_free()
	await process_frame
