extends SceneTree
const TRAILS = preload("res://scripts/forest_trails.gd")
var world: Node3D
var added: Array[Vector2] = []
var placements: Array = []

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	world = (load("res://scenes/world/open_world.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for i in range(35): await physics_frame
	var player := world.get_node("Original/Player") as CharacterBody3D
	player.set_physics_process(false)
	var space := world.get_world_3d().direct_space_state
	var group := world.get_node("SapinsChateau") as Node3D
	var prefab := load("res://scenes/vegetation/sapin_alpha.tscn") as PackedScene
	var rng := RandomNumberGenerator.new(); rng.seed = 30102026
	var centers := [Vector2(-167,-56),Vector2(-165,23),Vector2(-224,36),Vector2(-268,13),Vector2(-271,-70),Vector2(-214,-85)]
	for center: Vector2 in centers:
		var count := 0
		for attempt in range(160):
			if count == 3: break
			var p := center + Vector2(rng.randf_range(-9,9),rng.randf_range(-9,9))
			if p.x < -280 or p.x > -145 or p.y < -92: continue
			if p.distance_to(Vector2(-226,-32)) < 55: continue
			if TRAILS.distance_to_path(p) < 4.7: continue
			var nearby := false
			for q in added:
				if p.distance_to(q) < 6: nearby = true
			for existing in world.get_node("VegetationFirstPass/ArbresPlaines").get_children():
				if Vector2(existing.global_position.x,existing.global_position.z).distance_to(p) < 5.5: nearby = true
			if nearby: continue
			var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,100,p.y),Vector3(p.x,-10,p.y),1,[player.get_rid()])
			var hit := space.intersect_ray(query)
			if hit.is_empty() or not "/Terrain" in str(hit.collider.get_path()): continue
			if hit.normal.dot(Vector3.UP) < .94: continue
			var sphere := SphereShape3D.new(); sphere.radius = 2.4
			var sq := PhysicsShapeQueryParameters3D.new(); sq.shape = sphere; sq.collision_mask = 1
			sq.transform.origin = hit.position + Vector3.UP * 2.65
			var occupied := false
			for overlap in space.intersect_shape(sq,16):
				if not "/Terrain" in str(overlap.collider.get_path()): occupied = true
			if occupied: continue
			var inst := prefab.instantiate() as Node3D
			inst.name = "SapinExterieur_%02d" % (added.size()+1)
			group.add_child(inst); inst.owner = group
			inst.global_position = hit.position - Vector3.UP * .04
			var size := rng.randf_range(.68,1.04)
			inst.scale = Vector3(size*rng.randf_range(.85,1),size*rng.randf_range(.94,1.13),size*rng.randf_range(.85,1))
			inst.rotation.y = rng.randf_range(0,TAU)
			added.append(p); count += 1
			placements.append({"name":str(inst.name),"position":str(inst.position),"scale":str(inst.scale),"trail_clearance":TRAILS.distance_to_path(p),"terrain":str(hit.collider.get_path())})
	# Persist through Godot's serializer, preserving the prefab links.
	var packed := PackedScene.new(); assert(packed.pack(group) == OK)
	assert(ResourceSaver.save(packed,"res://scenes/world/sapins_chateau.tscn") == OK)
	FileAccess.open("res://assets/environment/vegetation/sapins_exterieur_validation.json",FileAccess.WRITE).store_string(JSON.stringify(placements,"\t"))
	print("EXTERIOR_PINES_ADDED ",added.size())
	assert(added.size() >= 12)
	world.queue_free()
	await process_frame; await process_frame
	quit()
