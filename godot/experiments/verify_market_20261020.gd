extends SceneTree
var failures: Array[String] = []
var world: Node3D
var player: CharacterBody3D
var out := "C:/Users/Utilisateur/Documents/Dev/Jeux/Relic of the fallen star/3D MODELS/chateau/marche_20261020/"
var report := {}
func _initialize() -> void:
	call_deferred("run")
func local_point(p: Vector3) -> Vector3:
	var q := p - Vector3(2,4,0)
	q = Basis(Vector3.UP, PI/2.0-.35) * Vector3(q.x,q.z,-q.y)
	return q + Vector3(-226,12,-32)
func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)
func walk_to(target: Vector3) -> bool:
	for i in range(1100):
		await physics_frame
		var delta := Vector2(target.x-player.global_position.x,target.z-player.global_position.z)
		if delta.length() < .14:
			print("WAYPOINT ",player.global_position)
			return true
		var dir := delta.normalized()
		var speed := minf(3.0, delta.length()*15.0)
		player.velocity.x = dir.x * speed
		player.velocity.z = dir.y * speed
		player.velocity.y -= 20.0/60.0
		player.move_and_slide()
	print("BLOCKED ",player.global_position," target ",target)
	for i in range(player.get_slide_collision_count()):
		print("COLLIDER ", player.get_slide_collision(i).get_collider().get_path())
	return false
func run() -> void:
	world=load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in range(30): await physics_frame
	player=world.get_node("Original/Player")
	player.set_physics_process(false)
	var castle=world.get_node("Sectors/WesternPlains/ChateauDesPlaines")
	var names: Array[String]=[]
	for child in castle.get_children(): names.append(str(child.name))
	report["nodes"]=names
	check(castle.has_node("CastleArchitecture"),"New castle architecture loaded")
	check(castle.has_node("CastleStairRamp_1") and castle.has_node("CastleStairRamp_2"),"Both smooth stair colliders imported")
	var ground=castle.get_node("CastleGround") as MeshInstance3D
	var water=castle.get_node("Water_Moat") as MeshInstance3D
	check(ground.material_override is ShaderMaterial and ground.material_override.shader.resource_path=="res://shaders/world_ground.gdshader","Original village ground shader retained")
	check(water.material_override is ShaderMaterial,"Existing moat water material configured")
	var tex_count:=0
	for m: MeshInstance3D in castle.find_children("CastleArchitecture","MeshInstance3D",true,false):
		for i in m.mesh.get_surface_count():
			var mat=m.get_active_material(i)
			if mat is StandardMaterial3D and mat.albedo_texture != null: tex_count+=1
	check(tex_count>=4,"Stone, paving, slate and wood textures imported")
	report["textured_surfaces"]=tex_count
	var bridge_bad:=0
	for i in range(57):
		var q=PhysicsRayQueryParameters3D.create(Vector3(-203.5+i*.5,13.0,-8.092),Vector3(-203.5+i*.5,9,-8.092),1,[player.get_rid()])
		var h=world.get_world_3d().direct_space_state.intersect_ray(q)
		if h.is_empty() or h.position.y<11.4: bridge_bad+=1
	check(bridge_bad==0,"Original bridge: 57 collision support samples")
	report["bridge_support_failures"]=bridge_bad
	var gate_out:=Vector3(-12.5+sin(.35)*6,-26-cos(.35)*6,.19)
	var gate_in:=Vector3(-12.5-sin(.35)*5,-26+cos(.35)*5,-.055)
	player.global_position=local_point(gate_out)+Vector3.UP*.65
	player.velocity=Vector3.ZERO
	for i in range(30):
		await physics_frame
		player.velocity.y-=20.0/60.0
		player.move_and_slide()
	var gate_ok:=await walk_to(local_point(gate_in))
	check(gate_ok,"Passage from original bridge through the repaired gate remains walkable")
	report["gate_passage"]=gate_ok
	var points: Array[Vector3]=[Vector3(-1,-12,0.12),Vector3(-1,4.8,7.12),Vector3(-1.9,5,7.12),Vector3(-1.9,7,7.12),Vector3(7.9,7,12.52),Vector3(7.9,7.7,12.52),Vector3(8.7,8.2,12.52),Vector3(8.7,8.8,12.52)]
	player.global_position=local_point(points[0])+Vector3.UP*.65
	player.velocity=Vector3.ZERO
	for i in range(30):
		await physics_frame
		player.velocity.y-=20.0/60.0
		player.move_and_slide()
	var up:=true
	for i in range(1,points.size()):
		if not await walk_to(local_point(points[i])):
			up=false
			break
	check(up,"Player capsule climbs both stair flights and reaches the castle parvis without jumping")
	report["ascent"]=up
	report["top_position"]=str(player.global_position)
	var down:=true
	if up:
		for i in range(points.size()-2,-1,-1):
			if not await walk_to(local_point(points[i])):
				down=false
				break
	else: down=false
	check(down,"Player capsule descends back to village")
	report["descent"]=down

	# Walk the open lane north of house 05 and into the three-sided market.
	player.global_position=local_point(Vector3(-10,-14,0))+Vector3.UP*.65
	player.velocity=Vector3.ZERO
	for i in range(30):
		await physics_frame
		player.velocity.y-=20.0/60.0
		player.move_and_slide()
	var market_ok:=true
	for p in [Vector3(-7,-13.5,0),Vector3(2,-13.5,0),Vector3(3.8,-20,0),Vector3(11.8,-20,0),Vector3(12,-16.8,0),Vector3(12,-13.4,0),Vector3(10,-16.8,0),Vector3(14,-16.8,0)]:
		if not await walk_to(local_point(p)):
			market_ok=false
			break
	check(market_ok,"Player capsule reaches market and all three shop fronts")
	report["market_access"]=market_ok
	for ui in world.find_children("*","CanvasLayer",true,false): ui.hide()
	var camera:=Camera3D.new()
	root.add_child(camera)
	camera.far=2500
	camera.fov=47
	camera.current=true
	camera.global_position=local_point(Vector3(-40,-55,40))
	camera.look_at(local_point(Vector3(3,3,10)))
	var env=world.get_node("Original/WorldEnvironment").environment
	var fog=env.fog_enabled
	env.fog_enabled=false
	for i in range(15): await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+"godot_integration.png")
	env.fog_enabled=fog
	report["failures"]=failures
	FileAccess.open(out+"godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("CASTLE_INTEGRATION ",JSON.stringify(report))
	world.queue_free()
	camera.queue_free()
	await process_frame
	await process_frame
	quit(0 if failures.is_empty() else 1)

