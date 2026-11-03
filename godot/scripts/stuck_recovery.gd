extends Node
## Hold jump while wedged: separate safely, then use a recent stable footing
## if the first escape fails or a ceiling prevents the upward separation.
const STALL_TIME := 0.7
const HOLD_TIME := 0.4
const STILL_RADIUS := 0.08
var actor: CharacterBody3D
var stalled := 0.0
var held := 0.0
var cooldown := 0.0
var grounded := 0.0
var anchor := Vector3.ZERO
var attempted := false
var safe_positions: Array[Vector3] = []

func _ready() -> void:
	actor = get_parent()
	anchor = actor.global_position

func reset() -> void:
	stalled = 0.0
	held = 0.0
	grounded = 0.0
	cooldown = 0.0
	attempted = false
	safe_positions.clear()
	if is_instance_valid(actor):
		anchor = actor.global_position

func tick(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	var blocked: bool = actor._is_ui_blocking() or actor.rest_state != "" or actor.guardian_knockback > 0.0 or actor.health <= 0.0 or actor.dodge.active or actor.swimming
	if blocked:
		stalled = 0.0
		held = 0.0
		grounded = 0.0
		anchor = actor.global_position
		return
	held = held + delta if Input.is_action_pressed("jump") else 0.0

func observe(delta: float, start: Vector3) -> void:
	# Scene transitions, loads and external teleports invalidate the old trail.
	if actor.global_position.distance_to(anchor) > 8.0:
		reset()
		anchor = actor.global_position
	if actor.swimming:
		stalled = 0.0
		grounded = 0.0
		return
	# Some wedges report a floor even though movement into either face fails.
	var pushing := Input.get_vector("move_left", "move_right", "move_forward", "move_backward").length() > 0.1
	var blocked_on_floor := pushing and actor.get_real_velocity().length() < 0.15
	if actor.is_on_floor() and not blocked_on_floor:
		grounded += delta
		stalled = 0.0
		anchor = actor.global_position
		if grounded >= 0.35 and not actor.is_on_wall():
			attempted = false
			var point := actor.global_position + Vector3.UP * 0.04
			if (safe_positions.is_empty() or point.distance_to(safe_positions.back()) >= 0.75) and _clear_at(point):
				safe_positions.append(point)
				if safe_positions.size() > 12:
					safe_positions.pop_front()
		return
	grounded = 0.0
	# Use accumulated displacement, not velocity: gravity can keep requesting
	# movement even when two collision faces completely pin the capsule.
	if actor.get_slide_collision_count() == 0 or actor.global_position.distance_to(anchor) > STILL_RADIUS or actor.global_position.distance_to(start) > STILL_RADIUS:
		anchor = actor.global_position
		stalled = 0.0
	else:
		stalled += delta

func _clear_at(point: Vector3) -> bool:
	var shape_node := actor.get_node("CollisionShape3D") as CollisionShape3D
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape_node.shape
	query.transform = shape_node.global_transform
	query.transform.origin += point - actor.global_position
	query.collision_mask = actor.collision_mask
	query.exclude = [actor.get_rid()]
	query.margin = 0.01
	return actor.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

func _return_to_footing() -> bool:
	for i in range(safe_positions.size() - 1, -1, -1):
		var point := safe_positions[i]
		var distance := point.distance_to(actor.global_position)
		if distance < 0.75 or distance > 8.0 or not _clear_at(point):
			continue
		var ray := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 0.8, actor.collision_mask, [actor.get_rid()])
		var hit := actor.get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or hit.normal.y < cos(actor.floor_max_angle):
			continue
		actor.global_position = point
		return true
	return false

func try_escape() -> bool:
	if stalled < STALL_TIME or held < HOLD_TIME or cooldown > 0.0:
		return false
	var escaped := false
	if attempted:
		escaped = _return_to_footing()
	if not escaped:
		for height in [0.08, 0.2, 0.4, 0.65]:
			var offset: Vector3 = Vector3.UP * height
			# Never teleport through a ceiling or into an adjacent collider.
			if not actor.test_move(actor.global_transform, offset) and _clear_at(actor.global_position + offset):
				actor.global_position += offset
				escaped = true
				break
	if not escaped:
		escaped = _return_to_footing()
	if not escaped:
		return false
	attempted = true
	stalled = 0.0
	cooldown = 1.2
	anchor = actor.global_position
	actor.velocity = Vector3.ZERO
	actor.gliding = false
	actor.water_jump_active = false
	# Preserve the spent air jump: escaping is not an extra jump in free air.
	actor.air_jump_used = true
	return true
