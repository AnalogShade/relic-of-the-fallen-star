extends SceneTree

func _initialize() -> void:
	call_deferred("check")

func check() -> void:
	var scene = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for path in ["Original/EnvironmentArt/Water", "Sectors/Tile_02_vallee_des_sources/Art/Water", "Sectors/Tile_07_meandres_du_sud/Art/Water", "Sectors/OasisDuNord/Water_Oasis_Source"]:
		assert(scene.get_node(path).material_override.shader.resource_path == "res://shaders/water.gdshader")
	for path in ["Sectors/OasisDuNord/Water_Oasis_Reservoir", "Sectors/OasisDuNord/Water_Oasis_Exutoire"]:
		assert(scene.get_node(path).material_override.shader.resource_path == "res://shaders/oasis_water.gdshader")
	print("WATER_RESTORE_PASS")
	scene.free()
	quit()
