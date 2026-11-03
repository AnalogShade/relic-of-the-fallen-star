extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1920, 1080)
	var stage = load("res://scenes/tests/nova_showcase.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	stage.autoplay = false
	for i in range(8): await physics_frame
	seed(123)
	var nova = stage.cast_nova()
	nova.set_physics_process(false)
	nova.elapsed = 0.62
	nova._update_visuals()
	assert(is_equal_approx(nova.get_node("EnergyVeil0").position.y, 2.2))
	assert(is_equal_approx(nova.get_node("EnergyVeil1").position.y, 4.4))
	assert(nova.veil_materials[0].get_shader_parameter("radius") > nova.veil_materials[1].get_shader_parameter("radius"))
	for hidden in [false, true]:
		stage.hud.visible = not hidden
		for i in range(4): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/nova_visual_trials/showcase_%s.png" % ("clean" if hidden else "controls"))
	for frame in range(34):
		nova.elapsed = float(frame) / 30.0
		nova._update_visuals()
		for i in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/nova_visual_trials/showcase_frame_%02d.png" % frame)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_C
	event.pressed = true
	stage._input(event)
	assert(stage.orbit)
	event.physical_keycode = KEY_R
	stage._input(event)
	assert(stage.autoplay)
	event.physical_keycode = KEY_Q
	stage._input(event)
	assert(is_instance_valid(stage.active_nova))
	print("NOVA_SHOWCASE_PASS: elevated tiers, independent expansion, captures, orbit, autoplay, manual cast")
	stage.queue_free()
	await process_frame
	quit()
