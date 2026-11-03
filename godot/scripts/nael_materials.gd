extends RefCounted
## Nael's texture has no transparent cutouts. Render the body in the opaque
## pass so intersecting water tests its depth per pixel instead of object order.
static func apply(model: Node) -> void:
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		if mesh.mesh == null:
			continue
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface) as BaseMaterial3D
			if source == null or source.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
				continue
			var material := source.duplicate() as BaseMaterial3D
			material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			mesh.set_surface_override_material(surface, material)
