extends CharacterBody3D
const HitFeedback = preload("res://scripts/hit_feedback.gd")

const CombatController = preload("res://scripts/enemy_combat.gd")
const CLOTHING_SHADER = preload("res://shaders/bandit_clothing.gdshader")
const COLOR_VARIANTS := {
	"vert": {"color": Color("4b995a"), "hue_shift": 0.32, "damage_scale": 0.75, "label": "Bandit vert"},
	"jaune": {"color": Color("c5a03e"), "hue_shift": 0.13, "damage_scale": 1.0, "label": "Bandit jaune"},
	"noir": {"color": Color("89909b"), "hue_shift": 0.0, "saturation_scale": 0.0, "value_scale": 0.30, "damage_scale": 4.0 / 3.0, "label": "Bandit noir"},
}
## Auto is stable per spawn. Naturel retains the original appearance and damage.
@export_enum("auto", "vert", "jaune", "noir", "naturel") var color_variant := "auto"
var selected_color_variant := "naturel"
var enemy_name := "Bandit"
# Share immutable materials between bandits of the same color, never mutate the GLB.
static var _variant_materials: Dictionary = {}
@export var combat_animations: Dictionary = {}
@export_enum("auto", "equilibre", "agressif", "prudent", "peureux") var temperament := "auto"
@export var behavior_seed := 0
@export var use_navigation := true
var combat: Node

## Camp guard: sight-based pursuit, a committed punch, then return to camp.
@export var detection_radius := 8.0
@export var leash_radius := 15.0
@export var run_speed := 3.5
@export var walk_speed := 1.5
@export var attack_range := 1.15
@export var damage := 12.0
@export var max_health := 100.0
## Time spent holding the final death pose before fading out.
@export_range(0.0, 60.0, 0.5) var corpse_lifetime := 8.0
@export_range(0.0, 5.0, 0.1) var corpse_fade_duration := 1.0
const DEATH_ANIMATION := "Death_Fall_Back"
var health := 100.0
var health_label: Label3D
var home: Vector3
var state := "idle"
var attack_time := 0.0
var hit_applied := false
var cooldown := 0.0
var player: CharacterBody3D
var last_seen_position: Vector3
var sight_memory := 0.0
var sight_timer := 0.0
var sees_player := false
var path_timer := 0.0
var path_destination := Vector3.INF
@onready var visual: Node3D = $Visual
@onready var animator: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)
@onready var navigation: NavigationAgent3D = $NavigationAgent3D
var attack_audio_player: AudioStreamPlayer3D
var attack_sounds: Array[AudioStream] = []

func _ready() -> void:
	_setup_color_variant()
	health = max_health
	health_label = Label3D.new()
	health_label.position = Vector3(0, 2.15, 0)
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = 36
	health_label.modulate = COLOR_VARIANTS[selected_color_variant].color if selected_color_variant in COLOR_VARIANTS else Color(1.0, 0.4, 0.3)
	health_label.hide()
	add_child(health_label)
	
	attack_audio_player = AudioStreamPlayer3D.new()
	attack_audio_player.name = "BanditAttackPlayer"
	attack_audio_player.bus = "SFX"
	attack_audio_player.max_distance = 18.0
	attack_audio_player.unit_size = 3.0
	add_child(attack_audio_player)
	attack_sounds.clear()

	home = global_position
	for clip in ["Idle", "Walking", "Running"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	_play("Idle")
	animator.get_animation(DEATH_ANIMATION).loop_mode = Animation.LOOP_NONE

	combat = CombatController.new()
	add_child(combat)
	combat.setup(self, "bandit")

func _setup_color_variant() -> void:
	selected_color_variant = color_variant
	if selected_color_variant == "auto":
		var rng := RandomNumberGenerator.new()
		# World position survives sector unload/reload and does not depend on node order.
		rng.seed = hash(str(global_position.snapped(Vector3.ONE * 0.01)))
		selected_color_variant = ["vert", "jaune", "noir"][rng.randi_range(0, 2)]
	if selected_color_variant not in COLOR_VARIANTS:
		selected_color_variant = "naturel"
		return
	var variant: Dictionary = COLOR_VARIANTS[selected_color_variant]
	damage *= float(variant.damage_scale)
	enemy_name = variant.label
	for node in visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface in range(mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original == null: continue
			var key := "%s:%s" % [original.get_instance_id(), selected_color_variant]
			if not _variant_materials.has(key):
				var material := ShaderMaterial.new()
				material.shader = CLOTHING_SHADER
				material.set_shader_parameter("hue_shift", variant.hue_shift)
				material.set_shader_parameter("saturation_scale", variant.get("saturation_scale", 1.0))
				material.set_shader_parameter("value_scale", variant.get("value_scale", 1.0))
				material.set_shader_parameter("base_color", original.albedo_color)
				material.set_shader_parameter("albedo_texture", original.albedo_texture)
				material.set_shader_parameter("normal_texture", original.normal_texture)
				material.set_shader_parameter("normal_enabled", original.normal_enabled)
				material.set_shader_parameter("normal_scale", original.normal_scale)
				material.set_shader_parameter("orm_texture", original.roughness_texture)
				material.set_shader_parameter("orm_enabled", original.roughness_texture != null)
				material.set_shader_parameter("roughness_value", original.roughness)
				material.set_shader_parameter("metallic_value", original.metallic)
				_variant_materials[key] = material
			mesh.set_surface_override_material(surface, _variant_materials[key])

func _play(clip: String) -> void:
	if animator.current_animation != clip:
		animator.play(clip, 0.12)

func _clear_sight(target: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, target.global_position + Vector3.UP * 0.6, 3, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target

func _physics_process(delta: float) -> void:
	if health <= 0.0: return
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	velocity.x = 0.0
	velocity.z = 0.0
	if not is_on_floor(): velocity.y -= 20.0 * delta
	cooldown = maxf(0.0, cooldown - delta)
	var inventory := get_node_or_null("/root/Inventory")
	if inventory != null and inventory.is_open:
		animator.pause()
		HitFeedback.apply_recoil(self, delta)
		move_and_slide()
		return
	if not animator.is_playing(): animator.play()
	if combat.tick(delta):
		HitFeedback.apply_recoil(self, delta)
		move_and_slide()
		return

	path_timer = maxf(0.0, path_timer - delta)
	sight_timer -= delta
	sight_memory = maxf(0.0, sight_memory - delta)
	if sight_timer <= 0.0:
		sight_timer = 0.15
		sees_player = is_instance_valid(player) and _clear_sight(player)
		if sees_player:
			last_seen_position = player.global_position
			sight_memory = 4.0
	var pursuing := false
	if is_instance_valid(player):
		var distance := global_position.distance_to(player.global_position)
		var engaged := state == "chase"
		pursuing = distance < (leash_radius if engaged else detection_radius) and player.global_position.distance_to(home) < leash_radius and (sees_player or (engaged and sight_memory > 0.0))
		if pursuing:
			var offset := player.global_position - global_position
			var flat := Vector3(offset.x, 0, offset.z)
			if sees_player and flat.length() <= attack_range and absf(offset.y) < 1.0:
				visual.rotation.y = lerp_angle(visual.rotation.y, atan2(flat.x, flat.z), minf(delta * 12.0, 1.0))
				if cooldown <= 0.0:
					combat.start_attack()
				else: _play("Idle")
			else:
				state = "chase"
				_move_toward(player.global_position if sees_player else last_seen_position, run_speed, delta)
				_play("Running")
	if not pursuing:
		var home_flat := Vector2(home.x - global_position.x, home.z - global_position.z)
		if home_flat.length() > 0.3:
			state = "return"
			_move_toward(home, walk_speed, delta)
			_play("Walking")
		else:
			state = "idle"
			_play("Idle")
	HitFeedback.apply_recoil(self, delta)
	move_and_slide()

func take_damage(amount: float, source: Vector3, attack_kind: String = "claw") -> void:
	if health <= 0.0 or amount <= 0.0: return
	HitFeedback.hit(self, source, 6.5)
	health = maxf(0.0, health - combat.receive_hit(amount, source, attack_kind))
	if health <= 0.0:
		Progression.reward_enemy(self, 40)
		_die()
		return
	health_label.text = "%s : %d / %d PV" % [enemy_name, int(health), int(max_health)]
	health_label.show()
	last_seen_position = source
	sight_memory = 4.0

func _die() -> void:
	if state == "dead": return
	state = "dead"
	var gold_drop := preload("res://scripts/gold_pickup.gd").new()
	gold_drop.amount = randi_range(5, 12)
	get_parent().add_child(gold_drop)
	gold_drop.global_position = global_position
	set_physics_process(false)
	velocity = Vector3.ZERO
	HitFeedback.clear_recoil(self)
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	$CollisionShape3D.set_deferred("disabled", true)
	navigation.avoidance_enabled = false
	health_label.hide()
	combat.set_process(false)
	combat.set_physics_process(false)
	combat.status_label.hide()
	attack_audio_player.stop()
	animator.clear_queue()
	animator.speed_scale = 1.0
	animator.play(DEATH_ANIMATION, 0.08, 1.0)
	await animator.animation_finished
	# A non-looping AnimationPlayer holds the last pose while the body remains.
	await get_tree().create_timer(corpse_lifetime, false).timeout
	if corpse_fade_duration > 0.0:
		var fade := create_tween().set_parallel(true)
		for mesh in visual.find_children("*", "GeometryInstance3D", true, false):
			fade.tween_property(mesh, "transparency", 1.0, corpse_fade_duration)
		await fade.finished
	queue_free()


func _move_toward(destination: Vector3, speed: float, delta: float) -> void:
	var next := destination
	var map := navigation.get_navigation_map()
	var on_mesh := false
	if use_navigation and NavigationServer3D.map_get_iteration_id(map) > 0 and not NavigationServer3D.map_get_regions(map).is_empty():
		on_mesh = NavigationServer3D.map_get_closest_point(map, global_position).distance_to(global_position) < 2.0 and NavigationServer3D.map_get_closest_point(map, destination).distance_to(destination) < 2.0
	if on_mesh:
		# Reuse the baked route; only refresh a moving destination a few times a second.
		if path_timer <= 0.0 and (path_destination == Vector3.INF or path_destination.distance_to(destination) > 0.5):
			path_destination = destination
			navigation.target_position = destination
			path_timer = 0.35
		next = navigation.get_next_path_position()
		if navigation.is_navigation_finished(): return
	var direction := next - global_position
	direction.y = 0.0
	direction = direction.normalized()
	if not on_mesh: direction = _safe_roaming_direction(direction)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	if direction.length_squared() > 0.0:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(direction.x, direction.z), minf(delta * 10.0, 1.0))

func _safe_roaming_direction(desired: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	for angle in [0.0, 0.65, -0.65, 1.2, -1.2]:
		var direction := desired.rotated(Vector3.UP, angle)
		var origin := global_position + Vector3.UP * 0.7
		var wall := PhysicsRayQueryParameters3D.create(origin, origin + direction * 1.1, 1, [get_rid()])
		if not space.intersect_ray(wall).is_empty(): continue
		var low_origin := global_position + Vector3.UP * 0.3
		var low_wall := PhysicsRayQueryParameters3D.create(low_origin, low_origin + direction * 0.8, 1, [get_rid()])
		if not space.intersect_ray(low_wall).is_empty(): continue
		var floor_query := PhysicsRayQueryParameters3D.create(origin + direction * 0.8, global_position + direction * 0.8 - Vector3.UP * 0.9, 1, [get_rid()])
		var ground := space.intersect_ray(floor_query)
		if not ground.is_empty() and ground.normal.y > 0.65: return direction
	return Vector3.ZERO
