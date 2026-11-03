extends Node3D
var failures: Array[String] = []
var finished := false
var report: Dictionary = {}
@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $World/Original/Player
var excluded: Array[RID] = []

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
	print(("PASS: " if ok else "FAIL: ") + message)

func frames(count: int) -> void:
	for i in range(count): await get_tree().physics_frame

func ground_hit(x: float, z: float) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -5, z), 1, excluded)
	return get_world_3d().direct_space_state.intersect_ray(q)

func _ready() -> void:
	await frames(45)
	for node in world.find_children("*", "CollisionObject3D", true, false):
		if not "/Terrain" in str(node.get_path()):
			excluded.append(node.get_rid())
	check(world.get_node("Sectors").find_children("Tile_*", "Node3D", false, false).size() == 29, "Twenty-nine additional terrain sectors loaded")
	check(player.world_bounds.has_point(Vector2(-56, -1)), "Cabin inside expanded playable bounds")
	var holes := 0
	var min_h := 100.0
	var max_h := -100.0
	for x in range(-92, 93, 4):
		for z in range(-100, 85, 4):
			var hit := ground_hit(x, z)
			if hit.is_empty(): holes += 1
			else:
				min_h = minf(min_h, hit.position.y)
				max_h = maxf(max_h, hit.position.y)
	check(holes == 0, "Terrain collision coverage: %d holes" % holes)
	var seam_errors := 0
	for x in [-32.0, 32.0]:
		for z in range(-100, 85, 2):
			var a := ground_hit(x - 0.02, z)
			var b := ground_hit(x + 0.02, z)
			if a.is_empty() or b.is_empty() or absf(a.position.y - b.position.y) > 0.2:
				seam_errors += 1
				print("SEAM ", x, " ", z, " ", a, " ", b)
	for z in [-40.0, 24.0]:
		for x in range(-92, 93, 2):
			var a := ground_hit(x, z - 0.02)
			var b := ground_hit(x, z + 0.02)
			if a.is_empty() or b.is_empty() or absf(a.position.y - b.position.y) > 0.2:
				seam_errors += 1
				print("SEAM ", x, " ", z, " ", a, " ", b)
	check(seam_errors == 0, "Tile seam collision continuity: %d failures" % seam_errors)
	check(max_h > 35.0, "Mountain relief reaches %.2f metres" % max_h)
	var start := ground_hit(-30.0, -1.0)
	if not start.is_empty():
		player.global_position = start.position + Vector3.UP * 0.5
		player.velocity = Vector3.ZERO
		player.pivot.rotation.y = 0.0
		await frames(45)
		Input.action_press("move_left")
		await frames(120)
		Input.action_release("move_left")
		await frames(15)
		print("WALK_END ", player.global_position, " bounds ", player.world_bounds)
		check(player.global_position.x < -32.5, "Player walks beyond old map limit without respawning")
	var approach := ground_hit(-56.0, 6.0)
	if not approach.is_empty():
		player.global_position = approach.position + Vector3.UP * 0.5
		player.velocity = Vector3.ZERO
		await frames(60)
		check(player.is_on_floor(), "Character stands on cabin clearing")
	var wall_query := PhysicsRayQueryParameters3D.create(Vector3(-56.5, 13.2, 6), Vector3(-56.5, 13.2, -1), 1)
	var wall_hit := get_world_3d().direct_space_state.intersect_ray(wall_query)
	check(not wall_hit.is_empty() and "Cabin" in str(wall_hit.collider.get_path()), "Cabin walls have collision")
	report = {"failures": failures, "holes": holes, "seam_errors": seam_errors, "elevation_min": min_h, "elevation_max": max_h, "fps": Engine.get_frames_per_second()}
	var file := FileAccess.open("res://tests/world_validation_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(-56, 14.2, 8.5)
	camera.look_at(Vector3(-56, 14.5, -1))
	camera.fov = 68
	camera.far = 480
	camera.current = true
	await frames(5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/world_cabin.png")
	camera.global_position = Vector3(125, 135, 170)
	camera.look_at(Vector3(0, 10, -8))
	camera.fov = 42
	await frames(5)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/world_overview.png")
	finished = true
	print("WORLD_VALIDATION: " + JSON.stringify(report))
