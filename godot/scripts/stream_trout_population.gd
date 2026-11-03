extends Node3D
## Independent copies of the lake trout scene, confined to the real stream bed.
const TROUT = preload("res://scenes/truite.tscn")
const HOLDING = preload("res://scripts/stream_trout.gd")
const HEIGHTS = preload("res://scripts/stream_bank_seal.gd")
var water_grid := {}
var ground_grid := {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 731904
	call_deferred("_populate")

func _index_mesh(mesh: MeshInstance3D, grid: Dictionary) -> void:
	var faces := mesh.mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var a: Vector3 = mesh.global_transform * faces[i]
		var b: Vector3 = mesh.global_transform * faces[i+1]
		var c: Vector3 = mesh.global_transform * faces[i+2]
		var low := Vector2(a.x,a.z).min(Vector2(b.x,b.z)).min(Vector2(c.x,c.z))
		var high := Vector2(a.x,a.z).max(Vector2(b.x,b.z)).max(Vector2(c.x,c.z))
		for x in range(floori(low.x/HEIGHTS.CELL), floori(high.x/HEIGHTS.CELL)+1):
			for z in range(floori(low.y/HEIGHTS.CELL), floori(high.y/HEIGHTS.CELL)+1):
				var key := Vector2i(x,z)
				if not grid.has(key):
					grid[key] = []
				grid[key].append([a,b,c])

func _cross_section(faces: PackedVector3Array, z: float) -> Vector2:
	var left := INF
	var right := -INF
	for i in range(0, faces.size(), 3):
		for j in 3:
			var a := faces[i+j]
			var b := faces[i+(j+1)%3]
			if absf(b.z-a.z) < 0.00001 or z < minf(a.z,b.z) or z > maxf(a.z,b.z):
				continue
			var x := lerpf(a.x,b.x,(z-a.z)/(b.z-a.z))
			left = minf(left,x)
			right = maxf(right,x)
	return Vector2(left,right)

func _populate() -> void:
	var world := get_parent()
	var waters: Array[MeshInstance3D] = []
	var bounds := AABB()
	for water: MeshInstance3D in world.find_children("Water", "MeshInstance3D", true, false):
		if water.mesh == null:
			continue
		waters.append(water)
		var box: AABB = water.global_transform * water.get_aabb()
		bounds = box if waters.size() == 1 else bounds.merge(box)
		_index_mesh(water,water_grid)
	var region := bounds.grow(3.0)
	for ground: MeshInstance3D in world.find_children("Terrain*", "MeshInstance3D", true, false):
		if ground.mesh == null:
			continue
		var box: AABB = ground.global_transform * ground.get_aabb()
		if box.end.x < region.position.x or box.position.x > region.end.x or box.end.z < region.position.z or box.position.z > region.end.z:
			continue
		_index_mesh(ground,ground_grid)
	for water in waters:
		var faces := water.mesh.get_faces()
		for i in faces.size():
			faces[i] = water.global_transform * faces[i]
		var box: AABB = water.global_transform * water.get_aabb()
		var z := box.position.z+3.5
		while z < box.end.z-2.0:
			var span := _cross_section(faces,z)
			var ahead := _cross_section(faces,z-0.8)
			if is_finite(span.x) and is_finite(ahead.x):
				var upstream := Vector3((ahead.x+ahead.y-span.x-span.y)*0.5,0.0,-0.8).normalized()
				var size := [0.45,0.6,0.75,0.9,1.05][rng.randi_range(0,4)] as float
				for attempt in 5:
					var point := Vector3(lerpf(span.x,span.y,rng.randf_range(0.28,0.72)),0.0,z)
					var surface := HEIGHTS.height_at(water_grid,point)
					var floor_height := HEIGHTS.height_at(ground_grid,point)
					if not is_finite(surface) or not is_finite(floor_height):
						continue
					var bottom := floor_height+0.18*size+0.08
					var top := surface-0.30*size-0.065
					if bottom > top:
						continue
					point.y = lerpf(bottom,top,0.65)
					if not can_occupy(point,upstream,size):
						continue
					var fish := TROUT.instantiate()
					fish.set_script(HOLDING)
					fish.name = "StreamTrout%02d" % (get_child_count()+1)
					fish.fish_scale = size
					fish.home = point
					fish.upstream = upstream
					var room := _holding_room(point,upstream,size)
					fish.motion_room = room
					fish.allow_wobble = room.length_squared() > 0.0001
					fish.rng.seed = rng.randi()
					add_child(fish)
					break
			z += rng.randf_range(5.5,8.5)
	print("[StreamTrout] ",get_child_count()," animated trout holding against the current across ",waters.size()," stream sections")

func _holding_room(point: Vector3, upstream: Vector3, size: float) -> Vector2:
	# Bake a complete swept envelope once. Any interpolation inside it is safe;
	# fish never search the terrain triangles during a physics frame.
	var side := upstream.cross(Vector3.UP).normalized()
	for factor: float in [1.0,0.5,0.25]:
		var room := Vector2(0.55,0.24)*factor
		# Include tail/head, animation width, slight yaw and the holding wobble.
		var low := Vector2(-0.86*size-room.x,-0.23*size-room.y-0.03)
		var high := Vector2(0.34*size+room.x,0.23*size+room.y+0.03)
		var steps := Vector2i(ceili((high.x-low.x)/0.08),ceili((high.y-low.y)/0.08))
		var safe := true
		for x in range(steps.x+1):
			for z in range(steps.y+1):
				var probe := point+upstream*lerpf(low.x,high.x,float(x)/steps.x)+side*lerpf(low.y,high.y,float(z)/steps.y)
				var surface := HEIGHTS.height_at(water_grid,probe)
				var floor_height := HEIGHTS.height_at(ground_grid,probe)
				if not is_finite(surface) or not is_finite(floor_height) or point.y+0.30*size+0.015 > surface-0.04 or point.y-0.18*size-0.015 < floor_height+0.045:
					safe = false
					break
			if not safe:
				break
		if safe:
			return room
	return Vector2.ZERO

func can_occupy(point: Vector3, upstream: Vector3, size: float) -> bool:
	var side := upstream.cross(Vector3.UP).normalized()
	# Include the long tail, head and width of the animated lake model.
	for along in [-0.82, -0.3, 0.30]:
		for across in [-0.17, 0.0, 0.17]:
			var probe: Vector3 = point + (upstream*along+side*across)*size
			var surface := HEIGHTS.height_at(water_grid,probe)
			var floor_height := HEIGHTS.height_at(ground_grid,probe)
			if not is_finite(surface) or not is_finite(floor_height):
				return false
			if point.y+0.30*size > surface-0.04 or point.y-0.18*size < floor_height+0.045:
				return false
	return true
