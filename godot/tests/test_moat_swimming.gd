extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok:
		failures.append(label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(30)
	var player = world.get_node("Original/Player")
	for point in [Vector3(-266,10,-30.7), Vector3(-224.7,10,-76.2), Vector3(-183.4,10,-30.7), Vector3(7,5,-213)]:
		var height: float = player.water_surface.height_at(point)
		player.global_position = Vector3(point.x, height - 1.5, point.z)
		player.velocity = Vector3.ZERO
		await frames(180)
		check(player.swimming and absf(height - player.global_position.y - player.float_depth) < 0.04, "Consistent immersion at " + str(point))
	# Exercise the real controller and collisions while exiting the west moat.
	player.global_position = Vector3(-266,10,-30.7)
	player.velocity = Vector3.ZERO
	player.pivot.rotation.y = 0.0
	await frames(120)
	Input.action_press("move_left")
	await frames(120)
	Input.action_press("jump")
	await frames(5)
	check(player.water_jump_active and player.velocity.y > 0.0, "Jump launches from swimming")
	Input.action_release("jump")
	await frames(160)
	Input.action_release("move_left")
	check(not player.swimming and player.is_on_floor() and player.global_position.x < -275.0 and not is_finite(player.water_surface.height_at(player.global_position)), "Water jump reaches dry outer bank")
	Input.action_press("move_left")
	await frames(60)
	Input.action_release("move_left")
	check(player.global_position.x < -279.0 and player.is_on_floor(), "Walking continues after leaving the moat")
	player.respawn()
	check(not player.water_jump_active, "Respawn clears water jump")
	world.free()
	print("MOAT_RESULT %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
