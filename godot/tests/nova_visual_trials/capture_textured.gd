extends SceneTree
const OUT := "res://tests/nova_visual_trials/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1280, 720)
	var stage = load("res://tests/primordial_nova_preview.tscn").instantiate()
	root.add_child(stage)
	current_scene = stage
	for i in range(12): await physics_frame
	stage.actor.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = stage.get_viewport().get_camera_3d()
	camera.position = Vector3(8, 9, 11)
	camera.look_at(Vector3(0, 0.5, 0))
	var title: Label = stage.get_children().filter(func(n): return n is CanvasLayer)[0].get_child(0)
	for variant in ["reference", "textured", "layered"]:
		title.text = {"reference": "A · NOVA ORIGINALE", "textured": "B · TEXTURE ALPHA + ROTATION", "layered": "C · TROIS COUCHES + ROTATION + AURA"}[variant] + "\nMême caméra et même instant · Compatibilité OpenGL"
		var nova = load("res://scripts/spells/primordial_nova.gd").new()
		seed(123)
		stage.add_child(nova)
		nova.global_position = stage.actor.global_position
		nova.set_physics_process(false)
		if variant != "layered":
			nova.get_node("EnergyVeil0").hide()
			nova.get_node("EnergyVeil1").hide()
			nova.aura.hide()
		if variant == "reference":
			nova.get_child(0).mesh.size = Vector2(20.7, 20.7)
			nova.material.shader = load(OUT + "reference_wave.gdshader")
			nova.shell.material_override.shader = load(OUT + "reference_shell.gdshader")
		var moments: Array[float] = [0.22, 0.42, 0.62]
		for frame in range(33): moments.append(float(frame) / 30.0)
		var sample := 0
		for moment in moments:
			nova.elapsed = moment
			nova._update_visuals()
			if variant == "reference": nova.rotation.y = 0.0
			for i in range(4): await process_frame
			await RenderingServer.frame_post_draw
			var filename := "%s_%02d.png" % [variant, roundi(moment * 100)] if sample < 3 else "%s_frame_%02d.png" % [variant, sample - 3]
			var result := root.get_texture().get_image().save_png(OUT + filename)
			assert(result == OK)
			sample += 1
		nova.free()
	stage.queue_free()
	await process_frame
	print("NOVA_TEXTURE_TRIALS_COMPLETE: 108 captures")
	quit()
