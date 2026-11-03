extends SceneTree
## Rebuild only the bank circled downstream of the shrine; keep the imported GLB.
const OUT := "res://assets/environment/shrine_bank_relief/"
const SOURCE := "res://assets/environment/trails_20261021/tile_07_meandres_du_sud.glb"
const Z_MIN := 24.0
const Z_MAX := 42.0
const WIDTH := 5.0
const SAMPLE = preload("res://scripts/stream_bank_seal.gd")
var rows: Array = []
var grid := {}

func _initialize() -> void:
	call_deferred("run")

func banks(z: float) -> Vector4:
	var lo := 0
	var hi := rows.size() - 1
	while hi - lo > 1:
		var mid := (hi + lo) / 2
		if rows[mid].z <= z: lo = mid
		else: hi = mid
	var t := clampf((z - rows[lo].z) / (rows[hi].z - rows[lo].z), 0.0, 1.0)
	return Vector4(lerpf(rows[lo].left, rows[hi].left, t), lerpf(rows[lo].right, rows[hi].right, t), lerpf(rows[lo].height, rows[hi].height, t), 0)

func delta_at(p: Vector3) -> float:
	if p.z <= Z_MIN or p.z >= Z_MAX: return 0.0
	var shore := banks(p.z)
	# Only the right bank indicated in the editor screenshot.
	var distance := p.x - shore.y
	if distance <= -1.6 or distance >= WIDTH: return 0.0
	var original := SAMPLE.height_at(grid, p)
	if not is_finite(original): return 0.0
	var target: float
	if distance <= 0.0:
		target = shore.z - 0.4 + 0.46 * smoothstep(-1.6, 0.0, distance)
	else:
		var outer := SAMPLE.height_at(grid, Vector3(shore.y + WIDTH, 0, p.z))
		if not is_finite(outer): return 0.0
		target = lerpf(shore.z + 0.06, maxf(outer, shore.z + 0.35), smoothstep(0.0, WIDTH, distance))
	var weight := smoothstep(Z_MIN, Z_MIN + 3.0, p.z) * (1.0 - smoothstep(Z_MAX - 3.0, Z_MAX, p.z))
	return (target - original) * weight

func deform(node: MeshInstance3D, path: String) -> bool:
	var staged := ArrayMesh.new()
	var changed := 0
	for s in node.mesh.get_surface_count():
		var arrays := node.mesh.surface_get_arrays(s)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			var p := node.global_transform * vertices[i]
			var shift := delta_at(p)
			if absf(shift) > 0.00001:
				p.y += shift
				vertices[i] = node.global_transform.affine_inverse() * p
				changed += 1
		arrays[Mesh.ARRAY_VERTEX] = vertices
		staged.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		staged.surface_set_material(s, node.mesh.surface_get_material(s))
	if changed == 0: return false
	var result := ArrayMesh.new()
	for s in staged.get_surface_count():
		var surface := SurfaceTool.new()
		surface.create_from(staged, s)
		surface.generate_normals()
		surface.commit(result)
	assert(ResourceSaver.save(result, OUT + path + ".res") == OK)
	if path == "terrain":
		assert(ResourceSaver.save(result.create_trimesh_shape(), OUT + "terrain_collision.res") == OK)
	print("BAKED ", node.name, " vertices_changed=", changed)
	return true

func run() -> void:
	var source: Node3D = load(SOURCE).instantiate()
	root.add_child(source)
	var terrain := source.find_child("Terrain", true, false) as MeshInstance3D
	var water := source.find_child("Water", true, false) as MeshInstance3D
	var by_z := {}
	for v in water.mesh.get_faces():
		var p: Vector3 = water.global_transform * v
		var key := snappedf(p.z, 0.001)
		if not by_z.has(key): by_z[key] = {"z": p.z, "left": p.x, "right": p.x, "height": p.y}
		by_z[key].left = minf(by_z[key].left, p.x)
		by_z[key].right = maxf(by_z[key].right, p.x)
	rows = by_z.values()
	rows.sort_custom(func(a, b): return a.z < b.z)
	var faces := terrain.mesh.get_faces()
	for i in range(0, faces.size(), 3):
		var a: Vector3 = terrain.global_transform * faces[i]
		var b: Vector3 = terrain.global_transform * faces[i+1]
		var c: Vector3 = terrain.global_transform * faces[i+2]
		var low := Vector2(minf(a.x, minf(b.x,c.x)), minf(a.z,minf(b.z,c.z)))
		var high := Vector2(maxf(a.x,maxf(b.x,c.x)), maxf(a.z,maxf(b.z,c.z)))
		if high.y < Z_MIN - 1 or low.y > Z_MAX + 1 or high.x < -12 or low.x > 15: continue
		for x in range(floori(low.x / SAMPLE.CELL), floori(high.x / SAMPLE.CELL) + 1):
			for z in range(floori(low.y / SAMPLE.CELL), floori(high.y / SAMPLE.CELL) + 1):
				var key := Vector2i(x,z)
				if not grid.has(key): grid[key] = []
				grid[key].append([a,b,c])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	assert(deform(terrain, "terrain"))
	var undergrowth := source.find_child("Undergrowth", true, false) as MeshInstance3D
	if undergrowth != null: deform(undergrowth, "undergrowth")
	var scene_path := "res://scenes/world/tile_07_meandres_du_sud.tscn"
	var authored: Node3D = load(scene_path).instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	authored.set_editable_instance(authored.get_node("Art"), true)
	authored.get_node("Art/Terrain").mesh = load(OUT + "terrain.res")
	authored.get_node("Art/Undergrowth").mesh = load(OUT + "undergrowth.res")
	for shape: CollisionShape3D in authored.get_node("Art/Terrain").find_children("*", "CollisionShape3D", true, false):
		shape.shape = load(OUT + "terrain_collision.res")
	var packed := PackedScene.new()
	assert(packed.pack(authored) == OK)
	assert(ResourceSaver.save(packed, scene_path) == OK)
	authored.free()
	print("RELIEF_BAKE_DONE")
	source.free()
	quit()


