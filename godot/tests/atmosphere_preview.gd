extends Node3D
var failures: Array[String] = []
var finished := false

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
	print(("PASS: " if ok else "FAIL: ") + message)

func capture(label: String) -> void:
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/atmosphere_" + label + ".png")

func _ready() -> void:
	await get_tree().create_timer(2.0).timeout
	var world := $World
	var motes := world.get_node("ForestMotes") as MultiMeshInstance3D
	var before := motes.multimesh.get_instance_transform(0)
	await capture("forest")
	check(not before.is_equal_approx(motes.multimesh.get_instance_transform(0)), "Airborne motes move over time")
	check(world.get_node("Original/Sun").shadow_enabled, "Sun shadows preserved")
	check(world.get_node("Original/Sun").light_energy < 1.0, "Direct sunlight reduced")
	var old_paths := 0
	for node in world.get_node("Sectors").find_children("Paths*", "MeshInstance3D", true, false):
		old_paths += 1
		check(not node.visible, "Old path ribbon hidden: " + str(node.name))
	check(old_paths > 0, "Legacy path meshes found")
	var excluded: Array[RID] = []
	for node in world.find_children("*", "CollisionObject3D", true, false):
		if not "/Terrain" in str(node.get_path()):
			excluded.append(node.get_rid())
	var camera := Camera3D.new()
	add_child(camera)
	camera.far = 480.0
	camera.fov = 65.0
	camera.current = true
	world.get_node("Original/HUD").hide()
	var player := world.get_node("Original/Player") as CharacterBody3D
	var q := PhysicsRayQueryParameters3D.create(Vector3(-46, 80, 5), Vector3(-46, -5, 5), 1, excluded)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	check(not hit.is_empty(), "Cabin approach has terrain collision")
	if not hit.is_empty():
		player.global_position = hit.position + Vector3.UP * 0.4
		camera.global_position = Vector3(-56, 15.3, 9)
		camera.look_at(Vector3(-56, 12.9, 1))
		await capture("cabin_path")
		camera.global_position = Vector3(-56, 18, 8)
		camera.look_at(Vector3(-53, 12, 5))
		await capture("path_overview")
	finished = true
	print("ATMOSPHERE_VALIDATION: " + JSON.stringify({"failures": failures, "legacy_paths": old_paths, "motes": motes.multimesh.instance_count, "fps": Engine.get_frames_per_second()}))
