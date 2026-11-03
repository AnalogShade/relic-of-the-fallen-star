extends SceneTree
## Integration coverage for the one outdoor rig, local lights and real travel.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + message)
	if not ok:
		failures += 1

func frames(count: int) -> void:
	for frame in count:
		await process_frame
		await physics_frame

func light_values(world: Node) -> Dictionary:
	var result := {}
	for light in world.find_children("*", "Light3D", true, false):
		if light is DirectionalLight3D:
			continue
		result[str(world.get_path_to(light))] = [light.light_color, light.light_energy,
			light.visible, light.shadow_enabled, light.light_specular]
	return result

func run() -> void:
	var packed: PackedScene = load("res://scenes/world/open_world.tscn")
	var world: Node3D = packed.instantiate()
	root.add_child(world)
	current_scene = world
	await frames(8)
	var cycle = world.get_node("Original/DayNightCycle")
	cycle.is_paused = true
	var env: Environment = cycle.world_environment.environment
	var sky: Sky = env.sky
	var mat: ShaderMaterial = sky.sky_material
	check(cycle.use_outdoor_sky and mat.shader.resource_path.ends_with("outdoor_sky.gdshader"), "Open World uses the new sky")
	check(world.find_children("*", "WorldEnvironment", true, false).size() == 1, "Exactly one outdoor WorldEnvironment")
	check(world.find_children("*", "DayNightCycle", true, false).size() == 1, "Exactly one day/night controller")
	check(world.find_children("*", "DirectionalLight3D", true, false).size() == 3, "No new directional lights")
	check(env.ambient_light_source == Environment.AMBIENT_SOURCE_SKY, "Sky supplies outdoor ambient lighting")
	var local_before := light_values(world)
	check(local_before.size() > 20, "Local light sources are present for preservation check")
	var valid_rig := true
	var max_direction_error := 0.0
	for step in 97:
		var hour := step * 0.25
		# Direct lighting updates do not emit time signals: insects keep their state.
		cycle._update_lighting(fposmod(hour, 24.0))
		var active := int(cycle.sun.visible) + int(cycle.moon.visible)
		valid_rig = valid_rig and active <= 1 and not cycle.soft_fill.visible and is_zero_approx(cycle.soft_fill.light_energy)
		var direction: Vector3 = mat.get_shader_parameter("sun_direction")
		max_direction_error = maxf(max_direction_error, direction.distance_to(cycle.sun.basis.z))
	check(valid_rig, "Full 24h: no competing directional fill or simultaneous sun/moon")
	check(max_direction_error < 0.0001, "Visible sky sun always matches the actual light direction")
	check(local_before == light_values(world), "All local light settings preserved across the full lighting cycle")
	cycle.time_of_day = 12.0
	check(cycle.sun.visible and not cycle.moon.visible, "Noon: sun only")
	check(is_zero_approx(mat.get_shader_parameter("stars_visibility")), "No stars in daylight")
	cycle.time_of_day = 0.0
	check(cycle.moon.visible and not cycle.sun.visible, "Midnight: moon only")
	check(is_equal_approx(mat.get_shader_parameter("stars_visibility"), 1.0), "Stars visible at night")
	cycle.time_of_day = 6.0
	check(absf(cycle.sun.basis.z.y) < 0.0001, "Sunrise aligned with 06:00")
	cycle.time_of_day = 18.0
	check(absf(cycle.sun.basis.z.y) < 0.0001, "Sunset aligned with 18:00")
	cycle.is_paused = false
	var offset: Vector2 = mat.get_shader_parameter("cloud_offset")
	var old_time: float = cycle.time_of_day
	cycle._process(1.0)
	check(offset.distance_to(mat.get_shader_parameter("cloud_offset")) > 0.001, "Clouds move with the existing controller")
	check(cycle.time_of_day > old_time, "Existing clock still advances")
	cycle.is_paused = true
	check(is_equal_approx(cycle.day_duration_minutes, 18.0) and is_equal_approx(cycle.night_duration_minutes, 3.0), "Existing cycle durations preserved")
	var insects = world.get_node("InsectManager")
	check(insects.day_night_cycle == cycle, "Fireflies remain connected to the same clock")
	# Resource isolation: loading the reusable original forest remains unchanged.
	var standalone: Node3D = load("res://experiments/arbres_20261014/playable_forest.tscn").instantiate()
	check(standalone.get_node("WorldEnvironment").environment.sky.sky_material is ProceduralSkyMaterial, "Shared original resource was not modified")
	standalone.free()
	var travel = root.get_node("CabinTravel")
	world.get_node("Original/Player").set_physics_process(false)
	for interior in ["cabin_room", "cave_room"]:
		cycle.time_of_day = 0.0
		cycle.is_paused = false
		await travel.enter_cabin(world.get_node("GrotteEntree"), "res://scenes/interiors/" + interior + ".tscn")
		check(travel.inside and not world.is_inside_tree(), interior + ": outdoor world detached")
		var parked_hour: float = cycle.time_of_day
		var parked_clouds: float = cycle._cloud_seconds
		var interior_envs: Array[Node] = travel.room.find_children("*", "WorldEnvironment", true, false)
		var interior_env: Environment = interior_envs[0].environment
		check(interior_envs.size() == 1 and interior_env.sky == null and interior_env.ambient_light_source == Environment.AMBIENT_SOURCE_COLOR, interior + ": original interior environment only")
		check(root.find_children("*", "WorldEnvironment", true, false).size() == 1, interior + ": no outdoor environment leaking inside")
		check(is_equal_approx(interior_env.ambient_light_energy, 0.38 if interior == "cabin_room" else 0.20), interior + ": original ambient energy preserved")
		await frames(5)
		check(is_equal_approx(cycle.time_of_day, parked_hour) and is_equal_approx(cycle._cloud_seconds, parked_clouds), interior + ": outside clock and clouds remain parked")
		if interior == "cave_room":
			await travel.enter_subroom("res://scenes/interiors/cave_depths.tscn")
			var depth_env: Environment = travel.room.find_children("*", "WorldEnvironment", true, false)[0].environment
			check(depth_env.sky == null and is_equal_approx(depth_env.ambient_light_energy, 0.48), "Cave depths: original environment preserved")
			await travel.leave_subroom()
		await travel.leave_cabin()
		check(current_scene == world and env.sky == sky and sky.sky_material == mat, interior + ": same outdoor sky restored")
		check(world.find_children("*", "WorldEnvironment", true, false).size() == 1, interior + ": no duplicates on return")
		cycle.is_paused = true
		await frames(2)
	world.queue_free()
	await frames(3)
	print("OUTDOOR_SKY_FAILURES: ", failures)
	quit(1 if failures else 0)
