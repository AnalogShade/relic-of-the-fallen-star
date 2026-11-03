extends Node
## Keeps healing and transitions tied to an actual camp seat.
@export var healing_interval := 5.0
var player: CharacterBody3D
var seat: Node3D
var exit_position := Vector3.ZERO
var seated_position := Vector3.ZERO
var elapsed := 0.0
var healing_elapsed := 0.0
var route: Array[Vector2] = []
var facing_direction := Vector3.ZERO
var approach_elapsed := 0.0

# Visibility graph around an expanded footprint. Clearance includes Naël's capsule.
func crosses(a: Vector2, b: Vector2, obstacle: Rect2) -> bool:
	var inset := obstacle.grow(-0.01)
	var low := 0.0
	var high := 1.0
	var d := b - a
	for axis in range(2):
		if absf(d[axis]) < 0.00001:
			if a[axis] < inset.position[axis] or a[axis] > inset.end[axis]: return false
		else:
			var t0 := (inset.position[axis] - a[axis]) / d[axis]
			var t1 := (inset.end[axis] - a[axis]) / d[axis]
			low = maxf(low, minf(t0, t1))
			high = minf(high, maxf(t0, t1))
			if low > high: return false
	return true

func plan_route(start: Vector2, finish: Vector2, obstacle: Rect2) -> Array[Vector2]:
	var nodes: Array[Vector2] = [start, finish, obstacle.position, Vector2(obstacle.end.x, obstacle.position.y), obstacle.end, Vector2(obstacle.position.x, obstacle.end.y)]
	for margin in [0.6, 1.2, 1.8]:
		var outer := obstacle.grow(margin)
		nodes.append_array([outer.position, Vector2(outer.end.x, outer.position.y), outer.end, Vector2(outer.position.x, outer.end.y)])
	var costs: Array[float] = []
	var previous: Array[int] = []
	for i in range(nodes.size()):
		costs.append(0.0 if i == 0 else INF)
		previous.append(-1)
	var visited: Array[int] = []
	for iteration in range(nodes.size()):
		var best := -1
		for i in range(nodes.size()):
			if i not in visited and (best == -1 or costs[i] < costs[best]): best = i
		if best == -1 or not is_finite(costs[best]): break
		visited.append(best)
		for next in range(nodes.size()):
			if next == best: continue
			var barrier := obstacle
			if best == 0 and obstacle.has_point(start): barrier = obstacle.grow(-0.52)
			if crosses(nodes[best], nodes[next], barrier): continue
			if not passage_clear(nodes[best], nodes[next]): continue
			var cost := costs[best] + nodes[best].distance_to(nodes[next])
			if cost < costs[next]:
				costs[next] = cost
				previous[next] = best
	var path: Array[Vector2] = []
	if not is_finite(costs[1]): return path
	var index := 1
	while index != 0:
		path.push_front(nodes[index])
		index = previous[index]
	return path

func passage_clear(a: Vector2, b: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.34
	query.shape = sphere
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var from := walking_center(a)
	var to := walking_center(b)
	if not from.is_finite() or not to.is_finite(): return false
	var steps := maxi(1, ceili(a.distance_to(b) / 0.20))
	for step in range(1, steps + 1):
		to = walking_center(a.lerp(b, float(step) / steps))
		if not to.is_finite(): return false
		var horizontal := Vector2(to.x - from.x, to.z - from.z).length()
		if absf(to.y - from.y) > horizontal * 1.1 + 0.05: return false
		query.transform.origin = from
		query.motion = to - from
		var motion := player.get_world_3d().direct_space_state.cast_motion(query)
		if motion[0] < 0.99: return false
		from = to
	return true

func walking_center(point: Vector2) -> Vector3:
	# Indoor seats probe below the ceiling instead of treating the roof as ground.
	var probe_height: float = seat.walking_probe_height() if is_instance_valid(seat) and seat.has_method("walking_probe_height") else 4.0
	var from := Vector3(point.x, player.global_position.y + probe_height, point.y)
	var query := PhysicsRayQueryParameters3D.create(from, from - Vector3.UP * 10.0, 1, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < 0.65: return Vector3(INF, INF, INF)
	return hit.position + Vector3.UP * 0.825

func _ready() -> void:
	player = get_parent()

func begin(bench: Node3D, target: Vector3, facing: Vector3) -> void:
	if player.rest_state != "" or player.swimming or player.is_attacking or not player.is_on_floor(): return
	var animator: AnimationPlayer = player.get_node("Nael").animator
	if not animator.has_animation("Nael_Sit_Down"): return
	seat = bench
	exit_position = player.global_position
	seated_position = target
	facing_direction = facing
	var obstacle: Rect2 = bench.footprint().grow(0.52)
	var center := Vector2(target.x, target.z)
	var forward := Vector2(facing.x, facing.z)
	var distance := 0.0
	var approach := center
	while obstacle.has_point(approach):
		distance += 0.05
		approach = center + forward * distance
	var start := Vector2(player.global_position.x, player.global_position.z)
	route.clear()
	for extra in [0.0, 0.2, 0.4, 0.6]:
		for sideways in [0.0, 0.25, -0.25, 0.5, -0.5]:
			var candidate: Vector2 = approach + forward * extra + Vector2(-forward.y, forward.x) * sideways
			if not walking_center(candidate).is_finite(): continue
			route = plan_route(start, candidate, obstacle)
			if not route.is_empty(): break
		if not route.is_empty(): break
	if route.is_empty():
		seat = null
		return
	player.velocity = Vector3.ZERO
	player.rest_state = "approaching_seat"
	elapsed = 0.0
	approach_elapsed = 0.0
	healing_elapsed = 0.0
	animator.speed_scale = 1.0
	animator.play("Nael_Walk", 0.15)

func physics_step(delta: float) -> void:
	if not is_instance_valid(seat):
		cancel()
		return
	if player.rest_state != "approaching_seat":
		player.velocity = Vector3.ZERO
		return
	if player._is_ui_blocking():
		player.velocity = Vector3.ZERO
		return
	approach_elapsed += delta
	if approach_elapsed > 15.0:
		cancel()
		return
	var current := Vector2(player.global_position.x, player.global_position.z)
	var arrival_distance := 0.30 if route.size() == 1 else 0.15
	if current.distance_to(route[0]) < arrival_distance:
		route.pop_front()
		if route.is_empty():
			exit_position = player.global_position
			player.rest_state = "sitting_down"
			player.velocity = Vector3.ZERO
			player.get_node("Nael").rotation.y = atan2(facing_direction.x, facing_direction.z)
			player.get_node("Nael").animator.speed_scale = 1.0
			player.get_node("Nael").animator.play("Nael_Sit_Down", 0.15)
			elapsed = 0.0
			return
	var direction := (route[0] - current).normalized()
	var speed := minf(player.speed, current.distance_to(route[0]) / delta)
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.y * speed
	player.velocity.y = -0.1 if player.is_on_floor() else player.velocity.y - player.gravity * delta
	player.move_and_slide()
	var model := player.get_node("Nael") as Node3D
	model.rotation.y = lerp_angle(model.rotation.y, atan2(direction.x, direction.y), minf(delta * 12.0, 1.0))
	model.animator.speed_scale = clampf(speed / 2.0, 0.5, 1.2)

func stand() -> void:
	if player.rest_state != "seated": return
	player.rest_state = "standing_up"
	elapsed = 0.0
	player.get_node("Nael").animator.play("Nael_Stand_Up", 0.12)

func cancel() -> void:
	if player.rest_state == "": return
	if player.rest_state != "approaching_seat": player.global_position = exit_position
	player.rest_state = ""
	seat = null
	route.clear()
	player.velocity = Vector3.ZERO
	player.get_node("Nael").animator.speed_scale = 1.0
	player.get_node("Nael").animator.play("Nael_Idle_Breathe", 0.15)

func _process(delta: float) -> void:
	if player.rest_state == "": return
	if not is_instance_valid(seat):
		cancel()
		return
	if player.rest_state == "approaching_seat": return
	var animator: AnimationPlayer = player.get_node("Nael").animator
	if player._is_ui_blocking(): return
	elapsed += delta
	if player.rest_state == "seated":
		healing_elapsed += delta
		if healing_elapsed >= healing_interval:
			healing_elapsed -= healing_interval
			var fire := (seat.rest_fire() if seat.has_method("rest_fire") else seat.get_parent().get_node_or_null("Flammes_Animees")) as Node3D
			if fire and fire.is_visible_in_tree() and player.global_position.distance_to(fire.global_position) < 5.0 and player.health < player.max_health:
				player.heal(1.0)
		return
	var u := smoothstep(0.0, 1.0, minf(elapsed / 1.5, 1.0))
	player.global_position = exit_position.lerp(seated_position, u) if player.rest_state == "sitting_down" else seated_position.lerp(exit_position, u)
	if elapsed >= 1.5:
		if player.rest_state == "sitting_down":
			player.rest_state = "seated"
			animator.play("Nael_Seated_Idle_Loop", 0.15)
		else:
			cancel()
