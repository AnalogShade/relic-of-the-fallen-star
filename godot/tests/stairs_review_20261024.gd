extends SceneTree

func _initialize():
	call_deferred("run")

func run():
	var w = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(w)
	for i in range(70): await process_frame
	var tower = w.get_node("Vigie")
	var before = "--before" in OS.get_cmdline_user_args()
	tower.nouvelles_marches = not before
	w.get_node("Original/HUD").hide()
	var cam = Camera3D.new()
	w.add_child(cam)
	cam.current = true
	cam.far = 450
	cam.fov = 60
	var route = JSON.parse_string(FileAccess.get_file_as_string("res://tests/vigie_route.json")).route
	var views = [
		["ensemble", Vector3(21,63,-34), Vector3(63,25,-74)],
		["depart", Vector3(43,17,-39), Vector3(53,11,-49)],
		["flanc", Vector3(91,35,-75), Vector3(78,27,-78)],
		["sommet", Vector3(77,50,-59), Vector3(65,43,-69)]
	]
	for view in views:
		cam.position = view[1]
		cam.look_at(view[2])
		for i in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../diagnostics/stairs_20261024/" + ("avant_" if before else "apres_") + view[0] + ".png")
	var misses = []
	for i in range(route.size()):
		var p = route[i]
		var ray = PhysicsRayQueryParameters3D.create(Vector3(p[0],p[2]+.3,-p[1]),Vector3(p[0],p[2]-.2,-p[1]),1)
		var hit = w.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or not "VigieAscent" in str(hit.collider.get_path()): misses.append(i)
	var report = {"route_samples": route.size(), "collision_misses": misses, "old_mesh_visible": tower.find_children("VigieSteps*","MeshInstance3D",true,false)[0].visible, "new_visible": tower.get_node("MarchesNaturelles").visible}
	FileAccess.open("res://../diagnostics/stairs_20261024/"+("baseline" if before else "validation")+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("STAIRS_REVIEW ",JSON.stringify(report))
	quit()
