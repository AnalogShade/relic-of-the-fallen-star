extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func key(p: Vector3) -> Vector3i:
	return Vector3i((p*1000.0).round())

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 8: await process_frame
	await physics_frame
	var plan = JSON.parse_string(FileAccess.get_file_as_string("res://../diagnostics/path_edge_grass_20261028/plan.json"))
	var node := world.get_node(NodePath(plan.node)) as MeshInstance3D
	# Always start from the imported mesh, including when rerunning after integration.
	var source = load("res://assets/environment/trails_20261021/forest_test_remaining.glb").instantiate()
	node.mesh = source.get_node("Undergrowth").mesh
	source.free()
	if "export" in OS.get_cmdline_user_args():
		for surface in node.mesh.get_surface_count():
			if not node.mesh.surface_get_material(surface).resource_name.begins_with("Herbes"): continue
			var arrays := node.mesh.surface_get_arrays(surface)
			var positions := []
			for vertex in arrays[Mesh.ARRAY_VERTEX]:
				var p := node.to_global(vertex)
				positions.append([p.x,p.y,p.z])
			FileAccess.open("res://../diagnostics/path_edge_grass_20261028/actual_grass.json",FileAccess.WRITE).store_string(JSON.stringify({"vertices":positions,"indices":Array(arrays[Mesh.ARRAY_INDEX])}))
		print("GRASS_SOURCE_EXPORTED")
		quit()
		return
	var excluded: Array[RID] = []
	for body in world.find_children("*", "CollisionObject3D", true, false):
		if not "Terrain" in str(body.get_path()): excluded.append(body.get_rid())
	var shifts := {}
	var grounded := []
	for clump in plan.clumps:
		var p := Vector2(clump.target[0],clump.target[1])
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,100,p.y),Vector3(p.x,-10,p.y),1,excluded)
		var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			push_error("Grass verge has no ground: " + str(p))
			quit(1)
			return
		var shift := Vector3(p.x-float(clump.source[0]),hit.position.y-float(clump.base_y),p.y-float(clump.source[2]))
		for blade in clump.blades:
			var base := Vector3(blade.base[0],blade.base[1],blade.base[2])
			var target := base+Vector3(shift.x,0,shift.z)
			var blade_query := PhysicsRayQueryParameters3D.create(target+Vector3.UP*100,target-Vector3.UP*100,1,excluded)
			var blade_hit := root.get_world_3d().direct_space_state.intersect_ray(blade_query)
			if blade_hit.is_empty():
				push_error("Grass blade has no ground")
				quit(1)
				return
			var blade_shift := Vector3(shift.x,blade_hit.position.y-base.y,shift.z)
			for v in blade.vertices:
				shifts[key(Vector3(v[0],v[1],v[2]))] = blade_shift
		grounded.append({"from":clump.source,"to":[p.x,hit.position.y,p.y],"side":clump.side})
	var mesh := ArrayMesh.new()
	var moved := 0
	var matched := {}
	for surface in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var wp: Vector3 = node.to_global(vertices[i])
			var vertex_key := key(wp)
			# Decimal rounding can differ by one millimetre at float half-steps.
			if not shifts.has(vertex_key):
				var found := false
				for x in range(-1,2):
					if found: break
					for y in range(-1,2):
						if found: break
						for z in range(-1,2):
							var candidate := vertex_key+Vector3i(x,y,z)
							if shifts.has(candidate):
								vertex_key = candidate
								found = true
								break
			if shifts.has(vertex_key):
				vertices[i] = node.to_local(wp+shifts[vertex_key])
				matched[vertex_key] = true
				moved += 1
		arrays[Mesh.ARRAY_VERTEX] = vertices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(surface,node.mesh.surface_get_material(surface))
	if matched.size() != shifts.size():
		push_error("Grass vertex mapping incomplete: %d / %d" % [matched.size(),shifts.size()])
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute("res://assets/environment/path_edge_grass")
	var result := ResourceSaver.save(mesh,"res://assets/environment/path_edge_grass/undergrowth.res")
	FileAccess.open("res://../diagnostics/path_edge_grass_20261028/result.json",FileAccess.WRITE).store_string(JSON.stringify({"clumps":grounded,"moved_vertices":moved,"mapped_positions":matched.size(),"save_error":result},"\t"))
	print("GRASS_BAKE clumps=",grounded.size()," moved_vertices=",moved," matched=",matched.size()," save=",result)
	quit(result)
