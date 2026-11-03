extends Node3D
## Aimed once at release; swept collision prevents tunnelling through Naël or cover.
const Splash = preload("res://scripts/lake_monster_splash.gd")
const FlightFX = preload("res://scripts/lake_projectile_fx.gd")
var direction := Vector3.FORWARD
var speed := 13.0
var damage := 60.0
var age := 0.0
var source_rid: RID
var water_y := 5.4
var visual: Node3D
var collision_shape := SphereShape3D.new()

func _ready() -> void:
	collision_shape.radius = 0.40
	add_to_group("lake_monster_projectiles")
	visual = FlightFX.new()
	add_child(visual)
	visual.orient(direction)

func _physics_process(delta: float) -> void:
	var bag := get_node_or_null("/root/Inventory")
	if bag and bag.is_open:
		return
	age += delta
	if age > 5.0:
		visual.finish(false)
		queue_free()
		return
	var next := global_position + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next, 1 | 2)
	if source_rid.is_valid():
		query.exclude = [source_rid]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	# A small swept volume makes contact with the projectile's visible radius count.
	if hit.is_empty():
		var sweep := PhysicsShapeQueryParameters3D.new()
		sweep.shape = collision_shape
		sweep.transform = Transform3D(Basis.IDENTITY, global_position)
		sweep.motion = next - global_position
		sweep.collision_mask = 2
		var fraction := get_world_3d().direct_space_state.cast_motion(sweep)
		if fraction[0] < 1.0:
			sweep.transform.origin += sweep.motion * fraction[1]
			sweep.motion = Vector3.ZERO
			var contacts := get_world_3d().direct_space_state.intersect_shape(sweep, 1)
			if not contacts.is_empty():
				hit = {"collider": contacts[0].collider, "position": sweep.transform.origin}
	if not hit.is_empty():
		global_position = hit.position
		var target: Node = hit.collider
		if is_instance_valid(target) and target.is_in_group("player"):
			target.take_damage(damage, global_position - direction)
		_impact()
		return
	global_position = next
	if global_position.y < water_y - 0.15:
		_impact()

func _impact() -> void:
	visual.finish()
	var player := get_tree().get_first_node_in_group("player")
	var surface := -INF
	if is_instance_valid(player) and player.water_surface != null:
		surface = player.water_surface.height_at(global_position)
	if is_finite(surface) and absf(global_position.y - surface) < 1.0:
		var splash := Splash.new()
		splash.large = false
		splash.position = get_parent().to_local(Vector3(global_position.x, surface + 0.03, global_position.z))
		get_parent().add_child(splash)
	queue_free()
