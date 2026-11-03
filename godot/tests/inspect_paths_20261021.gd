extends SceneTree
func _initialize():
	call_deferred("inspect")
func inspect():
	var scene = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var meshes = []
	for n in scene.find_children("*", "MeshInstance3D", true, false):
		var mats = []
		if n.mesh == null: continue
		for i in n.mesh.get_surface_count():
			var m = n.mesh.surface_get_material(i)
			mats.append(m.resource_name if m else "null")
		meshes.append({"path":str(scene.get_path_to(n)),"pos":str(n.global_position),"aabb":str(n.get_aabb()),"materials":mats,"vertices":n.mesh.get_faces().size()})
	var excluded: Array[RID] = []
	for n in scene.find_children("*", "CollisionObject3D", true, false):
		if not "/Terrain" in str(n.get_path()): excluded.append(n.get_rid())
	await physics_frame
	var heights = []
	for z in range(-24, 97, 2):
		for x in range(-74, 5, 2):
			var q = PhysicsRayQueryParameters3D.create(Vector3(x,100,z),Vector3(x,-8,z),1,excluded)
			var h = root.get_world_3d().direct_space_state.intersect_ray(q)
			if not h.is_empty(): heights.append([x,z,h.position.y])
	var f = FileAccess.open("res://../diagnostics/paths_20261021/inventory.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"meshes":meshes,"heights":heights},"\t"))
	print("INVENTORY_DONE ", meshes.size())
	quit()
