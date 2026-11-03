extends SceneTree

var failures: Array[String] = []
var world: Node3D
var player

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
	world = Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.05, 1)
	world.add_child(player)
	player.set_physics_process(false)
	await frames(3)
	for archetype in ["bandit", "golem", "araignee"]:
		await exercise(archetype)
	world.queue_free()
	await frames(3)
	print("REACTIVE_COMBAT_RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func exercise(archetype: String) -> void:
	var enemy = load("res://scenes/%s.tscn" % archetype).instantiate()
	enemy.temperament = "equilibre"
	world.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.player = player
	enemy.health = 1000.0
	player.position = Vector3(0, 0.05, 1)
	player.health = 100
	player.damage_invulnerability = 0
	var combat = enemy.combat
	await frames(3)
	combat.start_attack()
	check(combat.phase == "windup" and player.health == 100, archetype + ": anticipation without immediate damage")
	enemy.take_damage(25, player.position)
	check(enemy.health == 975, archetype + ": hit always deals damage")
	check(enemy.get_meta("hit_recoil_time", 0.0) > 0.0, archetype + ": damage starts physical recoil")
	var feedback = enemy.get_node("HitFeedback")
	check(not feedback.overlays.is_empty(), archetype + ": damage flashes character meshes")
	check(world.get_node_or_null("HitImpact") != null, archetype + ": damage creates localized impact")
	var previous_velocity: Vector3 = enemy.velocity
	preload("res://scripts/hit_feedback.gd").apply_recoil(enemy, 0.11)
	check(enemy.velocity.z < 0.0, archetype + ": recoil points away from attacker")
	preload("res://scripts/hit_feedback.gd").apply_recoil(enemy, 0.12)
	check(enemy.get_meta("hit_recoil_time") == 0.0, archetype + ": recoil expires")
	enemy.velocity = previous_velocity
	feedback._process(0.4)
	check(feedback.overlays.is_empty(), archetype + ": flash restores original overlays")
	if archetype == "golem":
		check(combat.phase == "windup", "Golem resists one claw interruption")
		enemy.take_damage(25, player.position)
		enemy.take_damage(25, player.position)
		check(combat.phase == "stagger", "Accumulated posture breaks golem attack")
	else:
		check(combat.phase == "stagger", archetype + ": hit interrupts pending attack")
	combat.tick(0.24)
	check(player.health == 100, archetype + ": interrupted attack cannot damage later")
	var phase_before: String = combat.phase
	var time_before: float = combat.remaining
	enemy.take_damage(5, player.position)
	check(combat.phase == phase_before and combat.remaining == time_before, archetype + ": repeated hit cannot extend stun indefinitely")
	if archetype != "golem":
		check(combat.phase == ("retreat" if archetype == "bandit" else "dodge"), archetype + ": archetype-specific repositioning")
		combat.tick(0.1)
		check(Vector2(enemy.velocity.x, enemy.velocity.z).length() > 0, archetype + ": dodge/recoil moves physical body")
	combat._reset()
	combat.aggression = 0
	combat.start_attack()
	player.position = Vector3(0, 0.05, -1)
	combat.tick(1.0)
	check(player.health == 100, archetype + ": committed attack can be sidestepped")
	combat.tick(0.2)
	check(combat.phase == "recover", archetype + ": missed attack leaves an opening")
	var before: float = enemy.health
	enemy.take_damage(20, player.position)
	check(is_equal_approx(before - enemy.health, 25), archetype + ": opening grants 25 percent damage bonus")
	combat._reset()
	combat.aggression = 80
	combat.special_cooldown = 0
	player.position = Vector3(0, 0.05, 4)
	combat.tick(0.01)
	check(combat.phase == "charge_windup", archetype + ": pressure triggers a telegraphed charge")
	var locked: Vector3 = combat.attack_direction
	combat.tick(1.0)
	player.position.x = 2
	combat.tick(0.05)
	check(combat.attack_direction == locked, archetype + ": charge does not home onto player")
	combat.tick(1.0)
	check(combat.phase == "recover", archetype + ": failed charge is punishable")
	combat._reset()
	combat.stagger_guard = 0
	combat.posture = 0
	enemy.take_damage(40, player.position, "fireball")
	check(combat.phase == "stagger", archetype + ": fireball breaks posture")
	var inventory = root.get_node("Inventory")
	inventory.is_open = true
	time_before = combat.remaining
	enemy._physics_process(0.1)
	check(combat.remaining == time_before, archetype + ": inventory pauses reactions")
	inventory.is_open = false
	combat._reset()
	player.position = Vector3(0, 0.05, 1)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(8, 3, 0.1)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 1, 0.5)
	world.add_child(wall)
	await frames(3)
	combat.start_attack()
	combat.tick(1.0)
	check(player.health == 100, archetype + ": wall blocks attack impact")
	wall.queue_free()
	await frames(3)
	combat._reset()
	combat.start_attack()
	combat.tick(1.0)
	check(player.health < 100, archetype + ": unobstructed attack damages player")
	var after: float = player.health
	player.damage_invulnerability = 0
	combat._strike()
	check(player.health == after, archetype + ": one damage application per attack")
	player.position = Vector3(100, 0, 0)
	combat.tick(0.1)
	check(combat.phase.is_empty() and combat.aggression == 0, archetype + ": leash cancels combat")
	player.position = Vector3(0, 0.05, 2)
	if archetype != "golem":
		combat._reset()
		combat.dodge_cooldown = 0
		combat.saw_player_attack = false
		player.is_attacking = true
		combat.tick(0.01)
		check(combat.phase.is_empty(), archetype + ": dodge has a perception delay")
		combat.tick(0.2)
		check(combat.phase == "dodge", archetype + ": anticipates a visible player swing")
		player.is_attacking = false
		combat.tick(0.3)
		if combat.phase.is_empty(): combat.start_attack()
		check(combat.phase == "windup" and combat.counter, archetype + ": dodge followed by counterattack")
	combat._reset()
	enemy.position = Vector3(19.7, 0, 0)
	enemy.velocity = Vector3.ZERO
	combat._move(Vector3.RIGHT, 5, 0.1)
	check(enemy.velocity.x == 0, archetype + ": repositioning refuses a cliff or leash boundary")
	enemy.position = Vector3.ZERO
	player.position = Vector3(0, 0.05, 1.1)
	player.health = 100
	player.damage_invulnerability = 0
	combat.aggression = 0
	combat.stagger_guard = 0
	enemy.set_physics_process(true)
	await frames(160)
	check(player.health < 100, archetype + ": real physics loop completes an attack")
	enemy.take_damage(10000, player.position)
	check(enemy.state == "dead" and not enemy.is_physics_processing(), archetype + ": death stops combat")
	enemy.queue_free()
	await frames(3)
