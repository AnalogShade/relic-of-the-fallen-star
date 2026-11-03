extends SceneTree
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: ", message)
	else:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(30):
		await physics_frame
	var boss = world.get_node("LakeMonster")
	var player = world.get_node("Original/Player")
	check(boss.state == "dormant" and not boss.visual.visible, "Absent avant l'approche")
	check(boss.clips.size() == 4, "Quatre animations V3 importées")
	check(boss.skeleton.get_bone_count() == 26, "Squelette V3 importé avec contrôles cuits")
	check(boss.Model.resource_path.ends_with("crystalmaw_v003.glb"), "Nouveau modèle utilisé dans le monde principal")
	boss.animator.play(boss.clips.Walk)
	boss.animator.seek(0.0, true)
	var foot_index: int = boss.skeleton.find_bone("foot.R")
	var foot_rest: Vector3 = boss.skeleton.get_bone_global_pose(foot_index).origin
	boss.animator.seek(1.2, true)
	var foot_lift: Vector3 = boss.skeleton.get_bone_global_pose(foot_index).origin
	check(foot_lift.distance_to(foot_rest) > 0.15, "Mouvements IK des pattes réellement cuits dans le GLB")
	boss.animator.stop()
	var old_health: float = boss.health
	boss.take_damage(50000, boss.global_position, "claw")
	check(boss.health == old_health, "Griffes sans effet sur boss dormant")
	player.global_position = Vector3(31, 8, -213)
	player.velocity = Vector3.ZERO
	await physics_frame
	await physics_frame
	check(boss.state == "emerging" and boss.visual.visible, "Approche déclenche le surgissement")
	await create_timer(3.0).timeout
	check(boss.splash_count >= 2, "Éclaboussures du surgissement")
	check(is_equal_approx(boss.visual.position.y, boss.immersion), "Surgissement animé conserve la ligne d'immersion")
	await create_timer(3.7).timeout
	check(boss.state == "attack", "Début d'attaque après surgissement")
	# Pause autonomous behavior while checking the damage contract.
	boss.set_physics_process(false)
	boss.state = "attack"
	boss.state_time = 1.5
	boss._sync_mouth()
	var mouth: Vector3 = boss.mouth_area.global_position
	boss.take_damage(50000, mouth, "claw")
	check(boss.health == old_health, "Griffes impuissantes même sur point faible ouvert")
	boss.take_damage(40, boss.global_position + Vector3.UP * 4, "fireball")
	check(boss.health == old_health, "Boule de feu contre carapace sans effet")
	boss.state_time = 0.1
	boss.take_damage(40, mouth, "fireball")
	check(boss.health == old_health - 80, "Intérieur de la gueule vulnérable même hors fenêtre de charge")
	boss.health = old_health # Restore fixture before exercising real projectiles.
	boss.state_time = 1.5
	# Exercise the real player fireball hit dispatch against the Area3D.
	var fireball = load("res://scenes/spells/fireball_projectile.tscn").instantiate()
	world.add_child(fireball)
	fireball.global_position = mouth
	fireball._handle_hit(boss.mouth_area)
	check(boss.health == old_health - 80, "Vrai projectile de feu inflige 80 au point faible")
	var flying_fireball = load("res://scenes/spells/fireball_projectile.tscn").instantiate()
	world.add_child(flying_fireball)
	flying_fireball.global_position = mouth + Vector3.RIGHT * 6
	flying_fireball.direction = Vector3.LEFT
	await create_timer(0.5).timeout
	check(boss.health == old_health - 160, "Boule de feu en vol touche la hitbox de la gueule")
	boss.shot_target = player.global_position + Vector3.UP * 0.65
	boss._fire()
	check(boss.shots_fired == 1, "Création du projectile ennemi")
	# Real collision and player damage. Disable movement so the target stays fixed.
	player.set_physics_process(false)
	player.global_position = Vector3(34, 9, -213)
	player.health = 100
	player.damage_invulnerability = 0
	for projectile in get_nodes_in_group("lake_monster_projectiles"):
		projectile.queue_free()
	await physics_frame
	var projectile = load("res://scripts/lake_monster_projectile.gd").new()
	projectile.direction = Vector3.RIGHT
	projectile.water_y = -100
	world.add_child(projectile)
	projectile.global_position = player.global_position + Vector3.LEFT * 3
	await create_timer(0.6).timeout
	check(player.health == 40, "Projectile ennemi enlève réellement 60 PV")
	# Retreat and defeat transitions disable collisions immediately.
	boss.set_physics_process(true)
	player.global_position = Vector3(90, 8, -213)
	await physics_frame
	await physics_frame
	check(boss.state == "sinking" and boss.collision_layer == 0, "Retraite fait replonger le boss")
	await create_timer(5.3).timeout
	check(boss.state == "dormant" and not boss.visual.visible and boss.health == boss.max_health, "Réarmement après retraite")
	# Slow gait drives an actual collision-aware body rather than just a model animation.
	player.global_position = Vector3(33, 8, -220)
	boss._begin_emerge()
	boss.state = "walking"
	boss.state_time = 0
	boss._play("Walk")
	var before_walk: Vector3 = boss.global_position
	await create_timer(2.0).timeout
	check(boss._flat_distance(before_walk, boss.global_position) > 0.35, "Marche lente déplace réellement le monstre")
	check(boss._flat_distance(boss.global_position, boss.home_position) < boss.maximum_excursion, "Poursuite limitée aux abords du lac")
	player.global_position = Vector3(90, 8, -213)
	await physics_frame
	await physics_frame
	check(boss.state == "returning", "Éloignement du joueur déclenche un retour à pied")
	var return_shots: int = boss.shots_fired
	boss.walk_speed = 2.0 # Keep the return test quick; the real speed was checked above.
	for i in range(14):
		if boss.state == "dormant": break
		await create_timer(1.0).timeout
	check(boss.state == "dormant" and boss._flat_distance(boss.global_position, boss.home_position) < 0.1, "Retour au lac puis immersion complète")
	check(boss.shots_fired == return_shots, "Aucun nouveau tir pendant le retour")
	boss.set_physics_process(false)
	boss._begin_emerge()
	boss._play("Idle", 0.0)
	boss._sync_mouth()
	boss.state = "attack"
	boss.state_time = 1.5
	boss.take_damage(1000, boss.mouth_area.global_position, "fireball")
	check(boss.health == 0 and boss.state == "sinking", "Victoire fait replonger le boss")
	check(get_root().get_node("Inventory").collected.has("story/lake_monster_defeated"), "Victoire persistante dans les story flags")
	var restored = load("res://scripts/lake_monster.gd").new()
	world.add_child(restored)
	check(restored.state == "defeated" and not restored.visual.visible and restored.collision_layer == 0, "Boss vaincu reste absent à la recréation du monde")
	print("LAKE_MONSTER_RESULT: ", "PASS" if failures.is_empty() else "FAIL", " (", failures.size(), " failures)")
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
