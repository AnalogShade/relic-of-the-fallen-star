@tool
extends SceneTree

func _init() -> void:
	print("--- Capturing Day/Night cycle screenshots ---")
	var scene: PackedScene = load("res://scenes/forest_test.tscn")
	var forest: Node3D = scene.instantiate()
	root.add_child(forest)
	
	for i in range(10):
		await process_frame
		
	var hud = forest.get_node_or_null("HUD")
	if hud != null:
		hud.hide()
	var player = forest.get_node_or_null("Player")
	if player != null:
		player.set_physics_process(false)
		
	var cycle: Node = forest.get_node("DayNightCycle")
	cycle.is_paused = true
	
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 68.0
	cam.far = 1000.0
	forest.add_child(cam)
	
	# Panoramic view overlooking the forest clearing and shrine
	cam.global_position = Vector3(6.0, 5.0, 14.0)
	cam.look_at(Vector3(0.0, 2.5, -6.0))
	
	var hours = [
		{"name": "01_midday",   "hour": 12.0},
		{"name": "02_sunset",   "hour": 18.5},
		{"name": "03_midnight", "hour": 0.0},
		{"name": "04_dawn",     "hour": 6.0}
	]
	
	for entry in hours:
		cycle.time_of_day = entry["hour"]
		for i in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		
		var img := root.get_texture().get_image()
		var path := "res://tests/daynight_%s.png" % entry["name"]
		img.save_png(path)
		print("Saved screenshot: ", path)
	
	print("--- Done capturing screenshots ---")
	forest.queue_free()
	quit(0)
