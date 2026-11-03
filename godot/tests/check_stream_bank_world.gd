extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var started := Time.get_ticks_msec()
	var scene = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	var streams := 0
	var seals := 0
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		if node.material_override is ShaderMaterial and node.material_override.shader.resource_path == "res://shaders/stream_water.gdshader":
			streams += 1
			var seal := node.get_node_or_null("BankSeal") as MeshInstance3D
			if seal != null:
				seals += 1
				assert(seal.material_override != node.material_override)
				if str(node.name) == "Water":
					assert(seal.material_override.get_shader_parameter("stream_stones_enabled") == true, "Stream bank stones must survive world material setup")
					assert(seal.material_override.get_shader_parameter("stream_footprint") is Texture2D)
				print("STREAM_SEALED ", node.get_path(), " triangles=", seal.mesh.get_faces().size() / 3)
	assert(streams > 0 and seals > 0)
	print("BANK_WORLD_CHECK streams=", streams, " seals=", seals, " load_ms=", Time.get_ticks_msec() - started)
	scene.queue_free()
	await process_frame
	quit()
