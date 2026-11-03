extends CharacterBody3D
const HitFeedback = preload("res://scripts/hit_feedback.gd")

const CombatController = preload("res://scripts/enemy_combat.gd")
@export var combat_animations: Dictionary = {}
@export_enum("auto", "equilibre", "agressif", "prudent", "peureux") var temperament := "auto"
@export var behavior_seed := 0
@export var corrupted_carapace := false
var corruption_shell: MeshInstance3D
var combat: Node

## Araignée géante de la Forêt Maléfique.
## IA de patrouille/garde, détection vibratoire et visuelle, poursuite et attaque crachat/contact.

@export var enemy_name: String = "Araignée géante"
@export var max_health: float = 80.0
@export var damage: float = 15.0
@export var spider_scale: float = 1.5
@export var walk_speed: float = 2.0
@export var chase_speed: float = 3.6
@export var walk_anim_speed: float = 1.0 # Cadence des pattes (le cycle de base a été accéléré de 3x dans le modèle)
@export var detection_radius: float = 18.0
@export var attack_range: float = 2.4
@export var leash_radius: float = 35.0
@export var patrol_radius: float = 10.0

var health: float = 80.0
var health_label: Label3D
var label_hide_timer: float = 0.0

var home_position: Vector3
var wander_target: Vector3 = Vector3.ZERO
var state: String = "idle" # "idle", "patrol", "chase", "attack", "dead"

var idle_timer: float = 0.0
var stuck_timer: float = 0.0
var last_patrol_pos: Vector3 = Vector3.ZERO

var attack_time: float = 0.0
var hit_applied: bool = false
var attack_cooldown: float = 0.0

var player: CharacterBody3D
var sight_memory: float = 0.0
var sight_timer: float = 0.0
var sees_player: bool = false

@onready var visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mouth_socket: Marker3D = $MouthSocket

var animator: AnimationPlayer

var walk_anim_name: String = ""
var attack_anim_name: String = ""
var idle_anim_name: String = ""
var attack_audio_player: AudioStreamPlayer3D
var attack_sounds: Array[AudioStream] = []

const GRAVITY: float = 25.0
const ATTACK_HIT_TIME: float = 1.2917 # Image 31 à 24 i/s (instant exact de projection buccale)
const ATTACK_TOTAL_TIME: float = 2.50 # 60 images à 24 i/s

func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	home_position = global_position
	wander_target = global_position
	last_patrol_pos = global_position
	if corrupted_carapace:
		corruption_shell = MeshInstance3D.new()
		var shell_mesh := SphereMesh.new()
		shell_mesh.radius = spider_scale * 0.85
		shell_mesh.height = spider_scale * 1.3
		corruption_shell.mesh = shell_mesh
		corruption_shell.position.y = spider_scale * 0.45
		var skin := ShaderMaterial.new()
		skin.shader = preload("res://shaders/corrupted_carapace.gdshader")
		corruption_shell.material_override = skin
		corruption_shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(corruption_shell)
	idle_timer = randf_range(1.0, 2.5)
	
	attack_audio_player = AudioStreamPlayer3D.new()
	attack_audio_player.name = "SpiderAttackPlayer"
	attack_audio_player.bus = "SFX"
	attack_audio_player.max_distance = 22.0
	attack_audio_player.unit_size = 3.5
	add_child(attack_audio_player)
	attack_sounds.clear()

	# Floor snap and slope settings to ensure legs stay on the ground
	floor_snap_length = 0.6 * spider_scale
	floor_max_angle = deg_to_rad(55.0)
	floor_constant_speed = true
	
	# 1. Visual setup: scale visual directly
	if visual:
		visual.scale = Vector3.ONE * spider_scale
		visual.position = Vector3.ZERO
		animator = visual.find_child("AnimationPlayer", true, false)
		
	# 2. Collision setup: calibrate shape so bottom is ALWAYS at Y = 0.0
	if collision_shape:
		var h: float = 0.65 * spider_scale
		var r: float = 0.65 * spider_scale
		var cyl := CylinderShape3D.new()
		cyl.height = h
		cyl.radius = r
		collision_shape.shape = cyl
		collision_shape.scale = Vector3.ONE
		collision_shape.position = Vector3(0.0, h * 0.5, 0.0)
		
	# 3. Mouth Socket
	if mouth_socket:
		mouth_socket.position = Vector3(0.0, 0.35 * spider_scale, 0.55 * spider_scale)
		
	# 4. Setup Health Label (Billboard 3D above spider)
	health_label = Label3D.new()
	health_label.position = Vector3(0.0, 0.75 * spider_scale + 0.45, 0.0)
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.font_size = int(30 + 4 * spider_scale)
	health_label.modulate = Color(0.95, 0.35, 0.25)
	health_label.outline_modulate = Color.BLACK
	health_label.outline_size = 8
	health_label.hide()
	add_child(health_label)
	
	# 5. Resolve animation names
	_setup_animations()

	combat = CombatController.new()
	add_child(combat)
	combat.setup(self, "spider")

func _setup_animations() -> void:
	if not animator: return
	
	if animator.has_animation("Araignee_Marche"):
		walk_anim_name = "Araignee_Marche"
	elif animator.has_animation("Araignee_Marche_Loop"):
		walk_anim_name = "Araignee_Marche_Loop"
		
	if animator.has_animation("Araignee_Attaque_Crachat"):
		attack_anim_name = "Araignee_Attaque_Crachat"
		
	if animator.has_animation("araigné1_default"):
		idle_anim_name = "araigné1_default"
		
	if walk_anim_name != "":
		var a = animator.get_animation(walk_anim_name)
		if a: a.loop_mode = Animation.LOOP_LINEAR
		
	if attack_anim_name != "":
		var a = animator.get_animation(attack_anim_name)
		if a: a.loop_mode = Animation.LOOP_NONE
		
	_play_anim(walk_anim_name, 0.2, 1.0)

func _play_anim(anim_name: String, blend_time: float = 0.15, speed: float = 1.0) -> void:
	if not animator or anim_name == "": return
	animator.speed_scale = speed
	if animator.current_animation != anim_name or not animator.is_playing():
		animator.play(anim_name, blend_time)

func _clear_sight(target: Node3D) -> bool:
	if not is_instance_valid(target): return false
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * (0.6 * spider_scale),
		target.global_position + Vector3.UP * 0.9,
		1, # Environment layer
		[get_rid()]
	)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.collider == target

func _physics_process(delta: float) -> void:
	if state == "dead":
		return
		
	# Apply gravity & floor snap
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = -0.5
		
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	
	# Health label auto-hide
	if label_hide_timer > 0.0:
		label_hide_timer -= delta
		if label_hide_timer <= 0.0:
			health_label.hide()
			
	# Pause if player inventory is open
	var inventory := get_node_or_null("/root/Inventory")
	if inventory != null and inventory.is_open:
		if animator and animator.is_playing(): animator.pause()
		velocity.x = 0.0
		velocity.z = 0.0
		HitFeedback.apply_recoil(self, delta)
		move_and_slide()
		return
	elif animator and not animator.is_playing() and state != "idle":
		animator.play()
		
	# Acquire player reference
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
		
	if combat.tick(delta):
		HitFeedback.apply_recoil(self, delta)
		move_and_slide()
		return

	# Senses update
	sight_timer -= delta
	sight_memory = maxf(0.0, sight_memory - delta)
	if sight_timer <= 0.0 and is_instance_valid(player):
		sight_timer = 0.2
		var d := global_position.distance_to(player.global_position)
		# Spiders sense footsteps/vibrations closely (< 65% detection radius), or check line of sight further out
		if d <= detection_radius * 0.65:
			sees_player = true
			sight_memory = 5.0
		elif d <= detection_radius:
			sees_player = _clear_sight(player)
			if sees_player: sight_memory = 5.0
		else:
			sees_player = false
			
	# State Machine execution
	match state:
		"idle":
			_process_idle(delta)
		"patrol":
			_process_patrol(delta)
		"chase":
			_process_chase(delta)
			
	HitFeedback.apply_recoil(self, delta)
	move_and_slide()

func _process_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
	
	# Rest pose when stationary
	if idle_anim_name != "":
		_play_anim(idle_anim_name, 0.25, 1.0)
	else:
		_play_anim(walk_anim_name, 0.25, 0.0)
	
	if _should_engage_player():
		state = "chase"
		return
		
	idle_timer -= delta
	if idle_timer <= 0.0:
		_pick_new_wander_target()
		state = "patrol"
		stuck_timer = 0.0
		last_patrol_pos = global_position

func _process_patrol(delta: float) -> void:
	if _should_engage_player():
		state = "chase"
		return
		
	var flat_dist := Vector2(wander_target.x - global_position.x, wander_target.z - global_position.z)
	if flat_dist.length() < 1.4:
		state = "idle"
		idle_timer = randf_range(2.0, 4.5)
		return
		
	# Check if blocked or stuck against a tree
	if global_position.distance_to(last_patrol_pos) < 0.15:
		stuck_timer += delta
		if stuck_timer > 1.2:
			# Pick new target if wedged
			_pick_new_wander_target()
			stuck_timer = 0.0
			return
	else:
		stuck_timer = 0.0
		last_patrol_pos = global_position
		
	var move_dir := Vector3(flat_dist.x, 0.0, flat_dist.y).normalized()
	velocity.x = move_dir.x * walk_speed
	velocity.z = move_dir.z * walk_speed
	
	_rotate_towards(move_dir, delta * 5.0)
	_play_anim(walk_anim_name, 0.15, walk_anim_speed)

func _process_chase(delta: float) -> void:
	if not is_instance_valid(player):
		state = "idle"
		return
		
	var dist_to_home := global_position.distance_to(home_position)
	var dist_to_player := global_position.distance_to(player.global_position)
	
	# Leash check: return if player fled beyond leash
	if dist_to_home > leash_radius or (sight_memory <= 0.0 and dist_to_player > detection_radius):
		state = "patrol"
		wander_target = home_position
		return
		
	var offset := player.global_position - global_position
	var flat := Vector3(offset.x, 0.0, offset.z)
	var current_attack_range := attack_range * (0.85 + 0.15 * spider_scale)
	
	# Close enough to attack
	if flat.length() <= current_attack_range and absf(offset.y) < 2.0:
		_rotate_towards(flat.normalized(), delta * 12.0)
		if attack_cooldown <= 0.0:
			combat.start_attack()
			return
		else:
			# Waiting for cooldown: slow circle / approach
			velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
			_play_anim(walk_anim_name, 0.2, walk_anim_speed * 0.5)
			return
			
	# Charge towards player
	var move_dir := flat.normalized()
	velocity.x = move_dir.x * chase_speed
	velocity.z = move_dir.z * chase_speed
	
	_rotate_towards(move_dir, delta * 8.0)
	_play_anim(walk_anim_name, 0.12, walk_anim_speed * 1.35)

func _should_engage_player() -> bool:
	if not is_instance_valid(player): return false
	var dist := global_position.distance_to(player.global_position)
	if dist <= detection_radius and (sees_player or dist <= detection_radius * 0.65):
		return true
	if sight_memory > 0.0 and dist <= leash_radius:
		return true
	return false

func _pick_new_wander_target() -> void:
	var angle := randf_range(0.0, TAU)
	var dist := randf_range(3.0, patrol_radius)
	wander_target = home_position + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)

func _rotate_towards(dir: Vector3, rate: float) -> void:
	if dir.length_squared() > 0.001 and visual:
		var target_angle := atan2(dir.x, dir.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, target_angle, minf(rate, 1.0))

func take_damage(amount: float, source: Vector3, attack_kind: String = "claw") -> void:
	if health <= 0.0 or amount <= 0.0: return
	if corrupted_carapace:
		if attack_kind != "nova":
			combat.status_label.text = "CARAPACE CORROMPUE · ONDE PRIMORDIALE (Q)"
			combat.status_label.modulate = Color("aaffea")
			combat.status_label.show()
			sight_memory = 8.0
			return
		corrupted_carapace = false
		if is_instance_valid(corruption_shell): corruption_shell.queue_free()
		var bag := get_node_or_null("/root/Inventory")
		if bag: bag.ui.notify("L’Onde primordiale brise la carapace corrompue !")
	
	HitFeedback.hit(self, source, 6.5)
	health = maxf(0.0, health - combat.receive_hit(amount, source, attack_kind))
	label_hide_timer = 4.5
	
	if health_label:
		health_label.text = "%s : %d / %d PV" % [enemy_name, int(health), int(max_health)]
		health_label.show()
		
	# Immediate agro on attacker
	sight_memory = 8.0
	sees_player = true

		
	if health <= 0.0:
		Progression.reward_enemy(self, 30)
		_die()

func _die() -> void:
	state = "dead"
	combat.status_label.hide()
	set_physics_process(false)
	
	if collision_shape:
		collision_shape.set_deferred("disabled", true)
		
	if health_label:
		health_label.text = "%s : Éliminée !" % enemy_name
		
	var tween := create_tween()
	if visual:
		tween.tween_property(visual, "position:y", -0.5 * spider_scale, 1.2)
		tween.parallel().tween_property(visual, "scale", visual.scale * 0.7, 1.2)
	tween.tween_callback(queue_free)
