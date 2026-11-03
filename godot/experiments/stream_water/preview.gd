extends Node3D

var water: MeshInstance3D
var original: ShaderMaterial
var experiment: Material
var label: Label
var showing_experiment := true

func _ready() -> void:
	var forest := preload("res://assets/environment/forest.glb").instantiate()
	add_child(forest)
	forest.find_child("Ripples", true, false).hide()
	water = forest.find_child("Water", true, false) as MeshInstance3D
	original = ShaderMaterial.new()
	original.shader = preload("res://shaders/water.gdshader")
	preload("res://scripts/stream_water.gd").apply(water)
	experiment = water.material_override
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.76, 0.8, 0.76)
	env.ambient_light_energy = 0.45
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	add_child(sun)
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(6, 5, 17)
	camera.look_at(Vector3(0, 0.05, 9))
	camera.current = true
	var ui := CanvasLayer.new()
	add_child(ui)
	label = Label.new()
	label.position = Vector2(24, 24)
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	ui.add_child(label)
	_update_label()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		showing_experiment = not showing_experiment
		water.material_override = experiment if showing_experiment else original
		_update_label()

func _update_label() -> void:
	label.text = "Ruisseau : %s\nB : comparer avec l'autre rendu" % ("expérimentation" if showing_experiment else "ancien rendu")
