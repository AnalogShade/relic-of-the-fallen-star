@tool
extends RefCounted
## Baked Blender variants share their meshes/textures and use small primitive hulls.
## The imported source GLBs stay intact; only scattered rock surfaces are replaced.
const REPLACEMENTS = preload("res://scenes/world/rocks_blender_replacements.tscn")
const SOURCES := "res://assets/environment/rocks_blender/replacement_sources.json"

static func apply(world: Node3D) -> void:
	if world.get_node_or_null("RochesBlender") != null:
		return
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(SOURCES))
	for record in records:
		var source := world.get_node_or_null(NodePath(record.path)) as MeshInstance3D
		if source == null:
			push_error("Rock replacement source missing: " + str(record.path))
			continue
		var retained_path := str(record.retained_mesh)
		if retained_path.is_empty():
			source.visible = false
		else:
			source.mesh = load(retained_path) as Mesh
		var retained_collision: Shape3D
		if not str(record.retained_collision).is_empty():
			retained_collision = load(str(record.retained_collision)) as Shape3D
		for collision: CollisionShape3D in source.find_children("*", "CollisionShape3D", true, false):
			collision.shape = retained_collision
			collision.disabled = retained_collision == null
	var replacement := REPLACEMENTS.instantiate() as Node3D
	world.add_child(replacement)
