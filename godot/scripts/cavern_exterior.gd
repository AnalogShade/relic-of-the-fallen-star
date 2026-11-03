@tool
extends Node3D
## Keep the source asset reusable. Darkness is an editable scene instance.

func _ready() -> void:
	for mesh: MeshInstance3D in $Art.find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = null
		# The edited stone floor is inclined; physics follows the actual static mesh.
		if not $Collisions.has_node("CaveSurface"):
			var shape := CollisionShape3D.new()
			shape.name = "CaveSurface"
			shape.shape = mesh.mesh.create_trimesh_shape()
			$Collisions.add_child(shape)
			shape.transform = $Collisions.global_transform.affine_inverse() * mesh.global_transform
