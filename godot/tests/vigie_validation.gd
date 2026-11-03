extends Node3D
var finished := false
var report: Dictionary = {}
var failures: Array[String] = []
@onready var world: Node3D = $World
@onready var player: CharacterBody3D = $World/Original/Player

func frames(count: int) -> void:
	for i in range(count): await get_tree().physics_frame

func check(ok: bool, text: String) -> void:
	if not ok: failures.append(text)
	print(("PASS: " if ok else "FAIL: ") + text)

func ray(a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	return get_world_3d().direct_space_state.intersect_ray(q)

func _ready() -> void:
	await frames(40)
	var vigie := world.get_node_or_null("Vigie")
	check(vigie != null, "Vigie is instanced in the main world")
	if vigie == null: return
	check(vigie.find_children("*", "MeshInstance3D", true, false).size() == 6, "Six static mesh batches imported")
	check(vigie.find_children("*", "CollisionShape3D", true, false).size() == 5, "Five solid collision groups imported")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vigie_route.json"))
	var route: Array = data.route
	var misses: Array = []
	var points: Array[Vector3] = []
	for i in range(route.size()):
		var s: Array = route[i]
		var hit := ray(Vector3(s[0], s[2] + 3.0, -s[1]), Vector3(s[0], s[2] - 0.5, -s[1]))
		if hit.is_empty() or not "Vigie" in str(hit.collider.get_path()):
			misses.append(i)
			points.append(Vector3(s[0], s[2], -s[1]))
		else:
			points.append(hit.position)
	check(misses.is_empty(), "All 73 step centers have Vigie collision: misses " + str(misses))
	var wall := ray(Vector3(69, 46, -75), Vector3(64, 46, -75))
	check(not wall.is_empty() and "VigieWalls" in str(wall.collider.get_path()), "Tower wall collision at intended world location")
	var entry := ray(Vector3(64, 45.5, -70), Vector3(64, 45.5, -75))
	check(entry.is_empty(), "Doorway center is unobstructed")
	var landing := ray(Vector3(62.5, 49, -76.6), Vector3(62.5, 45, -76.6))
	check(not landing.is_empty() and "VigieFloors" in str(landing.collider.get_path()), "Interior lookout has solid floor")
	for index in [2, 18, 35, 52, 70]:
		player.global_position = points[index] + Vector3.UP * 0.75
		player.velocity = Vector3.ZERO
		await frames(40)
		check(player.is_on_floor() and player.global_position.distance_to(points[index]) < 2.0, "Nael stands on route section %d" % index)
	# Real input and real player physics: jump between two lower landings.
	player.global_position = points[3] + Vector3.UP * 0.6
	player.velocity = Vector3.ZERO
	await frames(35)
	var start_height: float = player.global_position.y
	var target: Vector3 = points[5]
	var direction := (target - player.global_position)
	direction.y = 0
	player.pivot.rotation.y = atan2(-direction.x, -direction.z)
	Input.action_press("move_forward")
	Input.action_press("jump")
	await frames(1)
	Input.action_release("jump")
	var reached := false
	for i in range(65):
		if Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(target.x, target.z)) < 0.23:
			Input.action_release("move_forward")
		await frames(1)
		if player.is_on_floor() and player.global_position.y > start_height + 0.3:
			reached = true
			break
	Input.action_release("move_forward")
	check(reached, "Nael jumps upward onto the stone route using normal controls")
	var camera := Camera3D.new()
	add_child(camera)
	camera.far = 480
	camera.fov = 58
	camera.global_position = Vector3(79, 54, -54)
	camera.look_at(Vector3(64, 47, -75))
	camera.current = true
	world.get_node("Original/HUD").visible = false
	await frames(8)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/vigie_ingame.png")
	report = {"failures": failures, "step_count": route.size(), "collision_misses": misses, "tower_position": [64,44.221379,-75], "jump_verified": reached}
	var file := FileAccess.open("res://tests/vigie_integration_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	finished = true
	print("VIGIE_VALIDATION: " + JSON.stringify(report))
