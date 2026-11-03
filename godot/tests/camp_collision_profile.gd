extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in range(8): await physics_frame
	var player: CharacterBody3D = world.get_node("Original/Player")
	player.set_physics_process(false)
	var camp: Node3D = world.get_node("Sectors/CampBandits")
	var triangles := 0
	var types := {}
	for c in camp.find_children("*", "CollisionShape3D", true, false):
		var kind: String = c.shape.get_class()
		types[kind] = types.get(kind,0)+1
		if c.shape is ConcavePolygonShape3D: triangles += c.shape.get_faces().size()/3
	var samples := []
	for name in ["Camp_Banc_Bois_01", "Camp_Banc_Bois_03", "Camp_Banniere_Socle_Rocheux"]:
		var prop: MeshInstance3D = camp.get_node(name)
		var start: Vector3 = prop.global_position + Vector3(-2.0,.65,0)
		var times: Array[int] = []
		var contacts := 0
		for i in range(600):
			var transform := Transform3D(Basis.IDENTITY,start)
			var begin := Time.get_ticks_usec()
			var touched := player.test_move(transform,Vector3(2.5,0,0))
			times.append(Time.get_ticks_usec()-begin)
			if touched: contacts+=1
		times.sort()
		samples.append({"name":name,"median_us":times[300],"p95_us":times[570],"max_us":times[-1],"contacts":contacts})
	var report := {"collision_triangles":triangles,"shape_types":types,"samples":samples}
	var suffix := "before" if triangles>100 else "after"
	FileAccess.open("res://tests/camp_collision_"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print(JSON.stringify(report))
	world.queue_free()
	for i in range(3): await process_frame
	quit()
