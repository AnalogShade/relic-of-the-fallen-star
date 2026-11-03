extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	for i in 5: await physics_frame
	var player: Node3D = get_first_node_in_group("player")
	print("SPAWN ", player.global_position)
	var report: Array = []
	for n in world.find_children("*", "MultiMeshInstance3D", true, false):
		if not n.multimesh: continue
		var near: Array = []
		for i in n.multimesh.instance_count:
			var p: Vector3 = n.global_transform * n.multimesh.get_instance_transform(i).origin
			if Vector2(p.x, p.z).distance_to(Vector2(player.global_position.x, player.global_position.z)) < 32:
				near.append([i, p.x, p.y, p.z])
		if not near.is_empty(): report.append({"path":str(world.get_path_to(n)), "count":n.multimesh.instance_count,"near":near})
	var file := FileAccess.open("res://../diagnostics/ogre_quest_20261021/vegetation_survey.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	for entry in report: print(entry.path, " count=", entry.count, " near=", entry.near.size())
	for n in world.find_children("*", "MeshInstance3D", true, false):
		if "Undergrowth" in str(n.name):
			var names: Array = []
			for s in n.mesh.get_surface_count():
				var mat: Material = n.mesh.surface_get_material(s)
				names.append(mat.resource_name if mat else "none")
			print("UNDERGROWTH ", n.get_path(), " ", names)
			for s in n.mesh.get_surface_count():
				var mat: Material = n.mesh.surface_get_material(s)
				if not mat or not "Fougères" in mat.resource_name: continue
				var vertices: PackedVector3Array = n.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
				var points: Array = []
				for v in vertices:
					var p: Vector3 = n.global_transform * v
					points.append([p.x,p.y,p.z])
				var vertices_file := FileAccess.open("res://../diagnostics/ogre_quest_20261021/fern_vertices.json",FileAccess.WRITE)
				vertices_file.store_string(JSON.stringify(points))
				print("FERN MESH ", vertices.size(), " ", n.global_transform)
				var plants: Array = []
				for k in range(0, vertices.size(), 448):
					var bounds := AABB(n.global_transform * vertices[k], Vector3.ZERO)
					for j in range(k, mini(k+448, vertices.size())): bounds = bounds.expand(n.global_transform * vertices[j])
					plants.append({"center":[bounds.get_center().x,bounds.position.y,bounds.get_center().z],"size":str(bounds.size)})
				var plants_file := FileAccess.open("res://../diagnostics/ogre_quest_20261021/fern_survey.json",FileAccess.WRITE)
				plants_file.store_string(JSON.stringify(plants,"\t"))
	print("PORTAL ",world.get_node("GrotteEntree/Portal").global_position)
	quit()
