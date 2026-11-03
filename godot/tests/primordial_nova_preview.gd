extends Node3D
## Isolated visual playground. No progress or save files are changed.
var actor: CharacterBody3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("14232e")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("a9c6d4")
	settings.ambient_light_energy = 0.6
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_color = Color("d7e6ef")
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	shape.position.y = -0.5
	floor_body.add_child(shape)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("263c42")
	mat.roughness = 0.9
	ground.material_override = mat
	floor_body.add_child(ground)
	add_child(floor_body)
	actor = preload("res://scenes/player.tscn").instantiate()
	actor.position = Vector3(0, 0.1, 0)
	add_child(actor)
	get_node("/root/Inventory").add_item("primordial_wave")
	var camera := Camera3D.new()
	camera.position = Vector3(11, 13, 16)
	add_child(camera)
	camera.look_at(Vector3(0, 0.5, 0))
	camera.current = true
	var ui := CanvasLayer.new()
	add_child(ui)
	var title := Label.new()
	title.text = "ONDE PRIMORDIALE · APERÇU GODOT\nQ : nova   ·   Recharge 7 s   ·   Déplacement habituel"
	title.position = Vector2(28, 25)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("b6f9e9"))
	ui.add_child(title)
	for i in range(10):
		var stone := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.35 + (i % 3) * 0.12
		mesh.height = 0.6
		mesh.radial_segments = 5
		mesh.rings = 2
		stone.mesh = mesh
		stone.material_override = mat
		stone.position = Vector3(cos(i * TAU / 10.0) * 10, 0.2, sin(i * TAU / 10.0) * 10)
		add_child(stone)
