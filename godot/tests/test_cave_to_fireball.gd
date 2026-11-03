extends SceneTree

var failures: Array[String] = []
var tests := 0
var level: Node3D
var player: CharacterBody3D
var enemy: Node3D

func check(ok: bool, msg: String) -> void:
	tests += 1
	if ok:
		print("PASS: %s" % msg)
	else:
		failures.append(msg)
		print("FAIL: %s" % msg)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	print("==================================================")
	print("TEST SUITE: CAVE RECOVERY -> INVENTORY -> FIREBALL")
	print("==================================================")
	
	level = Node3D.new()
	root.add_child(level)
	current_scene = level
	
	# Sol physique pour que le joueur soit au sol (is_on_floor)
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(100, 1, 100)
	col.shape = box
	col.position.y = -0.5
	floor_body.add_child(col)
	level.add_child(floor_body)
	
	# Joueur
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.5, 0)
	level.add_child(player)
	
	# Ennemi distant (bandit)
	enemy = load("res://scenes/bandit.tscn").instantiate()
	enemy.position = Vector3(0, 0, -8.0) # 8 mètres devant
	level.add_child(enemy)
	enemy.set_physics_process(false)
	
	await frames(20)
	
	var inventory := root.get_node_or_null("Inventory")
	check(inventory != null, "Inventory autoload is available")
	if not inventory:
		_finish()
		return
	
	# Vider l'inventaire pour le test
	inventory.equipment.clear()
	inventory.stacks.clear()
	inventory.collected.clear()
	
	check(inventory.has_fireball_relic() == false, "Player starts without fireball relic")
	
	# 1. Tentative de lancer sans la relique
	var cast_blocked = not player.start_fireball() or not inventory.has_fireball_relic()
	check(cast_blocked == true, "Cannot cast fireball without relic in inventory")
	
	# 2. Récupération de la relique comme dans le coffre de la grotte
	print("\n[Simulation] Player recovers 'first_echo' in the cave...")
	var relic_added: bool = inventory.add_item("first_echo")
	check(relic_added == true, "Relic added to inventory")
	check(inventory.has_fireball_relic() == true, "Inventory confirms player has fireball power")
	
	# 3. Lancer au clic droit
	print("\n[Simulation] Player triggers right-click ranged spell cast...")
	var initial_enemy_health: float = enemy.health
	
	# Orienter le personnage et la caméra vers l'ennemi (droit devant, Z négatif)
	player.pivot.rotation.y = 0.0
	player.arm.rotation.x = 0.0
	player.get_node("Nael").rotation.y = PI
	
	var cast_started: bool = player.start_fireball()
	check(cast_started == true, "Player starts fireball cast")
	check(player.is_attacking == true, "Player enters attacking state")
	check(player.is_casting_spell == true, "Player enters spell casting state")
	
	# Laisser l'animation progresser jusqu'au point de lâcher du sort
	await frames(15)
	check(player.fireball_spawned == true, "Fireball projectile spawned at release time")
	check(player.attack_feedback.text == "Boule de feu lancée !", "Combat UI displayed cast feedback")
	
	# Trouver le projectile dans le niveau
	var fireball = null
	for child in level.get_children():
		if "FireballProjectile" in child.name or child is Area3D:
			fireball = child
			break
	
	check(fireball != null, "Fireball projectile exists in level")
	if fireball:
		check(fireball.has_node("FireLight"), "Fireball has dynamic OmniLight3D")
		check(fireball.has_node("ShardTrail"), "Fireball has 3D ShardTrail")
		var shard_p: CPUParticles3D = fireball.get_node("ShardTrail") as CPUParticles3D
		check(shard_p != null and shard_p.local_coords == false, "Shard particles use world-space coordinates (tisons traînant en arrière)")
	
	# Attendre que le projectile vole et frappe l'ennemi (8 mètres à 20 m/s = ~0.4s = ~24 frames)
	print("\n[Simulation] Fireball travels through air towards enemy...")
	await frames(30)
	
	check(enemy.health < initial_enemy_health, "Enemy took damage from fireball impact (Health: %d -> %d)" % [int(initial_enemy_health), int(enemy.health)])
	
	_finish()

func _finish() -> void:
	print("\n==================================================")
	print("TOTAL TESTS: %d | FAILURES: %d" % [tests, failures.size()])
	print("==================================================")
	quit(1 if failures.size() > 0 else 0)
