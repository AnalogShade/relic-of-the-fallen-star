@tool
extends RefCounted
## Opaque terrain beneath exposed shore edges. The water mesh/material stay intact.
const CELL := 2.0
const OVERLAP := 0.08
const APRON := 0.6

static func apply(water: MeshInstance3D) -> void:
	if water.mesh == null or water.has_node("BankSeal"):
		return
	var faces := water.mesh.get_faces()
	var edges := {}
	var bounds := AABB(water.global_transform * faces[0], Vector3.ZERO) if not faces.is_empty() else AABB()
	for i in range(0, faces.size(), 3):
		var triangle := [water.global_transform * faces[i], water.global_transform * faces[i + 1], water.global_transform * faces[i + 2]]
		for j in 3:
			var a: Vector3 = triangle[j]
			var b: Vector3 = triangle[(j + 1) % 3]
			bounds = bounds.expand(a)
			# Imported meshes may split vertices at UV/normal seams; weld by position.
			var ka := Vector3i((a * 10000.0).round())
			var kb := Vector3i((b * 10000.0).round())
			var key := str(ka) + ":" + str(kb) if str(ka) < str(kb) else str(kb) + ":" + str(ka)
			if edges.has(key):
				edges[key][0] += 1
			else:
				edges[key] = [1, a, b, triangle[(j + 2) % 3]]
	if faces.is_empty():
		return
	var scene: Node = water
	while scene.get_parent() != null and not scene.get_parent() is Window:
		scene = scene.get_parent()
	preload("res://scripts/stream_stone_ground.gd").apply.call_deferred(scene)
	var grid := {}
	var ground_material: Material
	var region := bounds.grow(APRON + CELL)
	for node in scene.find_children("Terrain*", "MeshInstance3D", true, false):
		var terrain := node as MeshInstance3D
		if terrain.mesh == null:
			continue
		var terrain_bounds: AABB = terrain.global_transform * terrain.get_aabb()
		if terrain_bounds.end.x < region.position.x or terrain_bounds.position.x > region.end.x or terrain_bounds.end.z < region.position.z or terrain_bounds.position.z > region.end.z:
			continue
		var terrain_faces := terrain.mesh.get_faces()
		for i in range(0, terrain_faces.size(), 3):
			var a: Vector3 = terrain.global_transform * terrain_faces[i]
			var b: Vector3 = terrain.global_transform * terrain_faces[i + 1]
			var c: Vector3 = terrain.global_transform * terrain_faces[i + 2]
			var low := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
			var high := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
			if high.x < region.position.x or low.x > region.end.x or high.y < region.position.z or low.y > region.end.z:
				continue
			if ground_material == null:
				ground_material = terrain.material_override if terrain.material_override != null else terrain.get_active_material(0)
			for x in range(floori(low.x / CELL), floori(high.x / CELL) + 1):
				for z in range(floori(low.y / CELL), floori(high.y / CELL) + 1):
					var key := Vector2i(x, z)
					if not grid.has(key):
						grid[key] = []
					grid[key].append([a, b, c])
	if ground_material == null:
		return
	# Sector seams are open water, not banks: avoid artificial cross-stream ridges.
	var neighboring_water := {}
	for node in scene.find_children("Water*", "MeshInstance3D", true, false):
		var neighbor := node as MeshInstance3D
		if neighbor == water or neighbor.mesh == null:
			continue
		var neighbor_bounds: AABB = neighbor.global_transform * neighbor.get_aabb()
		if neighbor_bounds.end.x < region.position.x or neighbor_bounds.position.x > region.end.x or neighbor_bounds.end.z < region.position.z or neighbor_bounds.position.z > region.end.z:
			continue
		var neighbor_faces := neighbor.mesh.get_faces()
		for i in range(0, neighbor_faces.size(), 3):
			var a: Vector3 = neighbor.global_transform * neighbor_faces[i]
			var b: Vector3 = neighbor.global_transform * neighbor_faces[i + 1]
			var c: Vector3 = neighbor.global_transform * neighbor_faces[i + 2]
			var low := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.z, minf(b.z, c.z)))
			var high := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.z, maxf(b.z, c.z)))
			if high.x < region.position.x or low.x > region.end.x or high.y < region.position.z or low.y > region.end.z:
				continue
			for x in range(floori(low.x / CELL), floori(high.x / CELL) + 1):
				for z in range(floori(low.y / CELL), floori(high.y / CELL) + 1):
					var key := Vector2i(x, z)
					if not neighboring_water.has(key):
						neighboring_water[key] = []
					neighboring_water[key].append([a, b, c])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inverse := water.global_transform.affine_inverse()
	var count := 0
	var shore_normals := {}
	for edge in edges.values():
		if edge[0] != 1:
			continue
		var a: Vector3 = edge[1]
		var b: Vector3 = edge[2]
		var tangent := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if tangent.length_squared() < 0.000001:
			continue
		var outward := Vector3(-tangent.z, 0.0, tangent.x).normalized()
		if outward.dot(edge[3] - (a + b) * 0.5) > 0.0:
			outward = -outward
		for point in [a, b]:
			var key := Vector3i((point * 10000.0).round())
			shore_normals[key] = shore_normals.get(key, Vector3.ZERO) + outward
	for edge in edges.values():
		if edge[0] != 1:
			continue
		var a: Vector3 = edge[1]
		var b: Vector3 = edge[2]
		var tangent := Vector3(b.x - a.x, 0.0, b.z - a.z)
		if tangent.length_squared() < 0.000001:
			continue
		# Shared offsets keep adjacent strips joined, including sharp corners.
		var outward_a: Vector3 = shore_normals[Vector3i((a * 10000.0).round())].normalized()
		var outward_b: Vector3 = shore_normals[Vector3i((b * 10000.0).round())].normalized()
		# Subdivide long shore edges to follow terrain rather than bridge depressions.
		var steps := maxi(1, ceili(tangent.length() / 0.3))
		for step in steps:
			var p := a.lerp(b, float(step) / steps)
			var q := a.lerp(b, float(step + 1) / steps)
			var direction_p := outward_a.lerp(outward_b, float(step) / steps)
			var direction_q := outward_a.lerp(outward_b, float(step + 1) / steps)
			var midpoint := (p + q) * 0.5
			var neighbor_height := height_at(neighboring_water, midpoint + (direction_p + direction_q).normalized() * 0.04)
			if is_finite(neighbor_height) and absf(neighbor_height - midpoint.y) < 0.05:
				continue
			var hp := height_at(grid, p)
			var hq := height_at(grid, q)
			if not is_finite(hp) or not is_finite(hq) or (hp >= p.y - 0.006 and hq >= q.y - 0.006):
				continue
			var outer_p := p + direction_p * APRON
			var outer_q := q + direction_q * APRON
			var ohp := height_at(grid, outer_p)
			var ohq := height_at(grid, outer_q)
			if not is_finite(ohp) or not is_finite(ohq):
				continue
			outer_p.y = ohp - 0.03
			outer_q.y = ohq - 0.03
			p -= direction_p * OVERLAP
			q -= direction_q * OVERLAP
			p.y -= 0.008
			q.y -= 0.008
			for tri in [[p, q, outer_q], [p, outer_q, outer_p]]:
				if (tri[1] - tri[0]).cross(tri[2] - tri[0]).y > 0.0:
					tri.reverse() # Godot front faces are clockwise.
				for point in tri:
					surface.add_vertex(inverse * point)
			count += 1
	if count == 0:
		return
	surface.generate_normals()
	var seal := MeshInstance3D.new()
	seal.name = "BankSeal"
	seal.mesh = surface.commit()
	seal.material_override = ground_material
	water.add_child(seal)
	seal.create_trimesh_collision()

static func height_at(grid: Dictionary, point: Vector3) -> float:
	var height := -INF
	for tri in grid.get(Vector2i(floori(point.x / CELL), floori(point.z / CELL)), []):
		var a: Vector3 = tri[0]
		var b: Vector3 = tri[1]
		var c: Vector3 = tri[2]
		var denominator := (b.z - c.z) * (a.x - c.x) + (c.x - b.x) * (a.z - c.z)
		if absf(denominator) < 0.000001:
			continue
		var u := ((b.z - c.z) * (point.x - c.x) + (c.x - b.x) * (point.z - c.z)) / denominator
		var v := ((c.z - a.z) * (point.x - c.x) + (a.x - c.x) * (point.z - c.z)) / denominator
		if u >= -0.0001 and v >= -0.0001 and u + v <= 1.0001:
			height = maxf(height, u * a.y + v * b.y + (1.0 - u - v) * c.y)
	return height
