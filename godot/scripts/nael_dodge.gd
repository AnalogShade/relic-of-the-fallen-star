extends Node
const HitFeedback = preload("res://scripts/hit_feedback.gd")
## Double-tap dodges / charge using the authored directional actions.
@export var double_tap_window := 0.25
@export var cooldown_time := 0.65
# Scale travel in every direction without changing animation or maneuver timing.
@export var distance_multiplier := 3.0
@export var charge_damage := 15.0
@export var charge_push := 9.0
@export var backstep_speed := 25.0
@export var backstep_push_time := 0.18
@export var backstep_playback_speed := 2.0
@export var frontstep_playback_speed := 2.5
var actor: CharacterBody3D
var active := false
var charging := false
var backstepping := false
var elapsed := 0.0
var duration := 0.5
var cooldown := 0.0
var direction := Vector3.ZERO
var pending := ""
var taps: Dictionary = {}
var hit_ids: Dictionary = {}
# Normalized lateral pelvis path from the 26-frame Blender action.
const SIDE_TRAVEL := [0.0, -0.0108025, -0.0308642, -0.0416667, -0.0202381, 0.025, 0.0891625, 0.1771345, 0.275, 0.3901519, 0.5194843, 0.6333333, 0.7302722, 0.8167685, 0.875, 0.9124211, 0.9464736, 0.9743159, 0.9931052, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0]
const SIDE_CLIP_TIME := 25.0 / 30.0
const SIDE_DISTANCE := 1.833465
const ACTIONS := ["move_left", "move_right", "move_backward", "move_forward"]

func _ready() -> void:
	actor = get_parent()
	var trail := preload("res://scripts/dodge_trail.gd").new()
	trail.name = "DodgeTrail"
	actor.add_child.call_deferred(trail)

func handle_input(event: InputEvent) -> void:
	if not event is InputEventKey or event.echo: return
	if actor._is_ui_blocking() or actor.rest_state != "" or (DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		taps.clear()
		return
	for action in ACTIONS:
		if event.is_action_pressed(action):
			var now := Time.get_ticks_msec() / 1000.0
			if taps.has(action) and now - float(taps[action]) <= double_tap_window:
				pending = action
				taps.clear()
			else:
				taps[action] = now
			return

func holds_backstep_facing() -> bool:
	# A first back tap may become a dodge: translate immediately, but keep
	# the current facing until the double-tap window has elapsed.
	if not actor.is_on_floor() or actor.swimming or actor.rest_state != "" or actor._is_ui_blocking():
		return false
	if not taps.has("move_backward"): return false
	if Input.is_action_pressed("move_left") or Input.is_action_pressed("move_right") or Input.is_action_pressed("move_forward"):
		return false
	return Time.get_ticks_msec() / 1000.0 - float(taps["move_backward"]) <= double_tap_window

func tick(delta: float) -> bool:
	cooldown = maxf(0.0, cooldown - delta)
	if actor._is_ui_blocking() or actor.rest_state != "" or actor.swimming or (DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		cancel()
		return false
	if pending != "":
		var request := pending
		pending = ""
		start(request)
	if not active: return false
	if not actor.is_on_floor():
		cancel()
		return false
	elapsed += delta
	var animator: AnimationPlayer = actor.get_node("Nael").animator
	if animator.assigned_animation == "esquive_back" and elapsed >= animator.get_animation("esquive_back").length / backstep_playback_speed:
		animator.speed_scale = 1.0
		animator.play("Nael_Idle_Breathe", 0.12)
	# The one-shot front clip holds its last pose until forward travel ends.
	if charging and animator.assigned_animation == "esquive_front" and elapsed >= 0.36:
		animator.speed_scale = 1.0
		animator.play("Nael_Idle_Breathe", 0.10)
	if animator.assigned_animation in ["esquive_gauche", "esquive_droite"] and elapsed >= SIDE_CLIP_TIME:
		animator.speed_scale = 1.0
		animator.play("Nael_Idle_Breathe", 0.10)
	if elapsed >= duration:
		cancel()
		return false
	var before := actor.global_position
	# Anticipation, explosive push, then deceleration into the landing.
	var rate := 0.0
	var push_time := backstep_push_time if backstepping else 0.32
	var peak_speed := backstep_speed if backstepping else (11.0 if charging else 9.0)
	if backstepping:
		rate = (_backstep_distance(elapsed) - _backstep_distance(elapsed - delta)) / delta
	elif not charging:
		rate = (_side_distance(elapsed) - _side_distance(elapsed - delta)) / delta
	elif elapsed >= 0.04 and elapsed < 0.04 + push_time:
		rate = sin(PI * (elapsed - 0.04) / push_time) * peak_speed
	rate *= distance_multiplier
	actor.velocity.x = direction.x * rate
	actor.velocity.z = direction.z * rate
	actor.velocity.y = -0.5
	if charging and rate > 0.0: _charge_hits(before, before + direction * 0.65)
	actor.move_and_slide()
	if charging and rate > 0.0: _charge_hits(before, actor.global_position + direction * 0.65)
	actor.was_on_floor = actor.is_on_floor()
	actor.previous_vertical_velocity = actor.velocity.y
	if actor.global_position.y < -8.0 or not actor.world_bounds.has_point(Vector2(actor.global_position.x, actor.global_position.z)):
		actor.respawn()
	return true

func start(action: String) -> bool:
	var index := ACTIONS.find(action)
	if index < 0 or active or cooldown > 0.0: return false
	if not actor.is_on_floor() or actor.swimming or actor.rest_state != "" or actor._is_ui_blocking() or actor.is_attacking or actor.fireball_aiming:
		return false
	var model = actor.get_node("Nael")
	actor.cancel_claw()
	actor.axe_throw_requested = false
	actor.jump_buffer = 0.0
	actor.gliding = false
	HitFeedback.clear_recoil(actor)
	charging = index == 3
	backstepping = index == 2
	duration = 0.30 if backstepping else (0.55 if charging else SIDE_CLIP_TIME + 0.10)
	var local := [Vector3.LEFT, Vector3.RIGHT, Vector3.BACK, Vector3.FORWARD][index] as Vector3
	direction = actor.pivot.global_basis * local
	direction.y = 0.0
	direction = direction.normalized()
	# Face the camera's forward throughout side/back maneuvers.
	model.rotation.y = actor.pivot.rotation.y + PI
	model.animator.speed_scale = backstep_playback_speed if backstepping else (frontstep_playback_speed if charging else 1.0)
	var clip := "esquive_back" if index == 2 and model.animator.has_animation("esquive_back") else "Nael_Idle_Breathe"
	if charging and model.animator.has_animation("esquive_front"):
		clip = "esquive_front"
	if index < 2:
		var side_clip := "esquive_gauche" if index == 0 else "esquive_droite"
		if model.animator.has_animation(side_clip):
			clip = side_clip
			model.animator.speed_scale = model.animator.get_animation(clip).length / SIDE_CLIP_TIME
	model.animator.play(clip, 0.04)
	model.animator.advance(0.0)
	elapsed = 0.0
	active = true
	cooldown = cooldown_time
	hit_ids.clear()
	return true

func _side_distance(time: float) -> float:
	var sample := clampf(time / SIDE_CLIP_TIME, 0.0, 1.0) * (SIDE_TRAVEL.size() - 1)
	var index := mini(int(sample), SIDE_TRAVEL.size() - 2)
	return lerpf(SIDE_TRAVEL[index], SIDE_TRAVEL[index + 1], sample - index) * SIDE_DISTANCE

func _backstep_distance(time: float) -> float:
	var t := clampf(time, 0.0, backstep_push_time)
	var brake := backstep_push_time * 0.22
	var full_speed := backstep_push_time - brake
	var tail := maxf(0.0, t - full_speed)
	return backstep_speed * (minf(t, full_speed) + tail - tail * tail / (2.0 * brake))

func avoids_damage() -> bool:
	if backstepping: return active and elapsed <= backstep_push_time
	return active and not charging and elapsed >= 0.07 and elapsed <= 0.27

func cancel() -> void:
	pending = ""
	taps.clear()
	if not active: return
	active = false
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0
	actor.get_node("Nael").animator.speed_scale = 1.0

func _charge_hits(from: Vector3, to: Vector3) -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"): continue
		var id: int = enemy.get_instance_id()
		if hit_ids.has(id) or ("health" in enemy and enemy.health <= 0.0): continue
		var center: Vector3 = enemy.global_position
		if absf(center.y - from.y) > 1.2: continue
		var a := Vector3(from.x, 0, from.z)
		var b := Vector3(to.x, 0, to.z)
		var p := Vector3(center.x, 0, center.z)
		var radius := 0.35
		var cs := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if cs and cs.shape and (cs.shape is CapsuleShape3D or cs.shape is SphereShape3D or cs.shape is CylinderShape3D):
			radius = cs.shape.radius * cs.global_basis.get_scale().x
		if Geometry3D.get_closest_point_to_segment(p, a, b).distance_to(p) > radius + 0.35: continue
		var offset := p - a
		if offset.length_squared() > 0.001 and offset.normalized().dot(direction) < 0.0: continue
		var ray := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.7, center + Vector3.UP * 0.7, 5, [actor.get_rid()])
		var obstruction := actor.get_world_3d().direct_space_state.intersect_ray(ray)
		if not obstruction.is_empty() and obstruction.collider != enemy: continue
		hit_ids[id] = true
		enemy.take_damage(charge_damage * Progression.physical_multiplier(), actor.global_position, "charge")
		if is_instance_valid(enemy) and enemy is CharacterBody3D and enemy.health > 0.0:
			enemy.set_meta("hit_recoil", direction * charge_push)
			enemy.set_meta("hit_recoil_time", 0.22)
		actor.combat_feedback_time = 2.0
		actor.combat_ui.show()
		actor.attack_feedback.text = "Charge : impact !"
