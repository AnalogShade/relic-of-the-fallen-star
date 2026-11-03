extends Node3D
var failures: Array[String] = []
var excluded: Array[RID] = []
var world: Node3D

func hit(x: float, z: float) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,150,z),Vector3(x,-6,z),1,excluded))

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)

func capture(camera: Camera3D, eye: Vector3, target: Vector3, label: String) -> void:
	camera.global_position=eye
	camera.look_at(target)
	for i in range(8): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/desert_"+label+".png")

func _ready() -> void:
	world=load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(30): await get_tree().physics_frame
	world.get_node("Original/HUD").hide()
	var player=world.get_node("Original/Player")
	player.set_physics_process(false)
	for node in world.find_children("*","CollisionObject3D",true,false):
		if not "/Terrain" in str(node.get_path()): excluded.append(node.get_rid())
	check(world.get_node("Sectors").find_children("Tile_*", "Node3D", false, false).size()==29,"30 tiles assembled including original")
	var holes=0
	var points=0
	var highest=0.0
	for x in range(-94,224,4):
		for z in range(-166,88,4):
			if x<96 and z> -104: continue
			points+=1
			var h=hit(x,z)
			if h.is_empty(): holes+=1
			else: highest=maxf(highest,h.position.y)
	check(holes==0,"New terrain collision coverage: %d points, %d holes" % [points,holes])
	var seams=0
	var pairs=0
	for x in [-32.0,32.0,96.0,160.0]:
		for z in range(-166,88,2):
			if x<96 and z> -104: continue
			var a=hit(x-.02,z);var b=hit(x+.02,z);pairs+=1
			if a.is_empty() or b.is_empty() or absf(a.position.y-b.position.y)>.2: seams+=1
	for z in [-104.0,-40.0,24.0]:
		for x in range(-94,224,2):
			if z> -104 and x<96: continue
			var a=hit(x,z-.02);var b=hit(x,z+.02);pairs+=1
			if a.is_empty() or b.is_empty() or absf(a.position.y-b.position.y)>.2: seams+=1
	check(seams==0,"Tile seams: %d pairs, %d failures" % [pairs,seams])
	var paths=[ [Vector2(96,-58),Vector2(111,-64),Vector2(128,-77),Vector2(145,-81),Vector2(162,-72),Vector2(184,-62),Vector2(217,-66)], [Vector2(22,-104),Vector2(22,-112),Vector2(30,-128),Vector2(48,-143),Vector2(74,-148),Vector2(103,-145),Vector2(132,-139),Vector2(164,-133),Vector2(211,-132)] ]
	var max_slope=0.0
	var missing=0
	for path in paths:
		for i in range(path.size()-1):
			var count=int(ceil(path[i].distance_to(path[i+1])))
			for k in range(count):
				var p=path[i].lerp(path[i+1],float(k)/count)
				var q=path[i].lerp(path[i+1],float(k+1)/count)
				var a=hit(p.x,p.y);var b=hit(q.x,q.y)
				if a.is_empty() or b.is_empty():missing+=1
				else:max_slope=maxf(max_slope,absf(a.position.y-b.position.y)/p.distance_to(q))
	check(missing==0 and max_slope<.8,"Mountain routes: %d missing points; maximum grade %.3f" % [missing,max_slope])
	check(player.world_bounds.has_point(Vector2(217,-132)),"Desert inside playable bounds")
	# Exercise CharacterBody3D on the real imported collision across the old edge.
	var start=hit(93,-58)
	if not start.is_empty():
		player.global_position=start.position+Vector3.UP*.2
		player.velocity=Vector3.ZERO
		var destination=Vector3(109,0,-63)
		for i in range(280):
			await get_tree().physics_frame
			var direction=Vector3(destination.x-player.global_position.x,0,destination.z-player.global_position.z)
			if direction.length()<.5: break
			direction=direction.normalized()
			player.velocity=Vector3(direction.x*5,player.velocity.y-20.0/60.0,direction.z*5)
			player.move_and_slide()
		check(player.global_position.x>107 and player.is_on_floor(),"Character walks across old boundary into mountain pass")
	var report={"failures":failures,"coverage_points":points,"holes":holes,"seam_pairs":pairs,"seam_errors":seams,"route_max_grade":max_slope,"max_height":highest}
	FileAccess.open("res://tests/desert_validation_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var camera=Camera3D.new();add_child(camera);camera.far=1200;camera.fov=32;camera.current=true
	var environment=world.get_node("Original/WorldEnvironment").environment
	var fog=environment.fog_enabled
	environment.fog_enabled=false
	await capture(camera,Vector3(340,290,340),Vector3(58,5,-39),"overview")
	environment.fog_enabled=fog
	camera.fov=65
	await capture(camera,Vector3(99,24,-58),Vector3(146,23,-80),"mountain_pass")
	await capture(camera,Vector3(158,25,-77),Vector3(208,8,-62),"dunes")
	print("DESERT_VALIDATION ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
