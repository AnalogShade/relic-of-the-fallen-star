extends SceneTree
var failures: Array[String] = []
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures.append(message)

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func run_tests() -> void:
	var packed := load("res://scenes/forest_test.tscn") as PackedScene
	check(packed != null, "Scene loads")
	var level := packed.instantiate()
	root.add_child(level)
	current_scene = level
	player = level.get_node("Player")
	await frames(100)
	check(player.is_on_floor(), "Cube lands on imported terrain")
	check(player.global_position.y > 0.5, "Spawn remains above the riverbed")
	var shapes := level.find_children("*", "CollisionShape3D", true, false)
	check(shapes.size() >= 5, "Terrain, wood, rocks and shrine have collisions")
	for pair in [[KEY_W, Vector3.FORWARD], [KEY_S, Vector3.BACK], [KEY_A, Vector3.LEFT], [KEY_D, Vector3.RIGHT]]:
		player.respawn()
		await frames(80)
		var before := player.global_position
		key(pair[0], true)
		# Allow half a second for the slower walking speed on sloped terrain.
		await frames(30)
		key(pair[0], false)
		var displacement := player.global_position - before
		var expected: Vector3 = player.pivot.global_basis * pair[1]
		check(displacement.dot(expected) > 0.35, "Physical key %s moves relative to camera" % OS.get_keycode_string(pair[0]))
	player.respawn()
	await frames(90)
	var floor_y := player.global_position.y
	key(KEY_SPACE, true)
	await frames(15)
	key(KEY_SPACE, false)
	check(player.global_position.y > floor_y + 0.5, "Space jumps")
	await frames(100)
	check(player.is_on_floor(), "Cube lands after jump")
	check(absf(player.global_position.y - floor_y) < 0.15, "No penetration on landing")
	player.global_position.y = -12
	await frames(4)
	check(player.global_position.y > 0, "Fall recovery returns to spawn")
	await frames(90)
	var world := player.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(-5,20,8),Vector3(-5,-5,8),1)
	check(not world.intersect_ray(ray).is_empty(), "Terrain raycast hits collision mesh")
	var wall := StaticBody3D.new()
	wall.position = player.global_position + Vector3(0,0,2.4)
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4,4,0.4)
	shape_node.shape = box
	wall.add_child(shape_node)
	level.add_child(wall)
	player.pivot.rotation.y = 0
	await frames(8)
	check(player.arm.get_hit_length() < 3.5, "Spring arm retracts against obstacles")
	wall.queue_free()
	await frames(8)
	check(player.arm.get_hit_length() > 4.0, "Spring arm extends after obstruction clears")
	player.pivot.rotation.y = -0.3
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		var motion := InputEventMouseMotion.new()
		motion.relative = Vector2(100,30)
		Input.parse_input_event(motion)
		await frames(2)
		check(player.pivot.rotation.y < -0.4, "Mouse orbits camera")
		player.pivot.rotation.y = -0.3
		player.arm.rotation.x = -0.27
		await frames(30)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/godot_playground.png")
	print("TEST_RESULT: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
