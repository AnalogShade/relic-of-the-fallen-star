@tool
extends SceneTree

func _init() -> void:
	print("--- Testing DayNightCycle with Forest scene (integrated) ---")
	var forest_scene: PackedScene = load("res://scenes/forest_test.tscn")
	var forest: Node3D = forest_scene.instantiate()
	root.add_child(forest)
	
	# Wait for ready processing
	for i in range(2):
		await process_frame
	
	var sun: DirectionalLight3D = forest.get_node("Sun")
	var moon: DirectionalLight3D = forest.get_node("Moon")
	var cycle: Node = forest.get_node("DayNightCycle")
	var env_node: WorldEnvironment = forest.get_node("WorldEnvironment")
	var env: Environment = env_node.environment
	
	print("Found Moon node: ", moon != null)
	print("Found DayNightCycle: ", cycle != null)
	
	# Test 1: Midday (12.0) - Should match exact original baseline
	cycle.time_of_day = 12.0
	print("\n[Hour 12.0 - Midday]")
	print("  Sun visible: ", sun.visible, " | energy: ", sun.light_energy, " | color: ", sun.light_color)
	print("  Moon visible: ", moon.visible, " | energy: ", moon.light_energy)
	print("  Ambient color: ", env.ambient_light_color, " | energy: ", env.ambient_light_energy)
	print("  Fog color: ", env.fog_light_color, " | energy: ", env.fog_light_energy)
	
	var ok_day: bool = is_equal_approx(sun.light_energy, 0.45) and sun.visible and (not moon.visible)
	print("  PASS Midday Day Baseline check: ", ok_day)
	
	# Test 2: Midnight (0.0) - Should be soft moonlit night, not pitch black
	cycle.time_of_day = 0.0
	print("\n[Hour 0.0 - Midnight]")
	print("  Sun visible: ", sun.visible, " | energy: ", sun.light_energy)
	print("  Moon visible: ", moon.visible, " | energy: ", moon.light_energy, " | color: ", moon.light_color)
	print("  Ambient color: ", env.ambient_light_color, " | energy: ", env.ambient_light_energy)
	print("  Fog color: ", env.fog_light_color, " | energy: ", env.fog_light_energy)
	
	var ok_night: bool = (not sun.visible) and (moon.visible and moon.light_energy > 0.15) and (env.ambient_light_energy >= 0.25)
	print("  PASS Midnight Moonlight check: ", ok_night)
	
	# Test 3: Sunset (18.5)
	cycle.time_of_day = 18.5
	print("\n[Hour 18.5 - Sunset / Golden hour]")
	print("  Sun energy: ", sun.light_energy, " | color: ", sun.light_color)
	print("  Fog color: ", env.fog_light_color, " | Sky horizon: ", env.sky.sky_material.sky_horizon_color)
	
	# Test 4: Dawn (6.0)
	cycle.time_of_day = 6.0
	print("\n[Hour 6.0 - Sunrise / Dawn]")
	print("  Sun energy: ", sun.light_energy, " | color: ", sun.light_color)
	print("  Ambient energy: ", env.ambient_light_energy)
	
	forest.queue_free()
	if ok_day and ok_night:
		print("\nALL CYCLE INTEGRATION TESTS PASSED SUCCESSFULLY!")
		quit(0)
	else:
		printerr("\nFAIL: One or more checks failed.")
		quit(1)
