extends SceneTree
const ASSETS := "res://assets/environment/vegetation/"
const SLUGS := ["fougere_compacte", "fougere_arquee", "fougere_rosette"]
var world: Node3D
var non_terrain: Array[RID]=[]
var terrain: Array[RID]=[]
var clearance_exclude: Array[RID]=[]
var rng:=RandomNumberGenerator.new()
func _initialize() -> void:call_deferred("bake")
func bake() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("An active renderer is required to save MultiMesh transforms and colors.");quit(1);return
	rng.seed=31102026
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://../diagnostics/fern_replacement_20261031/candidates.json"))
	world=load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 20:await physics_frame
	for body in world.find_children("*","CollisionObject3D",true,false):
		if "/Terrain" in str(body.get_path()) or "/CastleGround" in str(body.get_path()):terrain.append(body.get_rid())
		else:non_terrain.append(body.get_rid())
		if not body is StaticBody3D:clearance_exclude.append(body.get_rid())
	clearance_exclude.append_array(terrain)
	var meshes: Array[Mesh]=[]
	for slug in SLUGS:
		var art=load(ASSETS+slug+".glb").instantiate()
		var mesh=art.find_children("*","MeshInstance3D",true,false)[0].mesh.duplicate() as ArrayMesh
		for s in mesh.get_surface_count():
			var mat=mesh.surface_get_material(s).duplicate() as StandardMaterial3D
			mat.vertex_color_use_as_albedo=true
			mat.normal_enabled=false
			mat.normal_texture=null
			mat.roughness=0.88
			mat.cull_mode=BaseMaterial3D.CULL_DISABLED
			mesh.surface_set_material(s,mat)
		assert(ResourceSaver.save(mesh,ASSETS+slug+"_batched.res")==OK)
		meshes.append(mesh);art.free()
	var batches: Dictionary={}
	var records:=[]
	var pickups: Array=data.pickups.duplicate(true)
	var rejected:=0
	for candidate in data.plants:
		var p: Array=candidate.position
		var ray=PhysicsRayQueryParameters3D.create(Vector3(p[0],150,p[2]),Vector3(p[0],-10,p[2]),1)
		ray.exclude=non_terrain
		var hit=world.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y<0.68 or hit.position.y<0.5:rejected+=1;continue
		# Move roots out of embedded rocks, keeping the replacement in its old patch.
		var found_ground=false
		var original=Vector2(p[0],p[2])
		for attempt in 17:
			var test_point=original
			if attempt>0:
				test_point+=Vector2.from_angle((attempt-1)*TAU/8)*(0.65 if attempt<=8 else 1.05)
			var query=PhysicsRayQueryParameters3D.create(Vector3(test_point.x,150,test_point.y),Vector3(test_point.x,-10,test_point.y),1)
			query.exclude=non_terrain
			var trial=world.get_world_3d().direct_space_state.intersect_ray(query)
			if trial.is_empty() or trial.normal.y<0.68 or trial.position.y<0.5:continue
			var shape=SphereShape3D.new();shape.radius=0.24
			var clearance=PhysicsShapeQueryParameters3D.new();clearance.shape=shape
			clearance.transform.origin=trial.position+Vector3.UP*0.28
			clearance.collision_mask=1;clearance.exclude=clearance_exclude
			if not world.get_world_3d().direct_space_state.intersect_shape(clearance,1).is_empty():continue
			hit=trial;found_ground=true;break
		if not found_ground:rejected+=1;continue
		var pos: Vector3=hit.position-Vector3.UP*0.025
		var variant=records.size()%3
		var size=rng.randf_range(0.65,1.12)
		var vertical=rng.randf_range(0.65,2.25)
		var scale=Vector3(size,vertical,size)
		var basis=Basis(Vector3.UP,rng.randf_range(0,TAU)).scaled(scale)
		var tone=rng.randf_range(0.62,1.05)
		var color=Color(tone*rng.randf_range(0.88,1.02),tone,tone*rng.randf_range(0.82,1.05),1)
		var cell=Vector2i(floori(pos.x/24),floori(pos.z/24))
		var key="%d_%d_%d"%[variant,cell.x,cell.y]
		if not batches.has(key):batches[key]={"variant":variant,"transforms":[],"colors":[]}
		batches[key].transforms.append(Transform3D(basis,pos));batches[key].colors.append(color)
		records.append({"position":[pos.x,pos.y,pos.z],"variant":SLUGS[variant],"scale":[size,vertical,size],"color":[color.r,color.g,color.b,1],"source":candidate.source})
		# Extend coverage to replaced ferns that never had an individual harvest anchor.
		var covered=false
		for pickup in pickups:
			var q: Array=pickup.position
			if Vector2(q[0],q[2]).distance_to(Vector2(pos.x,pos.z))<1.1:covered=true;break
		if not covered:pickups.append({"id":"forest/fern_variant/%04d"%records.size(),"position":[pos.x,pos.y+0.35,pos.z]})
	var layer=Node3D.new();layer.name="FougeresDetaillees"
	root.add_child(layer)
	for key in batches:
		var batch: Dictionary=batches[key]
		var mm=MultiMesh.new();mm.transform_format=MultiMesh.TRANSFORM_3D;mm.use_colors=true;mm.mesh=meshes[batch.variant];mm.instance_count=batch.transforms.size()
		var center: Vector3=batch.transforms[0].origin
		for i in mm.instance_count:
			var transform: Transform3D=batch.transforms[i];transform.origin-=center
			mm.set_instance_transform(i,transform);mm.set_instance_color(i,batch.colors[i])
		var node=MultiMeshInstance3D.new();node.name=SLUGS[batch.variant]+"_"+str(key);node.multimesh=mm;node.position=center
		node.visibility_range_end=120;node.visibility_range_end_margin=15
		layer.add_child(node);node.owner=layer
	await process_frame
	await RenderingServer.frame_post_draw
	var packed=PackedScene.new();assert(packed.pack(layer)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/world/fougeres_detaillees.tscn")==OK)
	var manifest={"sources":data.sources,"pickups":pickups,"plants":records,"rejected":rejected,"seed":31102026}
	FileAccess.open("res://assets/data/fern_replacements.json",FileAccess.WRITE).store_string(JSON.stringify(manifest,"\t"))
	print("FERNS_BAKED plants=",records.size()," batches=",batches.size()," harvest_anchors=",pickups.size()," rejected=",rejected)
	layer.free();world.free();quit()
