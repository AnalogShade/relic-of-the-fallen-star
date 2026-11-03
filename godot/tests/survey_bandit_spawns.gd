extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	await process_frame
	await physics_frame
	await physics_frame
	var space = world.get_world_3d().direct_space_state
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.65
	capsule.height = 1.8
	for point in [Vector2(-30,-18), Vector2(-38,-32), Vector2(-45,-12), Vector2(-25,-48), Vector2(40,-30), Vector2(48,-48), Vector2(55,-15), Vector2(32,20), Vector2(45,35), Vector2(-35,32), Vector2(-50,40), Vector2(5,-85)]:
		var origin := Vector3(point.x,100,point.y)
		var hit = space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin-Vector3.UP*150,1))
		if hit.is_empty(): continue
		var pos: Vector3 = hit.position
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = capsule
		q.transform.origin = pos + Vector3.UP*1.0
		q.collision_mask = 1
		var clear: bool = space.intersect_shape(q).is_empty()
		var exits := 0
		for i in range(8):
			var d := Vector3(cos(i*TAU/8),0,sin(i*TAU/8))
			var ground = space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+d*4+Vector3.UP*3,pos+d*4-Vector3.UP*3,1))
			if not ground.is_empty() and ground.normal.y > 0.85 and space.intersect_ray(PhysicsRayQueryParameters3D.create(pos+Vector3.UP,pos+Vector3.UP+d*4,1)).is_empty(): exits += 1
		print("SPAWN ",pos," clear=",clear," exits=",exits," normal=",hit.normal," collider=",hit.collider.get_path())
	world.queue_free()
	await process_frame
	quit()
