extends SceneTree
const DIR := "res://assets/environment/vegetation/"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func save_scene(node: Node, path: String) -> void:
	var packed := PackedScene.new()
	assert(packed.pack(node) == OK)
	assert(ResourceSaver.save(packed, path) == OK)

func own(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		own(child, owner_node)

func run() -> void:
	# Build reusable game prefab and replace the existing scattered fir prefab.
	var model := load(DIR + "sapin_alpha.glb") as PackedScene
	assert(model != null)
	var tree := Node3D.new(); tree.name = "SapinAlpha"
	var visual := model.instantiate() as Node3D; visual.name = "Visual"; tree.add_child(visual); visual.owner = tree
	var body := StaticBody3D.new(); body.name = "Tronc"; body.collision_mask = 0; tree.add_child(body); body.owner = tree
	var collision := CollisionShape3D.new(); collision.name = "CapsuleTronc"; body.add_child(collision); collision.owner = tree
	var capsule := CapsuleShape3D.new(); capsule.radius = .19; capsule.height = 5.5
	collision.shape = capsule; collision.position.y = 2.75
	save_scene(tree, "res://scenes/vegetation/sapin_alpha.tscn")
	tree.name = "SapinElance"; visual.scale = Vector3.ONE * (4.4 / 6.1415615)
	capsule.radius = .15; capsule.height = 4.4; collision.position.y = 2.2
	save_scene(tree, "res://scenes/vegetation/sapin_elance.tscn")
	tree.free()
	# Remove only the three audited legacy fir materials from the combined castle mesh.
	var castle := (load("res://assets/environment/world/chateau_des_plaines.glb") as PackedScene).instantiate()
	var old := castle.find_child("CastlePreserved", true, false) as MeshInstance3D
	assert(old != null)
	var clean := old.mesh.duplicate() as ArrayMesh
	clean.shadow_mesh = null
	var removed := 0
	for i in range(clean.get_surface_count()-1,-1,-1):
		var mat := clean.surface_get_material(i)
		if mat != null and mat.resource_name in ["Mat_Tronc", "Mat_Feuilles_Vert", "Mat_Feuilles_Fonce"]:
			clean.surface_remove(i); removed += 1
	assert(removed == 3)
	assert(ResourceSaver.save(clean, DIR + "castle_without_old_pines.res") == OK)
	assert(ResourceSaver.save(clean.create_trimesh_shape(), DIR + "castle_without_old_pines_shape.res") == OK)
	castle.free()
	# Place the nine replacements plus the approved test exemplar at their exact world transforms.
	var group := Node3D.new(); group.name = "SapinsChateau"
	var prefab := load("res://scenes/vegetation/sapin_alpha.tscn") as PackedScene
	var records: Array = JSON.parse_string(FileAccess.get_file_as_string(DIR + "sapins_chateau.json"))
	for record in records:
		var inst := prefab.instantiate() as Node3D; inst.name = "SapinInterieur_%02d" % (group.get_child_count()+1)
		group.add_child(inst); inst.owner = group
		inst.position = Vector3(record.position[0], record.position[1], record.position[2])
		inst.rotation.y = record.yaw; inst.scale = Vector3(record.scale[0], record.scale[1], record.scale[2])
	save_scene(group, "res://scenes/world/sapins_chateau.tscn")
	group.free()
	print("PINE_PREFABS_READY: 10 castle instances, 8 scattered firs, 3 legacy surfaces removed")
	quit()
