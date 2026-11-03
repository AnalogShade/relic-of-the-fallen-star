extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://assets/spells/fireball.glb")
	var inst: Node3D = scene.instantiate() as Node3D
	var mesh_inst: MeshInstance3D = inst.find_child("Fireball_Body", true, false) as MeshInstance3D
	if mesh_inst and mesh_inst.mesh:
		var aabb: AABB = mesh_inst.mesh.get_aabb()
		print("FIREBALL AABB:", aabb)
		print("Position min:", aabb.position)
		print("Position max:", aabb.end)
	inst.free()
	quit(0)
