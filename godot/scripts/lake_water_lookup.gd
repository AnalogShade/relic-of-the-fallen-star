extends RefCounted
## Exact local water sampler. Build once while dormant; query only a 2 m cell.
const CELL_SIZE := 2.0
var triangles := PackedVector3Array()
var cells := {}
var broad_triangles := PackedInt32Array()

func build(surfaces: Array[Dictionary], center: Vector3, radius := 32.0) -> void:
	triangles.clear()
	cells.clear()
	broad_triangles.clear()
	for surface in surfaces:
		var bounds: AABB = surface.bounds
		if bounds.end.x < center.x - radius or bounds.position.x > center.x + radius or bounds.end.z < center.z - radius or bounds.position.z > center.z + radius:
			continue
		var points: PackedVector3Array = surface.triangles
		for i in range(0, points.size() - 2, 3):
			var a := points[i]
			var b := points[i + 1]
			var c := points[i + 2]
			var x0 := floori(minf(a.x, minf(b.x, c.x)) / CELL_SIZE)
			var x1 := floori(maxf(a.x, maxf(b.x, c.x)) / CELL_SIZE)
			var z0 := floori(minf(a.z, minf(b.z, c.z)) / CELL_SIZE)
			var z1 := floori(maxf(a.z, maxf(b.z, c.z)) / CELL_SIZE)
			var first := triangles.size()
			triangles.append_array(PackedVector3Array([a, b, c]))
			if (x1 - x0 + 1) * (z1 - z0 + 1) > 128:
				broad_triangles.append(first)
				continue
			for x in range(x0, x1 + 1):
				for z in range(z0, z1 + 1):
					var key := Vector2i(x, z)
					if not cells.has(key): cells[key] = []
					cells[key].append(first)

func _triangle_height(position: Vector3, i: int) -> float:
	var a := triangles[i]
	var b := triangles[i + 1]
	var c := triangles[i + 2]
	var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
	if absf(denominator) < 0.00001: return -INF
	var u := ((b.z - c.z) * (position.x - c.x) + (c.x - b.x) * (position.z - c.z)) / denominator
	var v := ((c.z - a.z) * (position.x - c.x) + (a.x - c.x) * (position.z - c.z)) / denominator
	if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
		return u * a.y + v * b.y + (1.0 - u - v) * c.y
	return -INF

func height_at(position: Vector3) -> float:
	var key := Vector2i(floori(position.x / CELL_SIZE), floori(position.z / CELL_SIZE))
	var height := -INF
	for i in cells.get(key, []): height = maxf(height, _triangle_height(position, i))
	for i in broad_triangles: height = maxf(height, _triangle_height(position, i))
	return height
