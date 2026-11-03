extends SceneTree
var world: Node3D
var terrain_exclude: Array[RID]=[]
var failures: Array[String]=[]

func _initialize() -> void:
	call_deferred("validate")

func check(ok: bool, text: String) -> void:
	print(("PASS " if ok else "FAIL ")+text)
	if not ok: failures.append(text)

func ground(x: float,z: float) -> Vector3:
	var h:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,80,z),Vector3(x,-5,z),1,terrain_exclude))
	return h.get("position",Vector3(x,-999,z))

func validate() -> void:
	world=load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in range(8): await physics_frame
	var camp: Node3D=world.get_node("Sectors/CampBandits")
	var player: CharacterBody3D=world.get_node("Original/Player")
	player.set_physics_process(false)
	for b in world.find_children("*","CollisionObject3D",true,false):
		if not "Terrain" in str(b.get_path()): terrain_exclude.append(b.get_rid())
	check(camp.get_child_count()==37,"Camp instanced in the main world with 35 props, fire and access marker")
	var tent: Node3D = camp.get_node("Tente_Toile_Rapiecee")
	check(tent.scene_file_path.is_empty(), "Baked tent has no duplicate imported scene instance")
	check(tent.find_children("*", "MeshInstance3D", true, false).size()==20, "Reloaded tent contains exactly 20 meshes")
	check(tent.find_children("*", "StaticBody3D", true, false).size()==5, "Reloaded tent retains its five collision bodies")
	var max_gap:=0.0
	for o in camp.get_children():
		if o.name in ["Flammes_Animees","Acces_Depuis_Sentier"]: continue
		max_gap=maxf(max_gap,absf(o.global_position.y-ground(o.global_position.x,o.global_position.z).y))
	check(max_gap<.04,"All 35 asset pivots fitted to terrain (max %.3f m)"%max_gap)
	check(camp.find_children("*","StaticBody3D",true,false).size()>=20,"Props and tent walls have static collision")
	var collision_triangles := 0
	for c in camp.find_children("*", "CollisionShape3D", true, false):
		if c.shape is ConcavePolygonShape3D:
			collision_triangles += c.shape.get_faces().size()/3
	check(collision_triangles <= 30, "Detailed collision limited to the low-poly tent walls: %d triangles" % collision_triangles)
	for prop_name in ["Camp_Banc_Bois_01", "Camp_Banc_Bois_02", "Camp_Banc_Bois_03", "Camp_Banniere_Socle_Rocheux"]:
		for c in camp.get_node(prop_name).find_children("*", "CollisionShape3D", true, false):
			check(c.shape is BoxShape3D or c.shape is CylinderShape3D, prop_name + " uses primitive collision")
	var fire=camp.get_node("Flammes_Animees")
	check(fire.get_script().resource_path=="res://scripts/cozy_fire.gd","Camp reuses the cabin flame animation")
	check(fire.tongues.size()==5 and fire.light!=null,"Five animated flames and warm point light created")
	var energy: float=fire.light.light_energy
	for i in range(15): await physics_frame
	check(absf(fire.light.light_energy-energy)>.001,"Firelight animates over time")
	var fground:=ground(22,-59)
	check(absf(fire.global_position.y-fground.y-.26)<.02,"Flames anchored inside the stone hearth")
	# Move the real player with move_and_slide through a route from trail to tent.
	var route: Array[Vector2]=[Vector2(17,-56),Vector2(17.2,-60.7),Vector2(19.3,-61.5),Vector2(21.2,-61.8),Vector2(20.8,-63.8)]
	player.global_position=ground(route[0].x,route[0].y)+Vector3.UP*.45
	for waypoint in route:
		var arrived:=false
		for i in range(300):
			await physics_frame
			var delta:=Vector3(waypoint.x-player.global_position.x,0,waypoint.y-player.global_position.z)
			if delta.length()<.22:
				arrived=true
				break
			var direction:=delta.normalized()
			player.velocity=Vector3(direction.x*2.2,player.velocity.y-20.0/60.0,direction.z*2.2)
			player.move_and_slide()
		check(arrived,"Walkable route to "+str(waypoint)+" reached "+str(player.global_position))
		if not arrived: break
	var report:=FileAccess.open("res://tests/camp_validation_report.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures":failures,"max_pivot_ground_gap":max_gap},"\t"))
	print("CAMP_VALIDATION_DONE failures=",failures.size())
	world.queue_free()
	for i in range(3): await process_frame
	quit(0 if failures.is_empty() else 1)
