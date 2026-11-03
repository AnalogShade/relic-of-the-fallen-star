extends SceneTree

const OUT := "C:/Users/Utilisateur/Documents/Dev/Jeux/Relic of the fallen star/3D MODELS/chateau/quartier_20261021/"
var world: Node3D
var camera: Camera3D
var failures: Array[String] = []
var report := {}

func _initialize() -> void:
	call_deferred("run")

func point(p: Vector3) -> Vector3:
	var q := p - Vector3(2,4,0)
	return Basis(Vector3.UP,PI/2.0-.35)*Vector3(q.x,q.z,-q.y)+Vector3(-226,12,-32)

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

func ground_ray(p: Vector3) -> Dictionary:
	var origin := point(p)
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin + Vector3.UP*35.0, origin - Vector3.UP*3.0, 1))

func capture(eye: Vector3, target: Vector3, file: String) -> void:
	camera.global_position=point(eye)
	camera.look_at(point(target))
	for i in range(35): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+file)

func run() -> void:
	world=load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in range(40): await physics_frame
	var player: CharacterBody3D=world.get_node("Original/Player")
	player.set_physics_process(false)
	player.global_position=point(Vector3(-16,-13,1))
	for ui in world.find_children("*","CanvasLayer",true,false): ui.hide()
	for ui in root.find_children("*","Control",true,false): ui.hide()
	var castle: Node3D=world.get_node("Sectors/WesternPlains/ChateauDesPlaines")
	var architecture: MeshInstance3D=castle.get_node("CastleArchitecture")
	var ground: MeshInstance3D=castle.get_node("CastleGround")
	check(ground.material_override is ShaderMaterial and ground.material_override.shader.resource_path=="res://shaders/world_ground.gdshader","Existing ground material retained")
	var materials: Array[String]=[]
	for i in architecture.mesh.get_surface_count():
		var m:=architecture.get_active_material(i) as StandardMaterial3D
		if m!=null and m.resource_name.begins_with("PBR"):
			check(m.albedo_texture!=null and m.normal_enabled and m.normal_texture!=null,"Baked color and normal: "+m.resource_name)
			materials.append(m.resource_name)
	check(materials.size()==3,"All three new PBR materials imported")
	var houses: Array=JSON.parse_string(FileAccess.get_file_as_string(OUT+"houses.json"))
	for h: Dictionary in houses:
		var c: Array=h["center"]
		var hit:=ground_ray(Vector3(c[0],c[1],0))
		check(not hit.is_empty() and hit.position.y>16.0,"House %02d roof collision at relocated position" % int(h["house"]))
	var old_house:=ground_ray(Vector3(2,-24,0))
	check(not old_house.is_empty() and absf(old_house.position.y-12.0)<0.2,"Former house 06 footprint is clear")
	var smoke_root:=world.get_node("Sectors/WesternPlains/ChimneySmoke")
	check(smoke_root.get_child_count()==2,"Exactly two smoking chimneys")
	for plume: CPUParticles3D in smoke_root.get_children():
		var hit:=world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(plume.global_position+Vector3.UP*.5,plume.global_position-Vector3.UP*.5,1))
		check(plume.emitting and not hit.is_empty() and absf(hit.position.y-plume.global_position.y)<.08,"Smoke anchored to chimney top: "+plume.name)
	# Check connected ground support through the new central residential lane.
	var unsupported:=0
	# Stop at the northern doorstep, before the occupied house 06 footprint.
	for i in range(35):
		var y:=-13.0+float(i)
		var x:=-16.0 if y<8.0 else lerpf(-16.0,-11.5,clampf((y-8.0)/15.0,0,1))
		var hit:=ground_ray(Vector3(x,y,0))
		if hit.is_empty() or absf(hit.position.y-12.0)>.2: unsupported+=1
	check(unsupported==0,"Ground support along the new central lane")
	player.global_position=point(Vector3(-16,-11,0.7))
	player.velocity=Vector3.ZERO
	var reached:=true
	for target: Vector3 in [Vector3(-16,-3,0),Vector3(-16,8,0),Vector3(-14.7,18,0)]:
		var destination:=point(target)
		var arrived:=false
		for step in range(650):
			await physics_frame
			var delta:=destination-player.global_position
			delta.y=0.0
			if delta.length()<.22:
				arrived=true
				break
			var velocity:=delta.normalized()*minf(5.0,delta.length()*10.0)
			player.velocity.x=velocity.x
			player.velocity.z=velocity.z
			player.velocity.y-=20.0/60.0
			player.move_and_slide()
		if not arrived:
			reached=false
			print("LANE_BLOCKED ",player.global_position," target ",destination)
			break
	check(reached,"Player capsule walks through the relocated quarter")
	var environment: Environment=world.get_node("Original/WorldEnvironment").environment
	environment.fog_enabled=false
	camera=Camera3D.new()
	root.add_child(camera)
	camera.current=true
	camera.far=2500
	camera.fov=47
	await capture(Vector3(-53,-45,42),Vector3(-12,5,3),"godot_quartier_ensemble.png")
	await capture(Vector3(-17,-29,19),Vector3(-19,-6,5),"godot_quartier_fumee.png")
	await capture(Vector3(-16,-5,1.8),Vector3(-16,16,4),"godot_quartier_rue.png")
	report={"failures":failures,"pbr_materials":materials,"smoke_emitters":smoke_root.get_child_count(),"lane_support_failures":unsupported,"lane_walkable":reached}
	FileAccess.open(OUT+"godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("QUARTER_VALIDATION ",JSON.stringify(report))
	world.queue_free()
	camera.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
