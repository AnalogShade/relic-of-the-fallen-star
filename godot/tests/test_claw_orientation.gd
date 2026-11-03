extends SceneTree

var failures: Array[String] = []
var actor
var enemy
var level: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func run() -> void:
	level = Node3D.new()
	root.add_child(level)
	current_scene = level
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collider.shape = shape
	collider.position.y = -0.5
	floor_body.add_child(collider)
	level.add_child(floor_body)

	actor = load("res://scenes/player.tscn").instantiate()
	actor.position = Vector3(0, 0.5, 0)
	level.add_child(actor)
	actor.pivot.rotation.y = 0.0

	var nael: Node3D = actor.get_node("Nael")
	await frames(15)

	# Test 1: Facing towards camera (rotation.y = 0.0, while camera pivot is 0.0)
	nael.rotation.y = 0.0
	var enemy_front = load("res://scenes/bandit.tscn").instantiate()
	enemy_front.position = Vector3(0, 0, 1.25)
	level.add_child(enemy_front)
	enemy_front.set_physics_process(false)

	var enemy_back = load("res://scenes/bandit.tscn").instantiate()
	enemy_back.position = Vector3(0, 0, -1.25)
	level.add_child(enemy_back)
	enemy_back.set_physics_process(false)

	await frames(5)
	check(actor.start_claw(), "Claw starts while facing camera")
	check(absf(nael.rotation.y) < 0.001, "Nael maintains facing-camera orientation immediately upon attack")
	await frames(15)
	check(absf(nael.rotation.y) < 0.001, "Nael maintains facing-camera orientation mid-swing")
	await frames(35)
	check(absf(nael.rotation.y) < 0.001, "Nael maintains facing-camera orientation at end of swing")
	check(enemy_front.health == 75.0, "Claw hits enemy in front of character facing camera")
	check(enemy_back.health == 100.0, "Claw does NOT hit enemy behind character facing camera")

	enemy_front.queue_free()
	enemy_back.queue_free()
	await frames(5)

	# Test 2: Facing sideways (rotation.y = PI * 0.5, facing +X) with camera pivot at arbitrary angle
	actor.pivot.rotation.y = 1.25
	nael.rotation.y = PI * 0.5

	var enemy_side = load("res://scenes/bandit.tscn").instantiate()
	enemy_side.position = Vector3(1.25, 0, 0)
	level.add_child(enemy_side)
	enemy_side.set_physics_process(false)

	await frames(5)
	check(actor.start_claw(), "Claw starts while facing sideways")
	check(absf(nael.rotation.y - PI * 0.5) < 0.001, "Sideways orientation preserved on attack")
	await frames(50)
	check(absf(nael.rotation.y - PI * 0.5) < 0.001, "Sideways orientation preserved after attack")
	check(enemy_side.health == 75.0, "Claw hits enemy sideways in front of character")

	enemy_side.queue_free()
	await frames(5)

	# Test 3: Camera rotation does not affect stationary character orientation
	actor.pivot.rotation.y = -2.1
	await frames(10)
	check(absf(nael.rotation.y - PI * 0.5) < 0.001, "Rotating camera pivot does not alter character orientation")

	print("CLAW_ORIENTATION_RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
