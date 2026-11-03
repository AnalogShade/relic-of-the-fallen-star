@tool
extends SceneTree

func _init() -> void:
	print("--- Testing DayNightCycle with Full OpenWorld Scene ---")
	var world_scene: PackedScene = load("res://scenes/world/open_world.tscn")
	var world: Node3D = world_scene.instantiate()
	root.add_child(world)
	
	for i in range(5):
		await process_frame
	
	var original: Node3D = world.get_node_or_null("Original")
	if original == null:
		printerr("FAIL: Original node not found in open_world.tscn")
		quit(1)
		return
		
	var cycle: Node = original.get_node_or_null("DayNightCycle")
	if cycle == null:
		printerr("FAIL: DayNightCycle not found inside Original")
		quit(1)
		return
		
	var moon: DirectionalLight3D = original.get_node_or_null("Moon")
	if moon == null:
		printerr("FAIL: Moon not found inside Original")
		quit(1)
		return
	
	print("PASS: Found DayNightCycle and Moon in OpenWorld!")
	
	# Simulate 1 minute of game time at 60x speed to verify smooth process loop
	cycle.time_speed_multiplier = 60.0
	var start_time: float = cycle.time_of_day
	for i in range(60):
		await process_frame
	
	print("Time progressed from %.2f to %.2f" % [start_time, cycle.time_of_day])
	var advanced: bool = not is_equal_approx(start_time, cycle.time_of_day)
	
	world.queue_free()
	if advanced:
		print("PASS: OpenWorld Day/Night cycle processed successfully!")
		quit(0)
	else:
		printerr("FAIL: Time did not advance in OpenWorld")
		quit(1)
