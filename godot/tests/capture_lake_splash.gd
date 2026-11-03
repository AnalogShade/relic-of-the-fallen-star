extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var in_world := "--world" in OS.get_cmdline_user_args()
	var stage: Node3D = load("res://scenes/world/open_world.tscn").instantiate() if in_world else Node3D.new()
	root.add_child(stage)
	current_scene = stage
	root.size = Vector2i(1280, 720)
	for i in range(30): await physics_frame
	if in_world:
		var player = stage.get_node("Original/Player")
		player.set_physics_process(false)
		player.global_position = Vector3(31, 8, -213)
		var boss = stage.get_node("LakeMonster")
		boss.set_physics_process(false)
		boss._begin_emerge()
		boss._play("Idle", 0)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(29, 14, -190) if in_world else Vector3(15, 10, 18)
	camera.look_at(Vector3(7, 7, -213) if in_world else Vector3(0, 1, 0))
	camera.current = true
	var effect = load("res://scripts/lake_monster_splash.gd").new()
	stage.add_child(effect)
	if in_world: effect.global_position = Vector3(7, 5.54, -213)
	effect.set_process(false)
	effect._process(0.5)
	print("EFFECT: ", effect.sheets.multimesh.instance_count, " custom=", effect.sheets.multimesh.get_instance_custom_data(0), " age=", effect.sheet_material.get_shader_parameter("age"))
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/lake_splash_world.png" if in_world else "res://tests/lake_splash_isolated.png")
	quit()
