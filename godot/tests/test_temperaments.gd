extends SceneTree
var failures: Array[String] = []
var checks := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	var arena = load("res://tests/combat_training.tscn").instantiate()
	root.add_child(arena)
	current_scene = arena
	arena.player.set_physics_process(false)
	await frames(3)
	for archetype in ["bandit", "araignee", "golem"]:
		var windups := {}
		for temperament in ["equilibre", "agressif", "prudent", "peureux"]:
			arena.selected_temperament = temperament
			arena._spawn(archetype)
			var enemy = arena.opponent
			enemy.set_physics_process(false)
			enemy.player = arena.player
			arena.player.position = enemy.position + Vector3(0, 0, 1.5)
			enemy.health = enemy.max_health * 0.5
			var combat = enemy.combat
			combat.start_attack()
			windups[temperament] = combat.remaining
			enemy.take_damage(1, arena.player.position)
			check(combat.temperament == temperament, archetype + ": explicit " + temperament)
			if temperament == "peureux":
				for i in range(10):
					if combat.phase == "flee": break
					combat.tick(0.1)
				check(combat.phase == "flee", archetype + ": injured coward flees")
				await frames(2)
				var before: float = enemy.global_position.distance_to(arena.player.global_position)
				enemy.set_physics_process(true)
				await frames(30)
				enemy.set_physics_process(false)
				check(enemy.global_position.distance_to(arena.player.global_position) > before + 0.4, archetype + ": physical flight increases distance")
				var remaining: float = combat.remaining
				root.get_node("Inventory").is_open = true
				enemy._physics_process(0.1)
				check(combat.remaining == remaining, archetype + ": flight pauses with inventory")
				root.get_node("Inventory").is_open = false
				enemy.take_damage(1, arena.player.position)
				check(combat.follow_up != "flee", archetype + ": flight cooldown prevents endless renewed panic")
			elif temperament == "agressif":
				check(combat.follow_up.is_empty() and combat.phase != "flee", archetype + ": aggressive enemy stands its ground")
				combat._reset()
				combat.tick(0.01)
				check(combat.phase == "charge_windup", archetype + ": aggressive enemy charges after one provocation")
			combat._recover()
			combat.stagger_guard = 5.0
			combat.flee_cooldown = 5.0
			var hp: float = enemy.health
			enemy.take_damage(10, arena.player.position)
			check(is_equal_approx(hp - enemy.health, 15.0 if temperament == "agressif" else 12.5), archetype + ": reckless profile more vulnerable in recovery")
			await frames(1)
		check(windups.agressif < windups.equilibre and windups.peureux > windups.equilibre, archetype + ": temperament changes attack cadence")
	var chosen := {}
	var rhythms := {}
	for seed_value in range(1, 13):
		var enemy = load("res://scenes/bandit.tscn").instantiate()
		enemy.behavior_seed = seed_value
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		chosen[enemy.combat.temperament] = true
		rhythms[seed_value] = [enemy.combat.temperament, enemy.combat.rhythm]
		enemy.queue_free()
	await frames(1)
	for seed_value in range(1, 13):
		var enemy = load("res://scenes/bandit.tscn").instantiate()
		enemy.behavior_seed = seed_value
		arena.add_child(enemy)
		enemy.set_physics_process(false)
		check(rhythms[seed_value] == [enemy.combat.temperament, enemy.combat.rhythm], "Auto profile and rhythm stable for seed %d" % seed_value)
		enemy.queue_free()
	check(chosen.size() >= 3, "Copies produce varied automatic temperaments")
	arena.queue_free()
	await frames(2)
	print("TEMPERAMENT_RESULT: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
