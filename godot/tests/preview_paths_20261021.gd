extends SceneTree
func _initialize(): call_deferred("run")
func run():
	var scene = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	var cycle = scene.get_node("Original/DayNightCycle")
	cycle.is_paused = true
	cycle.time_of_day = 12.0
	var cam = Camera3D.new()
	scene.add_child(cam)
	cam.current = true
	cam.far = 1000
	cam.fov = 48
	for n in root.find_children("*", "CanvasLayer", true, false): n.visible = false
	print("CLEARANCE ",scene.get_meta("trail_variant_trees_removed",0)," variants, ",scene.get_meta("trail_groundcover_removed",0)," plants")
	var views = [["river_link_final",Vector3(-21,25,18),Vector3(-18,1,1)],["cabin_cliff_final",Vector3(-51,35,-24),Vector3(-56,10,-1)],["cabin_after",Vector3(-54,35,22),Vector3(-54,10,3)],["river_after",Vector3(-22,45,34),Vector3(-23,1,0)]]
	for view in views:
		cam.position = view[1]
		cam.look_at(view[2])
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://../diagnostics/paths_20261021/"+view[0]+".png")
	print("RENDER_DONE")
	quit()
