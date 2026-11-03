@tool
extends RefCounted
## The architecture export accidentally includes a second, solid moat surface.
## Keep Water_Moat as the sole visible water and preserve all building surfaces.
static func apply(world: Node) -> void:
	var architecture := world.get_node_or_null("Sectors/WesternPlains/ChateauDesPlaines/CastleArchitecture") as MeshInstance3D
	if architecture == null or not architecture.mesh is ArrayMesh:
		return
	var remove: Array[int] = []
	for i in architecture.mesh.get_surface_count():
		var material := architecture.mesh.surface_get_material(i)
		if material != null and "Eau des douves" in material.resource_name:
			remove.append(i)
	if remove.is_empty():
		return
	var clean := architecture.mesh.duplicate() as ArrayMesh
	clean.shadow_mesh = null
	remove.reverse()
	for i in remove:
		clean.surface_remove(i)
	architecture.mesh = clean
	for shape in architecture.find_children("*", "CollisionShape3D", true, false):
		shape.shape = clean.create_trimesh_shape()

