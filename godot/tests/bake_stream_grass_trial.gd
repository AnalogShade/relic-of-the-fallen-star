extends SceneTree
## Rebuild after editing control maps; source model/texture refresh needs no rebuild.
const DIR = "res://assets/environment/stream_grass_trial/"
var settings: Dictionary
var allowed: Image
var rect: Rect2

func _initialize() -> void:
	call_deferred("run")

func read_image(path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	assert(image != null, "Missing map: "+path)
	return image

func sample(image: Image, p: Vector2) -> float:
	var uv := (p-rect.position)/rect.size
	if uv.x < 0 or uv.y < 0 or uv.x >= 1 or uv.y >= 1:
		return 0.0
	return image.get_pixel(clampi(int(uv.x*image.get_width()),0,image.get_width()-1),clampi(int(uv.y*image.get_height()),0,image.get_height()-1)).r

func footprint_allowed(p: Vector2, radius: float) -> bool:
	# Check the whole footprint, not just its root, so blades do not cross trails.
	var steps := ceili(radius/.09)
	for z in range(-steps,steps+1):
		for x in range(-steps,steps+1):
			var delta := Vector2(x,z)*.09
			if delta.length() <= radius+.07 and sample(allowed,p+delta) < .99:
				return false
	return true

func run() -> void:
	settings = JSON.parse_string(FileAccess.get_file_as_string(DIR+"settings.json"))
	var r: Array = settings.rect
	rect = Rect2(r[0],r[1],r[2],r[3])
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIR+"catalog.json"))
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	world.set_meta("disable_stream_grass_trial",true)
	root.add_child(world)
	for i in 16: await process_frame
	await physics_frame
	# Compile a diagnostic copy of the actual ground material. Authoritative
	# paths, their noise, and the real water/gravel footprint are never rewritten.
	var shader := Shader.new()
	var code := FileAccess.get_file_as_string("res://shaders/world_ground.gdshader")
	code = code.replace("shader_type spatial;","shader_type spatial;\nrender_mode unshaded;")
	shader.code = code.substr(0,code.rfind("}"))+"\n ALBEDO=vec3((protected_ground<=0.0 && worn<0.001 && hybrid_grass_stream_clearance(world_pos)>0.999 && slope<0.18) ? 1.0 : 0.0);\n}"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	viewport.add_child(environment)
	var material: ShaderMaterial
	var copies := 0
	for terrain: MeshInstance3D in world.find_children("Terrain*","MeshInstance3D",true,false):
		if terrain.mesh == null:
			continue
		var bounds: AABB = terrain.global_transform*terrain.get_aabb()
		if not rect.intersects(Rect2(bounds.position.x,bounds.position.z,bounds.size.x,bounds.size.z)):
			continue
		if material == null:
			material = terrain.material_override.duplicate()
			material.shader = shader
		var copy := MeshInstance3D.new()
		copy.mesh = terrain.mesh
		copy.transform = terrain.global_transform
		copy.material_override = material
		viewport.add_child(copy)
		copies += 1
	var cam := Camera3D.new()
	viewport.add_child(cam)
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = rect.size.x
	cam.far = 300
	var center := rect.get_center()
	cam.position = Vector3(center.x,150,center.y)
	cam.look_at(Vector3(center.x,0,center.y),Vector3.FORWARD)
	cam.current = true
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	allowed = viewport.get_texture().get_image()
	allowed.save_png(DIR+"maps/allowed_ground.png")
	var density := read_image(settings.density_map)
	var size_map := read_image(settings.size_map)
	var field_map := read_image(settings.field_map)
	var probabilities: Array[Image] = []
	for entry in catalog.variants:
		probabilities.append(read_image(entry.probability_map))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(settings.seed)
	var placements := {}
	var counts := {"base":0,"tuft":0,"tall":0}
	var total := 0
	var rejected := {"density":0,"ground":0,"obstacle":0}
	var spacing := float(settings.spacing)
	for z in range(floori(rect.size.y/spacing)):
		for x in range(floori(rect.size.x/spacing)):
			var p := rect.position+(Vector2(x,z)+Vector2(rng.randf_range(.1,.9),rng.randf_range(.1,.9)))*spacing
			if rng.randf() > sample(density,p):
				rejected.density += 1
				continue
			var weights: Array[float] = []
			var sum := 0.0
			for i in catalog.variants.size():
				var weight := maxf(0.0,float(catalog.variants[i].weight))*sample(probabilities[i],p)
				if catalog.variants[i].family == "tall":
					weight *= .08+sample(field_map,p)
				weights.append(weight)
				sum += weight
			if sum <= 0:
				continue
			var pick := rng.randf()*sum
			var index := weights.size()-1
			for i in weights.size():
				pick -= weights[i]
				if pick <= 0:
					index = i
					break
			var entry: Dictionary = catalog.variants[index]
			var height := lerpf(float(entry.height_min),float(entry.height_max),clampf(sample(size_map,p)+rng.randf_range(-.14,.14),0,1))
			var radius := height*float(entry.get("radius_per_height",2.0))+.12
			if not footprint_allowed(p,radius):
				rejected.ground += 1
				continue
			var hit := root.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,80,p.y),Vector3(p.x,-15,p.y),1))
			if hit.is_empty() or not "Terrain" in str(hit.collider.get_path()):
				rejected.obstacle += 1
				continue
			var position: Vector3 = hit.position
			var normal: Vector3 = hit.normal
			if normal.y < .94:
				continue
			if not placements.has(entry.id): placements[entry.id] = []
			placements[entry.id].append([position.x,position.y,position.z,normal.x,normal.y,normal.z,rng.randf()*TAU,height])
			counts[entry.family] += 1
			total += 1
	assert(total > 100,"Trial mask produced too few placements")
	var layout := {"rect":settings.rect,"seed":settings.seed,"total":total,"counts":counts,"placements":placements}
	FileAccess.open(DIR+"layout.json",FileAccess.WRITE).store_string(JSON.stringify(layout))
	var report := {"total":total,"counts":counts,"variants_used":placements.size(),"terrain_copies":copies,"rejected":rejected,"rect":settings.rect}
	FileAccess.open("res://../diagnostics/stream_grass_trial/bake_report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("STREAM_GRASS_BAKE ",JSON.stringify(report))
	viewport.queue_free()
	world.queue_free()
	material = null
	shader = null
	for i in 3: await process_frame
	quit()
