extends Node3D
## A physical, aimed dart. Ray sweeps prevent passing through thin obstacles.
const SPEED := 28.0
const LIFETIME := 15.0 # Covers the shared reticle's 400 m maximum distance.
var direction := Vector3.FORWARD
var shooter: RID
var age := 0.0

static func make_visual() -> Node3D:
	var model := Node3D.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b8cfa7")
	var shaft := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.012
	mesh.bottom_radius = 0.02
	mesh.height = 0.42
	shaft.mesh = mesh
	shaft.material_override = material
	shaft.rotation.x = PI / 2.0
	model.add_child(shaft)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.026
	cone.height = 0.1
	tip.mesh = cone
	tip.material_override = material
	tip.rotation.x = -PI / 2.0
	tip.position.z = -0.26
	model.add_child(tip)
	return model

func _ready() -> void:
	add_to_group("sleep_dart_projectiles")
	add_child(make_visual())

func launch(origin: Vector3, heading: Vector3, source: RID) -> void:
	global_position = origin
	direction = heading.normalized()
	shooter = source
	if not direction.is_zero_approx():
		look_at(origin + direction, Vector3.RIGHT if absf(direction.y) > 0.99 else Vector3.UP)

func _physics_process(delta: float) -> void:
	var destination := global_position + direction * SPEED * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, destination, 1 | 4 | 8 | 16, [shooter])
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Node = hit.collider
		if collider.has_method("receive_sleep_dart"):
			collider.receive_sleep_dart()
		queue_free()
		return
	global_position = destination
	age += delta
	if age >= LIFETIME: queue_free()
