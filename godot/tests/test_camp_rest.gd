extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures += 1
func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var camp: Node3D = load("res://scenes/world/camp_bandits.tscn").instantiate()
	world.add_child(camp)
	var bench: Node3D = camp.get_node("Camp_Banc_Bois_01")
	var ground := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collision.shape = shape
	ground.add_child(collision)
	world.add_child(ground)
	ground.position = Vector3(22, bench.position.y - 0.5, -59)
	if "--real-terrain" in OS.get_cmdline_user_args():
		ground.collision_layer = 0
		world.add_child(load("res://assets/environment/world/tile_02_vallee_des_sources.glb").instantiate())
	var player = load("res://scenes/player.tscn").instantiate()
	world.add_child(player)
	player.world_bounds = Rect2(-100, -100, 200, 200)
	player.global_position = bench.global_position + Vector3(1.1, 1, 0)
	for i in range(90): await physics_frame
	var animator: AnimationPlayer = player.get_node("Nael/AnimationPlayer")
	for clip in ["Nael_Sit_Down", "Nael_Seated_Pose", "Nael_Seated_Idle_Loop", "Nael_Stand_Up", "Nael_Claw_Left", "Nael_Idle_Breathe"]:
		check(animator.has_animation(clip), "animation " + clip)
	check(bench.can_interact(), "bench available when nearby")
	player.health = 90.0
	bench.interact()
	check(player.rest_state == "approaching_seat", "walk before sitting")
	for i in range(600):
		await physics_frame
		if player.rest_state == "seated": break
	check(player.rest_state == "seated", "seated loop reached")
	check(animator.current_animation == "Nael_Seated_Idle_Loop", "breathing loop plays")
	if DisplayServer.get_name() != "headless":
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.global_position = player.global_position + Vector3(2.7, 1.6, 2.5)
		camera.look_at(player.global_position + Vector3.UP * 0.5)
		camera.current = true
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-45, -30, 0)
		world.add_child(light)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/camp_rest_preview.png")
	check(player.health == 90.0, "no premature healing")
	player.rest_controller._process(5.0)
	check(player.health == 91.0, "one HP after five seconds")
	player.health = 100.0
	player.rest_controller._process(5.0)
	check(player.health == 100.0, "health capped")
	bench.interact()
	check(player.rest_state == "standing_up", "F interaction stands up")
	for i in range(100): await physics_frame
	check(player.rest_state == "", "movement restored")
	bench.interact()
	player.damage_invulnerability = 0.0
	player.take_damage(1.0, Vector3.ZERO)
	check(player.rest_state == "", "damage cancels rest")
	for name in ["Camp_Banc_Bois_01", "Camp_Banc_Bois_02", "Camp_Banc_Bois_03"]:
		var next: MeshInstance3D = camp.get_node(name)
		var fire: Node3D = camp.get_node("Flammes_Animees")
		var facing := fire.global_position - next.global_position
		facing.y = 0.0
		facing = facing.normalized()
		ground.position.y = next.position.y - 0.5
		player.global_position = next.global_position - facing * 1.65 + Vector3.UP
		for i in range(90): await physics_frame
		player.health = 90.0
		check(next.can_interact(), name + " usable from behind")
		next.interact()
		check(player.rest_state == "approaching_seat", name + " approaches walking")
		var footprint: Rect2 = next.footprint().grow(0.30)
		var safe := true
		for i in range(900):
			await physics_frame
			if player.rest_state != "approaching_seat": break
			if footprint.has_point(Vector2(player.global_position.x, player.global_position.z)): safe = false
		check(safe, name + " walking stays outside bench")
		for i in range(100): await physics_frame
		check(player.rest_state == "seated", name + " reaches seat from behind")
		check(absf(player.global_position.y + 0.05 - next.seat_surface().y) < 0.015, name + " aligned to visible surface")
		if DisplayServer.get_name() != "headless":
			var camera := Camera3D.new()
			world.add_child(camera)
			camera.global_position = player.global_position + facing * 1.8 + Vector3(-facing.z, 0, facing.x) * 0.9 + Vector3.UP * 1.0
			camera.look_at(player.global_position + Vector3.UP * 0.5)
			camera.current = true
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://tests/rest_" + name + ".png")
		player.rest_controller.cancel()
	print("REST_TEST_FAILURES: ", failures)
	quit(failures)
