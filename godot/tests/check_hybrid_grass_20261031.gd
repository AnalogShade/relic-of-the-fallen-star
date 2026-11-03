extends SceneTree
## Render the actual shader at fixed world coordinates, then compare every
## protected pixel against the original result with image detail disabled.
const OUT = "res://../diagnostics/hybrid_grass_20261031/"

func _initialize() -> void:
	call_deferred("check")

func capture() -> Image:
	for i in 4: await process_frame
	for layer in root.find_children("*", "CanvasLayer", true, false): layer.hide()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func check() -> void:
	root.size = Vector2i(640,640)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(64,64)
	mesh.mesh = plane
	root.add_child(mesh)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 64.0
	root.add_child(cam)
	cam.current = true
	var material := ShaderMaterial.new()
	var source := FileAccess.get_file_as_string("res://shaders/world_ground.gdshader")
	var shader := Shader.new()
	shader.code = source.replace("shader_type spatial;", "shader_type spatial;\nrender_mode unshaded;")
	material.shader = shader
	preload("res://scripts/hybrid_grass_material.gd").configure(material)
	mesh.material_override = material
	var footprint := Image.create(128,128,false,Image.FORMAT_RGF)
	for y in 128:
		for x in 128:
			var coverage := 1.0-smoothstep(0.11,0.18,absf(float(x)/127.0-0.5))
			footprint.set_pixel(x,y,Color(coverage,0,0,1))
	material.set_shader_parameter("stream_footprint",ImageTexture.create_from_image(footprint))
	material.set_shader_parameter("stream_rect",Vector4(-32,-32,64,64))
	var mask_shader := Shader.new()
	var ending := shader.code.rfind("}")
	mask_shader.code = shader.code.substr(0,ending)+"\n ALBEDO=vec3((protected_ground>0.0 || grass_clearance<=0.0 || hybrid_grass_stream_clearance(world_pos)<=0.0) ? 1.0 : 0.0);\n}"
	var edge_shader := Shader.new()
	edge_shader.code = shader.code.substr(0,ending)+"\n ALBEDO=vec3((worn>0.02 && worn<0.65 && protected_ground<=0.0 && hybrid_grass_stream_clearance(world_pos)>0.99) ? 1.0 : 0.0);\n}"
	var views := [
		["forest",Vector3(0,0,0),false],
		["stream",Vector3(0,0,0),true],
		["village",Vector3(-226,12,-32),false],
		["mountain",Vector3(134,20,-80),false],
		["coast",Vector3(0,0,126),false],
		["corrupted",Vector3(-215,5,-188),false],
		["western_grass",Vector3(-130,5,-17),false]
	]
	var report: Array = []
	var total_changed := 0
	var total_edge_changed := 0
	var failed := false
	for view in views:
		mesh.position = view[1]
		cam.position = mesh.position+Vector3(0,60,0)
		cam.look_at(mesh.position,Vector3.FORWARD)
		material.shader = shader
		material.set_shader_parameter("stream_stones_enabled",view[2])
		material.set_shader_parameter("hybrid_grass_enabled",false)
		var before: Image = await capture()
		material.set_shader_parameter("hybrid_grass_enabled",true)
		var after: Image = await capture()
		material.shader = mask_shader
		var mask: Image = await capture()
		material.shader = edge_shader
		var edge_mask: Image = await capture()
		var protected_pixels := 0
		var protected_changed := 0
		var changed := 0
		var edge_pixels := 0
		var edge_changed := 0
		for y in before.get_height():
			for x in before.get_width():
				var different := before.get_pixel(x,y) != after.get_pixel(x,y)
				if different: changed += 1
				if edge_mask.get_pixel(x,y).r > 0.5:
					edge_pixels += 1
					if different: edge_changed += 1
				if mask.get_pixel(x,y).r > 0.5:
					protected_pixels += 1
					if different: protected_changed += 1
		before.save_png(OUT+view[0]+"_surface_before.png")
		after.save_png(OUT+view[0]+"_surface_after.png")
		mask.save_png(OUT+view[0]+"_protected_mask.png")
		report.append({"view":view[0],"changed_grass_pixels":changed,"protected_pixels":protected_pixels,"protected_changed":protected_changed,"grass_transition_pixels":edge_pixels,"textured_transition_pixels":edge_changed})
		total_changed += changed
		total_edge_changed += edge_changed
		failed = failed or protected_changed>0
		print("HYBRID_CHECK ",report.back())
	FileAccess.open(OUT+"surface_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	if failed or total_changed==0 or total_edge_changed==0:
		push_error("Hybrid grass regression: protected surfaces changed or no image detail rendered")
		quit(1)
	else:
		print("HYBRID_SURFACES_PASS")
		quit()
