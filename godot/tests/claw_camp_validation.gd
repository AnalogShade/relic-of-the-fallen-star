extends Node3D

func frames(count: int) -> void:
	for i in range(count): await get_tree().physics_frame

func click() -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = get_viewport().get_visible_rect().size * 0.5
	event.pressed = true
	Input.parse_input_event(event)
	await frames(1)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)

func _ready() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	await frames(3)
	var actor = world.get_node("Original/Player")
	var enemy = world.get_node("Sectors/Bandit_Garde")
	actor.global_position = Vector3(12.0, 3.0, -53.0)
	actor.pivot.rotation.y = 0.0
	await frames(120)
	var passed := true
	# First click only recaptures the mouse after Escape.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await click()
	await frames(5)
	passed = passed and not actor.is_attacking and enemy.health == 100.0
	print("CAMP_RECAPTURE: ", not actor.is_attacking)
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = actor.global_position + Vector3(3, 1.8, 2.5)
	camera.look_at((actor.global_position + enemy.global_position) * 0.5 + Vector3.UP * 0.7)
	camera.current = true
	for strike in range(4):
		var offset: Vector3 = enemy.global_position - actor.global_position
		actor.pivot.rotation.y = atan2(offset.x, offset.z) - PI
		await click()
		await frames(17)
		print("CLICK_STATE mode=", Input.mouse_mode, " attacking=", actor.is_attacking, " grounded=", actor.is_on_floor(), " player=", actor.global_position, " enemy=", enemy.global_position, " yaw=", actor.pivot.rotation.y)
		passed = passed and actor.is_attacking
		if strike == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://tests/claw_camp_strike.png")
		await frames(31)
		if strike < 3:
			passed = passed and is_instance_valid(enemy) and enemy.health == 100.0 - 25.0 * (strike + 1)
			print("CAMP_STRIKE ", strike + 1, " enemy_health=", enemy.health if is_instance_valid(enemy) else -1)
	passed = passed and not is_instance_valid(enemy)
	passed = passed and actor.health < 100.0 and actor.health > 0.0
	print("CAMP_CLAW_RESULT: ", passed, " player_health=", actor.health)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/claw_camp_defeated.png")
	world.queue_free()
	await frames(3)
	get_tree().quit(0 if passed else 1)
