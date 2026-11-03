extends SceneTree

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	# Do not feed a previous bake back into the source geometry.
	var previous := world.get_node_or_null("Sectors/CampNavigation")
	if previous != null: previous.free()
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.cell_size = 0.2
	mesh.cell_height = 0.05
	mesh.agent_radius = 0.6
	mesh.agent_height = 1.7
	mesh.agent_max_climb = 0.1
	mesh.agent_max_slope = 42.0
	mesh.edge_max_error = 0.5
	mesh.filter_baking_aabb = AABB(Vector3(-2, -3, -77), Vector3(40, 24, 40))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(mesh, source, world)
	print("NAV_SOURCE_READY")
	NavigationServer3D.bake_from_source_geometry_data(mesh, source)
	print("NAV_BAKED polygons=", mesh.get_polygon_count(), " vertices=", mesh.vertices.size())
	DirAccess.make_dir_recursive_absolute("res://assets/navigation")
	ResourceSaver.save(mesh, "res://assets/navigation/bandit_camp.tres")
	world.queue_free()
	await process_frame
	quit()
