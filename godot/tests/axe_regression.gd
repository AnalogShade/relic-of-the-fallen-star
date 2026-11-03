extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	print("PASS " if value else "FAIL ", message)
	if not value: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	change_scene_to_file("res://scenes/world/open_world.tscn")
	for i in range(12): await physics_frame
	var player = get_first_node_in_group("player")
	var bag = root.get_node("Inventory")
	var billot = current_scene.get_node("Sectors/CampBandits/Camp_Billot_Hache_Rochers")
	var original_mesh: Mesh = billot.mesh
	check(billot.mesh.get_aabb().size.y > 0.2, "Modèle original avec hache conservé avant ramassage")
	var axes = get_nodes_in_group("world_axe")
	check(axes.size() == 1, "Une seule hache au camp")
	if axes.is_empty(): quit(1); return
	var axe = axes[0]
	check(not axe.model.visible and bag.axe_state.is_empty(), "Hache simple masquée et état intact avant ramassage")
	player.global_position = axe.global_position + Vector3(0.5, 0.0, 0.5)
	player.velocity = Vector3.ZERO
	await physics_frame
	axe.interact()
	await process_frame
	check(bag.equipment.has("axe"), "Ramassage ajoute au sac")
	check(billot.mesh != original_mesh and billot.mesh.get_aabb().size.y < 0.15, "Billot remplacé par version sans hache au ramassage")
	check(get_nodes_in_group("world_axe").is_empty(), "Hache disparaît du billot")
	bag.toggle_equipment("axe")
	await process_frame
	var held = player.get_node("HeldEquipment").axe
	check(held.visible and held.get_parent() is BoneAttachment3D, "Équipement attaché à la main")
	var before: Basis = held.global_basis
	held.get_parent().get_parent().rotation.x += 0.5
	await process_frame
	check(not held.global_basis.is_equal_approx(before), "Rotation du squelette transmise à la hache")
	held.get_parent().get_parent().rotation.x -= 0.5
	var visual = player.get_node("Nael")
	visual.set_process(false)
	visual.animator.play("Nael_FrontFlip_InPlace")
	visual.animator.seek(0.0, true)
	await process_frame
	var flip_start: Basis = held.global_basis
	visual.animator.seek(visual.animator.current_animation_length * 0.5, true)
	await process_frame
	check(not held.global_basis.is_equal_approx(flip_start), "Hache tourne pendant le vrai salto")
	check(held.global_basis.get_scale().is_equal_approx(Vector3.ONE), "Échelle du rig compensée pour une hache visible")
	visual.set_process(true)
	player.global_position = Vector3(27, 3, -54)
	for i in range(90): await physics_frame
	check(player.throw_axe(), "Lancer autorisé au sol")
	check(not bag.equipment.has("axe") and bag.equipped == "", "Lancer retire équipement et inventaire")
	var launched = get_first_node_in_group("world_axe")
	check(absf(launched.global_basis.z.y) < 0.001, "Axe de rotation horizontal perpendiculaire à la trajectoire")
	var spin_axis: Vector3 = launched.model.global_basis.z
	for i in range(2): await physics_frame
	check(launched.model.global_basis.z.is_equal_approx(spin_axis), "Rotation bout sur bout sans changement d’axe")
	for i in range(240): await physics_frame
	axes = get_nodes_in_group("world_axe")
	check(axes.size() == 1 and not axes[0].flight, "Projectile retombe et reste récupérable")
	if not axes.is_empty():
		player.global_position = axes[0].global_position + Vector3(0.4,0,0)
		player.velocity = Vector3.ZERO
		await physics_frame
		axes[0].interact()
		await process_frame
	check(bag.equipment.has("axe"), "Récupération après lancer")
	bag.toggle_equipment("axe")
	for i in range(90): await physics_frame
	check(player.start_claw() and player.active_axe_strike and not player.active_claw_left, "Combat utilise la hache droite")
	player.cancel_claw()
	change_scene_to_file("res://scenes/world/open_world.tscn")
	for i in range(12): await physics_frame
	check(get_nodes_in_group("world_axe").is_empty(), "Retour au camp sans duplication")
	player = get_first_node_in_group("player")
	player.set_physics_process(false)
	var target = preload("res://tests/axe_target.gd").new()
	current_scene.add_child(target)
	target.add_to_group("enemies")
	target.collision_layer = 4
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	shape.name = "CollisionShape3D"
	shape.shape = sphere
	target.add_child(shape)
	target.global_position = Vector3(26, 9, -55)
	var shot = preload("res://scripts/world_axe.gd").new()
	current_scene.add_child(shot)
	shot.global_position = target.global_position + Vector3(0,0,2)
	shot.velocity = Vector3(0,0,-14)
	shot.shooter = player
	shot.flight = true
	shot.last_safe = shot.global_position
	bag.equipment.erase("axe")
	bag.equipped = ""
	for i in range(20): await physics_frame
	check(target.health == 60.0 and shot.attached_enemy == target, "Impact inflige 40 PV et hache reste sur ennemi")
	target.global_position.x += 1
	await physics_frame
	check(shot.global_position.x > 26.5, "Hache suit ennemi touché")
	player.global_position = target.global_position - player.get_node("Nael").global_basis.z.normalized()
	player.active_axe_strike = true
	player.active_claw_left = false
	await physics_frame
	player.apply_claw_hit()
	check(target.health == 25.0, "Coup de hache inflige 35 PV")
	var saved_pos: Vector3 = shot.global_position
	var manager = root.get_node("SaveManager")
	var path: String = manager.save_game("Test hache", "user://saves/axe_regression_temp.json")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(data.inventory.axe_state.has("position"), "Sauvegarde conserve position de hache lancée")
	await manager.apply_save_data(data)
	for i in range(8): await physics_frame
	axes = get_nodes_in_group("world_axe")
	check(axes.size() == 1 and axes[0].global_position.distance_to(saved_pos) < 1.0, "Chargement restaure une seule hache près du dernier impact")
	DirAccess.remove_absolute(path)
	player = get_first_node_in_group("player")
	player.global_position = Vector3(27,3,-54)
	for i in range(90): await physics_frame
	player.cancel_claw()
	player.set_physics_process(false)
	var aim_target = preload("res://tests/axe_target.gd").new()
	current_scene.add_child(aim_target)
	aim_target.add_to_group("enemies")
	aim_target.collision_layer = 4
	var aim_shape := CollisionShape3D.new()
	aim_shape.name = "CollisionShape3D"
	aim_shape.shape = sphere
	aim_target.add_child(aim_shape)
	aim_target.global_position = player.global_position + Vector3(0,1,-4)
	var camera := Camera3D.new()
	current_scene.add_child(camera)
	camera.global_position = player.global_position + Vector3(0,2,4)
	camera.look_at(aim_target.global_position)
	camera.current = true
	bag.add_item("axe")
	bag.equipped = "axe"
	bag.changed.emit()
	await physics_frame
	var aim: Vector3 = player.axe_aim_point(camera, player.global_position + Vector3.UP * 1.15, -camera.global_basis.z)
	check(aim.distance_to(aim_target.global_position) < 0.1, "Visée sélectionne le centre de l’ennemi")
	check(player.throw_axe(), "Lancer réel sur cible visée")
	for i in range(40): await physics_frame
	check(aim_target.health == 60.0, "Trajectoire balistique touche l’ennemi visé")
	print("AXE_FAILURES ", failures)
	quit(failures)
