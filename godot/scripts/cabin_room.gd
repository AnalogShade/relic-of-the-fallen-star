extends Node3D
## Independent, slightly wider room; geometry is shared with the Blender cabin.
func _ready() -> void:
	$HearthFire.light_energy_scale = 0.45
	$HearthFire.light.omni_range = 4.2
	var pickup := preload("res://scripts/collectible.gd").new()
	pickup.name = "FishingRodPickup"
	pickup.item_id = "fishing_rod"
	pickup.pickup_id = "cabin/fishing_rod"
	pickup.position = Vector3(-1.4, 1.7, -2.6)
	var rod: Node3D = load("res://assets/items/fishing_rod.glb").instantiate()
	rod.rotation.z = -PI / 2.0
	pickup.add_child(rod)
	add_child(pickup)
	for x in [-1.3, 0.1]:
		var hook := MeshInstance3D.new()
		var hook_mesh := BoxMesh.new()
		hook_mesh.size = Vector3(0.08, 0.16, 0.24)
		hook.mesh = hook_mesh
		hook.position = Vector3(x, 1.63, -2.69)
		var metal := StandardMaterial3D.new()
		metal.albedo_color = Color("4b4939")
		metal.metallic = 0.6
		hook.material_override = metal
		add_child(hook)
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.065, 0.047, 0.030)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.90, 0.86)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env_node.environment = env
	add_child(env_node)
	var bounce := OmniLight3D.new()
	bounce.name = "SoftCeilingLight"
	bounce.position = Vector3(0, 3.3, 0)
	bounce.light_color = Color(1.0, 0.94, 0.84)
	bounce.light_energy = 0.32
	bounce.omni_range = 8.0
	bounce.omni_attenuation = 0.65
	bounce.shadow_enabled = false
	add_child(bounce)
	# Windows remain decorative; the ceiling fill and hearth light the room.
	var player := $Player
	player.world_bounds = Rect2(-4.1, -3.5, 8.2, 7.3)
	player.pivot.rotation.y = -0.55
	player.arm.spring_length = 2.6
	player.arm.rotation.x = -0.20
	player.get_node("CameraPivot/SpringArm3D/Camera3D").fov = 76.0
	player.get_node("CameraPivot/SpringArm3D/Camera3D").far = 40.0
