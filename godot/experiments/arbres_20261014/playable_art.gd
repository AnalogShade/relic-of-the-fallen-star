@tool
extends "res://scripts/environment.gd"

func _ready() -> void:
	super._ready()
	for mesh: MeshInstance3D in find_children("TEST*", "MeshInstance3D", true, false):
		var name_text := str(mesh.name)
		if name_text.begins_with("TEST_Wood") or name_text.begins_with("TEST_Rock"):
			for shape: CollisionShape3D in mesh.find_children("*", "CollisionShape3D", true, false):
				shape.shape = mesh.mesh.create_trimesh_shape()
		elif name_text.begins_with("TEST_Leaves"):
			for surface in range(mesh.mesh.get_surface_count()):
				var leaves := mesh.get_active_material(surface).duplicate() as StandardMaterial3D
				leaves.albedo_color = Color(1.12, 1.25, 1.02)
				mesh.set_surface_override_material(surface, leaves)
