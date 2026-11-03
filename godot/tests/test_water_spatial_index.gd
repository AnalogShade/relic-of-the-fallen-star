extends SceneTree
## Compare indexed sampling with the previous exhaustive algorithm on real water.
var failures := 0
var compared := 0

func _initialize() -> void:
	call_deferred("run")

func brute_height(surfaces: Array, point: Vector3) -> float:
	var height := -INF
	for surface in surfaces:
		var bounds: AABB = surface.bounds
		if point.x < bounds.position.x or point.x > bounds.end.x or point.z < bounds.position.z or point.z > bounds.end.z: continue
		var triangles: PackedVector3Array = surface.triangles
		for i in range(0, triangles.size() - 2, 3):
			var a := triangles[i]
			var b := triangles[i + 1]
			var c := triangles[i + 2]
			var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
			if absf(denominator) < 0.00001: continue
			var u := ((b.z - c.z) * (point.x - c.x) + (c.x - b.x) * (point.z - c.z)) / denominator
			var v := ((c.z - a.z) * (point.x - c.x) + (a.x - c.x) * (point.z - c.z)) / denominator
			if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
				height = maxf(height, u * a.y + v * b.y + (1.0 - u - v) * c.y)
	return height

func compare(sampler: Node, point: Vector3) -> void:
	var expected := brute_height(sampler.surfaces, point)
	var actual: float = sampler.height_at(point)
	compared += 1
	if is_finite(expected) != is_finite(actual) or (is_finite(expected) and absf(expected - actual) > 0.00001):
		failures += 1
		printerr("HEIGHT_MISMATCH ", point, " expected=", expected, " actual=", actual)

func run() -> void:
	var world := load("res://scenes/world/open_world.tscn").instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	for i in 30: await process_frame
	var sampler: Node = world.get_node("Original/Player").water_surface
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261027
	# Coarse/fine grids, dry shore, estuary seam and the entire offshore extent.
	for i in 120: compare(sampler, Vector3(rng.randf_range(-35, 35), 3, rng.randf_range(85, 175)))
	for i in 80: compare(sampler, Vector3(rng.randf_range(-3005, 3105), 3, rng.randf_range(80, 3175)))
	for z in [87.9999, 88.0, 88.0001, 89.99, 90.0, 90.0001, 150.0]:
		for x in [-9.0, 0.0, 8.0, 20.0]: compare(sampler, Vector3(x, 3, z))
	# Real mesh vertices, edges, centers and barycentric tolerance outside edges.
	for surface in sampler.surfaces:
		var points: PackedVector3Array = surface.triangles
		for j in 8:
			var index := rng.randi_range(0, points.size() / 3 - 1) * 3
			var a := points[index]
			var b := points[index + 1]
			var c := points[index + 2]
			for p in [a, (a + b) * 0.5, (a + b + c) / 3.0, a * 0.50005 + b * 0.50004 - c * 0.00009]: compare(sampler, p)
		await process_frame
	var timings := []
	for point in [Vector3(8,3,87.99), Vector3(8,3,88.01), Vector3(-9,3,90), Vector3(0,3,150), Vector3(7,5,-213)]:
		var start := Time.get_ticks_usec()
		for i in 1000: sampler.height_at(point)
		timings.append({"point": str(point), "query_ms": float(Time.get_ticks_usec() - start) / 1000000.0})
	# Rebuild must replace the index, and overlapping/degenerate test surfaces retain semantics.
	var synthetic := preload("res://scripts/water_surface.gd").new()
	var triangles := PackedVector3Array([Vector3(-4,1,-4), Vector3(4,1,-4), Vector3(0,1,4), Vector3(-4,3,-4), Vector3(4,3,-4), Vector3(0,3,4), Vector3.ZERO, Vector3.ZERO, Vector3.ZERO])
	synthetic.surfaces.append({"bounds": AABB(Vector3(-4,1,-4), Vector3(8,2,8)), "triangles": triangles})
	for point in [Vector3.ZERO, Vector3(-4,0,-4), Vector3(3,0,3), Vector3(-0.0001,0,3.9999)]: compare(synthetic, point)
	synthetic.free()
	var before: float = sampler.height_at(Vector3(0,3,150))
	var start := Time.get_ticks_usec()
	sampler.rebuild()
	var rebuild_ms := float(Time.get_ticks_usec() - start) / 1000.0
	if sampler.height_at(Vector3(0,3,150)) != before: failures += 1
	var report := {"comparisons": compared, "failures": failures, "rebuild_ms": rebuild_ms, "timings": timings}
	print("SPATIAL_INDEX ", JSON.stringify(report))
	var file := FileAccess.open("res://../diagnostics/beach_performance_20261027/spatial_index_after.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	world.queue_free()
	await process_frame
	quit(0 if failures == 0 else 1)
