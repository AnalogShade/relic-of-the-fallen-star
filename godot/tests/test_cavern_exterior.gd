extends SceneTree
const OUT = "res://../diagnostics/cavern_replacement_20261022/"
var failures: Array[String] = []
var cave: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame

func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures.append(label)

func shot(label: String, eye: Vector3, target: Vector3) -> void:
	if DisplayServer.get_name() == "headless": return
	camera.global_position = cave.to_global(eye)
	camera.look_at(cave.to_global(target))
	camera.make_current()
	await frames(5)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT + label + ".png")

func run() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await frames(30)
	cave = world.get_node("GrotteEntree")
	var player: CharacterBody3D = get_first_node_in_group("player")
	player.set_physics_process(false)
	player.global_position = cave.to_global(Vector3(0, 0.1, 4.8))
	camera = Camera3D.new()
	world.add_child(camera)
	check(cave.get_node("Art").scene_file_path.ends_with("cavern_shadowstone.glb"), "Blender exterior replaces old art")
	var meshes := cave.get_node("Art").find_children("*", "MeshInstance3D", true, false)
	check(meshes.size() == 1 and meshes[0].material_overlay is ShaderMaterial, "Depth gradient installed on textured mesh")
	var guardian := cave.get_node("OgreGuardian")
	var portal := cave.get_node("Portal")
	player.global_position = portal.to_global(Vector3(0, -0.6, 1.5))
	check(not portal.can_interact(), "Awake guardian blocks portal")
	await shot("01_guardian", Vector3(8, 5.2, 12), Vector3(0, 2.4, -1))
	guardian._restore_sleep()
	await frames(5)
	await shot("02_exterior", Vector3(6, 4.2, 10), Vector3(0, 2, -1.5))
	await shot("03_threshold", Vector3(0, 2.1, 4), Vector3(0, 2, -5))
	var space := world.get_world_3d().direct_space_state
	for z in [2.0, 1.0, 0.0, -1.0, -2.0]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(cave.to_global(Vector3(0, 3, z)), cave.to_global(Vector3(0, -3, z)), 1))
		print("GROUND z=", z, " local=", cave.to_local(hit.position) if not hit.is_empty() else Vector3.INF)
	# Walk with the real controller: its capsule origin is 0.425 m above its feet.
	player.global_position = cave.to_global(Vector3(0, 0.2, 3.8))
	player.velocity = Vector3.ZERO
	player.pivot.rotation.y = cave.global_rotation.y
	player.set_physics_process(true)
	Input.action_press("move_forward")
	var reached := false
	for tick in 180:
		await frames(1)
		if portal.can_interact():
			reached = true
			break
	Input.action_release("move_forward")
	check(reached, "Actual player walks from approach to F interaction zone")
	player.set_physics_process(false)
	player.global_position = portal.to_global(Vector3(0, -0.6, 1.5))
	await frames(4)
	check(portal.can_interact(), "Sleeping guardian allows portal")
	var bag := root.get_node("Inventory")
	check(bag.target == portal and "Entrer dans la caverne" in bag.ui.prompt.text, "F prompt targets the cave")
	await shot("04_interaction", Vector3(1.5, 2.7, 3), Vector3(0, 2, -4))
	var event := InputEventAction.new()
	event.action = "interact"
	event.pressed = true
	Input.parse_input_event(event)
	await frames(100)
	var travel := root.get_node("CabinTravel")
	check(travel.inside and is_instance_valid(travel.room) and travel.room.name == "CaveRoom", "F enters existing cave interior")
	if travel.inside:
		travel.leave_cabin()
		await frames(100)
		check(not travel.inside and guardian.state == "sleeping", "Return preserves sleeping guardian")
	var report := {"passed": failures.is_empty(), "failures": failures}
	var file := FileAccess.open(OUT + "validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print("CAVERN RESULTS ", JSON.stringify(report))
	quit(0 if failures.is_empty() else 1)
