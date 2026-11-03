extends SceneTree
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	world.add_child(load("res://assets/environment/world/tile_02_vallee_des_sources.glb").instantiate())
	var camp: Node3D = load("res://scenes/world/camp_bandits.tscn").instantiate()
	world.add_child(camp)
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.world_bounds = Rect2(-100, -100, 200, 200)
	var stump: Node3D = camp.get_node("Camp_Billot_Hache_Rochers")
	var collider: CollisionShape3D = stump.get_node("Camp_Billot_Hache_Rochers_col/Cylinder")
	check(collider.global_basis.y.normalized().dot(Vector3.UP) > 0.9999, "Billot collision must stay upright on sloped terrain")
	for sample in range(16):
		var angle := TAU * sample / 16.0
		var offset := Vector3(cos(angle), 0, sin(angle)) * 1.2
		player.global_position = stump.global_position + offset + Vector3.UP * 0.6
		player.velocity = Vector3.ZERO
		player.get_node("CameraPivot").rotation.y = PI / 2.0 - angle
		Input.action_press("move_forward")
		Input.action_press("sprint")
		var fastest := 0.0
		for i in range(240):
			await physics_frame
			fastest = maxf(fastest, player.velocity.length())
		print("STUMP offset=", offset, " pos=", player.global_position, " velocity=", player.velocity, " max_speed=", fastest, " floor=", player.is_on_floor())
		check(fastest < 12.0, "Speed must not accumulate while blocked at angle %d" % sample)
		Input.action_release("move_forward")
		Input.action_release("sprint")
		for i in range(60): await physics_frame
		check(player.velocity.length() < 0.1 and player.is_on_floor(), "Player must stop and remain grounded after input release at angle %d" % sample)
		player.jump_buffer = 0.12
		for i in range(3): await physics_frame
		check(player.velocity.y > 0.0, "Player must be able to jump beside the billot at angle %d" % sample)
		for i in range(90): await physics_frame
		var before: Vector3 = player.global_position
		Input.action_press("move_backward")
		for i in range(30): await physics_frame
		Input.action_release("move_backward")
		check(player.global_position.distance_to(before) > 0.25, "Player must be able to back away from the billot at angle %d" % sample)
		for i in range(30): await physics_frame
	print("CAMP_MOVEMENT_FAILURES: ", failures)
	world.queue_free()
	for i in range(3): await process_frame
	quit(failures)
