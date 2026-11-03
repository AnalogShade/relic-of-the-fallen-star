extends SceneTree
const OUT = "res://../diagnostics/mountain_ground_20261102/"

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
	print("MOUNTAIN_WORLD_BINDINGS terrain_meshes=",terrains," materials=",materials.size())
	for mat in materials:
		if mat.get_shader_parameter("mountain_textures_enabled") and mat.get_shader_parameter("mountain_granite") == null:
			push_error("Missing mountain texture")
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
		["schist_summit",Vector2(68,-78),Vector3(18,15,25)],
		["high_pass",Vector2(126,-35),Vector3(-26,18,35)],
		["northern_ridge",Vector2(-64,-130),Vector3(18,17,24)],
		["rock_close",Vector2(70,-78),Vector3(3,3,4)],
		["forest_paths",Vector2(-14,1),Vector3(7,6,10)]
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
		for mode in 4:
			var enabled = mode != 0
			for mat in materials: mat.set_shader_parameter("mountain_mask_preview",maxi(0,mode-1))
			for mat in materials: mat.set_shader_parameter("mountain_textures_enabled",enabled)
			for i in 12: await process_frame
			for layer in root.find_children("*", "CanvasLayer", true, false): layer.hide()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+view[0]+["_before.png","_after.png","_mountain_mask.png","_snow_mask.png"][mode])
		print("MOUNTAIN_WORLD_VIEW ",view[0])
	print("MOUNTAIN_WORLD_PREVIEWS_DONE")
	materials.clear()
	world.queue_free()
	cam.queue_free()
	for i in 3: await process_frame
	quit()

