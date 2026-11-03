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
	for i in range(12): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/oasis_"+label+".png")

func walk_to(target: Vector2, limit := 1000) -> bool:
	for i in range(limit):
		await get_tree().physics_frame
		var delta := target - Vector2(player.global_position.x, player.global_position.z)
		if delta.length()<.3: return true
		var dir := delta.normalized()
		player.velocity=Vector3(dir.x*6, player.velocity.y-20.0/60.0, dir.y*6)
		player.move_and_slide()
	return false

func press_f() -> void:
	Input.action_press("interact")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("interact")
	for i in range(3):await get_tree().physics_frame

func _ready() -> void:
	world=load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(30): await get_tree().physics_frame
	world.get_node("Original/HUD").hide()
	player=world.get_node("Original/Player")
	player.set_physics_process(false)
	for node in world.find_children("*","CollisionObject3D",true,false):
		if not "/Terrain" in str(node.get_path()): excluded.append(node.get_rid())
	var oasis=world.get_node("Sectors/OasisDuNord")
	check(oasis.find_children("Terrain*","MeshInstance3D",true,false).size()==16,"Sixteen northern terrain tiles imported")
	check(oasis.find_children("Water_Oasis*","MeshInstance3D",true,false).size()==3,"Reservoir, outlet and spring imported")
	var holes := 0
	var points := 0
	for x in range(-286,224,4):
		for z in range(-294,-168,4):
			points+=1
			if hit(x,z).is_empty(): holes+=1
	check(holes==0,"Terrain coverage: %d rays, %d holes" % [points,holes])
	var seams := 0
	var pairs := 0
	var maximum_seam := 0.0
	for z in [-168.0,-232.0]:
		for x in range(-286,224,2):
			var a=hit(x,z-.02);var b=hit(x,z+.02);pairs+=1
			if a.is_empty() or b.is_empty():seams+=1
			else:
				var gap=absf(a.position.y-b.position.y);maximum_seam=maxf(maximum_seam,gap)
				if gap>.25:seams+=1
	for x in [-224.0,-160.0,-96.0,-32.0,32.0,96.0,160.0]:
		for z in range(-294,-168,2):
			var a=hit(x-.02,z);var b=hit(x+.02,z);pairs+=1
			if a.is_empty() or b.is_empty():seams+=1
			else:
				var gap=absf(a.position.y-b.position.y);maximum_seam=maxf(maximum_seam,gap)
				if gap>.25:seams+=1
	check(seams==0,"Terrain seams: %d pairs, %d failures" % [pairs,seams])
	check(player.world_bounds.has_point(Vector2(0,-290)),"Player bounds include northern extension")
	var pier_bad := 0
	for i in range(33):
		var support=hit(18+i*.5,-213,false,7.0)
		if support.is_empty() or support.position.y<6.2:
			pier_bad+=1
			print("PIER_SUPPORT_FAILURE ",18+i*.5," ",support)
	check(pier_bad==0,"Pier collision supports all 33 samples")
	var lakebed=hit(7,-213)
	check(not lakebed.is_empty() and lakebed.position.y<5.5,"Reservoir water above basin floor")
	var start=hit(22,-112)
	var walked := not start.is_empty()
	if walked:
		player.global_position=start.position+Vector3.UP*.15;player.velocity=Vector3.ZERO
		for target in [Vector2(30,-128),Vector2(34,-158),Vector2(37,-184),Vector2(36,-213),Vector2(18,-213)]:
			if not await walk_to(target):
				walked=false
				print("BLOCKED_ROUTE ",target," at ",player.global_position)
				break
	check(walked,"Character walks from mountain pass across border onto pier")
	# Fishing uses actual input, the existing inventory and the imported water geometry.
	if not walked:player.global_position=Vector3(18,6.6,-213)
	player.velocity=Vector3.ZERO
	player.set_physics_process(true)
	for i in range(25):await get_tree().physics_frame
	var bag=get_node("/root/Inventory")
	bag.add_item("fishing_rod");bag.toggle_equipment("fishing_rod")
	var fishing=world.get_node("StreamFishing")
	check(fishing.can_interact(),"Fishing available from pier with rod equipped")
	await press_f()
	check(fishing.state=="waiting","F casts into oasis")
	if fishing.state=="waiting":
		fishing.remaining=.01
		for i in range(3):await get_tree().physics_frame
		check(fishing.state=="bite","Oasis bite window starts")
		await press_f()
		check(bag.stacks.size()>0 and bag.stacks[0].id=="trout","F lands a fish in inventory")
	check(world.has_node("GrotteEntree") and world.has_node("Vigie") and world.has_node("Sectors/WesternPlains"),"Existing landmarks retained")
	var report={"failures":failures,"coverage_points":points,"holes":holes,"seam_pairs":pairs,"seam_errors":seams,"maximum_seam":maximum_seam,"pier_errors":pier_bad,"route_walked":walked,"fishing_points":fishing.water_points.size(),"player_position":str(player.global_position)}
	FileAccess.open("res://tests/oasis_validation_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	bag.ui.hide()
	var camera=Camera3D.new();add_child(camera);camera.far=4000;camera.fov=52;camera.current=true
	var environment=world.get_node("Original/WorldEnvironment").environment
	var fog=environment.fog_enabled;environment.fog_enabled=false
	await capture(camera,Vector3(80,73,-148),Vector3(7,5,-217),"overview")
	await capture(camera,Vector3(28,11,-207),Vector3(-12,8,-227),"pier")
	await capture(camera,Vector3(6,8,-92),Vector3(6,2,-107),"spring")
	await capture(camera,Vector3(340,380,290),Vector3(-20,5,-30),"world")
	environment.fog_enabled=fog
	await capture(camera,Vector3(28,11,-207),Vector3(-12,8,-227),"atmosphere")
	print("OASIS_VALIDATION ",JSON.stringify(report))
	world.queue_free()
	for i in range(3):await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
