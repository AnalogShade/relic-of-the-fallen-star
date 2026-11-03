extends SceneTree
var player: CharacterBody3D

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	seed(42)
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	root.size = Vector2i(1280, 720)
	var ground := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(24, 1, 24)
	shape.shape = box
	shape.position.y = -0.5
	ground.add_child(shape)
	var sand := MeshInstance3D.new()
	var sand_mesh := PlaneMesh.new()
	sand_mesh.size = Vector2(24, 24)
	sand.mesh = sand_mesh
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.38, 0.32, 0.21)
	sand.material_override = sand_mat
	ground.add_child(sand)
	world.add_child(ground)
	var water := MeshInstance3D.new()
	water.name = "Water_Test"
	var water_mesh := PlaneMesh.new()
	water_mesh.size = Vector2(6, 20)
	water.mesh = water_mesh
	water.position.y = 0.18
	var water_mat := ShaderMaterial.new()
	water_mat.shader = load("res://shaders/stream_water.gdshader")
	water.material_override = water_mat
	world.add_child(water)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	world.add_child(sun)
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.15, 0.22, 0.28)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.65, 0.72, 0.8)
	environment.ambient_light_energy = 0.55
	env.environment = environment
	world.add_child(env)
	player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.43, 1)
	world.add_child(player)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(2.5, 2.2, 4.0)
	camera.look_at(Vector3(0, 0.6, 0))
	camera.current = true
	await create_timer(0.3).timeout
	var fx = player.water_footsteps
	assert(player.is_on_floor())
	assert(fx.foot_bones.size() == 2 and fx.foot_bones[0] >= 0 and fx.foot_bones[1] >= 0, "Foot bones must resolve")
	assert(fx.splash_count == 0, "Idle should not emit")
	Input.action_press("move_forward")
	await create_timer(1.1).timeout
	Input.action_release("move_forward")
	assert(fx.splash_count >= 2, "Animated walk must emit splashes")
	print("WALK_PASS: ", fx.splash_count, " splashes, foot bones ", fx.foot_bones)
	# Capture an actual foot splash at a readable close view.
	camera.position = player.global_position + Vector3(2.1, 1.6, 2.8)
	camera.look_at(player.global_position + Vector3(0, 0.2, 0))
	fx.step()
	await create_timer(0.12).timeout
	await capture("walk")
	var walk_count: int = fx.splash_count
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await create_timer(0.8).timeout
	Input.action_release("move_forward")
	Input.action_release("sprint")
	assert(fx.splash_count > walk_count, "Running must emit splashes")
	print("RUN_PASS")
	var count: int = fx.splash_count
	player.swimming = true
	fx.step()
	assert(fx.splash_count == count, "Swimming should not emit steps")
	player.swimming = false
	player.global_position.x = 8.0
	await physics_frame
	fx.step()
	assert(fx.splash_count == count, "Dry ground should not emit")
	player.global_position = Vector3(0, 2.6, 0)
	player.velocity = Vector3.ZERO
	fx.reset()
	await create_timer(0.7).timeout
	assert(fx.splash_count > count, "Falling through surface must emit")
	print("DRY_SWIM_ENTRY_PASS")
	fx.emit_at(Vector3(0, 0.18, 0), 2.4)
	camera.position = Vector3(2.1, 1.9, 3.0)
	camera.look_at(Vector3(0, 0.5, 0))
	await create_timer(0.12).timeout
	await capture("impact")
	await create_timer(1.3).timeout
	assert(get_nodes_in_group("water_splashes").is_empty(), "All effects must clean up")
	print("CLEANUP_PASS")
	world.free()
	await process_frame
	quit()

func capture(label: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/water_splash_" + label + ".png")
