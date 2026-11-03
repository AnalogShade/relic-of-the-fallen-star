extends SceneTree
var failures: Array[String] = []
var world: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func local_point(p: Vector3) -> Vector3:
	var q := p - Vector3(2,4,0)
	return Basis(Vector3.UP, PI/2.0-.35) * Vector3(q.x,q.z,-q.y) + Vector3(-226,12,-32)

func capture(cam: Camera3D, eye: Vector3, target: Vector3, filename: String) -> void:
	cam.global_position = eye; cam.look_at(target)
	for i in range(20): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://tests/"+filename+".png")

func run() -> void:
	world = (load("res://scenes/world/open_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for i in range(40): await physics_frame
	var group := world.get_node("SapinsChateau")
	var exterior := 0; var interior := 0
	for child in group.get_children():
		if str(child.name).begins_with("SapinExterieur"): exterior += 1
		else: interior += 1
	check(interior == 10,"9 castle replacements and approved exemplar loaded")
	check(exterior >= 12,"Exterior planting loaded: %d trees" % exterior)
	var before := group.get_child_count()
	preload("res://scripts/pine_foliage.gd").apply(world)
	check(world.get_node("SapinsChateau").get_child_count()==before,"Repeated world configuration creates no duplicate pines")
	var castle := world.get_node("Sectors/WesternPlains/ChateauDesPlaines/CastlePreserved") as MeshInstance3D
	var old_surfaces := 0
	for i in castle.mesh.get_surface_count():
		var m := castle.mesh.surface_get_material(i)
		if m != null and m.resource_name in ["Mat_Tronc","Mat_Feuilles_Vert","Mat_Feuilles_Fonce"]: old_surfaces += 1
	check(old_surfaces == 0,"Old castle trunks and foliage removed")
	var scattered := 0
	for child in world.get_node("VegetationFirstPass/ArbresPlaines").get_children():
		if not str(child.name).begins_with("sapin_elance"): continue
		scattered += 1
		check(child.get_node("Visual").scene_file_path.ends_with("sapin_alpha.glb"),"New model for " + str(child.name))
	check(scattered == 8,"All 8 scattered healthy firs replaced")
	var alpha_ok := true
	for tree in group.get_children():
		for mesh: MeshInstance3D in tree.find_children("*","MeshInstance3D",true,false):
			for i in mesh.mesh.get_surface_count():
				var m := mesh.get_active_material(i) as StandardMaterial3D
				if m != null and "Aiguilles" in m.resource_name:
					alpha_ok = alpha_ok and m.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and m.cull_mode==BaseMaterial3D.CULL_DISABLED
	check(alpha_ok,"Alpha cutout and double-sided foliage materials")
	var player := world.get_node("Original/Player") as CharacterBody3D
	player.set_physics_process(false)
	var space := world.get_world_3d().direct_space_state
	var ground_errors := 0
	for tree: Node3D in group.get_children():
		if not str(tree.name).begins_with("SapinExterieur"): continue
		var p := tree.global_position
		var excluded: Array[RID] = [player.get_rid()]
		for body: CollisionObject3D in tree.find_children("*","CollisionObject3D",true,false): excluded.append(body.get_rid())
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*10,p-Vector3.UP*2,1,excluded))
		if hit.is_empty() or absf(hit.position.y-p.y-.04)>.06: ground_errors += 1
	check(ground_errors==0,"All exterior trunks grounded on terrain")
	var bridge_errors := 0
	for i in range(57):
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-203.5+i*.5,13,-8.092),Vector3(-203.5+i*.5,9,-8.092),1,[player.get_rid()]))
		if hit.is_empty() or hit.position.y < 11.4: bridge_errors += 1
	check(bridge_errors==0,"Bridge and gate support retained: 57 samples")
	if DisplayServer.get_name() != "headless":
		for ui in world.find_children("*","CanvasLayer",true,false): ui.hide()
		for ui in root.find_children("*","Control",true,false): ui.hide()
		var cam := Camera3D.new(); root.add_child(cam);cam.current=true;cam.far=2000;cam.fov=55
		await capture(cam,local_point(Vector3(-27,35,11)),local_point(Vector3(-12,25,3)),"sapins_alpha_chateau")
		await capture(cam,Vector3(-157,16,-43),Vector3(-176,14,-58),"sapins_alpha_exterieur")
		cam.queue_free()
	var report := {"failures":failures,"castle_pines":interior,"scattered_pines":scattered,"exterior_pines":exterior,"ground_errors":ground_errors,"bridge_errors":bridge_errors}
	FileAccess.open("res://tests/sapins_alpha_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("PINE_VALIDATION ",JSON.stringify(report))
	world.queue_free();await process_frame;await process_frame
	quit(0 if failures.is_empty() else 1)
