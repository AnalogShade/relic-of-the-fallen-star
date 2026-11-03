extends Node
## Local contact occlusion; preserve the original image sharpness and palette.
const RADIUS := 0.45
const INTENSITY := 2.7
var enabled := true

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func set_enabled(value: bool) -> void:
	enabled = value
	for world in get_tree().root.find_children("*", "WorldEnvironment", true, false):
		if world.environment: world.environment.ssao_enabled = value

func _on_node_added(node: Node) -> void:
	if node is WorldEnvironment:
		_apply_to_world.call_deferred(node)

func _apply_to_world(world: WorldEnvironment) -> void:
	if is_instance_valid(world) and world.environment:
		configure(world.environment)
		world.environment.ssao_enabled = enabled

static func configure(environment: Environment) -> void:
	environment.ssao_enabled = true
	environment.ssao_radius = RADIUS
	environment.ssao_intensity = INTENSITY
