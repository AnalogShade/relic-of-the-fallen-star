@tool
extends RefCounted
## Baked alpha-cutout crowns, applied after path/rock clearance.
## Only audited broadleaf surfaces are replaced. Palm fronds and wood stay intact.
const MANIFEST := "res://assets/environment/foliage_alpha/manifest.json"

static func apply(world: Node3D) -> void:
	var items: Array = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	for item in items:
		var node := world.get_node_or_null(NodePath(item.path)) as MeshInstance3D
		if node == null or node.mesh == null:
			push_error("Broadleaf foliage target missing: " + str(item.path))
			continue
		if node.mesh.resource_path == str(item.mesh): continue
		var overrides := []
		for s in node.mesh.get_surface_count():
			if not item.removed_surfaces.has(float(s)):
				overrides.append(node.get_surface_override_material(s))
		node.mesh = load(str(item.mesh)) as Mesh
		for s in node.mesh.get_surface_count():
			node.set_surface_override_material(s, overrides[s] if s < overrides.size() else null)
