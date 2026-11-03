extends SceneTree
## Bake editable, terrain-grounded rosettes near woodland features.
const OUT := "res://scenes/world/rosettes_forestieres.tscn"
const TRAILS = preload("res://scripts/forest_trails.gd")
var world: Node3D
var rng := RandomNumberGenerator.new()
var non_terrain: Array[RID] = []
var terrain: Array[RID] = []
var anchors: Array[Dictionary] = []
var trees: Array[Vector3] = []
var placed: Array[Vector3] = []
var records: Array = []
var mesh: Mesh
var layer := Node3D.new()
func _initialize() -> void: call_deferred("bake")
func ground(p: Vector2) -> Dictionary:
	var q=PhysicsRayQueryParameters3D.create(Vector3(p.x,150,p.y),Vector3(p.x,-10,p.y),1)
	q.exclude=non_terrain
	return world.get_world_3d().direct_space_state.intersect_ray(q)
func zone(p: Vector3) -> String:
	if p.z < -90: return "ForetsDuNord"
	if p.x < -95 and p.z < 18:return "ForetCoteChateau"
	if p.x < -95:return "BoisOccidentaux"
	return "ForetCentraleEtEst"
func add_tree(p: Vector3, radius: float, path: String) -> void:
	for t in trees:
		if Vector2(t.x,t.z).distance_to(Vector2(p.x,p.z))<3.0:return
	var hit=ground(Vector2(p.x,p.z))
	if hit.is_empty() or absf(hit.position.y-p.y)>3.2:return
	trees.append(hit.position)
	anchors.append({"point":hit.position,"radius":clampf(radius,0.5,2.3),"kind":"arbre","source":path})
func try_place(anchor: Dictionary, target_zone: String) -> bool:
	var point: Vector3=anchor.point
	var angle=rng.randf_range(0,TAU)
	var offset=Vector2.from_angle(angle)*(float(anchor.radius)+rng.randf_range(0.9,3.8))
	var p=Vector2(point.x,point.z)+offset
	if TRAILS.distance_to_path(p)<2.1:return false
	var hit=ground(p)
	if hit.is_empty() or hit.normal.y<0.88 or hit.position.y<0.7:return false
	var pos: Vector3=hit.position
	if zone(pos)!=target_zone:return false
	if p.distance_to(Vector2(-226,-32))<31:return false
	for prev in placed:
		if Vector2(prev.x,prev.z).distance_to(p)<2.4:return false
	var tree_distance=INF
	for tree in trees:tree_distance=minf(tree_distance,p.distance_to(Vector2(tree.x,tree.z)))
	if tree_distance>13:return false
	var size=rng.randf_range(0.8,1.85)
	var height=size if rng.randf()<0.45 else size*rng.randf_range(0.65,1.65)
	# Check both roots and the occupied foliage volume against static scenery.
	var sphere=SphereShape3D.new()
	sphere.radius=0.5*size
	var query=PhysicsShapeQueryParameters3D.new()
	query.shape=sphere
	query.transform.origin=pos+Vector3.UP*(sphere.radius+0.12)
	query.exclude=terrain
	query.collision_mask=1
	if not world.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():return false
	# Keep roots flush across gentle slopes, without tilting the stem away from vertical.
	for step in [Vector2(0.35,0),Vector2(-0.35,0),Vector2(0,0.35),Vector2(0,-0.35)]:
		var sample=ground(p+step*size)
		if sample.is_empty() or absf(sample.position.y-pos.y)>0.28:return false
	var plant=MeshInstance3D.new()
	plant.name="Rosette_%03d"%(records.size()+1)
	plant.mesh=mesh
	plant.position=pos-Vector3.UP*0.025
	plant.rotation.y=rng.randf_range(0,TAU)
	plant.scale=Vector3(size,height,size)
	var material=mesh.surface_get_material(0).duplicate() as StandardMaterial3D
	var tone=rng.randf_range(0.82,1.05)
	material.albedo_color=material.albedo_color*Color(tone*rng.randf_range(0.92,1.03),tone,tone*rng.randf_range(0.86,1.03),1)
	material.normal_enabled=false
	material.normal_texture=null
	material.resource_local_to_scene=true
	plant.material_override=material
	plant.visibility_range_end=140
	plant.visibility_range_end_margin=15
	plant.set_meta("proximite",anchor.kind)
	plant.set_meta("repere",anchor.source)
	var group=layer.get_node_or_null(target_zone)
	if group==null:
		group=Node3D.new();group.name=target_zone;layer.add_child(group);group.owner=layer
	group.add_child(plant);plant.owner=layer
	placed.append(pos)
	records.append({"node":str(layer.get_path_to(plant)),"position":[pos.x,pos.y,pos.z],"scale":[size,height,size],"tint":str(material.albedo_color),"anchor":anchor.source,"kind":anchor.kind,"tree_distance":tree_distance,"trail_distance":TRAILS.distance_to_path(p),"normal_y":hit.normal.y})
	return true
func bake() -> void:
	# Reading existing MultiMesh rock transforms requires an active renderer.
	if DisplayServer.get_name() == "headless":
		push_error("Run with --rendering-method gl_compatibility, without --headless.")
		quit(1)
		return
	rng.seed=31102026
	world=load("res://scenes/world/open_world.tscn").instantiate()
	var old=world.get_node_or_null("RosettesForestieres")
	if old:old.free()
	root.add_child(world)
	for i in 15:await physics_frame
	for body in world.find_children("*","CollisionObject3D",true,false):
		if "/Terrain" in str(body.get_path()) or "/CastleGround" in str(body.get_path()):terrain.append(body.get_rid())
		else:non_terrain.append(body.get_rid())
	# Actual visible trunk bases, including the many trees baked into sector meshes.
	for source in world.find_children("*","MeshInstance3D",true,false):
		if not source.is_visible_in_tree() or source.mesh==null:continue
		var name_text=str(source.name).to_lower()
		if not (name_text=="wood" or "tronc" in name_text and not "couche" in name_text):continue
		if "SapinsChateau/SapinInterieur" in str(source.get_path()):continue
		var cells: Dictionary={}
		for s in source.mesh.get_surface_count():
			var vertices: PackedVector3Array=source.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
			for i in range(0,vertices.size(),3):
				var p: Vector3=source.global_transform*vertices[i]
				var cell=Vector2i(roundi(p.x/2),roundi(p.z/2))
				if not cells.has(cell) or p.y<cells[cell].y:cells[cell]=p
		for p in cells.values():add_tree(p,0.7,str(world.get_path_to(source)))
	# Additional collision-defined woodland trunks.
	for source in world.find_children("*","CollisionShape3D",true,false):
		if not source.shape is CapsuleShape3D or not source.get_parent() is StaticBody3D:continue
		var path=str(world.get_path_to(source))
		if not ("Tronc" in path or "ArbresMacabres" in path) or "SapinsChateau/SapinInterieur" in path:continue
		var p=source.global_position-Vector3.UP*source.shape.height*source.global_basis.get_scale().y*0.5
		add_tree(p,source.shape.radius*source.global_basis.get_scale().x,path)
	# Rock outskirts are eligible only within woodland, not open fields.
	var rocks=world.get_node_or_null("RochesBlender")
	if rocks:
		for batch in rocks.find_children("*","MultiMeshInstance3D",true,false):
			if not batch.is_visible_in_tree() or batch.multimesh==null:continue
			for i in batch.multimesh.instance_count:
				var tr: Transform3D=batch.global_transform*batch.multimesh.get_instance_transform(i)
				var box: AABB=tr*batch.multimesh.mesh.get_aabb()
				var p=box.get_center();p.y=box.position.y
				var close=false
				for tree in trees:
					if Vector2(tree.x,tree.z).distance_to(Vector2(p.x,p.z))<11:close=true;break
				if close:anchors.append({"point":p,"radius":maxf(box.size.x,box.size.z)*0.5,"kind":"roche","source":str(world.get_path_to(batch))+"/"+str(i)})
	var art=load("res://assets/environment/vegetation/rosette_ronde.glb").instantiate()
	mesh=art.find_children("*","MeshInstance3D",true,false)[0].mesh
	art.free()
	layer.name="RosettesForestieres"
	var counts: Dictionary={}
	for region in ["ForetCentraleEtEst","ForetCoteChateau","BoisOccidentaux","ForetsDuNord"]:
		var pool: Array[Dictionary]=[]
		for anchor in anchors:
			if zone(anchor.point)==region:pool.append(anchor)
		print("POOL ",region," ",pool.size())
		var rock_pool: Array[Dictionary]=[]
		for anchor in pool:
			if anchor.kind=="roche":rock_pool.append(anchor)
		print("ROCK_POOL ",region," ",rock_pool.size())
		var count=0
		for attempt in 4500:
			if count>=25 or pool.is_empty():break
			var candidates=rock_pool if count<8 and not rock_pool.is_empty() and attempt<2200 else pool
			if try_place(candidates[rng.randi_range(0,candidates.size()-1)],region):count+=1
		counts[region]=count
	assert(records.size()==100,"Could not place 100 safely: "+str(counts))
	var packed=PackedScene.new()
	assert(packed.pack(layer)==OK)
	assert(ResourceSaver.save(packed,OUT)==OK)
	FileAccess.open("res://../diagnostics/rosette_scatter_20261031/placement.json",FileAccess.WRITE).store_string(JSON.stringify({"seed":31102026,"trees":trees.size(),"anchors":anchors.size(),"counts":counts,"plants":records},"\t"))
	print("ROSETTES_BAKED ",counts," trees=",trees.size())
	layer.free();world.free();quit()
