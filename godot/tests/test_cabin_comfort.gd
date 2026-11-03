extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1
func frames(count: int) -> void:
	for i in range(count): await physics_frame
func run() -> void:
	var room: Node3D = load("res://scenes/interiors/cabin_room.tscn").instantiate()
	root.add_child(room)
	current_scene = room
	var player: CharacterBody3D = room.get_node("Player")
	var chair: Node3D = room.get_node("ArmchairSeat")
	await frames(60)
	for start in [Vector3(-0.5, 0.46, -0.6), Vector3(-2.3, 0.46, 1.0)]:
		player.global_position = start
		player.velocity = Vector3.ZERO
		await frames(30)
		check(chair.can_interact(), "chair available from " + str(start))
		chair.interact()
		check(player.rest_state == "approaching_seat", "walks toward chair")
		for i in range(1000):
			await physics_frame
			if player.rest_state == "seated" or player.rest_state == "": break
		check(player.rest_state == "seated", "reaches seated idle")
		check(player.global_position.distance_to(chair.global_position - Vector3.UP * 0.05) < 0.02, "hips aligned with cushion")
		check(player.get_node("Nael").basis.z.dot(chair.FACING) > 0.99, "faces out of chair")
		player.health = player.max_health - 10
		var health: float = player.health
		player.rest_controller.healing_elapsed = 0.0
		player.rest_controller._process(5.0)
		check(player.health == health + 1.0, "heals beside cabin hearth")
		if DisplayServer.get_name() != "headless":
			var camera := Camera3D.new()
			room.add_child(camera)
			camera.position = Vector3(0.8, 1.8, 1.7)
			camera.look_at(chair.global_position + Vector3.UP * 0.4)
			camera.current = true
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/cabin_seated.png")
			camera.queue_free()
		chair.interact()
		check(player.rest_state == "standing_up", "interaction stands up")
		await frames(110)
		check(player.rest_state == "" and player.is_on_floor(), "returns to floor with controls restored")
	room.free()
	var tile: Node3D = load("res://scenes/world/tile_04_bois_du_foyer.tscn").instantiate()
	root.add_child(tile)
	await process_frame
	await process_frame
	var smoke: Node3D = tile.get_node("ChimneySmoke")
	check(smoke.get_child_count() == 1, "one chimney plume")
	var plume := smoke.get_child(0) as CPUParticles3D
	check(plume != null and plume.emitting and plume.preprocess > 0, "continuous prewarmed smoke")
	check(plume.global_position.distance_to(Vector3(-58.40325, 19.38, -0.44569)) < 0.01, "smoke anchored at chimney opening")
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		tile.add_child(camera)
		camera.position = Vector3(-66, 23, 12)
		camera.look_at(Vector3(-56.5, 18.5, 0))
		camera.current = true
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-45, -30, 0)
		tile.add_child(sun)
		var sky := WorldEnvironment.new()
		sky.environment = Environment.new()
		sky.environment.background_mode = Environment.BG_COLOR
		sky.environment.background_color = Color(0.38, 0.46, 0.48)
		sky.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		sky.environment.ambient_light_color = Color(0.8, 0.85, 0.9)
		sky.environment.ambient_light_energy = 0.6
		tile.add_child(sky)
		await frames(90)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/cabin_chimney_smoke.png")
	tile.free()
	print("CABIN_COMFORT_FAILURES: ", failures)
	quit(failures)
