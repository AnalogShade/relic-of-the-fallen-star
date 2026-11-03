extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run_tests")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok:
		failures.append(label)

func frames(count: int) -> void:
	for i in count:
		await physics_frame

func run_tests() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var water := MeshInstance3D.new()
	water.name = "Water_Test"
	var plane := PlaneMesh.new()
	plane.size = Vector2(20, 20)
	water.mesh = plane
	world.add_child(water)
	var p = load("res://scenes/player.tscn").instantiate()
	p.position = Vector3(0, -1.5, 0)
	world.add_child(p)
	await frames(180)
	var ap: AnimationPlayer = p.get_node("Nael/AnimationPlayer")
	check(p.swimming, "Deep water enters swimming")
	check(absf(p.global_position.y + p.float_depth) < 0.04, "Buoyancy holds the body at the surface")
	check(ap.current_animation == "Nael_Float", "Stationary character floats")
	for clip in ["Nael_Float", "Nael_Swim"]:
		check(ap.has_animation(clip) and ap.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, clip + " imported and looping")
		if ap.has_animation(clip):
			for track in ap.get_animation(clip).get_track_count():
				var path := ap.get_animation(clip).track_get_path(track)
				check(p.get_node("Nael").has_node(NodePath(str(path).split(":")[0])), "Animation target resolves: " + str(path))
	var start: Vector3 = p.global_position
	Input.action_press("move_forward")
	await frames(40)
	check(ap.current_animation == "Nael_Swim", "Movement switches to swimming animation")
	check(p.global_position.distance_to(start) > 0.8, "Swimming propels the player")
	Input.action_press("jump")
	await frames(10)
	check(not p.swimming and not p.gliding and p.velocity.y > 0.0, "Jump launches the swimmer above water without buoyancy cancelling it")
	Input.action_release("jump")
	Input.action_release("move_forward")
	await frames(120)
	check(ap.current_animation == "Nael_Float", "Stopping returns to floating")
	check(not p.start_claw() and not p.start_fireball(), "Ground attacks do not interrupt swimming")
	p.set_physics_process(false)
	p.global_position = Vector3(0, -0.5, 0)
	p._update_swimming()
	check(not p.swimming and p.floor_snap_length > 0.0, "Shallow water restores ground movement")
	p.global_position = Vector3(11, -2, 0)
	p._update_swimming()
	check(not p.swimming, "Outside the water footprint stays dry")
	# A triangle covers only half its bounds: the missing half must stay dry.
	p.water_surface.surfaces.clear()
	p.water_surface.surfaces.append({"bounds": AABB(Vector3.ZERO, Vector3(10, 0, 10)), "triangles": PackedVector3Array([Vector3.ZERO, Vector3(10, 0, 0), Vector3(0, 0, 10)])})
	check(not is_finite(p.water_surface.height_at(Vector3(8, -2, 8))), "Irregular shore uses triangles rather than a bounding box")
	check(is_finite(p.water_surface.height_at(Vector3(2, -2, 2))), "Inside water triangle samples its height")
	p.respawn()
	check(not p.swimming and p.velocity == Vector3.ZERO, "Respawn resets water state")
	print("SWIMMING_TEST_RESULT: %d failure(s)" % failures.size())
	quit(0 if failures.is_empty() else 1)
