extends SceneTree

class Target extends CharacterBody3D:
	var health := 100.0
	func take_damage(amount: float, _source: Vector3) -> void:
		health -= amount

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)

func spawn(world: Node3D, variant: String, at: Vector3):
	var bandit = load("res://scenes/bandit.tscn").instantiate()
	bandit.color_variant = variant
	bandit.position = at
	world.add_child(bandit)
	bandit.set_physics_process(false)
	return bandit

func run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	current_scene = world
	var target := Target.new()
	world.add_child(target)
	var originals: Array[Material] = []
	var preview := "--preview" in OS.get_cmdline_user_args()
	for i in range(3):
		var variant: String = ["vert", "jaune", "noir"][i]
		var expected: float = [9.0, 12.0, 16.0][i]
		var bandit = spawn(world, variant, Vector3((i - (1.5 if preview else 1.0)) * 1.7, 0, 0))
		check(is_equal_approx(bandit.damage, expected), variant + ": base damage")
		var mesh: MeshInstance3D = bandit.visual.find_children("*", "MeshInstance3D", true, false)[0]
		originals.append(mesh.mesh.surface_get_material(0))
		check(mesh.get_active_material(0) is ShaderMaterial, variant + ": clothing material applied")
		check(mesh.get_active_material(0).get_shader_parameter("albedo_texture") == originals[-1].albedo_texture, variant + ": original albedo texture reused directly")
		target.position = bandit.position + Vector3(0, 0, 0.8)
		bandit.player = target
		bandit.combat.attack_direction = Vector3.BACK
		for heavy in [false, true]:
			target.health = 100.0
			bandit.combat.heavy = heavy
			bandit.combat.hit_done = false
			bandit.combat._strike()
			check(is_equal_approx(100.0 - target.health, expected * (1.35 if heavy else 1.0)), variant + ": actual " + ("heavy" if heavy else "normal") + " strike")
		bandit.player = null
		var label := Label3D.new()
		label.text = "%s\n%d dégâts" % [variant.capitalize(), int(expected)]
		label.position = bandit.position + Vector3(0, 2.35, 0)
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(label)
	var natural = spawn(world, "naturel", Vector3(0, 0, 20))
	check(natural.damage == 12.0 and natural.enemy_name == "Bandit", "Original variant retains base stats")
	for material in originals:
		check(material is StandardMaterial3D and material.albedo_color == Color.WHITE, "Imported shared material remains unchanged")
	var first = spawn(world, "auto", Vector3(15, 0, 20))
	var selected: String = first.selected_color_variant
	var parent := Node3D.new()
	parent.position = Vector3(5, 0, 0)
	world.add_child(parent)
	var reloaded = spawn(parent, "auto", Vector3(10, 0, 20))
	check(selected == reloaded.selected_color_variant, "Same world spawn keeps color under a different parent")
	var counts := {"vert": 0, "jaune": 0, "noir": 0}
	for i in range(30):
		var sample = spawn(world, "auto", Vector3(i * 5, 0, 40))
		counts[sample.selected_color_variant] += 1
		sample.queue_free()
	check(counts.values().all(func(count): return count > 0), "Automatic spawns include all colors: " + str(counts))
	if preview:
		natural.position = Vector3(2.55, 0, 0)
		var reference_label := Label3D.new()
		reference_label.text = "Original\nsans effet"
		reference_label.position = natural.position + Vector3(0, 2.35, 0)
		reference_label.font_size = 32
		reference_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		world.add_child(reference_label)
		for layer in root.find_children("*", "CanvasLayer", true, false):
			layer.hide()
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("202c35")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.65
		world.add_child(environment)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-40, -30, 0)
		light.light_energy = 1.5
		world.add_child(light)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 4.0
		camera.position = Vector3(0, 2.0, 7)
		camera.look_at(Vector3(0, 1.25, 0))
		camera.current = true
		for i in range(10): await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../diagnostics/bandit_black_20261026/preview.png"))
	world.queue_free()
	await process_frame
	print("BANDIT_VARIANTS_RESULT ", failures)
	quit(0 if failures.is_empty() else 1)
