extends SceneTree
## Render the production shader: snow must stay inside mountain coverage and
## pixels outside the mountain mask must remain identical when enabled.
const OUT = "res://../diagnostics/mountain_ground_20261102/"

func _initialize() -> void:
	call_deferred("check")

func capture() -> Image:
	for i in 4: await process_frame
	for layer in root.find_children("*", "CanvasLayer", true, false): layer.hide()
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func check() -> void:
	root.size = Vector2i(320,320)
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(48,48)
	mesh.mesh = plane
	root.add_child(mesh)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 48.0
	cam.current = true
	root.add_child(cam)
	var material := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = FileAccess.get_file_as_string("res://shaders/world_ground.gdshader").replace("shader_type spatial;","shader_type spatial;\nrender_mode unshaded;")
	shader.code = shader.code.replace("ALBEDO=vec3(mountain_mask);", "ALBEDO=vec3(mountain_mask>.001 ? 1.0 : 0.0);")
	material.shader = shader
	preload("res://scripts/hybrid_grass_material.gd").configure(material)
	preload("res://scripts/mountain_ground_material.gd").configure(material)
	mesh.material_override = material
	var views := [
		["forest",Vector3(0,0,0)],
		["western_grass",Vector3(-130,5,-17)],
		["desert",Vector3(196,8,-60)],
		["coast",Vector3(0,0,126)],
		["corrupted",Vector3(-215,5,-188)],
		["mountain_transition",Vector3(110,28,-70)],
		["summit",Vector3(126,55,-35)]
	]
	var report: Array = []
	var failures := 0
	var total_changed := 0
	var total_snow := 0
	for view in views:
		mesh.position = view[1]
		cam.position = mesh.position+Vector3(0,80,0)
		cam.look_at(mesh.position,Vector3.FORWARD)
		material.set_shader_parameter("mountain_mask_preview",0)
		material.set_shader_parameter("mountain_textures_enabled",false)
		var before := await capture()
		material.set_shader_parameter("mountain_textures_enabled",true)
		var after := await capture()
		material.set_shader_parameter("mountain_mask_preview",1)
		var mask := await capture()
		material.set_shader_parameter("mountain_mask_preview",2)
		var snow := await capture()
		var changed := 0
		var protected_changes := 0
		var snow_pixels := 0
		var snow_outside := 0
		for y in 320:
			for x in 320:
				var different := before.get_pixel(x,y) != after.get_pixel(x,y)
				if different: changed += 1
				if mask.get_pixel(x,y).r == 0.0 and different: protected_changes += 1
				if snow.get_pixel(x,y).r > 0.0: snow_pixels += 1
				if snow.get_pixel(x,y).r > mask.get_pixel(x,y).r+.005: snow_outside += 1
		if protected_changes > 0 or snow_outside > 0: failures += 1
		if view[0] in ["forest","western_grass","desert","coast","corrupted"] and changed>0: failures += 1
		total_changed += changed
		total_snow += snow_pixels
		report.append({"view":view[0],"changed":changed,"outside_mask_changed":protected_changes,"snow_pixels":snow_pixels,"snow_outside_mountain":snow_outside})
		for entry in [["before",before],["after",after],["mountain_mask",mask],["snow_mask",snow]]:
			entry[1].save_png(OUT+view[0]+"_surface_"+entry[0]+".png")
		print("MOUNTAIN_CHECK ",report.back())
	if total_changed == 0 or total_snow == 0: failures += 1
	var file := FileAccess.open(OUT+"surface_validation.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures":failures,"views":report},"\t"))
	print("MOUNTAIN_CHECK_DONE failures=",failures)
	quit(0 if failures==0 else 1)
