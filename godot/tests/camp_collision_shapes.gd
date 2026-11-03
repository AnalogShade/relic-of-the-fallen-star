extends RefCounted
## Authoring helper only. Visual meshes are independent of cheap physics proxies.

static func add_shape(body: StaticBody3D, shape: Shape3D, center: Vector3, label: String) -> void:
	var node := CollisionShape3D.new()
	node.name = label
	node.shape = shape
	node.position = center
	body.add_child(node)

static func create(prop: MeshInstance3D) -> void:
	var body := StaticBody3D.new()
	body.name = str(prop.name)+"_col"
	prop.add_child(body)
	var bounds := prop.get_aabb()
	var center := bounds.get_center()
	var size := bounds.size
	if "Banniere" in str(prop.name):
		# The cloth is not an invisible wall: collide with the rock base and mast.
		var base := BoxShape3D.new()
		base.size = Vector3(size.x, minf(size.y,.17), size.z)
		add_shape(body,base,Vector3(center.x,bounds.position.y+base.size.y/2,center.z),"Socle")
		var pole := CylinderShape3D.new()
		pole.radius = .016
		pole.height = size.y
		var top := AABB()
		var found := false
		for s in range(prop.mesh.get_surface_count()):
			for v in prop.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				if v.y < bounds.end.y-.025: continue
				if not found:
					top = AABB(v,Vector3.ZERO)
					found = true
				else: top = top.expand(v)
		var mast := top.get_center() if found else center
		add_shape(body,pole,Vector3(mast.x,center.y,mast.z),"Mat")
	elif "Feu_Camp" in str(prop.name) or "Torche" in str(prop.name):
		var cylinder := CylinderShape3D.new()
		cylinder.radius = maxf(size.x,size.z)*.44
		cylinder.height = minf(size.y,.10) if "Feu_Camp" in str(prop.name) else size.y
		add_shape(body,cylinder,Vector3(center.x,bounds.position.y+cylinder.height/2,center.z),"Cylinder")
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
