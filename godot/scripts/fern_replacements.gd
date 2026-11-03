@tool
extends RefCounted
## Replace legacy fern surfaces while retaining grass, palms and harvest identities.
const MANIFEST := "res://assets/data/fern_replacements.json"
const SCENE := preload("res://scenes/world/fougeres_detaillees.tscn")
static func apply(world: Node3D) -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for record in data.sources:
		if record.kind!="surface":continue
		var source=world.get_node_or_null(NodePath(record.path)) as MeshInstance3D
		if source==null or source.mesh==null:continue
		var kept: Array[int]=[]
		for s in source.mesh.get_surface_count():
			var material=source.get_active_material(s)
			var label=material.resource_name.to_lower() if material else ""
			if not ("foug" in label or "fern" in label):kept.append(s)
		if kept.size()==source.mesh.get_surface_count():continue
		var clean=ArrayMesh.new()
		for s in kept:
			clean.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,source.mesh.surface_get_arrays(s))
			clean.surface_set_material(clean.get_surface_count()-1,source.get_active_material(s))
		for s in source.get_surface_override_material_count():source.set_surface_override_material(s,null)
		source.mesh=clean
	var old=world.get_node_or_null("VegetationFirstPass/Fougeres") as Node3D
	if old:old.hide()
	if world.get_node_or_null("FougeresDetaillees")==null:
		var plants=SCENE.instantiate()
		world.add_child(plants)
