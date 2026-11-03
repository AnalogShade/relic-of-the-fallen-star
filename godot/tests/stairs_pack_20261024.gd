extends SceneTree
## Offline authoring: shared meshes, editable treads and spatially batched bases.
func _initialize():
	call_deferred("run")

func own(node: Node, owner_node: Node):
	for c in node.get_children():
		c.owner = owner_node
		own(c, owner_node)

func run():
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/marches_pierre/composition.json"))
	var names = ["Marche_Pierre_Haute_Irreguliere", "Marche_Pierre_Basse_Fragmentee", "Marche_Pierre_Moyenne_Equarrie", "Marche_Pierre_Large_Fissuree"]
	var meshes = []
	var low_meshes = []
	for n in names:
		var source = load("res://assets/environment/marches_pierre/"+n+".gltf").instantiate()
		meshes.append(source.find_children("*", "MeshInstance3D", true, false)[0].mesh)
		source.free()
		var low_source = load("res://assets/environment/marches_pierre/"+n+"_Assise.gltf").instantiate()
		low_meshes.append(low_source.find_children("*", "MeshInstance3D", true, false)[0].mesh)
		low_source.free()
	var result = Node3D.new()
	result.name = "MarchesNaturelles"
	var steps = Node3D.new()
	steps.name = "Marches"
	result.add_child(steps)
	var bases = Node3D.new()
	bases.name = "Assises"
	result.add_child(bases)
	var groups = {}
	for record in data.instances:
		var a = record.angle
		var size = record.scale
		var p = record.position
		# Native Godot basis vectors are COLUMNS.
		var basis = Basis(Vector3(cos(a),0,-sin(a)),Vector3.UP,Vector3(sin(a),0,cos(a)))
		basis = basis.scaled_local(Vector3(size[0],size[2],size[1]))
		var transform = Transform3D(basis,Vector3(p[0],p[2],-p[1]))
		if record.group == "Marches":
			var step = MeshInstance3D.new()
			step.name = record.name
			step.mesh = meshes[int(record.kind)]
			step.transform = transform
			steps.add_child(step)
		else:
			var key = "%d_%d" % [int(record.kind), int(record.name.split("_")[1])/20]
			if not groups.has(key): groups[key] = {"mesh": low_meshes[int(record.kind)], "transforms": []}
			groups[key].transforms.append(transform)
	for key in groups:
		var batch = MultiMeshInstance3D.new()
		batch.name = "Pierres_"+key
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = groups[key].mesh
		mm.instance_count = groups[key].transforms.size()
		for i in range(mm.instance_count): mm.set_instance_transform(i,groups[key].transforms[i])
		batch.multimesh = mm
		bases.add_child(batch)
	var moss = load("res://assets/environment/marches_pierre/Mousse_Ruine_Conservee.glb").instantiate()
	moss.name = "MousseRuineConservee"
	result.add_child(moss)
	own(result,result)
	var packed = PackedScene.new()
	packed.pack(result)
	var error = ResourceSaver.save(packed,"res://scenes/world/marches_naturelles.tscn")
	print("STAIRS_PACK ",error," treads=",steps.get_child_count()," base_batches=",bases.get_child_count())
	result.free()
	quit()
