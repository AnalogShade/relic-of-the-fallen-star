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
	stage.actor.set_physics_process(false)
	stage.actor.set_process(false)
	stage.actor.process_mode = Node.PROCESS_MODE_DISABLED
	var camera: Camera3D = stage.get_viewport().get_camera_3d()
	camera.position = Vector3(7, 8, 10)
	camera.look_at(Vector3(0, 0.5, 0))
	var title: Label = stage.get_children().filter(func(n): return n is CanvasLayer)[0].get_child(0)
	for variant in ["original", "soft", "motion"]:
		title.text = {"original": "A · NOVA ACTUELLE", "soft": "B · HALO DIFFUS + FRESNEL ADOUCI", "motion": "C · HALO DIFFUS + TRAÎNÉE RADIALE"}[variant] + "\nComparaison à caméra et instant identiques · Compatibilité OpenGL"
		var nova = load("res://scripts/spells/primordial_nova.gd").new()
		stage.add_child(nova)
		nova.global_position = stage.actor.global_position
		nova.set_physics_process(false)
		nova.get_node("EnergyVeil0").hide()
		nova.get_node("EnergyVeil1").hide()
		nova.aura.hide()
		nova.get_child(0).mesh.size = Vector2(20.7, 20.7)
		nova.material.shader = load(OUT + "reference_wave.gdshader")
		nova.shell.material_override.shader = load(OUT + "reference_shell.gdshader")
		if variant != "original":
			nova.material.shader = load(OUT + "soft_wave.gdshader")
			nova.material.set_shader_parameter("trail_strength", 1.0 if variant == "motion" else 0.0)
			nova.shell.material_override.shader = load(OUT + "soft_shell.gdshader")
		var moments: Array[float] = [0.22, 0.42, 0.62]
		for frame in range(30): moments.append(float(frame) / 30.0)
		var sample := 0
		for moment in moments:
			nova.elapsed = moment
			nova._update_visuals()
			nova.rotation.y = 0.0
			var ghosts: Array[MeshInstance3D] = []
			if variant == "motion":
				# Sample earlier wave radii, rather than blurring the character or world.
				nova.shell.material_override.set_shader_parameter("layer_weight", 0.55)
				for offset in [0.025, 0.05, 0.08]:
					var ghost := MeshInstance3D.new()
					ghost.mesh = nova.shell.mesh
					ghost.position = nova.shell.position
					ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					var r := maxf(0.08, 9.0 * clampf((moment - offset) / 0.65, 0.0, 1.0))
					ghost.scale = Vector3(r, maxf(0.12, r * 0.32), r)
					ghost.material_override = nova.shell.material_override.duplicate()
					ghost.material_override.set_shader_parameter("layer_weight", 0.18)
					nova.add_child(ghost)
					ghosts.append(ghost)
			for i in range(5): await process_frame
			await RenderingServer.frame_post_draw
			var filename := "%s_%02d.png" % [variant, roundi(moment * 100)] if sample < 3 else "%s_frame_%02d.png" % [variant, sample - 3]
			root.get_texture().get_image().save_png(OUT + filename)
			sample += 1
			for ghost in ghosts: ghost.free()
		nova.free()
	stage.queue_free()
	await process_frame
	print("NOVA_VISUAL_TRIALS_COMPLETE")
	quit()
