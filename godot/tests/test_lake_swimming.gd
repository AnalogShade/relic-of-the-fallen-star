extends SceneTree

func _initialize() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 10:
		await physics_frame
	var p = world.get_node("Original/Player")
	var lake_point := Vector3(7, 0, -213)
	var height: float = p.water_surface.height_at(lake_point)
	print("LAKE_SURFACE: ", height, " WATER_MESHES: ", p.water_surface.surfaces.size())
	if not is_finite(height):
		quit(1)
		return
	p.global_position = Vector3(lake_point.x, height - 1.5, lake_point.z)
	p.velocity = Vector3.ZERO
	for i in 180:
		await physics_frame
	var ap: AnimationPlayer = p.get_node("Nael/AnimationPlayer")
	var floating: bool = p.swimming and ap.current_animation == "Nael_Float" and absf(p.global_position.y - (height - p.float_depth)) < 0.1
	print("LAKE_FLOAT: ", floating, " POSITION: ", p.global_position, " ANIMATION: ", ap.current_animation)
	if "--swim-preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://tests/lake_float_preview.png")
	Input.action_press("move_forward")
	for i in 30:
		await physics_frame
	var moving: bool = p.swimming and ap.current_animation == "Nael_Swim"
	Input.action_release("move_forward")
	print("LAKE_SWIM: ", moving)
	if "--swim-preview" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://tests/lake_swim_preview.png")
	print("LAKE_SWIMMING_RESULT: ", "PASS" if floating and moving else "FAIL")
	quit(0 if floating and moving else 1)
