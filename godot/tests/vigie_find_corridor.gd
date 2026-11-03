extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var world=load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in range(90): await physics_frame
	var route=JSON.parse_string(FileAccess.get_file_as_string("res://tests/vigie_route.json")).route
	var offsets=[]
	var shape=CapsuleShape3D.new()
	shape.radius=.8
	shape.height=1.9
	var space=world.get_world_3d().direct_space_state
	for p in route:
		var radial=Vector3(p[0]-66,0,-p[1]+77).normalized()
		var found=0.0
		for k in range(33):
			var offset=k*.25
			var q=PhysicsShapeQueryParameters3D.new()
			q.shape=shape
			q.collision_mask=1
			q.transform.origin=Vector3(p[0],p[2]+.9,-p[1])+radial*offset
			var blocked=false
			for hit in space.intersect_shape(q,128):
				var path=str(hit.collider.get_path())
				if "Wood" in path or "Rocks" in path or "Rubble" in path: blocked=true
			if not blocked:
				found=offset
				break
			offsets.append(found) if false else null
		offsets.append(found)
	for i in range(offsets.size()-1): offsets[i+1]=maxf(offsets[i+1],offsets[i]-.15)
	for i in range(offsets.size()-2,-1,-1): offsets[i]=maxf(offsets[i],offsets[i+1]-.15)
	var old=JSON.parse_string(FileAccess.get_file_as_string("res://tests/vigie_avoidance.json"))
	for i in range(mini(old.size(),offsets.size())): offsets[i]+=old[i]
	FileAccess.open("res://tests/vigie_avoidance.json",FileAccess.WRITE).store_string(JSON.stringify(offsets))
	print("OFFSETS ",offsets)
	quit()


