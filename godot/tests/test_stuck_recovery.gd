extends SceneTree
var failures := 0
var level: Node3D
var p: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func frames(count: int) -> void:
	for i in count:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures += 1

func box(point: Vector3, size: Vector3, angle := 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	body.position = point
	body.rotation.z = deg_to_rad(angle)
	level.add_child(body)
	return body

func run() -> void:
	level = Node3D.new()
	root.add_child(level)
	current_scene = level
	box(Vector3(0, -0.5, 0), Vector3(80, 1, 80))
	p = load("res://scenes/player.tscn").instantiate()
	p.position = Vector3(0, 0.5, 0)
	level.add_child(p)
	p.world_bounds = Rect2(-100, -100, 200, 200)
	await frames(60)
	p.health = 71.0
	check(not p.stuck_recovery.safe_positions.is_empty(), "Records stable footing")
	# A V of steep faces holds the character airborne without a floor contact.
	box(Vector3(3, 1, 0), Vector3(8, 0.2, 8), 60)
	box(Vector3(3, 1, 0), Vector3(8, 0.2, 8), -60)
	p.global_position = Vector3(3, 3, 0)
	p.velocity = Vector3.ZERO
	p.jumped_this_air = true
	p.air_jump_used = true
	Input.action_press("move_right")
	await frames(120)
	print("WEDGE ", p.global_position, " floor=", p.is_on_floor(), " stalled=", p.stuck_recovery.stalled, " contacts=", p.get_slide_collision_count())
	check(p.stuck_recovery.stalled >= 0.7, "Detects wedged collision even when engine reports a floor")
	var start := p.global_position
	Input.action_press("jump")
	await frames(35)
	check(p.global_position.y > start.y + 0.3, "Holding jump escapes wedge after spent jumps")
	Input.action_release("jump")
	Input.action_release("move_right")
	check(is_equal_approx(p.health, 71.0), "Recovery preserves health")
	# Floating mode reproduces collision contacts that never report landing.
	p.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	p.global_position = start
	p.velocity = Vector3.ZERO
	p.jumped_this_air = true
	p.air_jump_used = true
	await frames(120)
	check(not p.is_on_floor() and p.stuck_recovery.stalled >= 0.7, "Detects airborne wedge with no landing")
	var airborne_start := p.global_position
	Input.action_press("jump")
	await frames(35)
	check(p.global_position.y > airborne_start.y + 0.3, "Held jump escapes airborne wedge")
	Input.action_release("jump")
	p.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	# Block the upward path; the remembered footing remains available nearby.
	p.global_position = start
	p.velocity = Vector3.ZERO
	box(start + Vector3.UP * 1.45, Vector3(1.5, 0.4, 2))
	Input.action_press("move_right")
	await frames(100)
	print("CLOSED ", p.global_position, " stalled=", p.stuck_recovery.stalled, " trail=", p.stuck_recovery.safe_positions)
	Input.action_press("jump")
	var returned := false
	for i in 150:
		await frames(1)
		if p.global_position.x < 1.0:
			returned = true
			break
	check(returned, "Closed wedge returns to recent stable ground")
	Input.action_release("jump")
	Input.action_release("move_right")
	# A real falling/gliding character never meets the stalled-contact condition.
	p.stuck_recovery.reset()
	p.global_position = Vector3(-10, 15, 0)
	p.velocity = Vector3.ZERO
	p.air_jump_used = true
	p.jumped_this_air = true
	Input.action_press("jump")
	await frames(75)
	check(p.stuck_recovery.stalled == 0.0 and p.velocity.y < 0.0, "Holding jump in free air does not add jumps")
	Input.action_release("jump")
	# A moved obstacle invalidates stored destinations through a shape query.
	box(Vector3(0, 1, 0), Vector3(2, 3, 2))
	await frames(2)
	p.stuck_recovery.safe_positions.assign([Vector3(0, 0.47, 0)])
	var before := p.global_position
	check(not p.stuck_recovery._return_to_footing() and p.global_position == before, "Occupied footing is rejected")
	p.respawn()
	check(p.stuck_recovery.safe_positions.is_empty(), "Respawn clears recovery trail")
	level.free()
	print("STUCK_RECOVERY failures=", failures)
	quit(1 if failures else 0)

