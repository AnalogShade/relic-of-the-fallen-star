extends CharacterBody3D
const HitFeedback = preload("res://scripts/hit_feedback.gd")
## Camera-relative movement, jump and hold-to-glide aerial control.
@export var speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_speed: float = 6.5
@export var air_jump_speed: float = 7.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.0025
@export var world_bounds := Rect2(-31.0, -38.0, 62.0, 61.0)
@onready var pivot: Node3D = $CameraPivot
@onready var arm: SpringArm3D = $CameraPivot/SpringArm3D
var dodge: Node
var spawn_position: Vector3
var coyote_time: float = 0.0
var jump_buffer: float = 0.0
var gliding := false
@export var swim_speed := 2.0
@export var swim_jump_speed := 11.5
@export var swim_jump_move_speed := 4.5
@export var swim_enter_depth := 0.9
@export var swim_exit_depth := 0.72
@export var float_depth := 0.9
var swimming := false
var water_jump_active := false
var water_height := -INF
var water_surface: Node
var water_footsteps: Node
var jumped_this_air := false
var air_jump_used := false
var health := 100.0
var max_health: float:
	get: return Progression.maximum_health()
var guardian_knockback := 0.0
var rest_state := ""
var rest_controller: Node
var damage_invulnerability := 0.0
var health_label: Label
var damage_flash: ColorRect
var combat_ui: CanvasLayer
var combat_feedback_time := 0.0
@export var claw_damage := 25.0
@export var claw_range := 1.8
@export_range(0.0, 1.0) var left_claw_chance := 0.35
@export var left_claw_damage_multiplier := 2.0
const LEFT_CLAW_IMPACT_TIME := 0.32
const CLAW_BUFFER_TIME := 0.65
const CLAW_CHAIN_GRACE := 0.65
var claw_buffer_remaining := 0.0
var claw_chain_remaining := 0.0
var claw_chain_count := 0
var active_claw_left := false
var active_claw_clip := "Nael_Claw"
var active_claw_impact := 0.55
var is_attacking := false
# Nael_Claw: the right hand reaches the front of the swing at 0.55 s.
const CLAW_IMPACT_TIME := 0.55
const CLAW_AUDIO_PEAK_TIME := 0.151
var claw_hit_applied := false
var claw_requested := false
var axe_throw_requested := false
var active_axe_strike := false
var claw_sounds: Array[AudioStream] = []
var claw_audio_player: AudioStreamPlayer
var claw_sound_played := false
var claw_trail: Node3D

# Fireball spell casting
const FireballScene: PackedScene = preload("res://scenes/spells/fireball_projectile.tscn")
var fireball_requested := false
var fireball_aiming := false
var ranged_item := "" # Locked when aiming starts; darts share the fireball cursor and animation.
var fireball_cursor := Vector2.ZERO
const FIREBALL_AIM_DISTANCE := 400.0
var fireball_target := Vector3.ZERO
var fireball_target_locked := false
var fireball_reticle: Control
var is_casting_spell := false
var fireball_spawned := false
var fireball_cooldown := 0.0
var nova_ability: Node
const FIREBALL_COOLDOWN_TIME := 0.8
const FIREBALL_RELEASE_TIME := 0.28
var fireball_sounds: Array[AudioStream] = []
var fireball_audio_player: AudioStreamPlayer

# Movement & Foley SFX
var footstep_player: AudioStreamPlayer
var water_footstep_player: AudioStreamPlayer
var water_footstep_players: Array[AudioStreamPlayer] = []
var water_footstep_sound: AudioStream
var water_footstep_pool_index := 0
var last_water_footstep_pitch := -1.0
var movement_player: AudioStreamPlayer
var footstep_sounds: Array[AudioStream] = []
var steps_twigs: Array[AudioStream] = []
var steps_grass: Array[AudioStream] = []
var steps_gravel: Array[AudioStream] = []
var jump_sound: AudioStream
var land_twigs: AudioStream
var land_grass: AudioStream
var land_gravel: AudioStream
# Character Voice SFX
var voice_player: AudioStreamPlayer
var voice_attack_sounds: Array[AudioStream] = []
var voice_damage_sounds: Array[AudioStream] = []
var voice_jump_sounds: Array[AudioStream] = []
var voice_land_sounds: Array[AudioStream] = []
var step_distance := 0.0
var anim_step_prev_pos := -1.0
var anim_step_prev_name := ""
var last_footstep_index := -1
var was_on_floor := true
var previous_vertical_velocity := 0.0
var stuck_recovery := preload("res://scripts/stuck_recovery.gd").new()
var attack_feedback: Label
@export var glide_speed := 8.4
@export var glide_fall_speed := 1.3
@export var glide_braking := 14.0

func _ready() -> void:
	add_child(preload("res://scripts/progression_hud.gd").new())
	Progression.changed.connect(_on_progression_changed)
	add_child(stuck_recovery)
	dodge = preload("res://scripts/nael_dodge.gd").new()
	dodge.name = "Dodge"
	add_child(dodge)
	rest_controller = preload("res://scripts/camp_rest.gd").new()
	add_child(rest_controller)
	combat_ui = CanvasLayer.new()
	combat_ui.layer = 12
	add_child(combat_ui)
	damage_flash = ColorRect.new()
	damage_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	damage_flash.color = Color(0.65, 0.02, 0.01, 0.0)
	combat_ui.add_child(damage_flash)
	health_label = Label.new()
	health_label.position = Vector2(24, 120)
	health_label.add_theme_font_size_override("font_size", 22)
	health_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	health_label.add_theme_constant_override("shadow_offset_x", 2)
	health_label.add_theme_constant_override("shadow_offset_y", 2)
	combat_ui.add_child(health_label)
	nova_ability = preload("res://scripts/spells/nova_ability.gd").new()
	nova_ability.name = "NovaAbility"
	add_child(nova_ability)
	attack_feedback = Label.new()
	attack_feedback.position = Vector2(24, 150)
	attack_feedback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attack_feedback.add_theme_font_size_override("font_size", 20)
	combat_ui.add_child(attack_feedback)
	health_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var aim_layer := CanvasLayer.new()
	aim_layer.layer = 13
	add_child(aim_layer)
	fireball_reticle = preload("res://scripts/spells/fireball_reticle.gd").new()
	aim_layer.add_child(fireball_reticle)
	fireball_reticle.hide()
	combat_ui.hide()
	var held := preload("res://scripts/held_equipment.gd").new()
	held.name = "HeldEquipment"
	add_child(held)
	claw_trail = get_node_or_null("ClawTrail")
	_init_audio()
	spawn_position = global_position
	water_surface = preload("res://scripts/water_surface.gd").new()
	water_surface.name = "WaterSurface"
	add_child(water_surface)
	water_footsteps = preload("res://scripts/water_footsteps.gd").new()
	water_footsteps.name = "WaterFootsteps"
	add_child(water_footsteps)
	arm.add_excluded_object(get_rid())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _is_ui_blocking() -> bool:
	var inv = get_node_or_null("/root/Inventory")
	if inv and inv.is_open: return true
	var dlg = get_node_or_null("/root/DialogueManager")
	if dlg and dlg.is_open: return true
	var qm = get_node_or_null("/root/QuestManager")
	if qm and qm.is_journal_open: return true
	return false

func _unhandled_input(event: InputEvent) -> void:
	dodge.handle_input(event)
	if _is_ui_blocking():
		cancel_fireball_aim()
		return
	if event.is_action_pressed("primordial_nova") and not event.is_echo():
		nova_ability.try_cast()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			begin_fireball_aim()
		elif fireball_aiming:
			update_fireball_aim()
			fireball_target_locked = true
			fireball_requested = true
			fireball_aiming = false
			fireball_reticle.hide()
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				if event.ctrl_pressed and get_node("/root/Inventory").equipped == "axe":
					axe_throw_requested = true
				else:
					request_claw()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			arm.spring_length = maxf(2.0, arm.spring_length - 0.5)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			arm.spring_length = minf(9.0, arm.spring_length + 0.5)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if fireball_aiming:
			var viewport_size := get_viewport().get_visible_rect().size
			fireball_cursor = (fireball_cursor + event.relative).clamp(Vector2.ZERO, viewport_size)
			update_fireball_aim()
			return
		pivot.rotation.y -= event.relative.x * mouse_sensitivity
		arm.rotation.x = clampf(arm.rotation.x - event.relative.y * mouse_sensitivity, -1.1, 0.35)
	if event.is_action_pressed("reset_player"):
		respawn()

func _physics_process(delta: float) -> void:
	stuck_recovery.tick(delta)
	# Les restaurations/transitions doivent respecter la même règle que les dégâts.
	if health <= 0.0 or not is_finite(health):
		respawn()
	if guardian_knockback > 0.0:
		guardian_knockback = maxf(0.0, guardian_knockback - delta)
		damage_invulnerability = maxf(0.0, damage_invulnerability - delta)
		velocity.y -= gravity * delta
		HitFeedback.apply_recoil(self, delta)
		move_and_slide()
		return
	if fireball_aiming:
		if _is_ui_blocking() or rest_state != "" or swimming or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or (ranged_item == "sleep_dart" and (get_node("/root/Inventory").equipped != "sleep_dart" or get_node("/root/Inventory").get_item_count("sleep_dart") <= 0)):
			cancel_fireball_aim()
		else:
			update_fireball_aim()
	if rest_state != "":
		dodge.cancel()
		damage_invulnerability = maxf(0.0, damage_invulnerability - delta)
		damage_flash.color.a = move_toward(damage_flash.color.a, 0.0, delta * 0.8)
		rest_controller.physics_step(delta)
		return
	_update_swimming()
	if dodge.tick(delta):
		damage_invulnerability = maxf(0.0, damage_invulnerability - delta)
		return
	claw_buffer_remaining = maxf(0.0, claw_buffer_remaining - delta)
	if not is_attacking:
		claw_chain_remaining = maxf(0.0, claw_chain_remaining - delta)
		if claw_chain_remaining <= 0.0:
			claw_chain_count = 0
	fireball_cooldown = maxf(0.0, fireball_cooldown - delta)
	if axe_throw_requested:
		axe_throw_requested = false
		throw_axe()
	if fireball_requested:
		fireball_requested = false
		if not start_fireball():
			fireball_target_locked = false
	elif claw_requested:
		claw_requested = false
		start_claw()
	elif not is_attacking and claw_buffer_remaining > 0.0:
		claw_buffer_remaining = 0.0
		start_claw()
	if is_attacking:
		if _is_ui_blocking():
			cancel_claw()
		else:
			var animator: AnimationPlayer = $Nael.animator
			var expected_clip := "Nael_Claw" if is_casting_spell else active_claw_clip
			if animator.assigned_animation != expected_clip:
				cancel_claw()
			elif is_casting_spell:
				if not fireball_spawned and animator.current_animation_position >= FIREBALL_RELEASE_TIME:
					fireball_spawned = true
					spawn_fireball()
				if animator.current_animation_position >= animator.current_animation_length:
					is_attacking = false
					is_casting_spell = false
			else:
				# Synchronize claw sound so its peak impact coincides with the apex of the swing
				var anim_speed: float = animator.speed_scale if animator.speed_scale > 0.0 else 1.0
				var sound_start_pos := maxf(0.0, active_claw_impact - (CLAW_AUDIO_PEAK_TIME * anim_speed))
				if not claw_sound_played and animator.current_animation_position >= sound_start_pos:
					claw_sound_played = true
					if claw_audio_player and not claw_sounds.is_empty():
						var s: AudioStream = claw_sounds[0]
						claw_audio_player.stream = s
						# Variations aléatoires de pitch et volume pour rendre chaque coup unique et vivant
						claw_audio_player.pitch_scale = randf_range(0.92, 1.08)
						claw_audio_player.volume_db = randf_range(-2.5, -0.5)
						claw_audio_player.play()

				# Follow the displayed pose, including playback speed and pauses.
				if not claw_hit_applied and animator.current_animation_position >= active_claw_impact:
					claw_hit_applied = true
					apply_claw_hit()
				if animator.current_animation_position >= animator.current_animation_length:
					is_attacking = false
					is_casting_spell = false
					claw_chain_remaining = CLAW_CHAIN_GRACE
					if active_claw_left:
						claw_chain_count = 0
	damage_invulnerability = maxf(0.0, damage_invulnerability - delta)
	combat_feedback_time = maxf(0.0, combat_feedback_time - delta)
	if combat_feedback_time <= 0.0: attack_feedback.text = ""
	damage_flash.color.a = move_toward(damage_flash.color.a, 0.0, delta * 0.8)
	if combat_feedback_time <= 0.0 and health >= max_health: combat_ui.hide()
	if _is_ui_blocking():
		velocity.x = 0.0
		velocity.z = 0.0
		jump_buffer = 0.0
		if swimming:
			_apply_buoyancy(delta)
		elif not is_on_floor():
			velocity.y -= gravity * delta
		HitFeedback.apply_recoil(self, delta)
		move_and_slide()
		return
	var slope_support := _can_unstuck_jump()
	var can_jump_now := is_on_floor() or (coyote_time > 0.0 and not jumped_this_air) or slope_support
	coyote_time = 0.12 if is_on_floor() else maxf(0.0, coyote_time - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if is_on_floor() or slope_support:
		gliding = false
		jumped_this_air = false
		air_jump_used = false
	var recovery_jump: bool = stuck_recovery.try_escape()
	if recovery_jump:
		can_jump_now = true
	if Input.is_action_just_pressed("jump") or recovery_jump:
		cancel_claw()
		if swimming:
			water_jump_active = true
			swimming = false
			floor_snap_length = 0.0
			jump_buffer = 0.12
			can_jump_now = true
		elif can_jump_now:
			jump_buffer = 0.12
		elif not air_jump_used:
			air_jump_used = true
			jumped_this_air = true
			velocity.y = air_jump_speed
			coyote_time = 0.0
			jump_buffer = 0.0
			gliding = false
			$Nael.play_air_jump()
			_play_jump()
		else:
			gliding = true
			jump_buffer = 0.0
	if not Input.is_action_pressed("jump"):
		gliding = false
	if swimming:
		_apply_buoyancy(delta)
	elif not is_on_floor():
		if gliding and velocity.y <= 0.0:
			velocity.y = move_toward(velocity.y, -glide_fall_speed, glide_braking * delta)
		else:
			velocity.y -= gravity * delta
	if jump_buffer > 0.0 and can_jump_now:
		velocity.y = swim_jump_speed if water_jump_active else jump_speed
		jumped_this_air = true
		jump_buffer = 0.0
		coyote_time = 0.0
		gliding = false
		_play_jump()
	var axis := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	if is_attacking:
		axis = Vector2.ZERO
	var direction := pivot.global_basis * Vector3(axis.x, 0.0, axis.y)
	direction.y = 0.0
	var target_speed := (sprint_speed if Input.is_action_pressed("sprint") else speed) * Progression.movement_multiplier()
	if water_jump_active:
		target_speed = maxf(speed, swim_jump_move_speed)
	elif swimming:
		target_speed = swim_speed
	if gliding:
		target_speed = glide_speed
		if axis.length() < 0.1:
			direction = -pivot.global_basis.z
			direction.y = 0.0
	var target := direction.normalized() * target_speed * (1.0 if gliding else minf(axis.length(), 1.0))
	velocity.x = move_toward(velocity.x, target.x, 25.0 * delta)
	velocity.z = move_toward(velocity.z, target.z, 25.0 * delta)
	HitFeedback.apply_recoil(self, delta)
	var movement_start := global_position
	var requested_velocity := velocity
	move_and_slide()
	_release_stalled_slope(movement_start, requested_velocity)
	stuck_recovery.observe(delta, movement_start)
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor and not swimming:
		if previous_vertical_velocity < -1.5:
			_play_landing()
	previous_vertical_velocity = velocity.y
	was_on_floor = on_floor
	_process_footsteps(delta)
	if is_on_floor() or is_on_ceiling():
		gliding = false
	if global_position.y < -8.0 or not world_bounds.has_point(Vector2(global_position.x, global_position.z)):
		respawn()

func _release_stalled_slope(start: Vector3, requested_velocity: Vector3) -> void:
	if global_position.distance_squared_to(start) > 0.000001 or requested_velocity.length_squared() < 0.01:
		return
	for i in get_slide_collision_count():
		var normal := get_slide_collision(i).get_normal()
		if normal.y < cos(floor_max_angle):
			continue
		# Separate a tiny residual overlap only when the capsule's destination
		# is clear. This lets the controller resume climbing the bank normally.
		var shape_node := $CollisionShape3D as CollisionShape3D
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape_node.shape
		query.transform = shape_node.global_transform
		query.collision_mask = collision_mask
		query.exclude = [get_rid()]
		# At triangle joins, separating along one normal can push into the
		# neighbouring face. A small upward separation clears both floor faces.
		for offset in [normal * 0.02, Vector3.UP * 0.02]:
			query.transform = shape_node.global_transform
			query.transform.origin += offset
			if get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
				global_position += offset
				velocity = requested_velocity
				move_and_slide()
				return

func _can_unstuck_jump() -> bool:
	# A steep bank is classified as a wall. Pushing into it can hold the
	# capsule stationary after both jumps, without ever reporting a landing.
	# Recognize support beneath the lower cap even when the centre ray misses
	# the bank. Rising characters and vertical walls must not replenish jumps.
	var shape_node := $CollisionShape3D as CollisionShape3D
	var capsule := shape_node.shape as CapsuleShape3D
	if capsule != null and is_on_wall() and velocity.y <= 0.1 and absf(get_position_delta().y) < 0.02:
		var cap_center_y := shape_node.global_position.y - capsule.height * 0.5 + capsule.radius
		for i in get_slide_collision_count():
			var contact := get_slide_collision(i)
			if contact.get_normal().y >= 0.2 and contact.get_position().y < cap_center_y:
				return true
	# Si le joueur est en contact avec un mur ou coincé dans un interstice près du sol,
	# vérifier par raycast s'il y a un sol ou obstacle solide immédiatement sous ses pieds (<= 0.5m).
	# Cela lui permet de sauter pour se libérer s'il est pincé ou coincé entre des colliders.
	if is_on_wall() and not jumped_this_air:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.1, global_position + Vector3.DOWN * 0.5, collision_mask, [get_rid()])
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			return true
	return false

func _update_swimming() -> void:
	if water_surface == null:
		return
	water_height = water_surface.height_at(global_position)
	var depth := water_height - global_position.y
	# Keep the water leap active until landing or falling back into the water.
	if water_jump_active and velocity.y <= 0.0 and (is_on_floor() or depth >= swim_enter_depth):
		water_jump_active = false
	var should_swim := not water_jump_active and is_finite(water_height) and depth >= (swim_exit_depth if swimming else swim_enter_depth)
	if should_swim and not swimming:
		cancel_claw()
		gliding = false
		jump_buffer = 0.0
		coyote_time = 0.0
		jumped_this_air = false
		air_jump_used = false
		velocity.y = maxf(velocity.y, -1.0)
	swimming = should_swim
	floor_snap_length = 0.0 if swimming or water_jump_active else 0.35

func _apply_buoyancy(delta: float) -> void:
	var error := water_height - float_depth - global_position.y
	var target_vertical := clampf(error * 5.0, -2.0, 3.0)
	velocity.y = move_toward(velocity.y, target_vertical, 12.0 * delta)

func respawn() -> void:
	stuck_recovery.reset()
	guardian_knockback = 0.0
	var dodge_trail := get_node_or_null("DodgeTrail")
	if dodge_trail: dodge_trail.clear_trail()
	dodge.cancel()
	dodge.cooldown = 0.0
	if water_footsteps:
		water_footsteps.reset()
	rest_controller.cancel()
	cancel_claw()
	health = max_health
	damage_invulnerability = 2.0
	if health_label != null: health_label.text = "Vie : %d / %d" % [ceili(health), int(max_health)]
	gliding = false
	swimming = false
	water_jump_active = false
	water_height = -INF
	floor_snap_length = 0.35
	jumped_this_air = false
	air_jump_used = false
	HitFeedback.clear_recoil(self)
	global_position = spawn_position
	velocity = Vector3.ZERO
	jump_buffer = 0.0
	coyote_time = 0.0

## Restaure les PV sans contourner la remise au point de départ à zéro PV.
func restore_health(saved_health: float) -> void:
	if not is_finite(saved_health) or saved_health <= 0.0:
		respawn()
	else:
		health = minf(saved_health, max_health)
	combat_feedback_time = 4.0
	combat_ui.show()
	health_label.text = "Vie : %d / %d" % [ceili(health), int(max_health)]

func receive_guardian_kick(source: Vector3) -> void:
	dodge.cancel()
	rest_controller.cancel()
	cancel_claw()
	cancel_fireball_aim()
	claw_requested = false
	axe_throw_requested = false
	fireball_requested = false
	# A wounded beginner always survives the guardian's warning kick.
	damage_invulnerability = 0.0
	take_damage(minf(25.0, maxf(0.0, health - 1.0)), source)
	HitFeedback.hit(self, source, 12.5)
	set_meta("hit_recoil_time", 0.55)
	velocity.y = 6.0
	guardian_knockback = 0.65
	damage_invulnerability = 0.75

func take_damage(amount: float, source: Vector3) -> void:
	if damage_invulnerability > 0.0 or amount <= 0.0 or dodge.avoids_damage(): return
	dodge.cancel()
	rest_controller.cancel()
	HitFeedback.hit(self, source, 7.5)
	cancel_claw()
	health = maxf(0.0, health - amount)
	damage_invulnerability = 0.6
	combat_feedback_time = 4.0
	combat_ui.show()
	damage_flash.color.a = 0.22
	health_label.text = "Vie : %d / %d" % [ceili(health), int(max_health)]
	_play_voice(voice_damage_sounds, -1.0)
	if health <= 0.0:
		respawn()
		health_label.text = "Vous reprenez vos esprits au point de départ."

func heal(amount: float) -> void:
	if amount <= 0.0: return
	var prev_health := health
	health = minf(max_health, health + amount)
	combat_feedback_time = 3.5
	combat_ui.show()
	health_label.text = "Vie : %d / %d (+%d)" % [ceili(health), int(max_health), int(health - prev_health)]

func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		cancel_fireball_aim()
		if dodge: dodge.cancel()

func begin_fireball_aim() -> bool:
	var inv = get_node_or_null("/root/Inventory")
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or _is_ui_blocking():
		return false
	if rest_state != "" or swimming or is_attacking or dodge.active or fireball_cooldown > 0.0:
		return false
	if not inv:
		return false
	ranged_item = "sleep_dart" if inv.equipped == "sleep_dart" and inv.get_item_count("sleep_dart") > 0 else "first_echo"
	if ranged_item == "first_echo" and not inv.has_fireball_relic(): return false
	fireball_cursor = get_viewport().get_visible_rect().size * 0.5
	fireball_aiming = true
	fireball_target_locked = false
	update_fireball_aim()
	fireball_reticle.show()
	return true

func cancel_fireball_aim() -> void:
	fireball_aiming = false
	fireball_target_locked = false
	fireball_requested = false
	if fireball_reticle:
		fireball_reticle.hide()

func update_fireball_aim() -> void:
	var cam := arm.get_node("Camera3D") as Camera3D
	var screen_point := fireball_cursor if fireball_aiming or fireball_target_locked else get_viewport().get_visible_rect().size * 0.5
	var origin := cam.project_ray_origin(screen_point)
	var ray := cam.project_ray_normal(screen_point)
	var release := global_position + Vector3.UP * 1.05
	# Ignore scenery between the third-person camera and the player's firing plane.
	# A hit there would make Nael turn back toward the camera.
	var camera_forward := -cam.global_basis.z
	camera_forward.y = 0.0
	camera_forward = camera_forward.normalized()
	var forward_rate := maxf(ray.dot(camera_forward), 0.001)
	var start_distance := maxf(0.0, ((release - origin).dot(camera_forward) + 0.65) / forward_rate)
	var ray_start := origin + ray * start_distance
	var ray_end := origin + ray * maxf(FIREBALL_AIM_DISTANCE, start_distance + 1.0)
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1 | 4 | 8 | 16)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	fireball_target = hit.position if not hit.is_empty() else ray_end
	# Cover in front of the hand still blocks the actual projectile.
	var hand_query := PhysicsRayQueryParameters3D.create(release, fireball_target, 1 | 4 | 8 | 16)
	hand_query.exclude = [get_rid()]
	hand_query.collide_with_areas = true
	var obstruction := get_world_3d().direct_space_state.intersect_ray(hand_query)
	var blocked := false
	if not obstruction.is_empty():
		blocked = obstruction.position.distance_to(fireball_target) > 0.5
		fireball_target = obstruction.position
	if fireball_reticle:
		fireball_reticle.position = screen_point
		fireball_reticle.set_world_target(cam, release, fireball_target, blocked)

func start_fireball() -> bool:
	if dodge.active: return false
	if rest_state != "": return false
	if swimming:
		return false
	var inv = get_node_or_null("/root/Inventory")
	if not inv or inv.is_open:
		return false
	if ranged_item == "sleep_dart":
		if inv.equipped != "sleep_dart" or inv.get_item_count("sleep_dart") <= 0: return false
	elif not inv.has_fireball_relic():
		return false
	if is_attacking or fireball_cooldown > 0.0:
		return false
	var model := $Nael
	if not model.animator.has_animation("Nael_Claw"):
		return false
	
	if not fireball_target_locked:
		update_fireball_aim()
		fireball_target_locked = true
	var facing := fireball_target - global_position
	if Vector2(facing.x, facing.z).length_squared() > 0.001:
		model.rotation.y = atan2(facing.x, facing.z)
	claw_buffer_remaining = 0.0
	claw_chain_count = 0
	claw_chain_remaining = 0.0
	is_attacking = true
	is_casting_spell = true
	fireball_spawned = false
	fireball_cooldown = FIREBALL_COOLDOWN_TIME
	velocity.x = 0.0
	velocity.z = 0.0
	model.play_claw()
	return true

func spawn_sleep_dart() -> void:
	var inv := get_node("/root/Inventory")
	if inv.equipped != "sleep_dart" or not inv.remove_item("sleep_dart"):
		fireball_target_locked = false
		return
	var release := global_position + Vector3.UP * 1.05
	var heading := (fireball_target - release).normalized()
	fireball_target_locked = false
	var dart := preload("res://scripts/sleep_dart.gd").new()
	get_parent().add_child(dart)
	dart.launch(release, heading, get_rid())
	inv.ui.notify("Fléchette lancée · %d restantes" % inv.get_item_count("sleep_dart"))

func spawn_fireball() -> void:
	if ranged_item == "sleep_dart":
		spawn_sleep_dart()
		return
	if not fireball_target_locked:
		update_fireball_aim()
	var release := global_position + Vector3.UP * 1.05
	var shoot_dir := (fireball_target - release).normalized()
	var char_right := Vector3(-shoot_dir.z, 0.0, shoot_dir.x).normalized()
	var spawn_pos := release + char_right * 0.2
	shoot_dir = (fireball_target - spawn_pos).normalized()
	# Start near the hand so nearby walls cannot be skipped by a forward offset.
	spawn_pos += shoot_dir * 0.45
	fireball_target_locked = false

	# 4. Instanciation instantanée via preload (zéro lag)
	var fb: Node3D = FireballScene.instantiate() as Node3D
	fb.damage *= Progression.magic_multiplier()
	get_parent().add_child(fb)
	fb.launch(spawn_pos, shoot_dir)
	
	# Feedback UI
	combat_feedback_time = 2.5
	combat_ui.show()
	health_label.text = "Vie : %d / %d" % [ceili(health), int(max_health)]
	attack_feedback.text = "Boule de feu lancée !"
	
	# Son de projection / souffle magique de boule de feu
	if fireball_audio_player and not fireball_sounds.is_empty():
		fireball_audio_player.stream = fireball_sounds.pick_random()
		fireball_audio_player.pitch_scale = randf_range(0.97, 1.03)
		fireball_audio_player.volume_db = -1.0
		fireball_audio_player.play()
	elif claw_audio_player and not claw_sounds.is_empty():
		claw_audio_player.stream = claw_sounds.pick_random()
		claw_audio_player.pitch_scale = randf_range(1.25, 1.45)
		claw_audio_player.volume_db = -4.0
		claw_audio_player.play()

func request_claw() -> void:
	if dodge.active: return
	if rest_state != "": return
	if _is_ui_blocking() or not is_on_floor() or is_casting_spell:
		return
	if is_attacking:
		# Keep only one next strike; further clicks refresh its expiry.
		claw_buffer_remaining = CLAW_BUFFER_TIME
	else:
		claw_requested = true

func start_claw() -> bool:
	if rest_state != "": return false
	if swimming or is_attacking or dodge.active or not is_on_floor() or _is_ui_blocking():
		return false
	var model := $Nael
	if not model.animator.has_animation("Nael_Claw"):
		return false
	active_axe_strike = get_node("/root/Inventory").equipped == "axe"
	active_claw_left = not active_axe_strike and claw_chain_count >= 1 and model.animator.has_animation("Nael_Claw_Left") and (claw_chain_count >= 3 or randf() < left_claw_chance)
	active_claw_clip = "Nael_Claw_Left" if active_claw_left else ("Nael_Claw" if active_axe_strike else model.choose_primary_claw())
	active_claw_impact = LEFT_CLAW_IMPACT_TIME if active_claw_left else CLAW_IMPACT_TIME
	claw_chain_count += 1
	claw_chain_remaining = CLAW_CHAIN_GRACE
	claw_buffer_remaining = 0.0
	is_attacking = true
	is_casting_spell = false
	claw_hit_applied = false
	claw_sound_played = false
	velocity.x = 0.0
	velocity.z = 0.0
	model.play_claw(active_claw_left, active_claw_clip)
	_play_voice(voice_attack_sounds, -2.5)
	return true

func cancel_claw() -> void:
	cancel_fireball_aim()
	claw_buffer_remaining = 0.0
	claw_chain_remaining = 0.0
	claw_chain_count = 0
	claw_requested = false
	fireball_requested = false
	is_casting_spell = false
	claw_sound_played = false
	if claw_audio_player and claw_audio_player.playing:
		claw_audio_player.stop()
	if claw_trail and claw_trail.has_method("clear_trail"):
		claw_trail.clear_trail()
	if is_attacking:
		is_attacking = false
		$Nael.cancel_claw()

func apply_claw_hit() -> void:
	var forward: Vector3 = $Nael.global_basis.z.normalized()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
			continue
		var offset: Vector3 = enemy.global_position - global_position
		var flat := Vector3(offset.x, 0.0, offset.z)
		
		# Account for enemy collision radius so giant enemies (like giant spiders) can be hit
		var enemy_radius: float = 0.0
		var enemy_cs: CollisionShape3D = enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if enemy_cs and enemy_cs.shape:
			if enemy_cs.shape is CylinderShape3D or enemy_cs.shape is CapsuleShape3D or enemy_cs.shape is SphereShape3D:
				enemy_radius = enemy_cs.shape.radius * enemy_cs.global_transform.basis.get_scale().x
		var effective_dist := maxf(0.0, flat.length() - enemy_radius)
		var height_tolerance: float = 2.5 if ("spider_scale" in enemy and enemy.spider_scale > 1.8) else 1.2
		
		if effective_dist > (2.3 if active_axe_strike else claw_range) or absf(offset.y) > height_tolerance:
			continue
		if flat.length() > 0.01 and forward.dot(flat.normalized()) < 0.35:
			continue
		var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, enemy.global_position + Vector3.UP * 0.8, 5, [get_rid()])
		var obstruction := get_world_3d().direct_space_state.intersect_ray(ray)
		if not obstruction.is_empty() and obstruction.collider != enemy:
			continue
		var health_before: float = enemy.health
		enemy.take_damage((35.0 if active_axe_strike else claw_damage * (left_claw_damage_multiplier if active_claw_left else 1.0)) * Progression.physical_multiplier(), global_position)
		combat_feedback_time = 3.0
		combat_ui.show()
		health_label.text = "Vie : %d / %d" % [ceili(health), int(max_health)]
		var target_name: String = enemy.enemy_name if "enemy_name" in enemy else "Bandit"
		var strike_name := "Coup de hache" if active_axe_strike else ("Griffe gauche puissante" if active_claw_left else "Coup de griffe")
		attack_feedback.text = "%s éliminé !" % target_name if enemy.health <= 0.0 else "%s : −%d PV" % [strike_name, int(health_before - enemy.health)]

func _init_audio() -> void:
	# Initialisation des lecteurs audio sur le bus SFX (en attente de la nouvelle sélection)
	claw_audio_player = AudioStreamPlayer.new()
	claw_audio_player.name = "ClawAudioPlayer"
	claw_audio_player.bus = "SFX"
	add_child(claw_audio_player)

	fireball_audio_player = AudioStreamPlayer.new()
	fireball_audio_player.name = "FireballAudioPlayer"
	fireball_audio_player.bus = "SFX"
	add_child(fireball_audio_player)

	footstep_player = AudioStreamPlayer.new()
	footstep_player.name = "FootstepPlayer"
	footstep_player.bus = "SFX"
	add_child(footstep_player)

	water_footstep_players.clear()
	for i in range(2):
		var wp := AudioStreamPlayer.new()
		wp.name = "WaterFootstepPlayer%d" % (i + 1)
		wp.bus = "SFX"
		add_child(wp)
		water_footstep_players.append(wp)
	water_footstep_player = water_footstep_players[0]

	movement_player = AudioStreamPlayer.new()
	movement_player.name = "MovementPlayer"
	movement_player.bus = "SFX"
	add_child(movement_player)

	voice_player = AudioStreamPlayer.new()
	voice_player.name = "VoicePlayer"
	voice_player.bus = "SFX"
	add_child(voice_player)

	claw_sounds.clear()
	# Son sélectionné pour le personnage : 01 branche vive (avec variations procédurales pitch/volume au déclenchement)
	var claw_sfx := _load_sfx("res://assets/audio/sfx/combat/griffe_whoosh_01_branche_vive.wav")
	if claw_sfx != null:
		claw_sounds.append(claw_sfx)
		claw_audio_player.stream = claw_sfx
	fireball_sounds.clear()
	var fb_sfx := _load_sfx("res://assets/audio/sfx/spells/fireball/fireball_court_02_souffle_eclair.wav")
	if fb_sfx != null:
		fireball_sounds.append(fb_sfx)
	water_footstep_sound = _load_sfx("res://assets/audio/sfx/footsteps/water/pas_riviere_FX32_05_pas_eau_vive.wav")
	if water_footstep_sound == null:
		water_footstep_sound = _load_sfx("res://assets/audio/sfx/footsteps/water/pas_riviere_05_pas_eau_vive.wav")
	if water_footstep_sound != null:
		for wp in water_footstep_players:
			wp.stream = water_footstep_sound
	footstep_sounds.clear()
	var step_files := [
		"res://assets/audio/sfx/footsteps/pas_terre_07_poussiere_desert.wav",
		"res://assets/audio/sfx/footsteps/pas_terre_07_poussiere_desert_01.wav",
		"res://assets/audio/sfx/footsteps/pas_terre_07_poussiere_desert_02.wav",
		"res://assets/audio/sfx/footsteps/pas_terre_07_poussiere_desert_03.wav",
	]
	for p in step_files:
		var s := _load_sfx(p)
		if s != null:
			footstep_sounds.append(s)

	# Harmonisation uniforme sans distinction de sol
	steps_grass = footstep_sounds
	steps_gravel = footstep_sounds
	steps_twigs = footstep_sounds

	jump_sound = null
	land_twigs = null
	land_grass = null
	land_gravel = null
	voice_attack_sounds.clear()
	voice_damage_sounds.clear()
	voice_jump_sounds.clear()
	voice_land_sounds.clear()

func _load_sfx(path: String) -> AudioStream:
	if ResourceLoader.exists(path):
		var s = load(path)
		if s != null: return s
	if FileAccess.file_exists(path):
		return AudioStreamWAV.load_from_file(path)
	return null

func _process_footsteps(delta: float) -> void:
	if swimming or not is_on_floor() or is_attacking or get_node("/root/Inventory").is_open:
		step_distance = 0.0
		anim_step_prev_pos = -1.0
		anim_step_prev_name = ""
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.25:
		step_distance = 0.0
		anim_step_prev_pos = -1.0
		anim_step_prev_name = ""
		return

	# Synchronisation prioritaire sur l'animation de Naël pour un calage visuel absolu
	var animator: AnimationPlayer = null
	if has_node("Nael") and "animator" in $Nael:
		animator = $Nael.animator
		
	if animator and (animator.current_animation == "Nael_Walk" or animator.current_animation == "Nael_Run"):
		var cur_anim := animator.current_animation
		var cur_pos := animator.current_animation_position
		
		# Points d'impact au sol (en secondes) :
		# Nael_Walk (1.233s) : pied gauche ~0.410s, pied droit ~0.970s
		# Nael_Run  (0.833s) : pied gauche ~0.200s, pied droit ~0.570s
		var t1 := 0.410 if cur_anim == "Nael_Walk" else 0.200
		var t2 := 0.970 if cur_anim == "Nael_Walk" else 0.570
		
		if cur_anim != anim_step_prev_name or anim_step_prev_pos < 0.0:
			anim_step_prev_name = cur_anim
			anim_step_prev_pos = cur_pos
		else:
			var step_triggered := false
			if cur_pos >= anim_step_prev_pos:
				# Progression normale dans le cycle
				step_triggered = (anim_step_prev_pos < t1 and cur_pos >= t1) or (anim_step_prev_pos < t2 and cur_pos >= t2)
			else:
				# Bouclage en fin d'animation
				step_triggered = (anim_step_prev_pos < t2) or (cur_pos >= t1)
				
			if step_triggered:
				_play_footstep(1 if cur_pos >= t2 else 0)
				
			anim_step_prev_pos = cur_pos
		return

	# Secours par distance si l'animateur n'est pas actif (calibré sur la foulée réelle : 0.62m marche, 1.15m sprint)
	var is_sprinting := Input.is_action_pressed("sprint")
	var stride := 1.15 if is_sprinting else 0.62
	step_distance += horizontal_speed * delta
	if step_distance >= stride:
		step_distance -= stride
		_play_footstep()

func _play_water_footstep(depth: float = 0.15) -> void:
	if swimming or not is_on_floor() or water_footstep_sound == null or water_footstep_players.is_empty():
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_running := Input.is_action_pressed("sprint") or horizontal_speed > 3.0
	var depth_shift := clampf((depth - 0.1) * 0.05, 0.0, 0.04)
	# Pitch abaissé (~5 à 8 demi-tons plus grave) pour éliminer la résonance aiguë et donner du corps au remous
	var min_pitch := (0.68 if is_running else 0.62) - depth_shift
	var max_pitch := (0.82 if is_running else 0.76) - depth_shift
	var pitch := randf_range(min_pitch, max_pitch)
	for _attempt in range(8):
		if last_water_footstep_pitch < 0.0 or absf(pitch - last_water_footstep_pitch) >= 0.035:
			break
		pitch = randf_range(min_pitch, max_pitch)
	if last_water_footstep_pitch >= 0.0 and absf(pitch - last_water_footstep_pitch) < 0.035:
		var mid := 0.5 * (min_pitch + max_pitch)
		pitch = randf_range(mid + 0.02, max_pitch) if last_water_footstep_pitch < mid else randf_range(min_pitch, mid - 0.02)
	last_water_footstep_pitch = pitch

	var base_vol := -15.0 if is_running else -17.0
	var vol_db := base_vol + randf_range(-0.6, 0.5)

	var wp: AudioStreamPlayer = water_footstep_players[water_footstep_pool_index]
	water_footstep_pool_index = (water_footstep_pool_index + 1) % water_footstep_players.size()
	water_footstep_player = wp
	wp.stream = water_footstep_sound
	wp.pitch_scale = pitch
	wp.volume_db = vol_db
	wp.play()

func _play_footstep(foot: int = -1) -> void:
	if water_footsteps and water_footsteps.step(foot):
		return
	if footstep_player == null or footstep_sounds.is_empty():
		return
		
	# Alternance pour ne pas rejouer le même échantillon deux fois de suite
	var next_idx := randi() % footstep_sounds.size()
	if footstep_sounds.size() > 1 and next_idx == last_footstep_index:
		next_idx = (next_idx + 1) % footstep_sounds.size()
	last_footstep_index = next_idx
	
	var stream: AudioStream = footstep_sounds[next_idx]
	if stream != null:
		var horizontal_speed := Vector2(velocity.x, velocity.z).length()
		var is_running := Input.is_action_pressed("sprint") or horizontal_speed > 3.0
		
		# Volume encore réduit d'au moins 50 % (-6.5 dB) : marche (-18.0 dB), course (-16.0 dB)
		var base_vol := -16.0 if is_running else -18.0
		footstep_player.stream = stream
		footstep_player.volume_db = base_vol + randf_range(-0.6, 0.5)
		
		# Pitch : timbre doux et chaud à la marche (0.84 à 0.94), équilibré en course (0.95 à 1.05)
		if is_running:
			footstep_player.pitch_scale = randf_range(0.95, 1.05)
		else:
			footstep_player.pitch_scale = randf_range(0.84, 0.94)
			
		footstep_player.play()

func _play_voice(sounds: Array[AudioStream], vol_db: float = -2.5) -> void:
	if voice_player == null or sounds.is_empty(): return
	var stream: AudioStream = sounds.pick_random()
	if stream != null:
		voice_player.stream = stream
		voice_player.volume_db = vol_db + randf_range(-0.4, 0.4)
		voice_player.pitch_scale = randf_range(0.97, 1.03)
		voice_player.play()

func _play_jump() -> void:
	if movement_player and jump_sound:
		movement_player.stream = jump_sound
		movement_player.volume_db = -3.0
		movement_player.pitch_scale = randf_range(0.96, 1.04)
		movement_player.play()
	_play_voice(voice_jump_sounds, -2.0)

func _play_landing() -> void:
	if footstep_sounds.is_empty():
		return
		
	# Réinitialiser la progression des pas pour éviter un empilement immédiat
	step_distance = 0.0
	anim_step_prev_pos = -1.0
	
	# Premier pied : contact immédiat au sol sur footstep_player (-17.5 dB)
	var idx1 := randi() % footstep_sounds.size()
	var stream1: AudioStream = footstep_sounds[idx1]
	if footstep_player and stream1:
		footstep_player.stream = stream1
		footstep_player.volume_db = -17.5 + randf_range(-0.5, 0.5)
		footstep_player.pitch_scale = randf_range(0.82, 0.90)
		footstep_player.play()
		
	# Deuxième pied : retombe de façon très rapprochée (décalage naturel de 55 à 85 ms, -18.3 dB)
	var delay := randf_range(0.055, 0.085)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(self) or not is_inside_tree():
		return
		
	# Variation distincte pour le deuxième pied sur movement_player (polyphonie sans coupure)
	var idx2 := (idx1 + 1 + (randi() % (footstep_sounds.size() - 1))) % footstep_sounds.size()
	var stream2: AudioStream = footstep_sounds[idx2]
	var player2: AudioStreamPlayer = movement_player if movement_player else footstep_player
	if player2 and stream2:
		player2.stream = stream2
		player2.volume_db = -18.3 + randf_range(-0.5, 0.5)
		player2.pitch_scale = randf_range(0.86, 0.94)
		player2.play()

func throw_axe() -> bool:
	var bag := get_node("/root/Inventory")
	if bag.equipped != "axe" or is_attacking or swimming or rest_state != "" or _is_ui_blocking() or not is_on_floor(): return false
	if not start_claw(): return false
	claw_hit_applied = true
	var camera := get_viewport().get_camera_3d()
	var direction: Vector3 = (-camera.global_basis.z if camera else $Nael.global_basis.z).normalized()
	var release := global_position + Vector3.UP * 1.15
	var aim := axe_aim_point(camera, release, direction)
	direction = (aim - release).normalized()
	var projectile := preload("res://scripts/world_axe.gd").new()
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = release
	projectile.last_safe = global_position + Vector3.UP * 0.3
	projectile.shooter = self
	# Compensate gravity so the arc passes through the actual aimed point.
	var offset := aim - release
	var travel_time := clampf(Vector2(offset.x, offset.z).length() / 14.0, 0.12, 1.8)
	projectile.velocity = offset / travel_time + Vector3.UP * 9.0 * travel_time
	var sideways := direction.cross(Vector3.UP)
	if sideways.length_squared() < 0.001: sideways = Vector3.RIGHT
	sideways = sideways.normalized()
	projectile.global_basis = Basis(direction, sideways.cross(direction).normalized(), sideways)
	projectile.flight = true
	bag.equipment.erase("axe")
	bag.equipped = ""
	projectile.store_state()
	bag.changed.emit()
	claw_requested = false
	claw_buffer_remaining = 0.0
	$Nael.play_claw(false)
	return true

func axe_aim_point(camera: Camera3D, release: Vector3, direction: Vector3) -> Vector3:
	var view_origin := camera.global_position if camera else release
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(view_origin, view_origin + direction * 30.0, 5, [get_rid()])
	var hit := space.intersect_ray(ray)
	var aim: Vector3 = hit.position if not hit.is_empty() else release + direction * 20.0
	var best_alignment := 0.985
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"): continue
		if "health" in enemy and enemy.health <= 0.0: continue
		var shape := enemy.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var center: Vector3 = shape.global_position if shape else enemy.global_position + Vector3.UP * 0.8
		if release.distance_to(center) > 25.0: continue
		var alignment := direction.dot((center - view_origin).normalized())
		if alignment <= best_alignment: continue
		var sight := space.intersect_ray(PhysicsRayQueryParameters3D.create(release, center, 5, [get_rid()]))
		if not sight.is_empty():
			var obstacle: Node = sight.collider
			while obstacle and obstacle != enemy: obstacle = obstacle.get_parent()
			if obstacle != enemy: continue
		best_alignment = alignment
		aim = center
	return aim


func _on_progression_changed() -> void:
	health = minf(health, max_health)
	if health_label:
		health_label.text = "Vie : %d / %d" % [ceili(health), int(max_health)]
