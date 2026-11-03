extends SceneTree

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	var player: CharacterBody3D = world.get_node("Original/Player")
	for i in range(45): await physics_frame
	var start := player.global_position
	var travelled := 0.0
	for action in ["move_right", "move_forward", "move_left"]:
		var old := player.global_position
		Input.action_press(action)
		for i in range(30): await physics_frame
		Input.action_release(action)
		travelled += player.global_position.distance_to(old)
	for i in range(8): await physics_frame
	var report := {"start":str(start), "end":str(player.global_position), "travelled":travelled, "on_floor":player.is_on_floor(), "full_world":world.has_node("Sectors"), "player_camera_current":player.get_node("CameraPivot/SpringArm3D/Camera3D").current}
	var patch: Node = world.get_node("Original/EnvironmentArt/TreeVariants")
	var rock_checks := []
	for mesh: MeshInstance3D in patch.find_children("TEST_Rock*", "MeshInstance3D", true, false):
		for shape: CollisionShape3D in mesh.find_children("*", "CollisionShape3D", true, false):
			rock_checks.append(mesh.global_transform.is_equal_approx(shape.global_transform) and (shape.shape as ConcavePolygonShape3D).get_faces() == mesh.mesh.create_trimesh_shape().get_faces())
	report["moved_rock_colliders_match"] = rock_checks.all(func(value): return value)
	report["variant_wood_meshes"] = patch.find_children("TEST_Wood*", "MeshInstance3D", true, false).size()
	var dest := ProjectSettings.globalize_path("res://../environments/foret_des_lueurs/test_arbres_20261014/")
	var file := FileAccess.open(dest + "playable_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(dest + "playable_character.png")
	print("PLAYABLE_VALIDATION ", report)
	assert(travelled > 1.0, "Player movement blocked")
	assert(report.full_world and report.player_camera_current and report.moved_rock_colliders_match)
	current_scene = null
	world.queue_free()
	for i in range(3): await process_frame
	await RenderingServer.frame_post_draw
	quit()
