@tool
extends RefCounted
## The old Blender fog volume was exported as a solid surface in Shrine-col.
## Filter only that surface on a private mesh copy, preserving the original GLB.
static func apply(original: Node) -> void:
	for node in original.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if not instance.mesh is ArrayMesh:
			continue
		var remove: Array[int] = []
		for i in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(i)
			if material != null and material.resource_name.begins_with("Brume"):
				remove.append(i)
		if remove.is_empty():
			continue
		var clean := instance.mesh.duplicate() as ArrayMesh
		clean.shadow_mesh = null
		remove.reverse()
		for i in remove:
			clean.surface_remove(i)
		instance.mesh = clean
		for shape in instance.find_children("*", "CollisionShape3D", true, false):
			shape.shape = clean.create_trimesh_shape()
