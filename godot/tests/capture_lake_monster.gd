extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/lake_monster_" + label + ".png")
	print("CAPTURED: ", label)

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	root.size = Vector2i(1280, 720)
	for i in range(30):
		await physics_frame
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	player.global_position = Vector3(38, 7, -213)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.global_position = Vector3(37, 18, -184)
	camera.look_at(Vector3(7, 10, -213))
	camera.current = true
	await create_timer(0.7).timeout
	await capture("dormant")
	player.global_position = Vector3(31, 7, -213)
	await create_timer(2.0).timeout
	await capture("emerge")
	await create_timer(3.2).timeout
	await capture("surface")
	await create_timer(3.6).timeout
	await capture("tir")
	await create_timer(3.0).timeout
	await capture("marche_v3")
	var boss = world.get_node("LakeMonster")
	print("VISUAL_RESULT: clips=", boss.clips, " mouth=", boss.mouth_area.global_position, " surface=", player.water_surface.height_at(boss.global_position), " splashes=", boss.splash_count, " shots=", boss.shots_fired)
	world.queue_free()
	await process_frame
	quit()
