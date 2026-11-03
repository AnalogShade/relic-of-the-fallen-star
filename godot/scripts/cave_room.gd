extends Node3D

func _ready() -> void:
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101c23")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("8da9b4")
	env.ambient_light_energy = 0.20
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	for p in [Vector3(-2.8, 1.7, -1.5), Vector3(3.0, 2.0, -6), Vector3(-2.8, 1.6, -10.5)]:
		light(p, Color("77bdb4"), 0.38, 7.0)
	light(Vector3(0, 4.2, -10), Color("e8c38d"), 0.9, 8.0)
	light(Vector3(0, 2.5, 1.5), Color("afcbd5"), 0.4, 6.0)
	_build_depths_opening()
	var player := $Player
	player.world_bounds = Rect2(-5.7, -14.0, 11.4, 18.0)
	player.pivot.rotation.y = 0.0
	player.arm.spring_length = 3.0
	player.arm.rotation.x = -0.18
	player.get_node("CameraPivot/SpringArm3D/Camera3D").fov = 76.0
	player.get_node("CameraPivot/SpringArm3D/Camera3D").far = 45.0
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()

func _build_depths_opening() -> void:
	# Keep the imported vault and entrance; replace only the solid rear wall.
	for node in $Architecture.find_children("*Fond*", "MeshInstance3D", true, false):
		node.hide()
		for collision in node.find_children("*", "CollisionShape3D", true, false):
			collision.set_deferred("disabled", true)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("344448")
	stone.roughness = 0.9
	for side in [-1.0, 1.0]:
		_opening_box(Vector3(side * 2.8, 2.9, -13.6), Vector3(2.4, 6.2, 0.65), stone)
	_opening_box(Vector3(0, 4.75, -13.6), Vector3(3.2, 2.5, 0.65), stone)
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color("020508")
	_opening_box(Vector3(0, 1.75, -14.0), Vector3(3.2, 3.5, 0.1), dark)
	var portal := preload("res://scripts/cave_depths_portal.gd").new()
	portal.name = "DepthsPortal"
	portal.position = Vector3(0, 1.0, -12.8)
	add_child(portal)
	light(Vector3(0, 2.6, -13.0), Color("559fbb"), 0.7, 5.0)

func _opening_box(p: Vector3, size: Vector3, material: Material) -> void:
	var box := CSGBox3D.new()
	box.position = p
	box.size = size
	box.material = material
	box.use_collision = true
	add_child(box)

func light(p: Vector3, color: Color, energy: float, reach: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.position = p
	lamp.light_color = color
	lamp.light_energy = energy
	lamp.omni_range = reach
	lamp.shadow_enabled = true
	add_child(lamp)
