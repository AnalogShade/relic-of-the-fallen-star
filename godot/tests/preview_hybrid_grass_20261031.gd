extends SceneTree
const OUT = "res://../diagnostics/hybrid_grass_20261031/"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var world = load("res://scenes/world/open_world.tscn").instantiate()
	root.add_child(world)
	for i in 12: await process_frame
	await physics_frame
	var cycle = world.get_node("Original/DayNightCycle")
	cycle.is_paused = true
	cycle.time_of_day = 12.0
	for i in 3: await process_frame
	for node in world.find_children("*", "Node", true, false):
		node.set_process(false)
		node.set_physics_process(false)
	var materials: Array[ShaderMaterial] = []
	var terrains := 0
	for mesh in world.find_children("*", "MeshInstance3D", true, false):
		var mat = mesh.material_override as ShaderMaterial
		if mat != null and mat.shader != null and mat.shader.resource_path in ["res://shaders/world_ground.gdshader","res://shaders/ground.gdshader"]:
			terrains += 1
			if not materials.has(mat): materials.append(mat)
	print("HYBRID_WORLD_BINDINGS terrain_meshes=",terrains," materials=",materials.size())
	for mat in materials:
		if mat.get_shader_parameter("hybrid_grass_enabled") and mat.get_shader_parameter("hybrid_grass_a") == null:
			push_error("Missing hybrid grass texture")
			quit(1)
			return
	var excluded: Array[RID] = []
	for body in world.find_children("*", "CollisionObject3D", true, false):
		if not "Terrain" in str(body.get_path()): excluded.append(body.get_rid())
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.far = 1000.0
	cam.fov = 60.0
	root.size = Vector2i(1280,720)
	var views := [
		["junction",Vector2(-14,1),Vector3(7,6,10)],
		["grass_close",Vector2(-126,-12),Vector3(1,2,2)],
		["riverbank",Vector2(15,-57),Vector3(-5,8,10)],
		["cabin",Vector2(-54,11),Vector3(7,9,12)],
		["western_hills",Vector2(-130,-17),Vector3(7,9,12)],
		["forest_east",Vector2(53,0),Vector3(7,9,12)]
	]
	for view in views:
		var p: Vector2 = view[1]
		var query := PhysicsRayQueryParameters3D.create(Vector3(p.x,150,p.y),Vector3(p.x,-10,p.y),1,excluded)
		var hit := root.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			push_error("No terrain at "+view[0])
			continue
		cam.position = hit.position+view[2]
		cam.look_at(hit.position)
		for enabled in [false,true]:
			for mat in materials: mat.set_shader_parameter("hybrid_grass_enabled",enabled)
			for i in 12: await process_frame
			for layer in root.find_children("*", "CanvasLayer", true, false): layer.hide()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+view[0]+("_after.png" if enabled else "_before.png"))
		print("HYBRID_WORLD_VIEW ",view[0])
	print("HYBRID_WORLD_PREVIEWS_DONE")
	materials.clear()
	world.queue_free()
	cam.queue_free()
	for i in 3: await process_frame
	quit()
