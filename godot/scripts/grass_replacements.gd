@tool
extends RefCounted
## Replace only the legacy grass surfaces; preserve other plants and collisions.
const MANIFEST := "res://assets/data/grass_replacements.json"
const SCENE := preload("res://scenes/world/herbes_detaillees.tscn")

static func apply(world: Node3D) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for record in data.sources:
		var source=world.get_node_or_null(NodePath(record.path)) as MeshInstance3D
		if source==null or source.mesh==null: continue
		var kept: Array[int]=[]
		for s in source.mesh.get_surface_count():
			var material=source.get_active_material(s)
			var label=material.resource_name if material else ""
			if not label.begins_with("Herbes lumi"): kept.append(s)
		if kept.size()==source.mesh.get_surface_count(): continue
		var clean=ArrayMesh.new()
		for s in kept:
			clean.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.mesh.surface_get_arrays(s))
			clean.surface_set_material(clean.get_surface_count()-1,source.get_active_material(s))
		for s in source.get_surface_override_material_count(): source.set_surface_override_material(s,null)
		source.mesh=clean
	if world.get_node_or_null("HerbesDetaillees")==null:
		world.add_child(SCENE.instantiate())
