extends SceneTree
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
	print("PASS " if condition else "FAIL ", message)

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in range(count): await physics_frame

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var floor_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	collision.shape = box
	floor_body.add_child(collision)
	floor_body.position.y = -0.5
	world.add_child(floor_body)
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.425, 5)
	world.add_child(player)
	player.set_physics_process(false)
	var bandit = load("res://scenes/bandit.tscn").instantiate()
	world.add_child(bandit)
	var anim: AnimationPlayer = bandit.animator
	print("ANIMATIONS ", anim.get_animation_list())
	for clip in ["Idle", "Walking", "Running", "Punch"]:
		check(anim.has_animation(clip), "Imported " + clip)
	await frames(60)
	check(bandit.global_position.z > 1.0, "Chases nearby player")
	await frames(180)
	check(player.health < 100, "Punch inflicts damage")
	var before: float = player.health
	player.position = Vector3(25, 0.425, 25)
	await frames(120)
	check(player.health == before, "No damage outside range")
	await frames(240)
	check(bandit.global_position.distance_to(bandit.home) < 0.5, "Returns to camp")
	# An opaque wall blocks both detection and melee damage.
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(6, 3, 0.2)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 1.5, 0.6)
	world.add_child(wall)
	player.position = Vector3(0, 0.425, 1.1)
	await frames(90)
	check(player.health == before, "Wall blocks punches")
	player.damage_invulnerability = 0.0
	player.take_damage(200, Vector3.ZERO)
	check(player.health == 100 and player.global_position == player.spawn_position, "Defeat respawns player with restored health")
	print("BANDIT_TEST_RESULT ", failures)
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
