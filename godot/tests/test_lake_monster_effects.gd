extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in range(30): await physics_frame
	var boss = world.get_node("LakeMonster")
	var player = world.get_node("Original/Player")
	boss.set_physics_process(false)
	player.set_physics_process(false)
	check(boss.body_collision.shape is CapsuleShape3D and boss.body_collision.shape.radius == 0.5, "Petite capsule d'appui, sans collision détaillée du modèle")
	check(boss.carapace.get_child(0).shape.radius == 3.0 and boss.carapace.collision_mask == 0, "Capsule large de blocage sans balayage du terrain")
	check(boss.carapace.collision_layer == 0, "Capsule large inactive avant apparition")
	var matches := true
	var wet := 0
	var dry := 0
	# Includes banks, water, negative coordinates and grid boundaries.
	for x in range(-24, 33, 4):
		for z in range(-244, -180, 4):
			var point := Vector3(x, 0, z)
			var expected: float = player.water_surface.height_at(point)
			var actual: float = boss._water_height(point)
			if is_finite(expected):
				wet += 1
				matches = matches and is_finite(actual) and absf(expected - actual) < 0.0001
			else:
				dry += 1
				matches = matches and not is_finite(actual)
	check(matches and wet > 0 and dry > 0, "Index local identique aux triangles d'eau sur 240 points, eau et berges")
	player.global_position = Vector3(31, 8, -213)
	boss._begin_emerge()
	await physics_frame
	await physics_frame
	var origin: Vector3 = boss.global_position + Vector3(0, 3, 0)
	var query := PhysicsRayQueryParameters3D.create(origin + Vector3.RIGHT * 7, origin, 4)
	query.collide_with_areas = false
	var hit: Dictionary = world.get_world_3d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider == boss.carapace and hit.position.distance_to(origin) > 2.9, "Collision physique conservée sur le volume large de la carapace")
	for large in [true, false]:
		var effect = load("res://scripts/lake_monster_splash.gd").new()
		effect.large = large
		world.add_child(effect)
		check(effect.sheets.multimesh.mesh is QuadMesh and effect.sheets.multimesh.instance_count == (12 if large else 4), "Plans instanciés pour éclaboussure " + ("grande" if large else "petite"))
		check(effect.find_children("*", "CPUParticles3D", true, false).is_empty(), "Éclaboussure sans simulation de gouttes 3D")
		var image: Image = effect.SPLASH_TEXTURE.get_image()
		check(image.detect_alpha() != Image.ALPHA_NONE, "Texture avec canal alpha effectif")
		effect._process(effect.duration + 0.01)
		check(effect.is_queued_for_deletion(), "Suppression de l'effet après sa durée de vie")
	boss._begin_sink(false)
	check(boss.carapace.collision_layer == 0, "Capsule large désactivée lors de l'immersion")
	print("LAKE_EFFECTS_RESULT: ", "PASS" if failures == 0 else "FAIL", " (", failures, " failures)")
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
