extends Node3D

func _ready() -> void:
	_register_ferns()
	_register_cave_mushrooms()
	# The old forest batches mushrooms with ferns. Remove only those surfaces
	# from this instance, then replace them with individually collectible colonies.
	for node in get_parent().get_node("Original").find_children("Undergrowth*", "MeshInstance3D", true, false):
		var clean := ArrayMesh.new()
		for surface in range(node.mesh.get_surface_count()):
			var material: Material = node.mesh.surface_get_material(surface)
			if material and "Champignons" in material.resource_name: continue
			clean.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, node.mesh.surface_get_arrays(surface))
			clean.surface_set_material(clean.get_surface_count() - 1, material)
		node.mesh = clean
	var art: Node3D = load("res://assets/items/mushroom_colonies.glb").instantiate()
	add_child(art)
	for mesh in art.find_children("HarvestColony*", "MeshInstance3D", true, false):
		var center: Vector3 = mesh.global_transform * mesh.get_aabb().get_center()
		var pickup := preload("res://scripts/collectible.gd").new()
		pickup.name = str(mesh.name)
		pickup.pickup_id = "forest/" + str(mesh.name)
		pickup.quantity = 6
		add_child(pickup)
		pickup.global_position = center
		mesh.reparent(pickup, true)

func _register_cave_mushrooms() -> void:
	var flora := get_parent().get_node_or_null("GrotteEntree/Flora")
	if flora == null: return
	for plant in flora.get_children():
		if not str(plant.name).begins_with("GroundedMushroom"): continue
		var pickup := preload("res://scripts/collectible.gd").new()
		pickup.name = str(plant.name) + "Harvest"
		pickup.pickup_id = "cave/" + str(plant.name)
		add_child(pickup)
		pickup.global_position = plant.global_position
		# The model origin is buried below the ground; aim at the visible cap.
		for mesh in plant.find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.get_aabb()
			var cap: Vector3 = mesh.to_global(bounds.get_center() + Vector3.UP * bounds.size.y * 0.5)
			if cap.y > pickup.global_position.y:
				pickup.global_position = cap + Vector3.UP * 0.1
		plant.reparent(pickup, true)

func _register_ferns() -> void:
	# Preserve all legacy identifiers and positions after their geometry is replaced.
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/fern_replacements.json"))
	var existing := {}
	for plant in get_tree().get_nodes_in_group("dream_fern"):
		existing[plant.pickup_id] = true
	for entry in data.pickups:
		if existing.has(entry.id): continue
		var pickup := preload("res://scripts/dream_fern_harvest.gd").new()
		pickup.pickup_id = entry.id
		add_child(pickup)
		var point: Array = entry.position
		pickup.global_position = Vector3(point[0], point[1], point[2])
