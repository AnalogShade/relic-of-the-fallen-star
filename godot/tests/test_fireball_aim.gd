extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame
func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 5, 0)
	player.gravity = 0
	level.add_child(player)
	await frames(4)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	check(not player.begin_fireball_aim(), "Relic required to aim")
	root.get_node("Inventory").add_item("first_echo")
	player.arm.rotation.x = 0
	player.pivot.rotation.y = 0.6
	await frames(2)
	var prepared: Node3D = player.prepared_fireball
	check(is_instance_valid(prepared) and not prepared.is_inside_tree(), "Projectile prepared off-tree after unlocking relic")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	player._unhandled_input(press)
	check(player.fireball_aiming and player.fireball_reticle.visible, "Hold shows target")
	await frames(20)
	check(not player.is_casting_spell, "Holding does not fire")
	var saved_yaw: float = player.pivot.rotation.y
	var saved_pitch: float = player.arm.rotation.x
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(200, -180)
	player._unhandled_input(motion)
	var moved_cursor: Vector2 = player.fireball_cursor
	check(player.fireball_reticle.position == moved_cursor, "Reticle follows free cursor")
	check(moved_cursor.y < root.get_visible_rect().size.y * 0.5, "Can aim above character")
	check(player.pivot.rotation.y == saved_yaw and player.arm.rotation.x == saved_pitch, "Aiming leaves camera stationary")
	var upper_target: Vector3 = player.fireball_target
	check(upper_target.y > player.global_position.y + 1.05, "Upper screen produces upward target")
	for corner in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1), Vector2.ONE]:
		var expected: Vector2 = root.get_visible_rect().size * corner
		motion.relative = expected - player.fireball_cursor
		player._unhandled_input(motion)
		check(player.fireball_reticle.position.is_equal_approx(expected), "Cursor reaches screen corner " + str(corner))
	motion.relative = moved_cursor - player.fireball_cursor
	player._unhandled_input(motion)
	# Regression: camera ray hits scenery behind Nael before the distant target.
	var cam := player.arm.get_node("Camera3D") as Camera3D
	var ray_origin := cam.project_ray_origin(moved_cursor)
	var ray_direction := cam.project_ray_normal(moved_cursor)
	var behind := StaticBody3D.new()
	behind.position = ray_origin + ray_direction * 1.5
	var behind_shape := CollisionShape3D.new()
	var behind_box := BoxShape3D.new()
	behind_box.size = Vector3.ONE * 0.8
	behind_shape.shape = behind_box
	behind.add_child(behind_shape)
	level.add_child(behind)
	var far_target := StaticBody3D.new()
	far_target.position = ray_origin + ray_direction * 40.0
	var far_shape := CollisionShape3D.new()
	var far_box := BoxShape3D.new()
	far_box.size = Vector3.ONE * 2.0
	far_shape.shape = far_box
	far_target.add_child(far_shape)
	level.add_child(far_target)
	await frames(2)
	player.update_fireball_aim()
	check(player.fireball_target.distance_to(far_target.position) < 2.0, "Scenery between camera and player cannot steal distant target")
	var forward := -cam.global_basis.z
	forward.y = 0
	check((player.fireball_target - player.global_position).dot(forward) > 0, "Chosen target stays ahead of player")
	var hand: Vector3 = player.global_position + Vector3.UP * 1.05
	player.fireball_reticle.set_world_target(cam, hand, ray_origin + ray_direction * 8, false)
	var near_size: float = player.fireball_reticle.perspective_size
	player.fireball_reticle.set_world_target(cam, hand, ray_origin + ray_direction * 120, false)
	check(player.fireball_reticle.perspective_size < near_size, "Distant target visibly shrinks")
	check(player.fireball_reticle.position == moved_cursor, "Perspective never pulls cursor away from mouse")
	player.fireball_reticle.set_world_target(cam, hand, ray_origin + ray_direction * 8, true)
	check(player.fireball_reticle.distance_label.text.begins_with("Obstacle"), "Cover explicitly indicates blocked shot")
	behind.queue_free()
	far_target.queue_free()
	await frames(2)
	player.update_fireball_aim()
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_RIGHT
	player._unhandled_input(release)
	var target: Vector3 = player.fireball_target
	check(not player.fireball_aiming and not player.fireball_reticle.visible, "Release hides target")
	await frames(2)
	player.pivot.rotation.y = -0.7
	player.arm.rotation.x = -0.5
	await frames(20)
	var projectile: Node3D
	for child in level.get_children():
		if child is Area3D: projectile = child
	check(projectile != null, "Release spawns projectile")
	check(projectile != null and projectile == prepared, "First cast uses prepared projectile")
	if projectile:
		var expected := (target - projectile.global_position).normalized()
		check(projectile.direction.dot(expected) > 0.999, "Flight reaches locked target despite camera moving")
		check(projectile.direction.y > 0.1, "Free upper cursor fires upward")
		check(projectile.has_node("FireballModel/AnimationPlayer") or projectile.anim_player != null, "Original animated 3D model retained")
		check(projectile.lifetime * projectile.speed >= 400.0, "Unobstructed range is at least 400 metres")
		projectile.time_alive = 5.0
		projectile._physics_process(0.016)
		check(not projectile.impacted, "Projectile survives beyond former four-second limit")
		check(projectile.get_node("FlameWake").local_coords == false, "Wake stays in world space")
		projectile.explode()
		await frames(3)
		check(is_instance_valid(projectile) and not projectile.get_node("MistWake").emitting, "Wake fades after impact")
		await create_timer(1.3).timeout
		check(not is_instance_valid(projectile), "Projectile cleans up after fade")
	player.is_attacking = false
	player.is_casting_spell = false
	player.fireball_cooldown = 0
	check(player.begin_fireball_aim(), "Aim can restart")
	player.cancel_claw()
	check(not player.fireball_aiming and not player.fireball_reticle.visible, "Cancel clears aiming")
	var distant = load("res://scenes/spells/fireball_projectile.tscn").instantiate()
	level.add_child(distant)
	distant.launch(Vector3(0, 20, 0), Vector3.RIGHT)
	distant.set_physics_process(false)
	var wall := StaticBody3D.new()
	wall.position = Vector3(130, 20, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 4, 4)
	shape.shape = box
	wall.add_child(shape)
	level.add_child(wall)
	await frames(2)
	for i in range(8):
		if not distant.impacted: distant._physics_process(1.0)
	check(distant.impacted and distant.global_position.x > 129, "Projectile reaches and hits obstacle 130 metres away")
	level.queue_free()
	await frames(2)
	print("Aim failures: ", failures)
	quit(1 if failures else 0)
