@tool
extends RefCounted
## Clear instanced plants as well as the baked trees in trails_20261021.
const TRAILS = preload("res://scripts/forest_trails.gd")

static func _distance(p: Vector3) -> float:
	return TRAILS.distance_to_path(Vector2(p.x, p.z))

static func _hide_obstacle(node: Node) -> void:
	if node is Node3D:
		node.visible = false
	for body in node.find_children("*", "CollisionObject3D", true, false):
		body.collision_layer = 0
		body.collision_mask = 0

static func _variant_group(name_text: String) -> int:
	var suffix := name_text.get_slice("_", name_text.get_slice_count("_") - 1)
	var number := suffix.to_int() if suffix.is_valid_int() else 0
	if "Tronc" in name_text: return number
	if "Racine" in name_text: return number / 5
	if "Branche" in name_text: return number / 7
	if "Leaves" in name_text: return number / 8
	return -1

static func apply(world: Node) -> void:
	if world.has_meta("trails_cleared_20261021"):
		return
	world.set_meta("trails_cleared_20261021", true)
	var variants := world.get_node_or_null("Original/EnvironmentArt/TreeVariants")
	if variants != null:
		var bases := {}
		var blocked := {}
		for node in variants.get_children():
			if node is MeshInstance3D and "TEST_Wood_Tronc" in str(node.name):
				var group := _variant_group(str(node.name))
				bases[group] = (node.global_transform * node.get_aabb().position).y
		for node in variants.get_children():
			if not node is MeshInstance3D or not str(node.name).begins_with("TEST_Wood"):
				continue
			var group := _variant_group(str(node.name))
			if not bases.has(group): continue
			for i in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(i)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					var point: Vector3 = node.global_transform * vertex
					if point.y < bases[group] + 1.6 and _distance(point) < 1.65:
						blocked[group] = true
		for node in variants.get_children():
			if blocked.has(_variant_group(str(node.name))):
				_hide_obstacle(node)
		world.set_meta("trail_variant_trees_removed", blocked.size())
		for node in variants.get_children():
			if not node is MeshInstance3D or not str(node.name).begins_with("TEST_Rock"):
				continue
			var overlaps := false
			for i in node.mesh.get_surface_count():
				var arrays: Array = node.mesh.surface_get_arrays(i)
				for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
					if _distance(node.global_transform * vertex) < 1.65:
						overlaps = true
			if overlaps: _hide_obstacle(node)


	var vegetation := world.get_node_or_null("VegetationFirstPass")
	if vegetation == null: return
	var removed := 0
	for group_name in ["ArbresPlaines", "ArbresMontagne", "TouffesRocheuses"]:
		var group := vegetation.get_node_or_null(group_name)
		if group == null: continue
		for plant in group.get_children():
			if plant is Node3D and _distance(plant.global_position) < 3.0:
				_hide_obstacle(plant)
				removed += 1
	world.set_meta("trail_instance_obstacles_removed", removed)
	var cleared := 0
	for plant in vegetation.find_children("*", "MultiMeshInstance3D", true, false):
		if plant.multimesh == null: continue
		var source: MultiMesh = plant.multimesh
		var keep: Array[int] = []
		for i in source.instance_count:
			var point: Vector3 = plant.global_transform * source.get_instance_transform(i).origin
			if _distance(point) > 2.65:
				keep.append(i)
		if keep.size() == source.instance_count: continue
		var clean := MultiMesh.new()
		clean.transform_format = source.transform_format
		clean.use_colors = source.use_colors
		clean.use_custom_data = source.use_custom_data
		clean.mesh = source.mesh
		clean.instance_count = keep.size()
		for i in keep.size():
			clean.set_instance_transform(i, source.get_instance_transform(keep[i]))
			if source.use_colors: clean.set_instance_color(i, source.get_instance_color(keep[i]))
			if source.use_custom_data: clean.set_instance_custom_data(i, source.get_instance_custom_data(keep[i]))
		cleared += source.instance_count - keep.size()
		plant.multimesh = clean
	world.set_meta("trail_groundcover_removed", cleared)
