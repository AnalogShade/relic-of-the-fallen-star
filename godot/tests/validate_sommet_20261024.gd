extends SceneTree

func _initialize(): call_deferred("run")

func run():
	var tower = load("res://scenes/world/vigie.tscn").instantiate()
	root.add_child(tower)
	await physics_frame
	await physics_frame
	var enabled = []
	for shape in tower.find_children("*","CollisionShape3D",true,false):
		if not shape.disabled:enabled.append(str(shape.get_parent().get_path()))
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/marches_pierre/composition_sommet_20261024.json"))
	var route = []
	for r in data:route.append(Vector3(r.position[0],r.position[2]-.035,-r.position[1]))
	var misses = []
	for i in range(route.size()-1):
		var sample = route[i].lerp(route[i+1],.5)
		var hit = root.world_3d.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(sample+Vector3.UP*.15,sample-Vector3.UP*.20,1))
		if hit.is_empty():misses.append(i)
	var body = CharacterBody3D.new();body.collision_layer=2;body.collision_mask=1
	body.floor_snap_length=.35;body.floor_max_angle=deg_to_rad(50)
	var capsule = CapsuleShape3D.new();capsule.radius=.32;capsule.height=1.65
	var shape = CollisionShape3D.new();shape.shape=capsule;body.add_child(shape);root.add_child(body)
	var traversals = []
	for speed in [2.16,5.0]:
		body.position=route[1]+Vector3.UP*.84;body.velocity=Vector3.ZERO
		var index=2;var ticks=0;var stalled=0;var last=body.position
		while index<route.size() and ticks<8000:
			await physics_frame
			var delta=route[index]-body.position;delta.y=0
			if delta.length()<.14:index+=1;continue
			body.velocity.x=delta.normalized().x*speed;body.velocity.z=delta.normalized().z*speed
			body.velocity.y-=18.0/60
			body.move_and_slide()
			ticks+=1
			if ticks%120==0:
				if body.position.distance_to(last)<.15:stalled+=1
				else:stalled=0
				last=body.position
				if stalled>=2:break
		traversals.append({"speed":speed,"reached":index,"total":route.size(),"ticks":ticks,"position":str(body.position)})
	var stones=0;var stored_transforms=0;var support_stones=0
	for batch in tower.get_node("RuineSommet").find_children("*","MultiMeshInstance3D",true,false):
		stones+=batch.multimesh.instance_count
		stored_transforms+=batch.multimesh.buffer.size()/12
	for batch in tower.get_node("MarchesNaturelles/Assises").find_children("*","MultiMeshInstance3D",true,false):
		support_stones+=batch.multimesh.instance_count
	var report={"active_collision_bodies":enabled,"active_collision_count":enabled.size(),"route_raycast_misses":misses,"traversals":traversals,"foundation_multimeshes":tower.get_node("RuineSommet").find_children("*","MultiMeshInstance3D",true,false).size(),"foundation_visual_stones":stones,"stored_foundation_transforms":stored_transforms,"stair_support_visual_stones":support_stones}
	FileAccess.open("res://../diagnostics/ruin_foundation_20261024/godot_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SOMMET_VALIDATION ",JSON.stringify(report))
	body.free();tower.free()
	await process_frame
	call_deferred("quit",0 if enabled.size()==3 and misses.is_empty() and traversals[0].reached==224 and traversals[1].reached==224 and stones==370 and stored_transforms==370 and support_stones==747 else 1)
