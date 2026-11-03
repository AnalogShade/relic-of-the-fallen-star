extends SceneTree
## One-time authoring tool: bakes individually editable props onto terrain collision.
const OUT := "res://assets/props/camp_bandits/"
var world: Node3D
var camp: Node3D
var excluded: Array[RID] = []
var placements: Array = []

func _initialize() -> void:
	call_deferred("build")

func hit(x: float, z: float) -> Dictionary:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80, z), Vector3(x, -5, z), 1, excluded))

func height(x: float, z: float) -> float:
	var h := hit(x,z)
	assert(not h.is_empty(), "Missing ground under camp")
	return h.position.y

func own(n: Node) -> void:
	n.owner = camp
	for c in n.get_children(): own(c)

func settle(o: Node3D, x: float, z: float, yaw: float, size: float, span: float) -> void:
	var dx := (height(x+span,z)-height(x-span,z))/(2*span)
	var dz := (height(x,z+span)-height(x,z-span))/(2*span)
	var up := Vector3(-dx,1,-dz).normalized()
	var forward := Vector3(sin(yaw),0,cos(yaw))
	var right := up.cross(forward).normalized()
	var basis := Basis(right,up,right.cross(up)).scaled(Vector3.ONE*size)
	o.transform = Transform3D(basis,Vector3(x,height(x,z)-.025,z))
	placements.append({"name":o.name,"position":[x,o.position.y,z],"slope_degrees":rad_to_deg(up.angle_to(Vector3.UP))})

func build() -> void:
	world = Node3D.new()
	root.add_child(world)
	var terrain: Node3D = load("res://assets/environment/world/tile_02_vallee_des_sources.glb").instantiate()
	world.add_child(terrain)
	for b in terrain.find_children("*","CollisionObject3D",true,false):
		if not "Terrain" in str(b.get_path()): excluded.append(b.get_rid())
	await physics_frame
	await physics_frame
	camp = Node3D.new()
	camp.name = "CampBandits"
	world.add_child(camp)
	var source: Node3D = load(OUT+"camp_bandits_optimise.glb").instantiate()
	var layout := {
		"Feu_Camp_Rotissoire":[22.0,-59.0,0.2,6.0],
		"Banc_Bois_01":[19.2,-59.0,0.12,6.0],
		"Banc_Bois_02":[24.9,-58.9,-0.15,6.0],
		"Banc_Bois_03":[22.0,-56.7,0.12,6.0],
		"Banniere_Socle_Rocheux":[18.5,-55.0,-0.4,4.0],
		"Caisse_Tonneau_Provisions":[25.8,-63.8,-0.25,5.0],
		"Caisse_Chope":[25.4,-61.8,0.7,6.0],
		"Caisse_Rochers":[24.8,-63.0,0.3,5.0],
		"Billot_Hache_Rochers":[26.3,-55.9,-0.35,5.0],
		"Buches_Empilees":[26.7,-57.2,0.6,5.0],
		"Buche_Debout":[25.4,-55.7,0.2,5.0],
		"Torche_Sur_Piquet":[18.5,-57.0,0.0,6.0],
		"Sac_Provisions":[25.3,-64.7,0.4,5.0],
		"Accessoire_Provisions":[26.8,-64.0,0.2,5.0],
		"Rochers_01":[27.0,-61.1,0.0,4.0],
		"Rocher_02":[26.8,-62.0,0.0,4.0]
	}
	var i := 0
	for src in source.find_children("*","MeshInstance3D",true,false):
		var key := str(src.name).trim_prefix("Camp_")
		if key == "Massif_Rocheux": continue
		var values: Array
		if layout.has(key): values = layout[key]
		else:
			var angle := i*2.399
			values=[22.0+cos(angle)*5.2,-60.0+sin(angle)*6.4,angle,3.2]
			i+=1
		var o := MeshInstance3D.new()
		o.name=src.name
		o.mesh=src.mesh
		camp.add_child(o)
		settle(o,values[0],values[1],values[2],values[3],.65)
		if layout.has(key):
			preload("res://tests/camp_collision_shapes.gd").create(o)
			for body in o.find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
		own(o)
	var tent: Node3D = load(OUT+"tente_bandits.glb").instantiate()
	# Bake a local editable copy. Keeping the GLB instance link while assigning
	# its children to camp would serialize the same tent nodes twice.
	tent.scene_file_path = ""
	tent.name="Tente_Toile_Rapiecee"
	camp.add_child(tent)
	settle(tent,20.8,-64.0,.22,1.0,1.6)
	for m in tent.find_children("*","MeshInstance3D",true,false):
		if str(m.name).begins_with("Toile") or str(m.name).begins_with("Fond") or str(m.name).begins_with("Entree"):
			m.create_trimesh_collision()
			for body in m.find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
	own(tent)
	var fire := Node3D.new()
	fire.name="Flammes_Animees"
	fire.set_script(load("res://scripts/cozy_fire.gd"))
	camp.add_child(fire)
	fire.position=Vector3(22,height(22,-59)+.26,-59)
	fire.scale=Vector3(1.25,.85,1.25)
	fire.owner=camp
	var marker := Marker3D.new()
	marker.name="Acces_Depuis_Sentier"
	camp.add_child(marker)
	marker.position=Vector3(17,height(17,-56),-56)
	marker.owner=camp
	var packed := PackedScene.new()
	assert(packed.pack(camp)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/world/camp_bandits.tscn")==OK)
	var file := FileAccess.open("res://tests/camp_placements.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(placements,"\t"))
	print("CAMP_BAKED ",placements.size()," individually placed objects")
	source.free()
	world.queue_free()
	await process_frame
	quit()
