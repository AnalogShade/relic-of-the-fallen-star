extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	
	# Floor & environment lighting
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	col.shape = box
	col.position.y = -0.5
	floor_body.add_child(col)
	
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.15, 0.18, 0.16)
	floor_mat.roughness = 0.85
	floor_mesh.material_override = floor_mat
	floor_body.add_child(floor_mesh)
	level.add_child(floor_body)
	
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.7, 0.0)
	sun.light_energy = 0.8
	level.add_child(sun)
	
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.09, 0.12)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.2, 0.25, 0.3)
	env.environment = environment
	level.add_child(env)
	
	# Inventory setup for fireball
	var inv = root.get_node_or_null("Inventory")
	if inv:
		inv.add_item("first_echo")
	
	# Player
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.4, 0)
	level.add_child(player)
	player.get_node("CameraPivot/SpringArm3D/Camera3D").current = false
	player.get_node("Nael").rotation.y = PI # Face straight along -Z
	
	# Third-person over-the-shoulder camera view showing Naël and the fireball launching forward
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.position = Vector3(1.4, 1.6, 2.5)
	cam.look_at(Vector3(0.1, 1.0, -1.8), Vector3.UP)
	cam.current = true
	
	# Trigger fireball
	player.start_fireball()
	
	# Advance frames: release is at ~10 frames, at 18 frames fireball is 2.5m in front of Naël
	for f in range(18):
		await physics_frame
		await process_frame
	
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var out_path := "C:/Users/Utilisateur/.gemini/antigravity/brain/e89da791-3435-4d9e-8753-398dae534af6/fireball_ingame_action.png"
	img.save_png(out_path)
	print("SUCCESS: Saved in-game fireball action screenshot to: " + out_path)
	quit(0)
