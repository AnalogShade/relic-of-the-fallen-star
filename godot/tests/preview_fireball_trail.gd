extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.025, 0.045, 0.07)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.3, 0.4, 0.55)
	settings.ambient_light_energy = 0.6
	env.environment = settings
	level.add_child(env)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(45, 30)
	floor_mesh.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.12, 0.16)
	floor_mesh.material_override = mat
	level.add_child(floor_mesh)
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.position = Vector3(1, 7, 19)
	cam.look_at(Vector3(0, 3, 0))
	cam.current = true
	var projectile = load("res://scenes/spells/fireball_projectile.tscn").instantiate()
	level.add_child(projectile)
	projectile.launch(Vector3(-9, 3, 0), Vector3.RIGHT)
	for i in range(45):
		await physics_frame
		await process_frame
	projectile.set_physics_process(false)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/fireball_trail_preview.png")
	level.queue_free()
	await process_frame
	quit()
