extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var scene = load("res://assets/environment/forest.glb").instantiate()
	root.add_child(scene)
	for terrain in scene.find_children("Terrain*", "MeshInstance3D", true, false):
		var ground := ShaderMaterial.new()
		ground.shader = load("res://shaders/ground.gdshader")
		terrain.material_override = ground
	var water := scene.find_child("Water", true, false) as MeshInstance3D
	var original_mesh := water.mesh
	load("res://scripts/stream_water.gd").apply(water)
	var material := water.material_override
	await process_frame
	await process_frame
	assert(water.mesh == original_mesh, "Water geometry must remain unchanged")
	assert(water.material_override == material, "Water material must remain unchanged")
	var seal := water.get_node_or_null("BankSeal") as MeshInstance3D
	assert(seal != null, "Forest must have exposed edges sealed")
	assert(seal.mesh.get_faces().size() > 0)
	load("res://scripts/stream_bank_seal.gd").apply(water)
	assert(water.get_node("BankSeal") == seal, "Repeated setup must not duplicate geometry")
	print("BANK_SEAL_CHECK faces=", seal.mesh.get_faces().size() / 3, " water_geometry_and_material_unchanged")
	scene.queue_free()
	await process_frame
	quit()
