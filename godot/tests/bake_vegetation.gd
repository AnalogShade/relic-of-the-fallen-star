extends SceneTree
## Rebuild only the additive vegetation layer. Fixed seed keeps placement reproducible.
const ASSETS := "res://assets/environment/vegetation/"
const OUTPUT := "res://scenes/world/vegetation_first_pass.tscn"
const SHORT := ["herbe_courte_fine", "herbe_courte_dense", "herbe_courte_rampante"]
const TALL := ["herbe_haute_prairie", "herbe_haute_epis", "herbe_haute_balayee"]
const FERNS := ["fougere_rosette", "fougere_arquee", "fougere_compacte"]
const LEAVES := ["feuilles_lanceolees", "laiche_large", "rosette_ronde"]
var world: Node3D
var layer := Node3D.new()
var rng := RandomNumberGenerator.new()
var non_terrain: Array[RID] = []
var terrain: Array[RID] = []
var trails: Array[PackedVector2Array] = []
var batches: Dictionary = {}
var meshes: Dictionary = {}
var samples: Array[Dictionary] = []
var tree_points: Array[Vector2] = []
var groups: Dictionary = {}

func _initialize() -> void:
	call_deferred("bake")

func ground(p: Vector2) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, 160, p.y), Vector3(p.x, -8, p.y), 1)
	q.exclude = non_terrain
	return world.get_world_3d().direct_space_state.intersect_ray(q)

func trail_distance(p: Vector2) -> float:
	var distance := INF
	for pair in trails:
		distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, pair[0], pair[1])))
	return distance

func free_space(p: Vector3, radius: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	q.shape = sphere
	q.transform.origin = p + Vector3.UP * (radius + 0.12)
	q.exclude = terrain
	q.collision_mask = 1
	return world.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func safe_ground(p: Vector2, margin: float, radius: float) -> Dictionary:
	if trail_distance(p) < margin: return {}
	# Keep the castle, moat and bridge clear, including their approach.
	if p.distance_to(Vector2(-226, -32)) < 80: return {}
	var hit := ground(p)
	if hit.is_empty() or hit.normal.y < 0.88 or hit.position.y < 1.0: return {}
	if not free_space(hit.position, radius): return {}
	return hit

func foliage_mesh(slug: String) -> Mesh:
	if meshes.has(slug): return meshes[slug]
	var art: Node3D = load(ASSETS + slug + ".glb").instantiate()
	# Preserve painted atlases and fern vertex colors when rebaking.
	if slug == "rosette_ronde" or slug in FERNS:
		var source := art.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var textured_mesh := source.mesh.duplicate() as ArrayMesh
		var albedo_material := textured_mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		albedo_material.normal_enabled = false
		albedo_material.normal_texture = null
		textured_mesh.surface_set_material(0, albedo_material)
		assert(ResourceSaver.save(textured_mesh, ASSETS + slug + "_batched.res") == OK)
		meshes[slug] = textured_mesh
		art.free()
		return textured_mesh
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for child in art.find_children("*", "MeshInstance3D", true, false):
		var m := child as MeshInstance3D
		var tr: Transform3D = m.transform
		for surface in range(m.mesh.get_surface_count()):
			var arrays: Array = m.mesh.surface_get_arrays(surface)
			var material := m.mesh.surface_get_material(surface) as BaseMaterial3D
			var color := material.albedo_color if material != null else Color(0.3, 0.4, 0.12)
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			if indices.is_empty():
				for i in range(arrays[Mesh.ARRAY_VERTEX].size()): indices.append(i)
			for index in indices:
				vertices.append(tr * arrays[Mesh.ARRAY_VERTEX][index])
				normals.append((tr.basis * arrays[Mesh.ARRAY_NORMAL][index]).normalized())
				# Vertex colors are linear; imported material swatches are sRGB.
				colors.append(color.srgb_to_linear())
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.9
	mesh.surface_set_material(0, material)
	assert(ResourceSaver.save(mesh, ASSETS + slug + "_batched.res") == OK)
	meshes[slug] = mesh
	art.free()
	return mesh

func add_plant(slug: String, hit: Dictionary, category: String) -> void:
	var p: Vector3 = hit.position - Vector3.UP * 0.025
	var cell := Vector2i(floori(p.x / 24), floori(p.z / 24))
	var key := "%s/%s/%d_%d" % [category, slug, cell.x, cell.y]
	if not batches.has(key): batches[key] = {"slug": slug, "category": category, "transforms": []}
	var size := rng.randf_range(0.72, 1.28)
	var basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(size, size * rng.randf_range(0.88, 1.12), size))
	batches[key].transforms.append(Transform3D(basis, p))
	samples.append({"kind": "plant", "asset": slug, "position": [p.x, p.y, p.z], "ground_y": hit.position.y})

func tree_prefab(slug: String) -> PackedScene:
	var scene := Node3D.new()
	scene.name = slug.to_pascal_case()
	var art: Node3D = load(ASSETS + slug + ".glb").instantiate()
	art.name = "Visual"
	scene.add_child(art)
	art.owner = scene
	var body := StaticBody3D.new()
	body.name = "Tronc"
	body.collision_layer = 1
	body.collision_mask = 0
	scene.add_child(body)
	body.owner = scene
	var collision := CollisionShape3D.new()
	collision.name = "CapsuleTronc"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36 if slug == "sapin_elance" else 0.43
	capsule.height = 4.4 if slug == "sapin_elance" else 3.8
	collision.shape = capsule
	collision.position.y = capsule.height * 0.5
	body.add_child(collision)
	collision.owner = scene
	var packed := PackedScene.new()
	assert(packed.pack(scene) == OK)
	assert(ResourceSaver.save(packed, "res://scenes/vegetation/" + slug + ".tscn") == OK)
	scene.free()
	return load("res://scenes/vegetation/" + slug + ".tscn")

func bake() -> void:
	# MultiMesh buffers must be baked with an active renderer, not the headless dummy.
	if DisplayServer.get_name() == "headless":
		push_error("Run this bake with --windowed so MultiMesh buffers are serialized.")
		quit(1)
		return
	rng.seed = 15092026
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://scenes/vegetation"))
	world = load("res://scenes/world/open_world.tscn").instantiate()
	# Never include the previous pass when rebuilding grounding and clearance.
	var old := world.get_node_or_null("VegetationFirstPass")
	if old != null:
		world.remove_child(old)
		old.free()
	root.add_child(world)
	for i in range(5): await physics_frame
	for body in world.find_children("*", "CollisionObject3D", true, false):
		if "/Terrain" in str(body.get_path()): terrain.append(body.get_rid())
		else: non_terrain.append(body.get_rid())
	var expression := RegEx.new()
	expression.compile("segment_distance\\(p,vec2\\(([-0-9.]+),([-0-9.]+)\\),vec2\\(([-0-9.]+),([-0-9.]+)\\)\\)")
	for match in expression.search_all(FileAccess.get_file_as_string("res://shaders/world_ground.gdshader")):
		trails.append(PackedVector2Array([Vector2(float(match.get_string(1)), float(match.get_string(2))), Vector2(float(match.get_string(3)), float(match.get_string(4)))]))
	assert(trails.size() > 50)
	layer.name = "VegetationFirstPass"
	for category in ["HerbesCourtes", "HerbesHautes", "Fougeres", "FeuillesLarges", "ArbresPlaines", "ArbresMontagne", "TouffesRocheuses"]:
		var node := Node3D.new()
		node.name = category
		layer.add_child(node)
		node.owner = layer
		groups[category] = node
	var prefabs := {"sapin_elance": tree_prefab("sapin_elance"), "pin_balaye": tree_prefab("pin_balaye")}
	# Small initial tree population, in existing woodland gaps.
	for region in ["ArbresPlaines", "ArbresMontagne"]:
		var target := 24 if region == "ArbresPlaines" else 10
		var count := 0
		for attempt in range(900):
			if count >= target: break
			var p := Vector2(rng.randf_range(-211, -102), rng.randf_range(16, 93)) if region == "ArbresPlaines" else Vector2(rng.randf_range(46, 87), rng.randf_range(-91, -54))
			var close := false
			for other in tree_points:
				if p.distance_to(other) < 8: close = true
			if close: continue
			var hit := safe_ground(p, 5, 2.3 if region == "ArbresPlaines" else 1.1)
			if hit.is_empty(): continue
			var slug := "pin_balaye" if rng.randf() < (0.7 if region == "ArbresPlaines" else 0.2) else "sapin_elance"
			var tree: Node3D = prefabs[slug].instantiate()
			tree.name = "%s_%02d" % [slug, count + 1]
			groups[region].add_child(tree)
			tree.owner = layer
			tree.position = hit.position - Vector3.UP * 0.04
			tree.rotation.y = rng.randf_range(0, TAU)
			tree.scale = Vector3.ONE * rng.randf_range(0.72, 1.12)
			tree_points.append(p)
			samples.append({"kind": "tree", "asset": slug, "position": [tree.position.x, tree.position.y, tree.position.z], "ground_y": hit.position.y, "scale": tree.scale.x, "yaw": tree.rotation.y})
			count += 1
	# Irregular patches, tapering out over the grass/sand transition.
	for patch in range(220):
		var center := Vector2(rng.randf_range(-234, -100), rng.randf_range(20, 111))
		if center.y > 94 and rng.randf() < (center.y - 94) / 20: continue
		var family: Array = SHORT if rng.randf() < 0.68 else TALL
		var category := "HerbesCourtes" if family == SHORT else "HerbesHautes"
		for tuft in range(rng.randi_range(9, 22)):
			var p := center + Vector2(rng.randfn(0, 2.3), rng.randfn(0, 1.5))
			if p.y > 113: continue
			var hit := safe_ground(p, 2.8, 0.22)
			if not hit.is_empty(): add_plant(family[rng.randi_range(0, 2)], hit, category)
	# Ferns and broad leaves gather at the shady edges of the new trees.
	for p in tree_points:
		for i in range(7):
			var point: Vector2 = p + Vector2.from_angle(rng.randf_range(0, TAU)) * rng.randf_range(1.6, 4.2)
			var hit := safe_ground(point, 2.8, 0.3)
			if hit.is_empty(): continue
			var is_fern := rng.randf() < 0.7
			var family: Array = FERNS if is_fern else LEAVES
			add_plant(family[rng.randi_range(0, 2)], hit, "Fougeres" if is_fern else "FeuillesLarges")
	# Original rocky tuft: mountain foothills and the sides of the cave approach.
	for i in range(100):
		var p := Vector2(rng.randf_range(33, 60), rng.randf_range(-64, -42))
		if p.distance_to(Vector2(39.42, -48.26)) < 5: continue
		var hit := safe_ground(p, 2.5, 0.55)
		if hit.is_empty(): continue
		var plant: Node3D = load(ASSETS + "touffe_rocheuse.glb").instantiate()
		plant.name = "TouffeRocheuse_%03d" % i
		groups.TouffesRocheuses.add_child(plant)
		plant.owner = layer
		plant.position = hit.position - Vector3.UP * 0.035
		plant.rotation.y = rng.randf_range(0, TAU)
		plant.scale = Vector3.ONE * rng.randf_range(0.55, 0.95)
		samples.append({"kind": "rocky_tuft", "position": [plant.position.x, plant.position.y, plant.position.z], "ground_y": hit.position.y})
		if groups.TouffesRocheuses.get_child_count() >= 22: break
	for key in batches:
		var batch: Dictionary = batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = foliage_mesh(batch.slug)
		mm.instance_count = batch.transforms.size()
		var center: Vector3 = batch.transforms[0].origin
		for i in range(mm.instance_count):
			var tr: Transform3D = batch.transforms[i]
			tr.origin -= center
			mm.set_instance_transform(i, tr)
		var node := MultiMeshInstance3D.new()
		node.name = str(key).replace("/", "_")
		node.multimesh = mm
		node.position = center
		node.visibility_range_end = 110
		node.visibility_range_end_margin = 15
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		groups[batch.category].add_child(node)
		node.owner = layer
	await process_frame
	await RenderingServer.frame_post_draw
	var packed := PackedScene.new()
	assert(packed.pack(layer) == OK)
	assert(ResourceSaver.save(packed, OUTPUT) == OK)
	var report := {"seed": 15092026, "samples": samples, "batches": batches.size(), "trees": tree_points.size(), "trail_segments": trails.size()}
	FileAccess.open("res://tests/vegetation_placement.json", FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("VEGETATION_BAKED samples=", samples.size(), " trees=", tree_points.size(), " batches=", batches.size())
	layer.free()
	world.queue_free()
	await process_frame
	quit()
