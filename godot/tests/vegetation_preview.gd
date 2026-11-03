extends Node3D
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition: failures.append(message)

func _ready() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(12): await get_tree().physics_frame
	world.get_node("Original/HUD").hide()
	var player: CharacterBody3D = world.get_node("Original/Player")
	player.set_physics_process(false)
	var layer: Node3D = world.get_node("VegetationFirstPass")
	var trees: Array[Node] = layer.get_node("ArbresPlaines").get_children() + layer.get_node("ArbresMontagne").get_children()
	check(trees.size() >= 20, "Initial tree population loaded")
	var collisions := 0
	var blocked := 0
	var clear_canopies := 0
	for tree in trees:
		var shape: CollisionShape3D = tree.get_node("Tronc/CapsuleTronc")
		if shape.shape is CapsuleShape3D: collisions += 1
		var center: Vector3 = tree.global_position + Vector3.UP
		var q := PhysicsRayQueryParameters3D.create(center + Vector3.LEFT * 1.5, center + Vector3.RIGHT * 1.5, 1)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit.collider == tree.get_node("Tronc"): blocked += 1
		q.from = center + Vector3(0, 0, 1.4) + Vector3.LEFT
		q.to = center + Vector3(0, 0, 1.4) + Vector3.RIGHT
		hit = get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or hit.collider != tree.get_node("Tronc"): clear_canopies += 1
	check(collisions == trees.size(), "All new trees use primitive capsules")
	check(blocked == trees.size(), "All trunks block physics rays")
	check(clear_canopies == trees.size(), "Space beside trunks has no canopy collision")
	check(layer.find_children("*", "CollisionShape3D", true, false).size() == trees.size(), "Plants add no collisions and trees have one collider each")
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vegetation_placement.json"))
	var terrain_rids: Array[RID] = []
	var excluded: Array[RID] = []
	for body in world.find_children("*", "CollisionObject3D", true, false):
		if "/Terrain" in str(body.get_path()): terrain_rids.append(body.get_rid())
		else: excluded.append(body.get_rid())
	var floating := 0
	var assets: Dictionary = {}
	for sample in report.samples:
		var p := Vector3(sample.position[0], sample.position[1], sample.position[2])
		var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 3, p - Vector3.UP * 3, 1)
		q.exclude = excluded
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit.is_empty() or absf(p.y - hit.position.y) > 0.08: floating += 1
		if sample.has("asset"): assets[sample.asset] = true
	check(floating == 0, "All %d placements are grounded" % report.samples.size())
	check(assets.size() == 14, "All 12 plant variants and both trees are present")
	var stored_plants := 0
	var invalid_buffers := 0
	for node in layer.find_children("*", "MultiMeshInstance3D", true, false):
		stored_plants += node.multimesh.instance_count
		if node.multimesh.buffer.size() != node.multimesh.instance_count * 12: invalid_buffers += 1
	check(stored_plants > 2000 and invalid_buffers == 0, "Serialized plant instance buffers are complete")
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.far = 2000
	camera.fov = 58
	for shot in [["overview", Vector3(-151, 51, 141), Vector3(-186, 11, 49)], ["grass", Vector3(-166, 12, 86), Vector3(-180, 10, 60.0)], ["cave", Vector3(57, 15, -34), Vector3(42, 5, -53)]]:
		camera.global_position = shot[1]
		camera.look_at(shot[2])
		for i in range(12): await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://tests/vegetation_" + shot[0] + ".png")
	FileAccess.open("res://tests/vegetation_validation.json", FileAccess.WRITE).store_string(JSON.stringify({"failures": failures, "trees": trees.size(), "placements": report.samples.size(), "grounding_errors": floating}, "\t"))
	get_tree().quit(0 if failures.is_empty() else 1)


