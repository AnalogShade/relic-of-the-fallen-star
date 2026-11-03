extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	
	# Background floor & environment
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.10, 0.12, 0.15)
	floor_mat.roughness = 0.6
	floor_mesh.material_override = floor_mat
	floor_mesh.position.y = -0.5
	level.add_child(floor_mesh)
	
	# Projectile
	var proj_scene: PackedScene = load("res://scenes/spells/fireball_projectile.tscn")
	var proj = proj_scene.instantiate()
	level.add_child(proj)
	proj.launch(Vector3(0, 0.5, 0), Vector3(0, 0, -1))
	
	# Let particles emit and travel for 12 frames
	for i in range(12):
		await physics_frame
		await process_frame
		
	# Camera close-up looking at the flying fireball and trailing embers
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.global_position = proj.global_position + Vector3(1.2, 0.4, 1.6)
	cam.look_at(proj.global_position + Vector3(0, 0, -0.3), Vector3.UP)
	cam.current = true
	
	for i in range(3):
		await physics_frame
		await process_frame
	
	await RenderingServer.frame_post_draw
	var img: Image = root.get_texture().get_image()
	var out_path := "C:/Users/Utilisateur/.gemini/antigravity/brain/e89da791-3435-4d9e-8753-398dae534af6/fireball_ingame_closeup.png"
	img.save_png(out_path)
	print("Saved in-game closeup to: " + out_path)
	quit(0)
