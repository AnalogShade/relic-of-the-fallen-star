extends SceneTree
var failures := 0
func _initialize(): call_deferred("run")
func check_ground(world: Node, stage: String):
	var materials := 0
	var disabled := 0
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		var material = mesh.material_override as ShaderMaterial
		if material == null or material.shader == null: continue
		if material.shader.resource_path not in ["res://shaders/ground.gdshader", "res://shaders/world_ground.gdshader"]: continue
		materials += 1
		if material.get_shader_parameter("stream_stones_enabled") != true or not material.get_shader_parameter("stream_footprint") is Texture2D:
			disabled += 1
	print("STREAM_STONES ", stage, " materials=",materials," disabled=",disabled)
	if disabled > 0 or materials == 0: failures += 1
func settle():
	for i in 4: await process_frame
func run():
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await settle()
	check_ground(world,"initial_load")
	var original_mask = world.get_meta("stream_stone_mask").texture
	world._configure_world()
	await settle()
	check_ground(world,"material_reload")
	world._configure_world()
	await settle()
	check_ground(world,"second_reload")
	if world.get_meta("stream_stone_mask").texture != original_mask: failures += 1
	world.queue_free()
	await process_frame
	print("STREAM_STONES_RELOAD_RESULT: ",failures," failures")
	quit(0 if failures == 0 else 1)
