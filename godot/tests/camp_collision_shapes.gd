extends RefCounted
## Authoring helper only. Visual meshes are independent of cheap physics proxies.

static func add_shape(body: StaticBody3D, shape: Shape3D, center: Vector3, label: String) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.name = label
	node.shape = shape
	node.position = center
	body.add_child(node)
	return node

static func add_upright_cylinder(body: StaticBody3D, radius: float, height: float, center: Vector3, label: String) -> void:
	# Keep the footprint upright even when the visual mesh follows the slope.
	var counter_rotation := body.get_parent_node_3d().basis.orthonormalized().inverse()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = height
	var collider := add_shape(body, cylinder, counter_rotation * center, label)
	collider.basis = counter_rotation

static func create(prop: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	body.name = str(prop.name)+"_col"
	prop.add_child(body)
	var bounds := prop.get_aabb()
	var center := bounds.get_center()
	var size := bounds.size
	if "Banniere" in str(prop.name):
		# Fit the main cluster of rocks under the banner.
		add_upright_cylinder(body, 0.235, 0.135, Vector3(0.016, 0.05, -0.02), "Socle")
	elif "Feu_Camp" in str(prop.name):
		add_upright_cylinder(body, 0.158, 0.064, Vector3(-0.003, 0.027, 0.004), "Cylinder")
	elif "Torche" in str(prop.name):
		add_upright_cylinder(body, 0.016, 0.09, Vector3(0.0035, 0.035, -0.0007), "Cylinder")
	elif "Billot" in str(prop.name):
		# Billot avec hache : cylindre adapté au tronc du billot lui-même (rayon ~0.42m dans le monde),
		# évitant les murs invisibles au-dessus des petits cailloux au sol.
		var cylinder := CylinderShape3D.new()
		cylinder.radius = 0.085
		cylinder.height = 0.18
		add_shape(body, cylinder, Vector3(-0.007, 0.09, 0.026), "Cylinder")
	elif "Buche_Debout" in str(prop.name):
		# Petite bûche décorative au sol (35cm) : aucun collider pour ne pas coincer le joueur contre le billot.
		body.queue_free()
		return
	else:
		var box := BoxShape3D.new()
		box.size = size
		add_shape(body,box,center,"Box")
