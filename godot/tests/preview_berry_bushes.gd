@tool
extends SceneTree

func _initialize():
	call_deferred("render_previews")

func render_previews():
	print("--- RENDERING BERRY BUSHES PREVIEWS ---")
	var scene: PackedScene = load("res://scenes/world/open_world.tscn")
	var world: Node3D = scene.instantiate()
	root.add_child(world)
	
	# Disable player camera so our preview camera is active
	for c in world.find_children("*", "Camera3D", true, false):
		c.current = false
		
	# Camera 1: High angle looking down at the forest clearing and river
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.position = Vector3(-10.0, 65.0, 45.0)
	cam.look_at(Vector3(-10.0, 2.0, 15.0), Vector3.UP)
	cam.far = 1000.0
	cam.fov = 65.0
	cam.make_current()
	
	# Wait several frames for shaders, lights, and materials to compile & settle
	for i in range(10):
		await process_frame
		
	var img = root.get_texture().get_image()
	var out_dir := "C:/Users/Utilisateur/.gemini/antigravity/brain/2d201e42-43fe-4c46-bebd-597af6456fca"
	img.save_png(out_dir + "/godot_berry_bushes_aerial.png")
	print("Saved aerial preview")
	
	# Camera 2: Ground-level view near river bank looking at bushes in Zone 1 & Zone 4
	cam.position = Vector3(-2.0, 4.0, 12.0)
	cam.look_at(Vector3(-15.0, 3.0, 20.0), Vector3.UP)
	cam.fov = 65.0
	cam.make_current()
	for i in range(5):
		await process_frame
	img = root.get_texture().get_image()
	img.save_png(out_dir + "/godot_berry_bushes_ground.png")
	print("Saved ground preview")

	# Camera 3: Close-up hero shot of the berry bushes
	cam.position = Vector3(-10.0, 3.2, 17.0)
	cam.look_at(Vector3(-12.0, 2.5, 21.0), Vector3.UP)
	cam.fov = 55.0
	cam.make_current()
	for i in range(5):
		await process_frame
	img = root.get_texture().get_image()
	img.save_png(out_dir + "/godot_berry_bushes_closeup.png")
	print("Saved closeup preview")
	
	cam.queue_free()
	world.queue_free()
	quit()
