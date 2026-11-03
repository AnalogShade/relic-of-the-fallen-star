extends SceneTree

const BASE = "res://assets/environment/marches_pierre/"

func _initialize():
	# Godot's dummy headless renderer discards MultiMesh transform buffers.
	# Author this scene with --minimized --rendering-method gl_compatibility.
	if DisplayServer.get_name() == "headless":
		push_error("Pack sommet requires a real renderer to preserve every visual stone.")
		quit(1)
		return
	call_deferred("run")

func own_all(node: Node, owner_node: Node):
	for child in node.get_children():
		child.owner = owner_node
		own_all(child, owner_node)

func triangle(faces: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3):
	if (b-a).cross(c-a).y < 0:
		faces.append_array(PackedVector3Array([a,c,b]))
	else:
		faces.append_array(PackedVector3Array([a,b,c]))

func collider(parent: Node, label: String, faces: PackedVector3Array):
	var body = StaticBody3D.new()
	body.name = label
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)
	var shape = ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var node = CollisionShape3D.new()
	node.shape = shape
	body.add_child(node)

func relative_transform(node: Node3D, branch: Node3D) -> Transform3D:
	var value = node.transform
	var cursor = node.get_parent()
	while cursor != branch:
		if cursor is Node3D:value=cursor.transform*value
		cursor=cursor.get_parent()
	return value

func run():
	var data = JSON.parse_string(FileAccess.get_file_as_string(BASE+"composition_sommet_20261024.json"))
	var steps=Node3D.new();steps.name="MarchesNaturelles"
	var treads=Node3D.new();treads.name="Marches";steps.add_child(treads)
	var bases=Node3D.new();bases.name="Assises";steps.add_child(bases)
	var low_meshes={}
	for name in ["Haute_Irreguliere", "Moyenne_Equarrie", "Large_Fissuree"]:
		var key="Marche_Pierre_"+name
		var source=load(BASE+key+"_Assise.gltf").instantiate()
		low_meshes[key+"_Assise_Optimisee"]=source.find_children("*","MeshInstance3D",true,false)[0].mesh
		source.free()
	var records=JSON.parse_string(FileAccess.get_file_as_string(BASE+"assises_sommet_20261024.json"))
	var base_groups={}
	for record in records:
		var a=record.angle;var p=record.position;var s=record.scale
		var basis=Basis(Vector3(cos(a),0,-sin(a)),Vector3.UP,Vector3(sin(a),0,cos(a)))
		var t=Transform3D(basis.scaled_local(Vector3(s[0],s[2],s[1])),Vector3(p[0],p[2],-p[1]))
		var key="%s_%d_%d" % [record.mesh,floor(t.origin.x/12),floor(t.origin.z/12)]
		if not base_groups.has(key):base_groups[key]={"mesh":low_meshes[record.mesh],"transforms":[]}
		base_groups[key].transforms.append(t)
	for key in base_groups:
		var batch=MultiMeshInstance3D.new();batch.name="Assises_"+key
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=base_groups[key].mesh;mm.instance_count=base_groups[key].transforms.size()
		for i in range(mm.instance_count):mm.set_instance_transform(i,base_groups[key].transforms[i])
		batch.multimesh=mm;bases.add_child(batch)
	var meshes = {}
	for name in ["Haute_Irreguliere", "Basse_Fragmentee", "Moyenne_Equarrie", "Large_Fissuree"]:
		var key = "Marche_Pierre_"+name
		var source = load(BASE+key+".gltf").instantiate()
		meshes[key+"_Export_Unitaire"] = source.find_children("*","MeshInstance3D",true,false)[0].mesh
		source.free()
	var left = []; var right = []
	for record in data:
		var a = record.angle; var p = record.position; var s = record.scale
		var basis = Basis(Vector3(cos(a),0,-sin(a)),Vector3.UP,Vector3(sin(a),0,cos(a)))
		var origin = Vector3(p[0],p[2],-p[1])
		var mesh = MeshInstance3D.new()
		mesh.name = record.name
		mesh.mesh = meshes[record.mesh]
		mesh.transform = Transform3D(basis.scaled_local(Vector3(s[0],s[2],s[1])),origin)
		steps.get_node("Marches").add_child(mesh)
		# One smooth walking ribbon, slightly below the textured treads.
		left.append(origin-basis.x*(s[0]*0.46)-Vector3.UP*.035)
		right.append(origin+basis.x*(s[0]*0.46)-Vector3.UP*.035)
	var faces = PackedVector3Array()
	for i in range(left.size()-1):
		triangle(faces,left[i],right[i],left[i+1])
		triangle(faces,right[i],right[i+1],left[i+1])
	collider(steps,"AscensionCollisionContinue",faces)
	own_all(steps,steps)
	var packed = PackedScene.new(); packed.pack(steps)
	assert(ResourceSaver.save(packed,"res://scenes/world/marches_naturelles.tscn")==OK)
	steps.free()

	var summit = Node3D.new();summit.name="RuineSommet"
	var art = load(BASE+"ruine_assise_sommet.glb").instantiate()
	var groups = {}
	for node in art.find_children("*","MeshInstance3D",true,false):
		if node.name == "Ruine_Assise_Coeur_Continu" or str(node.name).begins_with("Meshy"):
			var copy=MeshInstance3D.new();copy.name=node.name;copy.mesh=node.mesh;copy.transform=relative_transform(node,art);summit.add_child(copy)
			continue
		var key = node.mesh.get_instance_id()
		if not groups.has(key):groups[key]={"mesh":node.mesh,"transforms":[]}
		groups[key].transforms.append(relative_transform(node,art))
	art.free()
	for key in groups:
		var batch = MultiMeshInstance3D.new();batch.name="AssisePierres_"+str(key)
		var mm = MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D
		mm.mesh=groups[key].mesh;mm.instance_count=groups[key].transforms.size()
		for i in range(mm.instance_count):mm.set_instance_transform(i,groups[key].transforms[i])
		batch.multimesh=mm;summit.add_child(batch)
	var walls = JSON.parse_string(FileAccess.get_file_as_string(BASE+"ruine_collision_simplifiee.json"))
	var wall_faces = PackedVector3Array()
	for p in walls:wall_faces.append(Vector3(p[0],p[1],p[2]))
	collider(summit,"RuineMursCollisionSimplifiee",wall_faces)
	# A single closed platform with a sloped shoulder; no brick colliders.
	var hull = JSON.parse_string(FileAccess.get_file_as_string("res://../diagnostics/ruin_foundation_20261024/build_report.json")).hull
	var center = Vector3(64,44.28,-76)
	var outer = []; var inner = []
	for p in hull:
		outer.append(Vector3(p[0],43.44,-p[1]))
		inner.append(center+(Vector3(p[0],44.28,-p[1])-center)*.76)
	var deck_faces = PackedVector3Array()
	for i in range(hull.size()):
		var j=(i+1)%hull.size()
		triangle(deck_faces,center,inner[i],inner[j])
		triangle(deck_faces,inner[i],outer[i],outer[j])
		triangle(deck_faces,inner[i],outer[j],inner[j])
		var a=outer[i]-Vector3.UP*12;var b=outer[j]-Vector3.UP*12
		triangle(deck_faces,outer[i],a,b)
		triangle(deck_faces,outer[i],b,outer[j])
	collider(summit,"AssiseCollisionVolumeUnique",deck_faces)
	own_all(summit,summit)
	packed=PackedScene.new();packed.pack(summit)
	assert(ResourceSaver.save(packed,"res://scenes/world/ruine_sommet.tscn")==OK)
	print("SOMMET_PACK marches=",data.size()," foundation_batches=",groups.size()," collision_bodies=3 ramp_triangles=",faces.size()/3," platform_triangles=",deck_faces.size()/3," wall_triangles=",wall_faces.size()/3)
	summit.free()
	call_deferred("quit")

