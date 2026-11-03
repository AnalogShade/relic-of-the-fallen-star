extends Node3D
## Standalone filming stage. Uses the real spell; never loads or writes a save.
var camera: Camera3D
var hud: CanvasLayer
var status: Label
var active_nova: Node3D
var autoplay := true
var orbit := false
var cycle := 1.0
var azimuth := 0.55
var distance := 22.0
var elevation := 7.5
var hidden_layers: Dictionary = {}

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		hidden_layers[node] = node.visible
		node.hide()
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("08131d")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("80a4c2")
	settings.ambient_light_energy = 0.45
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -35, 0)
	sun.light_color = Color("b7d6ed")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(180, 180)
	ground.mesh = plane
	var ground_material := StandardMaterial3D.new()
	ground_material.albedo_color = Color("15232c")
	ground_material.roughness = 1.0
	ground.material_override = ground_material
	add_child(ground)
	var actor := preload("res://assets/characters/nael.glb").instantiate() as Node3D
	actor.position.y = -0.425
	actor.rotation.y = PI + 0.55
	add_child(actor)
	preload("res://scripts/nael_materials.gd").apply(actor)
	var animator := actor.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator and animator.has_animation("Nael_Idle_Breathe"):
		animator.get_animation("Nael_Idle_Breathe").loop_mode = Animation.LOOP_LINEAR
		animator.play("Nael_Idle_Breathe")
	camera = Camera3D.new()
	camera.fov = 50.0
	camera.current = true
	add_child(camera)
	_update_camera()
	_build_hud()

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 100
	add_child(hud)
	var title := Label.new()
	title.text = "RELIC OF THE FALLEN STAR\nNOVA · ONDE PRIMORDIALE"
	title.position = Vector2(36, 28)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("b9f8ee"))
	hud.add_child(title)
	status = Label.new()
	status.position = Vector2(36, 104)
	status.add_theme_font_size_override("font_size", 17)
	status.add_theme_color_override("font_color", Color("9ab5c3"))
	hud.add_child(status)
	_update_status()

func _update_status() -> void:
	status.text = "ESPACE / Q : Nova    R : boucle %s    C : orbite %s    H : masquer l’interface\nFlèches : angle / hauteur    Molette : zoom    F11 : plein écran    Échap : quitter" % ["ON" if autoplay else "OFF", "ON" if orbit else "OFF"]

func _process(delta: float) -> void:
	if autoplay:
		cycle -= delta
		if cycle <= 0.0:
			cast_nova()
			cycle = 2.4
	if orbit: azimuth += delta * 0.14
	if Input.is_physical_key_pressed(KEY_LEFT): azimuth -= delta * 0.7
	if Input.is_physical_key_pressed(KEY_RIGHT): azimuth += delta * 0.7
	if Input.is_physical_key_pressed(KEY_UP): elevation = minf(18.0, elevation + delta * 5.0)
	if Input.is_physical_key_pressed(KEY_DOWN): elevation = maxf(3.5, elevation - delta * 5.0)
	_update_camera()

func _update_camera() -> void:
	camera.position = Vector3(sin(azimuth) * distance, elevation, cos(azimuth) * distance)
	camera.look_at(Vector3(0, 1.4, 0))

func cast_nova() -> Node3D:
	if is_instance_valid(active_nova): active_nova.queue_free()
	active_nova = preload("res://scripts/spells/primordial_nova.gd").new()
	add_child(active_nova)
	active_nova.position.y = 0.04
	cycle = 2.4
	return active_nova

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(15.0, distance - 1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(36.0, distance + 1.0)
		return
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_SPACE, KEY_Q: cast_nova()
		KEY_R:
			autoplay = not autoplay
			cycle = 0.2
			_update_status()
		KEY_C:
			orbit = not orbit
			_update_status()
		KEY_H: hud.visible = not hud.visible
		KEY_F11:
			var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		KEY_ESCAPE: get_tree().quit()
		_: return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	for node in hidden_layers:
		if is_instance_valid(node): node.visible = hidden_layers[node]
