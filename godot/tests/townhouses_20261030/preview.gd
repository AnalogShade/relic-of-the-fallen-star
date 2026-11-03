extends SceneTree

func _initialize() -> void:
	call_deferred("build")

func build() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	for ui in root.find_children("*", "CanvasLayer", true, false):
		ui.hide()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("829eb4")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("c1d3df")
	e.ambient_light_energy = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48,-32,0)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	stage.add_child(sun)
	var cam := Camera3D.new()
	cam.far = 1200
	stage.add_child(cam)
	cam.make_current()
	var house := load("res://scenes/world/maison_colombages_01.tscn").instantiate() as Node3D
	stage.add_child(house)
	for i in range(4):
		var a := i * PI/2
		cam.position = Vector3(sin(a)*13,7,cos(a)*13)
		cam.look_at(Vector3(0,3.5,0))
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/townhouses_20261030/model_%d.png" % i)
	house.queue_free()
	await process_frame
	var quarter := load("res://scenes/world/western_plains.tscn").instantiate() as Node3D
	var merchant := quarter.get_node_or_null("Merrick")
	if merchant:
		quarter.remove_child(merchant)
		merchant.free()
	var sectors := Node3D.new()
	sectors.name = "Sectors"
	stage.add_child(sectors)
	sectors.add_child(quarter)
	load("res://scripts/pine_foliage.gd").apply(stage)
	load("res://scripts/castle_moat_cleanup.gd").apply(stage)
	var ground := ShaderMaterial.new()
	ground.shader = load("res://shaders/world_ground.gdshader")
	for mesh in quarter.find_children("CastleGround*", "MeshInstance3D",true,false):
		mesh.material_override = ground
	await physics_frame
	await physics_frame
	var validation: Array = []
	for name in ["MaisonColombages_02", "MaisonColombages_04", "MaisonColombages_05"]:
		var building := quarter.get_node(name) as Node3D
		var bodies := building.find_children("*", "StaticBody3D", true, false)
		assert(bodies.size() == 1, "Each house requires one collision body")
		var query := PhysicsRayQueryParameters3D.create(building.global_position + Vector3(0,15,0), building.global_position - Vector3(0,2,0))
		var roof := quarter.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not roof.is_empty() and building.is_ancestor_of(roof.collider), "Roof collision must belong to replacement house")
		query.exclude = [bodies[0].get_rid()]
		var floor_hit := quarter.get_world_3d().direct_space_state.intersect_ray(query)
		assert(not floor_hit.is_empty(), "Ground must remain below replacement")
		assert(absf(floor_hit.position.y - building.global_position.y) < 0.05, "House base must rest on ground")
		validation.append({"house":name,"scale":building.scale.x,"roof_y":roof.position.y,"ground_y":floor_hit.position.y,"base_y":building.global_position.y,"collision":true})
	var report := FileAccess.open("res://tests/townhouses_20261030/validation.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(validation,"\t"))
	report.close()
	var points := [Vector3(-210,33,16),Vector3(-222,19,-12),Vector3(-231,20,-25),Vector3(-207,19,-13)]
	var targets := [Vector3(-232,15,-14),Vector3(-228.49,16,-4.69),Vector3(-246.03,16,-15.64),Vector3(-218.27,16,-18.76)]
	for i in range(points.size()):
		cam.position = points[i]
		cam.look_at(targets[i])
		for f in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://tests/townhouses_20261030/quarter_%d.png" % i)
	print("TOWNHOUSE_PREVIEW_COMPLETE")
	stage.queue_free()
	await process_frame
	call_deferred("quit")
