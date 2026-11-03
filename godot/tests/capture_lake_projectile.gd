extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var in_world := "--world" in OS.get_cmdline_user_args()
	var stage: Node3D = load("res://scenes/world/open_world.tscn").instantiate() if in_world else Node3D.new()
	root.add_child(stage)
	current_scene = stage
	root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.current = true
	for i in range(30): await physics_frame
	if in_world:
		var player = stage.get_node("Original/Player")
		player.set_physics_process(false)
		player.global_position = Vector3(37, 8, -213)
		var boss = stage.get_node("LakeMonster")
		boss.set_physics_process(false)
		boss._begin_emerge()
		boss._play("Spit", 0)
		boss.animator.seek(2.34, true)
		boss.animator.pause()
		boss.state = "attack"
		boss._sync_mouth()
		boss.shot_target = player.global_position + Vector3.UP
		boss._fire()
		camera.global_position = Vector3(35, 15, -190)
		camera.look_at(Vector3(18, 8, -213))
	else:
		var projectile = load("res://scripts/lake_monster_projectile.gd").new()
		projectile.direction = Vector3.RIGHT
		projectile.water_y = -100
		stage.add_child(projectile)
		projectile.position = Vector3(-6, 1, 0)
		camera.position = Vector3(7, 4, 12)
		camera.look_at(Vector3(0, 1, 0))
	await create_timer(0.65).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/lake_projectile_world.png" if in_world else "res://tests/lake_projectile_close.png")
	print("LAKE_PROJECTILE_CAPTURED")
	quit()
