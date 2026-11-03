extends Node3D
var failures: Array[String] = []
var excluded: Array[RID] = []
var world: Node3D
var player: CharacterBody3D

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func hit(x: float, z: float, terrain_only := true, top := 150.0) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x,top,z),Vector3(x,-12,z),1)
	q.exclude = excluded if terrain_only else [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func capture(camera: Camera3D, eye: Vector3, target: Vector3, label: String) -> void:
	camera.global_position=eye
	camera.look_at(target)
	for i in range(15): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/castle_west_"+label+".png")

func walk_to(target: Vector2, limit := 1600) -> bool:
	for i in range(limit):
		await get_tree().physics_frame
		var delta := target - Vector2(player.global_position.x, player.global_position.z)
		if delta.length()<.45: return true
		var dir := delta.normalized()
		player.velocity=Vector3(dir.x*6, player.velocity.y-20.0/60.0, dir.y*6)
		player.move_and_slide()
	return false

func _ready() -> void:
	world=load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(30): await get_tree().physics_frame
	world.get_node("Original/HUD").hide()
	player=world.get_node("Original/Player")
	player.set_physics_process(false)
	for node in world.find_children("*","CollisionObject3D",true,false):
		if not "/Terrain" in str(node.get_path()): excluded.append(node.get_rid())
	var west=world.get_node("Sectors/WesternPlains")
	check(west.get_child_count()==19,"18 western tiles and castle loaded")
	check(west.get_node("ChateauDesPlaines").get_child_count()>=4,"Castle meshes imported")
	var holes := 0
	var points := 0
	for x in range(-286,-95,4):
		for z in range(-166,216,4):
			points+=1
			if hit(x,z).is_empty(): holes+=1
	check(holes==0,"Western terrain coverage: %d points, %d holes" % [points,holes])
	var seams := 0
	var pairs := 0
	var maximum_seam := 0.0
	for x in [-224.0,-160.0,-96.0]:
		for z in range(-166,216,2):
			var a=hit(x-.02,z); var b=hit(x+.02,z); pairs+=1
			if a.is_empty() or b.is_empty(): seams+=1
			else:
				var gap=absf(a.position.y-b.position.y); maximum_seam=maxf(maximum_seam,gap)
				if gap>.25: seams+=1
	for z in [-104.0,-40.0,24.0,88.0,152.0]:
		for x in range(-286,-95,2):
			var a=hit(x,z-.02); var b=hit(x,z+.02); pairs+=1
			if a.is_empty() or b.is_empty(): seams+=1
			else:
				var gap=absf(a.position.y-b.position.y); maximum_seam=maxf(maximum_seam,gap)
				if gap>.25: seams+=1
	check(seams==0,"Terrain seams: %d pairs, %d errors" % [pairs,seams])
	check(player.world_bounds.has_point(Vector2(-280,160)),"Player bounds include western extension")
	check(world.has_node("GrotteEntree") and world.has_node("Vigie") and world.has_node("Sectors/Ocean"),"Cave, watchtower and ocean retained")
	var bridge_bad := 0
	for i in range(57):
		var p=hit(-203.5+i*.5,-8.092,false,13.0)
		if p.is_empty() or p.position.y<11.4: bridge_bad+=1
	check(bridge_bad==0,"Bridge and threshold: 57 support samples, %d failures" % bridge_bad)
	var start=hit(-92,-8)
	var walked := false
	if not start.is_empty():
		player.global_position=start.position+Vector3.UP*.2; player.velocity=Vector3.ZERO
		walked=true
		for target in [Vector2(-98,-8),Vector2(-115,-15),Vector2(-138,-18),Vector2(-156,-13),Vector2(-174,-8.092),Vector2(-200,-8.092),Vector2(-208,-8.092)]:
			if not await walk_to(target):
				walked=false
				print("BLOCKED_ROUTE ",target," position ",player.global_position)
				break
	check(walked,"Character crosses old border, plains, bridge and castle gate")
	var report={"failures":failures,"coverage_points":points,"holes":holes,"seam_pairs":pairs,"seam_errors":seams,"maximum_seam_height_difference":maximum_seam,"bridge_errors":bridge_bad,"route_walked":walked,"final_player_position":str(player.global_position)}
	FileAccess.open("res://tests/castle_west_validation_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var camera=Camera3D.new();add_child(camera);camera.far=4000;camera.fov=52;camera.current=true
	var environment=world.get_node("Original/WorldEnvironment").environment
	var fog=environment.fog_enabled
	environment.fog_enabled=false
	await capture(camera,Vector3(-330,295,365),Vector3(-25,8,-10),"overview")
	await capture(camera,Vector3(-125,42,52),Vector3(-226,27,-32),"plains")
	await capture(camera,Vector3(-169,22,4),Vector3(-219,25,-16),"bridge")
	environment.fog_enabled=fog
	await capture(camera,Vector3(-133,18,-11),Vector3(-221,26,-27),"atmosphere")
	print("CASTLE_WEST_VALIDATION ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
