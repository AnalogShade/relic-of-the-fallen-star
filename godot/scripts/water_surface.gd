extends Node
## Samples the actual water triangles, so shores and irregular rivers stay dry.
## Each triangle belongs to one grid scale; large offshore faces use coarse cells.
const CELL_SIZE := 2.0
const MAX_CELLS_PER_TRIANGLE := 16
const EDGE_TOLERANCE := 0.0001
var surfaces: Array[Dictionary] = []

func _ready() -> void:
	call_deferred("rebuild")

func rebuild() -> void:
	surfaces.clear()
	var world := get_tree().current_scene
	if world == null:
		return
	for node in world.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if not (str(node.name).begins_with("Water") or str(node.name).begins_with("Ocean")) or mesh_node.mesh == null:
			continue
		var triangles := PackedVector3Array()
		for surface in mesh_node.mesh.get_surface_count():
			if mesh_node.mesh is ArrayMesh and mesh_node.mesh.surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var arrays := mesh_node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var count := indices.size() if not indices.is_empty() else vertices.size()
			for i in count:
				triangles.append(mesh_node.global_transform * vertices[indices[i] if not indices.is_empty() else i])
		if triangles.is_empty():
			continue
		var bounds := AABB(triangles[0], Vector3.ZERO)
		for point in triangles:
			bounds = bounds.expand(point)
		surfaces.append({"bounds": bounds, "triangles": triangles, "grids": _build_index(triangles)})

func _build_index(triangles: PackedVector3Array) -> Dictionary:
	var grids := {}
	for i in range(0, triangles.size() - 2, 3):
		var a := triangles[i]
		var b := triangles[i + 1]
		var c := triangles[i + 2]
		var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(denominator) < 0.00001:
			continue
		# Match the barycentric edge tolerance, including just outside a triangle.
		var padding := Vector2(
			absf(a.x - b.x) + absf(b.x - c.x) + absf(c.x - a.x),
			absf(a.z - b.z) + absf(b.z - c.z) + absf(c.z - a.z)
		) * EDGE_TOLERANCE
		var low := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z))) - padding
		var high := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z))) + padding
		var size := CELL_SIZE
		var first := Vector2i((low / size).floor())
		var last := Vector2i((high / size).floor())
		while (last.x - first.x + 1) * (last.y - first.y + 1) > MAX_CELLS_PER_TRIANGLE:
			size *= 4.0
			first = Vector2i((low / size).floor())
			last = Vector2i((high / size).floor())
		if not grids.has(size):
			grids[size] = {}
		var cells: Dictionary = grids[size]
		for x in range(first.x, last.x + 1):
			for z in range(first.y, last.y + 1):
				var key := Vector2i(x, z)
				if not cells.has(key):
					cells[key] = []
				cells[key].append(i)
	return grids

func height_at(position: Vector3) -> float:
	var height := -INF
	for surface in surfaces:
		var bounds: AABB = surface.bounds
		if position.x < bounds.position.x or position.x > bounds.end.x or position.z < bounds.position.z or position.z > bounds.end.z:
			continue
		var triangles: PackedVector3Array = surface.triangles
		# Also support surfaces supplied directly by isolated gameplay tests.
		if not surface.has("grids"):
			surface["grids"] = _build_index(triangles)
		var grids: Dictionary = surface.grids
		for size in grids:
			var key := Vector2i(floori(position.x / size), floori(position.z / size))
			var cells: Dictionary = grids[size]
			for i in cells.get(key, []):
				var a := triangles[i]
				var b := triangles[i + 1]
				var c := triangles[i + 2]
				var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
				var u := ((b.z - c.z) * (position.x - c.x) + (c.x - b.x) * (position.z - c.z)) / denominator
				var v := ((c.z - a.z) * (position.x - c.x) + (a.x - c.x) * (position.z - c.z)) / denominator
				if u >= -EDGE_TOLERANCE and v >= -EDGE_TOLERANCE and u + v <= 1.0 + EDGE_TOLERANCE:
					height = maxf(height, u * a.y + v * b.y + (1.0 - u - v) * c.y)
	return height
