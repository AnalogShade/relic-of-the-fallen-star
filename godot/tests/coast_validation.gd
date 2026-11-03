extends Node3D
var failures: Array[String] = []
var excluded: Array[RID] = []
var world: Node3D

func hit(x: float, z: float) -> Dictionary:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x,150,z),Vector3(x,-12,z),1,excluded))

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ")+message)
	if not ok: failures.append(message)

func capture(camera: Camera3D, eye: Vector3, target: Vector3, label: String) -> void:
	camera.global_position=eye
	camera.look_at(target)
	for i in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/coast_"+label+".png")

func _ready() -> void:
	world=load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(30): await get_tree().physics_frame
	world.get_node("Original/HUD").hide()
	var player=world.get_node("Original/Player")
	player.set_physics_process(false)
	for node in world.find_children("*","CollisionObject3D",true,false):
		if not "/Terrain" in str(node.get_path()): excluded.append(node.get_rid())
	var tiles=0
	for node in world.get_node("Sectors").get_children():
		if str(node.name).begins_with("Tile_"): tiles+=1
	check(tiles==29,"30 tiles including original")
	var holes=0
	var points=0
	for x in range(-94,224,4):
		for z in range(90,216,4):
			points+=1
			if hit(x,z).is_empty(): holes+=1
	check(holes==0,"Coast collision coverage: %d samples, %d holes" % [points,holes])
	var seams=0
	var pairs=0
	for z in [88.0,152.0]:
		for x in range(-94,224,2):
			var a=hit(x,z-.02);var b=hit(x,z+.02);pairs+=1
			if a.is_empty() or b.is_empty() or absf(a.position.y-b.position.y)>.2: seams+=1
	for x in [-32.0,32.0,96.0,160.0]:
		for z in range(90,216,2):
			var a=hit(x-.02,z);var b=hit(x+.02,z);pairs+=1
			if a.is_empty() or b.is_empty() or absf(a.position.y-b.position.y)>.2: seams+=1
	check(seams==0,"Coast seams: %d pairs, %d failures" % [pairs,seams])
	var river_bad=0
	for z in range(88,173):
		var t=clampf((z-88.0)/12.0,0,1)
		var x=.1474023+6*sin((z-88)*.045)*t*t*(3-2*t)
		var h=hit(x,z)
		if h.is_empty() or h.position.y>0: river_bad+=1
	check(river_bad==0,"River bed continuously below sea level to mouth")
	check(player.world_bounds.has_point(Vector2(200,212)),"New rows inside playable bounds")
	var start=hit(40,85)
	if not start.is_empty():
		player.global_position=start.position+Vector3.UP*.2
		player.velocity=Vector3.ZERO
		for i in range(720):
			await get_tree().physics_frame
			player.velocity=Vector3(0,player.velocity.y-20.0/60.0,5)
			player.move_and_slide()
			if player.global_position.z>140: break
		check(player.global_position.z>140 and player.is_on_floor(),"Character walks from forest across old edge onto beach")
	var report={"failures":failures,"coverage_points":points,"holes":holes,"seam_pairs":pairs,"seam_errors":seams,"river_bed_errors":river_bad}
	FileAccess.open("res://tests/coast_validation_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	var camera=Camera3D.new();add_child(camera);camera.far=4000;camera.fov=45;camera.current=true
	var environment=world.get_node("Original/WorldEnvironment").environment
	environment.fog_enabled=false
	await capture(camera,Vector3(335,335,445),Vector3(60,4,12),"overview")
	camera.fov=62
	await capture(camera,Vector3(57,20,105),Vector3(15,0,164),"beach")
	await capture(camera,Vector3(-29,35,128),Vector3(3,0,135),"estuary")
	print("COAST_VALIDATION ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
