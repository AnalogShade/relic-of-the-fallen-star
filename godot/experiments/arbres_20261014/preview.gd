extends Node3D

const SHOTS = [
	[Vector3(23, 14, 28), Vector3(0, 14, -5)],
	[Vector3(-2, 8, 13), Vector3(-8, 11, 4)],
	[Vector3(-4, 3.4, 11), Vector3(-8, 2.0, 5)],
	[Vector3(-7, 3.5, 4), Vector3(-7, 16, 4.2)],
	[Vector3(1, 3.5, 14), Vector3(0, 17, -10)]
]
var before: Node3D
var after: Node3D
var camera: Camera3D
var label: Label
var improved := true
var shot := 0

func _ready() -> void:
	before = load("res://assets/environment/forest.glb").instantiate()
	before.name = "Avant"
	add_child(before)
	after = Node3D.new()
	after.name = "Apres"
	add_child(after)
	after.add_child(load("res://experiments/arbres_20261014/forest_test_remaining.glb").instantiate())
	after.add_child(load("res://experiments/arbres_20261014/arbres_patch.glb").instantiate())
	for world in [before, after]:
		preload("res://scripts/world_legacy_cleanup.gd").apply(world)
		for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
			var n := str(mesh.name)
			if n.begins_with("TEST_Wood") or n.begins_with("TEST_Rock"):
				for shape: CollisionShape3D in mesh.find_children("*", "CollisionShape3D", true, false):
					shape.shape = mesh.mesh.create_trimesh_shape()
			if n.begins_with("TEST_Leaves"):
				for surface in range(mesh.mesh.get_surface_count()):
					var leaves := mesh.get_active_material(surface).duplicate() as StandardMaterial3D
					leaves.albedo_color = Color(1.12, 1.25, 1.02)
					mesh.set_surface_override_material(surface, leaves)
			if n.begins_with("Terrain"):
				var ground := ShaderMaterial.new()
				ground.shader = load("res://shaders/world_ground.gdshader")
				mesh.material_override = ground
			elif n.begins_with("Water"):
				var water := ShaderMaterial.new()
				water.shader = load("res://shaders/water.gdshader")
				mesh.material_override = water
			elif n.begins_with("DistantHills") or n.begins_with("Ripples"):
				mesh.hide()
		preload("res://scripts/natural_surface_materials.gd").apply(world)
	var source: Node3D = load("res://scenes/forest_test.tscn").instantiate()
	for name in ["WorldEnvironment", "Sun", "SoftFill"]:
		var node := source.get_node(name).duplicate()
		add_child(node)
	source.free()
	camera = Camera3D.new()
	camera.far = 600
	camera.fov = 65
	add_child(camera)
	camera.make_current()
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label = Label.new()
	label.position = Vector2(18, 14)
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	set_shot(4)
	set_mode(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if "--capture" in OS.get_cmdline_user_args(): capture.call_deferred()

func set_mode(value: bool) -> void:
	improved = value
	before.visible = not value
	after.visible = value
	for group in [before, after]:
		for shape: CollisionShape3D in group.find_children("*", "CollisionShape3D", true, false):
			shape.disabled = (group == before) == value
	label.text = ("APRÈS — six variantes, volume des couronnes ×3" if value else "AVANT — forêt originale") + "\nTab : comparer | 1/2/3/4/5 : vues | clic droit + souris : regarder | WASD / Q E : déplacer"

func set_shot(value: int) -> void:
	shot = value
	camera.position = SHOTS[value][0]
	camera.look_at(SHOTS[value][1])

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_TAB: set_mode(not improved)
		if event.keycode >= KEY_1 and event.keycode <= KEY_5: set_shot(event.keycode - KEY_1)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		camera.rotation.y -= event.relative.x * 0.003
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -1.5, 1.5)

func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): move.z -= 1
	if Input.is_physical_key_pressed(KEY_S): move.z += 1
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1
	if Input.is_physical_key_pressed(KEY_D): move.x += 1
	if Input.is_physical_key_pressed(KEY_Q): move.y -= 1
	if Input.is_physical_key_pressed(KEY_E): move.y += 1
	camera.position += camera.basis * move * delta * (14 if Input.is_key_pressed(KEY_SHIFT) else 5)

func capture() -> void:
	get_window().size = Vector2i(1280, 720)
	var dest := ProjectSettings.globalize_path("res://../environments/foret_des_lueurs/test_arbres_20261014/")
	for mode in [false, true]:
		set_mode(mode)
		for view in range(SHOTS.size()):
			set_shot(view)
			for i in range(8): await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(dest + ("apres" if mode else "avant") + "_%d.png" % view)
	var collisions := []
	for mesh: MeshInstance3D in after.find_children("*", "MeshInstance3D", true, false):
		if not str(mesh.name).begins_with("TEST_Rock"): continue
		for shape: CollisionShape3D in mesh.find_children("*", "CollisionShape3D", true, false):
			var expected := mesh.mesh.create_trimesh_shape()
			var actual := shape.shape as ConcavePolygonShape3D
			collisions.append({"mesh":str(mesh.name), "visual_transform":str(mesh.global_transform), "collider_transform":str(shape.global_transform), "same_transform":mesh.global_transform.is_equal_approx(shape.global_transform), "same_faces":actual.get_faces() == expected.get_faces()})
	var file := FileAccess.open(dest + "godot_validation.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"rock_collisions":collisions, "before_meshes":before.find_children("*", "MeshInstance3D", true, false).size(), "after_meshes":after.find_children("*", "MeshInstance3D", true, false).size()}, "\t"))
	print("TREE_PREVIEW_CAPTURE_DONE ", collisions)
	get_tree().quit()
