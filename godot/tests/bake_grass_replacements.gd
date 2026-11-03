extends SceneTree
## Retain the surveyed roots and fitted transforms of existing grass plants.
const PLAN := "res://../diagnostics/grass_replacement_20261031/plan.json"
const OUTPUT := "res://scenes/world/herbes_detaillees.tscn"
const MATERIAL := preload("res://assets/environment/grass_detailed/grass_natural.tres")
func _initialize() -> void: call_deferred("bake")
func bake() -> void:
	assert(DisplayServer.get_name()!="headless", "MultiMesh serialization requires a renderer")
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PLAN))
	var meshes: Array[Mesh]=[]
	for variant in data.variants:
		var art=load(str(variant.file)).instantiate()
		var mesh=art.find_children("*","MeshInstance3D",true,false)[0].mesh.duplicate() as ArrayMesh
		for s in mesh.get_surface_count(): mesh.surface_set_material(s,MATERIAL)
		var path="res://assets/environment/grass_detailed/grass_%02d_batched.res"%(int(variant.variant)+1)
		assert(ResourceSaver.save(mesh,path)==OK)
		meshes.append(mesh);art.free()
	var batches: Dictionary={}
	for plant in data.plants:
		var p: Array=plant.position
		var cell=Vector2i(floori(float(p[0])/24),floori(float(p[2])/24))
		var key="%02d_%d_%d"%[int(plant.variant),cell.x,cell.y]
		if not batches.has(key): batches[key]={"variant":int(plant.variant),"transforms":[]}
		var b: Array=plant.basis
		var basis=Basis(Vector3(b[0],b[1],b[2]),Vector3(b[3],b[4],b[5]),Vector3(b[6],b[7],b[8]))
		batches[key].transforms.append(Transform3D(basis,Vector3(p[0],p[1],p[2])))
	var layer=Node3D.new();layer.name="HerbesDetaillees";root.add_child(layer)
	for key in batches:
		var batch: Dictionary=batches[key]
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.mesh=meshes[batch.variant];mm.instance_count=batch.transforms.size()
		var center: Vector3=batch.transforms[0].origin
		for i in mm.instance_count:
			var transform: Transform3D=batch.transforms[i];transform.origin-=center
			mm.set_instance_transform(i,transform)
		var node=MultiMeshInstance3D.new();node.name="Herbe_"+key;node.multimesh=mm;node.position=center
		node.visibility_range_end=90;node.visibility_range_end_margin=12
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		layer.add_child(node);node.owner=layer
	await process_frame
	await RenderingServer.frame_post_draw
	var packed=PackedScene.new();assert(packed.pack(layer)==OK)
	assert(ResourceSaver.save(packed,OUTPUT)==OK)
	var manifest={"sources":data.sources,"plants":data.plants,"variants":data.variants,"batches":batches.size(),"saturation":0.42,"brightness":0.92}
	FileAccess.open("res://assets/data/grass_replacements.json",FileAccess.WRITE).store_string(JSON.stringify(manifest))
	print("GRASS_BAKED plants=",data.plants.size()," batches=",batches.size())
	layer.free();quit()
