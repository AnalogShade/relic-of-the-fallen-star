extends Node3D
## Assembly for the guardian and harvest anchors on the existing stream ferns.

func _ready() -> void:
	var world := get_parent()
	var cave := world.get_node("GrotteEntree") as Node3D
	var guardian := preload("res://scripts/ogre_guardian.gd").new()
	guardian.name = "OgreGuardian"
	cave.add_child(guardian)
	guardian.position = Vector3(0, 0, 1.25)
	guardian.configure(cave)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/dream_fern_patches.json"))
	var source := world.get_node_or_null(NodePath(str(data.source))) as MeshInstance3D
	if not source or not source.is_visible_in_tree(): return
	for patch in data.patches:
		var harvest := preload("res://scripts/dream_fern_harvest.gd").new()
		harvest.name = str(patch.id)
		harvest.pickup_id = "forest/dream_fern/" + str(patch.id)
		add_child(harvest)
		var p: Array = patch.position
		harvest.global_position = source.to_global(Vector3(float(p[0]), float(p[1]), float(p[2])))
