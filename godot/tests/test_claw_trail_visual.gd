extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	
	# Light & background
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.7, 0.0)
	sun.light_energy = 0.9
	level.add_child(sun)
	
	var env := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.06, 0.07, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.25, 0.25, 0.35)
	env.environment = environment
	level.add_child(env)
	
	# Floor
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.12, 0.14, 0.16)
	floor_mesh.material_override = floor_mat
	level.add_child(floor_mesh)
	
	# Load Player
	var player = load("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.425, 0)
	level.add_child(player)
	player.set_physics_process(false)
	player.get_node("Nael").rotation.y = PI # Face -Z
	
	# Hide UI overlays
	for c in root.find_children("*", "CanvasLayer", true, false):
		c.hide()
	
	# Remove player camera to guarantee our camera is 100% active
	var player_cam = player.find_child("Camera3D", true, false)
	if player_cam:
		player_cam.current = false
		player_cam.queue_free()
	
	# Attach ClawTrail3D to Player
	var ClawTrailClass = preload("res://scripts/claw_trail.gd")
	var claw_trail: MeshInstance3D = ClawTrailClass.new()
	claw_trail.name = "ClawTrail3D"
	player.add_child(claw_trail)
	
	# Camera 1: Dynamic Combat View (Front-Angle)
	var cam := Camera3D.new()
	level.add_child(cam)
	cam.position = Vector3(0.55, 0.95, -1.65)
	cam.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	cam.current = true
	cam.fov = 52.0
	
	for i in range(5): await process_frame
	
	var ap: AnimationPlayer = player.get_node("Nael/AnimationPlayer")
	print("Triggering claw attack (Front view)...")
	player.is_attacking = true
	player.get_node("Nael").play_claw()
	
	var captured_front := false
	while ap.is_playing() and ap.current_animation == "Nael_Claw":
		await process_frame
		var pos = ap.current_animation_position
		if pos >= 0.34 and not captured_front:
			captured_front = true
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			if img:
				img.save_png("C:/Users/Utilisateur/.gemini/antigravity/brain/ab6f358b-6bb1-4d9d-9edf-f6f5a6cef82d/claw_trail_front.png")
				print("Saved claw_trail_front.png at pos=%.3f, slices=%d" % [pos, claw_trail._slices.size()])
	
	# Reset and run Camera 2: Player 3rd person gameplay over-the-shoulder view
	claw_trail.clear_trail()
	for i in range(5): await process_frame
	
	cam.position = Vector3(0.65, 1.15, 1.7)
	cam.look_at(Vector3(0.1, 0.8, -1.5), Vector3.UP)
	cam.fov = 58.0
	
	print("Triggering claw attack (Gameplay 3rd-person view)...")
	player.is_attacking = true
	player.get_node("Nael").play_claw()
	
	var captured_gameplay := false
	while ap.is_playing() and ap.current_animation == "Nael_Claw":
		await process_frame
		var pos = ap.current_animation_position
		if pos >= 0.34 and not captured_gameplay:
			captured_gameplay = true
			await RenderingServer.frame_post_draw
			var img: Image = root.get_texture().get_image()
			if img:
				img.save_png("C:/Users/Utilisateur/.gemini/antigravity/brain/ab6f358b-6bb1-4d9d-9edf-f6f5a6cef82d/claw_trail_gameplay.png")
				print("Saved claw_trail_gameplay.png at pos=%.3f, slices=%d" % [pos, claw_trail._slices.size()])
	
	for i in range(5): await process_frame
	print("All renders completed successfully!")
	player.free()
	level.free()
	quit()





