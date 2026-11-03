extends CharacterBody3D
const HitFeedback = preload("res://scripts/hit_feedback.gd")

const CombatController = preload("res://scripts/enemy_combat.gd")
@export var combat_animations: Dictionary = {}
@export_enum("auto", "equilibre", "agressif", "prudent", "peureux") var temperament := "auto"
@export var behavior_seed := 0
var combat: Node

## Cavern Golem: patrols waypoints, pursues on sight, attacks with stone fists.

@export var golem_type: String = "standard" # "petit", "standard", "grand"
@export var custom_scale: float = 1.0
@export var max_health: float = 100.0
@export var damage: float = 12.0
@export var walk_speed: float = 1.35
@export var run_speed: float = 3.2
@export var attack_range: float = 1.3
@export var detection_radius: float = 7.5
@export var leash_radius: float = 14.0
@export var patrol_wait_time: float = 2.0
@export var patrol_points: Array[Vector3] = []

var health: float = 100.0
var enemy_name: String = "Golem"
var health_label: Label3D
var state: String = "patrol" # "patrol", "wait", "chase", "attack", "return", "dead"
var patrol_index: int = 0
var wait_timer: float = 0.0
var attack_time: float = 0.0
var hit_applied: bool = false
var cooldown: float = 0.0
var player: CharacterBody3D
var home_position: Vector3
var last_seen_position: Vector3
var sight_memory: float = 0.0
var sight_timer: float = 0.0
var sees_player: bool = false

var visual: Node3D
var collision_shape: CollisionShape3D
var animator: AnimationPlayer
var attack_audio_player: AudioStreamPlayer3D
var attack_sounds: Array[AudioStream] = []

func _ready() -> void:
	visual = get_node_or_null("Visual") as Node3D
	collision_shape = get_node_or_null("CollisionShape3D") as CollisionShape3D

	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 7
	floor_snap_length = 0.35
	floor_max_angle = 0.872665

	attack_audio_player = AudioStreamPlayer3D.new()
	attack_audio_player.name = "GolemAttackPlayer"
	attack_audio_player.bus = "SFX"
	attack_audio_player.max_distance = 25.0
	attack_audio_player.unit_size = 4.0
	add_child(attack_audio_player)
	attack_sounds.clear()

	_apply_archetype()
	health = max_health
	home_position = global_position

	if patrol_points.is_empty():
		patrol_points = [global_position]

	_setup_visuals_and_animations()
	_setup_health_label()

	combat = CombatController.new()
	add_child(combat)
	combat.setup(self, "golem")

func _apply_archetype() -> void:
	match golem_type.to_lower():
		"petit":
			enemy_name = "Petit Golem"
			if custom_scale == 1.0: custom_scale = 0.80
			max_health = 70.0
			damage = 8.0
			walk_speed = 1.55
			run_speed = 3.7
			attack_range = 1.1
			detection_radius = 7.0
		"grand":
			enemy_name = "Grand Golem"
			if custom_scale == 1.0: custom_scale = 1.42
			max_health = 175.0
			damage = 18.0
			walk_speed = 1.1
			run_speed = 2.6
			attack_range = 1.6
			detection_radius = 8.0
		_: # "standard"
			enemy_name = "Golem"
			if custom_scale == 1.0: custom_scale = 1.05
			max_health = 100.0
			damage = 12.0
			walk_speed = 1.35
			run_speed = 3.2
			attack_range = 1.3
			detection_radius = 7.5

	if visual != null:
		visual.scale = Vector3.ONE * custom_scale

	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		var capsule := collision_shape.shape as CapsuleShape3D
		capsule.radius = 0.42 * custom_scale
		capsule.height = 1.15 * custom_scale
		collision_shape.position = Vector3(0, 0.58 * custom_scale, 0)

func _setup_visuals_and_animations() -> void:
	if visual == null:
		return
	animator = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator == null:
		return

	for clip in animator.get_animation_list():
		var clean := _clean_anim_name(clip)
		if clean in ["marche", "rest_position"]:
			animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
		elif clean == "attaque":
			animator.get_animation(clip).loop_mode = Animation.LOOP_NONE

	_play_anim("rest_position")

func _setup_health_label() -> void:
	health_label = Label3D.new()
	health_label.position = Vector3(0, 1.35 * custom_scale, 0)
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 32
	health_label.modulate = Color(1.0, 0.55, 0.22)
	health_label.outline_modulate = Color.BLACK
	health_label.outline_size = 4
	health_label.text = "%s : %d / %d PV" % [enemy_name, int(health), int(max_health)]
	health_label.hide()
	add_child(health_label)

func _clean_anim_name(name: String) -> String:
	var idx := name.rfind("/")
	if idx >= 0: return name.substr(idx + 1)
	idx = name.rfind("|")
	if idx >= 0: return name.substr(idx + 1)
	return name

func _play_anim(clip_target: String, blend: float = 0.15, speed: float = 1.0) -> void:
	if animator == null:
		return
	var matched := ""
	for anim in animator.get_animation_list():
		if _clean_anim_name(anim) == clip_target:
			matched = anim
			break
	if matched != "":
		if animator.current_animation != matched or not animator.is_playing():
			animator.play(matched, blend, speed)
		else:
			animator.speed_scale = speed

func _clear_sight(target: Node3D) -> bool:
	var from_pos := global_position + Vector3.UP * (0.7 * custom_scale)
	var to_pos := target.global_position + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos, 5, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target

func _physics_process(delta: float) -> void:
	if health <= 0.0:
		return

	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D

	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor():
		velocity.y -= 20.0 * delta

	cooldown = maxf(0.0, cooldown - delta)

	var inventory := get_node_or_null("/root/Inventory")
	if inventory != null and inventory.is_open:
		if animator != null and animator.is_playing():
			animator.pause()
		HitFeedback.apply_recoil(self, delta)
		move_and_slide()
		return
	elif animator != null and not animator.is_playing():
		animator.play()

	if combat.tick(delta):
		HitFeedback.apply_recoil(self, delta)
		move_and_slide()
		return

	# Periodic sight sensing
	sight_timer -= delta
	sight_memory = maxf(0.0, sight_memory - delta)
	if sight_timer <= 0.0:
		sight_timer = 0.15
		sees_player = is_instance_valid(player) and _clear_sight(player)
		if sees_player:
			last_seen_position = player.global_position
			sight_memory = 4.0

	_process_navigation(delta)

	HitFeedback.apply_recoil(self, delta)
	move_and_slide()

func _process_navigation(delta: float) -> void:
	var pursuing := false
	if is_instance_valid(player):
		var distance := global_position.distance_to(player.global_position)
		var engaged := (state == "chase")
		var max_dist := leash_radius if engaged else detection_radius
		var dist_to_home := global_position.distance_to(home_position)
		pursuing = distance < max_dist and dist_to_home < leash_radius and (sees_player or (engaged and sight_memory > 0.0))

		if pursuing:
			var offset := player.global_position - global_position
			var flat := Vector3(offset.x, 0.0, offset.z)
			if sees_player and flat.length() <= attack_range and absf(offset.y) < 1.3:
				_turn_toward(player.global_position, delta * 12.0)
				if cooldown <= 0.0:
					combat.start_attack()
				else:
					_play_anim("rest_position", 0.15)
			else:
				state = "chase"
				var target_pos := player.global_position if sees_player else last_seen_position
				_move_toward(target_pos, run_speed, delta)
				_play_anim("marche", 0.12, run_speed / walk_speed)

	if not pursuing:
		if state == "chase":
			state = "return"

		if state == "return":
			var nearest_target := home_position
			if not patrol_points.is_empty():
				nearest_target = patrol_points[patrol_index]
			var dist := Vector2(nearest_target.x - global_position.x, nearest_target.z - global_position.z).length()
			if dist > 0.6:
				_move_toward(nearest_target, walk_speed, delta)
				_play_anim("marche", 0.15, 1.0)
			else:
				state = "patrol"
		elif state == "wait":
			wait_timer -= delta
			_play_anim("rest_position", 0.15, 1.0)
			if wait_timer <= 0.0:
				patrol_index = (patrol_index + 1) % patrol_points.size()
				state = "patrol"
		elif state == "patrol":
			if patrol_points.is_empty():
				_play_anim("rest_position", 0.15, 1.0)
				return
			var target_wp := patrol_points[patrol_index]
			var dist := Vector2(target_wp.x - global_position.x, target_wp.z - global_position.z).length()
			if dist <= 0.6:
				state = "wait"
				wait_timer = patrol_wait_time + randf_range(-0.4, 0.4)
				_play_anim("rest_position", 0.15, 1.0)
			else:
				_move_toward(target_wp, walk_speed, delta)
				_play_anim("marche", 0.15, 1.0)

func _move_toward(destination: Vector3, speed: float, delta: float) -> void:
	var desired_dir := destination - global_position
	desired_dir.y = 0.0
	if desired_dir.length_squared() < 0.001:
		return
	desired_dir = desired_dir.normalized()

	# Obstacle avoidance via whisker raycasts
	var steer_dir := _steer_around_obstacles(desired_dir)
	velocity.x = steer_dir.x * speed
	velocity.z = steer_dir.z * speed

	_turn_toward(global_position + steer_dir, delta * 10.0)

func _steer_around_obstacles(desired: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray_start := global_position + Vector3.UP * (0.4 * custom_scale)
	var forward_query := PhysicsRayQueryParameters3D.create(ray_start, ray_start + desired * 1.1, 1, [get_rid()])
	var hit := space.intersect_ray(forward_query)
	if hit.is_empty():
		return desired

	# Test 40-degree left and right deviations
	var left_dir := desired.rotated(Vector3.UP, deg_to_rad(40.0))
	var right_dir := desired.rotated(Vector3.UP, deg_to_rad(-40.0))
	var left_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, ray_start + left_dir * 1.1, 1, [get_rid()]))
	var right_hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, ray_start + right_dir * 1.1, 1, [get_rid()]))

	if left_hit.is_empty():
		return left_dir
	elif right_hit.is_empty():
		return right_dir
	return desired

func _turn_toward(target_pos: Vector3, rate: float) -> void:
	var dir := target_pos - global_position
	dir.y = 0.0
	if dir.length_squared() > 0.01:
		var target_angle := atan2(dir.x, dir.z)
		if visual != null:
			visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, minf(rate, 1.0))
		else:
			rotation.y = lerp_angle(rotation.y, target_angle, minf(rate, 1.0))

func take_damage(amount: float, source: Vector3, attack_kind: String = "claw") -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	HitFeedback.hit(self, source, 2.8)
	health = maxf(0.0, health - combat.receive_hit(amount, source, attack_kind))
	if health <= 0.0:
		Progression.reward_enemy(self, 60)
		state = "dead"
		set_physics_process(false)
		hide()
		queue_free()
		return

	if health_label != null:
		health_label.text = "%s : %d / %d PV" % [enemy_name, int(health), int(max_health)]
		health_label.show()

	last_seen_position = source
	sight_memory = 4.0

