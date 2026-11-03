extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var stage = load("res://tests/primordial_nova_preview.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	for i in range(10): await physics_frame
	stage.actor.nova_ability.try_cast()
	var nova = get_first_node_in_group("primordial_novas")
	nova.set_physics_process(false)
	nova.elapsed = 0.42
	nova._update_visuals()
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/primordial_nova_preview.png")
	print("NOVA_PREVIEW_CAPTURED")
	stage.queue_free()
	await process_frame
	quit()
