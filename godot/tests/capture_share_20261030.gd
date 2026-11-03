extends SceneTree

const OUT := "C:/Users/Utilisateur/Documents/Dev/Jeux/Relic of the fallen star/screenshots/Nael_2026-10-30/"
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func frames(n: int = 4) -> void:
	for i in n: await process_frame

func hide_hud(node: Node) -> void:
	if node is CanvasLayer or node is Label3D: node.hide()
	for child in node.get_children(): hide_hud(child)

func aim(world: Node, eye: Vector3, target: Vector3, fov: float = 58.0) -> void:
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		world.add_child(camera)
	camera.fov = fov
	camera.global_position = eye
	camera.look_at(target)
	camera.make_current()

func capture(label: String) -> void:
	hide_hud(root)
	await frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("CAPTURED ", label)

func pose(actor: Node3D, target: Vector3) -> void:
	actor.set_physics_process(false)
	var model = actor.get_node("Nael")
	model.set_process(false)
	var direction: Vector3 = target - actor.global_position
	model.rotation.y = atan2(direction.x, direction.z)
	model.animator.play("Nael_Claw")
	model.animator.seek(0.40, true)
	model.animator.pause()

func fire(world: Node, actor: Node3D, target: Vector3, distance: float) -> Node3D:
	pose(actor, target)
	var projectile = load("res://scenes/spells/fireball_projectile.tscn").instantiate()
	world.add_child(projectile)
	var origin := actor.global_position + Vector3.UP * 1.05
	var direction := (target - origin).normalized()
	projectile.launch(origin + direction * distance, direction)
	projectile.set_physics_process(false)
	projectile.collision_mask = 0
	projectile.set_deferred("monitoring", false)
	return projectile

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1920, 1080)
	var cave = load("res://scenes/interiors/cave_depths.tscn").instantiate()
	root.add_child(cave)
	current_scene = cave
	await frames(40)
	var actor = cave.get_node("Player")
	actor.set_physics_process(false)
	actor.global_position = Vector3(27, 8.05, -34)
	for enemy in get_nodes_in_group("enemies"): enemy.set_physics_process(false)
	fire(cave, actor, Vector3(25, 9, -43), 2.0)
	aim(cave, Vector3(31.5, 10.5, -29.5), Vector3(26.5, 9.1, -36.5), 58)
	await create_timer(0.7).timeout
	await capture("01_Nael_boule_de_feu_caverne")
	aim(cave, Vector3(31, 10.3, -35), Vector3(26.5, 9.0, -36), 68)
	await capture("02_Nael_magie_caverne")
	cave.free()
	camera = null
	await frames()
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(30)
	world.get_node("EnemyActivity").free()
	actor = world.get_node("Original/Player")
	actor.set_physics_process(false)
	actor.global_position = Vector3(-230, 9.6, -150)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.hide()
	var spiders: Array[Node3D] = []
	for i in 7:
		var spider = load("res://scenes/araignee.tscn").instantiate()
		spider.spider_scale = 1.25
		world.add_child(spider)
		var angle := TAU * i / 7.0
		var p: Vector3 = actor.global_position + Vector3(cos(angle) * 6.5, 0, sin(angle) * 6.5)
		var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 10, p - Vector3.UP * 10, 1))
		if not hit.is_empty(): p.y = hit.position.y + 0.05
		spider.global_position = p
		spider.set_physics_process(false)
		spider.rotation.y = atan2(actor.global_position.x-p.x, actor.global_position.z-p.z)
		spider.health_label.hide()
		spider.combat.set_physics_process(false)
		spiders.append(spider)
	pose(actor, actor.global_position + Vector3(0,0,3))
	var nova = load("res://scripts/spells/primordial_nova.gd").new()
	world.add_child(nova)
	nova.global_position = actor.global_position
	nova.set_physics_process(false)
	nova.elapsed = 0.38
	nova._update_visuals()
	aim(world, actor.global_position + Vector3(8, 7, 10), actor.global_position + Vector3(0, 0.5, 0), 58)
	await capture("03_Nael_supernova_araignees")
	nova.elapsed = 0.53
	nova._update_visuals()
	aim(world, actor.global_position + Vector3(8, 4, 10), actor.global_position + Vector3(0,0.6,0), 66)
	await capture("04_Nael_onde_primordiale")
	nova.free()
	for spider in spiders: spider.free()
	actor.global_position = Vector3(33, 8, -213)
	var shore: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(33, 20, -213), Vector3(33, -5, -213), 1))
	if not shore.is_empty(): actor.global_position.y = shore.position.y + 0.04
	var boss = world.get_node("LakeMonster")
	boss.process_mode = Node.PROCESS_MODE_INHERIT
	boss._begin_emerge()
	boss.set_physics_process(false)
	boss.show()
	boss.visual.show()
	boss.visual.position.y = boss.immersion
	boss._play("Spit", 0.0)
	boss.animator.seek(1.9, true)
	boss.animator.pause()
	boss.health_label.hide()
	boss.pivot.rotation.y = atan2(actor.global_position.x-boss.global_position.x, actor.global_position.z-boss.global_position.z)
	var target: Vector3 = boss.global_position + Vector3.UP * 4.5
	fire(world, actor, target, 2.5)
	aim(world, Vector3(40, 12, -199), Vector3(18, 9, -213), 53)
	await create_timer(0.5).timeout
	await capture("05_Nael_combat_monstre_du_lac")
	aim(world, Vector3(38, 10, -207), Vector3(18, 8, -213), 68)
	await capture("06_Nael_face_au_devoreur")
	quit()



