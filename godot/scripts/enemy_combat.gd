extends Node
## Shared combat states. Locomotion/patrol remain in each enemy's script.
## Animation slots use exact AnimationPlayer names and can be set on each enemy.
signal action_started(action: String)
const Temperaments = preload("res://scripts/combat_temperaments.gd")
var temperament := "equilibre"
var profile: Dictionary
var rng := RandomNumberGenerator.new()
var rhythm := 1.0
var flee_cooldown := 0.0
var flee_blocked := 0.0

var actor
var kind := "bandit"
var phase := ""
var remaining := 0.0
var elapsed := 0.0
var aggression := 0.0
var posture := 0.0
var stagger_guard := 0.0
var dodge_cooldown := 1.0
var special_cooldown := 0.0
var direction := Vector3.ZERO
var attack_direction := Vector3.FORWARD
var heavy := false
var counter := false
var counter_window := 0.0
var follow_up := ""
var hit_done := false
var saw_player_attack := false
var dodge_delay := -1.0
var dodge_side := 1.0
var status_label: Label3D

func setup(body, archetype: String) -> void:
	actor = body
	kind = archetype
	rng.seed = actor.behavior_seed if actor.behavior_seed != 0 else hash(str(actor.get_path()))
	temperament = actor.temperament
	if temperament == "auto":
		temperament = Temperaments.AUTOMATIC[rng.randi_range(0, Temperaments.AUTOMATIC.size() - 1)]
	profile = Temperaments.PROFILES.get(temperament, Temperaments.PROFILES["equilibre"])
	# Stable per-instance nuance in auto mode; explicit profiles remain predictable.
	rhythm = rng.randf_range(0.92, 1.08) if actor.temperament == "auto" else 1.0
	name = "Combat"
	status_label = Label3D.new()
	status_label.name = "CombatStatus"
	status_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	status_label.font_size = 27
	status_label.outline_size = 7
	status_label.position = actor.health_label.position + Vector3.UP * 0.38
	actor.add_child(status_label)
	status_label.hide()

func _home() -> Vector3:
	return actor.home if kind == "bandit" else actor.home_position

func _target_valid() -> bool:
	return is_instance_valid(actor.player) and actor.player.global_position.distance_to(_home()) < actor.leash_radius and actor.global_position.distance_to(_home()) < actor.leash_radius

func _flat_target() -> Vector3:
	var offset: Vector3 = actor.player.global_position - actor.global_position
	offset.y = 0.0
	return offset

func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.001 and actor.visual:
		actor.visual.rotation.y = atan2(dir.x, dir.z)

func _enter(next: String, duration: float, text: String, color := Color.WHITE) -> void:
	phase = next
	actor.state = next
	remaining = duration
	elapsed = 0.0
	status_label.text = text
	status_label.modulate = color
	status_label.visible = not text.is_empty()
	_play_action(next, duration)
	action_started.emit(next)

func _play_action(action: String, duration: float) -> void:
	var anim: AnimationPlayer = actor.animator
	if anim == null: return
	anim.speed_scale = 1.0
	var clip: String = actor.combat_animations.get(action, "")
	if not clip.is_empty() and anim.has_animation(clip):
		anim.play(clip, 0.08)
		return
	# Existing attacks are retimed so their authored impact matches the wind-up.
	if action == "windup":
		var impact := 0.375
		if kind == "bandit": clip = "Punch"
		elif kind == "spider":
			clip = actor.attack_anim_name
			impact = actor.ATTACK_HIT_TIME
		else:
			for candidate in anim.get_animation_list():
				if actor._clean_anim_name(candidate) == "attaque": clip = candidate
		if anim.has_animation(clip):
			anim.play(clip, 0.08, impact / maxf(duration, 0.01))
			return
	# A stopped attack cannot visually continue after being interrupted.
	if action in ["stagger", "dodge", "retreat", "flee", "charge_windup", "charge", "recover"]:
		anim.stop()
		if kind == "bandit": actor._play("Running" if action in ["charge", "flee"] else "Idle")
		elif kind == "golem": actor._play_anim("marche" if action in ["charge", "flee"] else "rest_position")
		else: actor._play_anim(actor.walk_anim_name, 0.08, 1.0 if action in ["dodge", "retreat", "charge", "flee"] else 0.0)

func start_attack(is_counter := false) -> void:
	if not _target_valid():
		_reset()
		return
	counter = is_counter or counter_window > 0.0
	counter_window = 0.0
	heavy = kind == "golem" or aggression >= float(profile.charge)
	hit_done = false
	attack_direction = _flat_target().normalized()
	_face(attack_direction)
	var windup := 0.5
	if kind == "golem": windup = 0.9
	elif kind == "spider": windup = 0.65
	if counter: windup *= 0.85
	windup *= float(profile.windup) * rhythm
	_enter("windup", windup, "CONTRE-ATTAQUE !" if counter else ("FRAPPE LOURDE !" if heavy else "ATTAQUE !"), Color(1, 0.65, 0.2))

func tick(delta: float) -> bool:
	aggression = maxf(0.0, aggression - delta * float(profile.decay))
	posture = maxf(0.0, posture - delta * 7.0)
	stagger_guard = maxf(0.0, stagger_guard - delta)
	dodge_cooldown = maxf(0.0, dodge_cooldown - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	counter_window = maxf(0.0, counter_window - delta)
	flee_cooldown = maxf(0.0, flee_cooldown - delta)
	if not _target_valid():
		if not phase.is_empty(): _reset()
		aggression = 0.0
		dodge_delay = -1.0
		status_label.hide()
		return false
	var offset := _flat_target()
	var attacking: bool = actor.player.get("is_attacking") == true
	# Perceive the beginning of a swing, then react after 180 ms, never on impact.
	if phase.is_empty() and actor.state == "chase" and attacking and not saw_player_attack and dodge_cooldown <= 0.0 and kind != "golem" and offset.length() < 3.2 and actor._clear_sight(actor.player):
		if rng.randf() < float(profile.dodge): dodge_delay = 0.18 * rhythm
	saw_player_attack = attacking
	if dodge_delay >= 0.0:
		dodge_delay -= delta
		if dodge_delay <= 0.0:
			dodge_delay = -1.0
			if phase.is_empty(): _evade("dodge")
	if phase.is_empty():
		if actor.state == "chase" and aggression >= float(profile.charge) and special_cooldown <= 0.0 and offset.length() < 7.0 and actor._clear_sight(actor.player):
			heavy = true
			hit_done = false
			attack_direction = offset.normalized()
			_face(attack_direction)
			_enter("charge_windup", 0.75 if kind == "golem" else 0.55, "FURIE — CHARGE !", Color(1, 0.25, 0.2))
		else: return false
	actor.velocity.x = 0.0
	actor.velocity.z = 0.0
	remaining -= delta
	elapsed += delta
	match phase:
		"windup":
			# Only the first half tracks: sidestepping the committed attack works.
			if remaining > elapsed:
				attack_direction = offset.normalized()
				_face(attack_direction)
			if remaining <= 0.0:
				_enter("strike", 0.16, "FRAPPE !", Color(1, 0.3, 0.2))
				_strike()
		"strike":
			if remaining <= 0.0: _recover()
		"recover":
			if remaining <= 0.0: _reset()
		"stagger":
			_move(direction, 1.8 * maxf(0.0, 1.0 - elapsed / 0.22), delta)
			if remaining <= 0.0:
				if not follow_up.is_empty():
					var next := follow_up
					follow_up = ""
					_evade(next)
				else: _reset()
		"dodge", "retreat":
			_move(direction, 5.2 if kind == "spider" else 3.6, delta)
			if remaining <= 0.0:
				counter_window = 1.8
				if offset.length() <= actor.attack_range + 0.5: start_attack(true)
				else: _reset()
		"flee":
			var away := -offset.normalized()
			# Try side routes when cornered; never run indefinitely into a wall.
			var escaped := false
			for angle in [0.0, 0.8, -0.8, 1.3, -1.3]:
				var escape_dir := away.rotated(Vector3.UP, angle)
				if _escape_clear(escape_dir) and _move(escape_dir, 3.0 if kind == "golem" else 4.8, delta):
					_face(escape_dir)
					escaped = true
					break
			flee_blocked = 0.0 if escaped else flee_blocked + delta
			if remaining <= 0.0 or offset.length() > 7.0 or flee_blocked > 0.25:
				_reset()
		"charge_windup":
			if remaining <= 0.0:
				aggression = 0.0
				special_cooldown = 5.0
				_enter("charge", 0.65, "CHARGE !", Color(1, 0.25, 0.2))
		"charge":
			_move(attack_direction, 6.0 if kind == "golem" else 8.0, delta)
			if offset.length() <= actor.attack_range + 0.25:
				_strike()
				_recover()
			elif remaining <= 0.0 or actor.is_on_wall(): _recover()
	return true

func _strike() -> void:
	if hit_done or not _target_valid(): return
	hit_done = true
	var offset: Vector3 = actor.player.global_position - actor.global_position
	var flat := Vector3(offset.x, 0, offset.z)
	if flat.length() > actor.attack_range + 0.35 or absf(offset.y) > 1.4: return
	if flat.length() > 0.05 and attack_direction.dot(flat.normalized()) < 0.45: return
	if actor._clear_sight(actor.player) and actor.player.has_method("take_damage"):
		actor.player.take_damage(actor.damage * (1.35 if heavy else 1.0), actor.global_position)

func _recover() -> void:
	var duration := 1.05 if kind == "golem" else (0.55 if kind == "spider" else 0.7)
	_enter("recover", duration * float(profile.recovery) * rhythm, "OUVERTURE !", Color(0.35, 1, 0.65))

func _reset() -> void:
	phase = ""
	follow_up = ""
	actor.state = "chase"
	status_label.hide()
	if actor.animator: actor.animator.speed_scale = 1.0
	if kind == "spider": actor.attack_cooldown = float(profile.rest) * rhythm
	else: actor.cooldown = float(profile.rest) * rhythm

func _evade(action: String) -> void:
	if action == "flee":
		flee_cooldown = 6.0
		flee_blocked = 0.0
		counter_window = 0.0
		_enter("flee", 1.4, "PREND LA FUITE !", Color(0.5, 0.8, 1))
		return
	var toward := _flat_target().normalized()
	dodge_side *= -1.0
	direction = toward.cross(Vector3.UP) * dodge_side
	if action == "retreat": direction = (-toward + direction * 0.4).normalized()
	dodge_cooldown = (2.0 if kind == "spider" else 3.2) * float(profile.evade_cooldown) * rhythm
	_enter(action, 0.28, "ESQUIVE" if action == "dodge" else "REPLI", Color(0.5, 0.8, 1))

func _escape_clear(dir: Vector3) -> bool:
	var origin: Vector3 = actor.global_position + Vector3.UP * 0.6
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 1.5, 1, [actor.get_rid()])
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _move(dir: Vector3, speed: float, delta: float) -> bool:
	if speed <= 0.0: return false
	var step := dir * speed * delta
	var destination: Vector3 = actor.global_position + step
	if destination.distance_to(_home()) > actor.leash_radius - 0.5: return false
	# The caller's move_and_slide sweeps the collider, allowing a lateral escape
	# even when touching the player. Ground probing prevents stepping off cliffs.
	var query := PhysicsRayQueryParameters3D.create(destination + dir * 0.5 + Vector3.UP * 0.5, destination + dir * 0.5 - Vector3.UP * 1.2, 1, [actor.get_rid()])
	if actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): return false
	actor.velocity.x = dir.x * speed
	actor.velocity.z = dir.z * speed
	return true

func receive_hit(amount: float, source: Vector3, attack_kind: String) -> float:
	var dealt := amount * (float(profile.opening) if phase == "recover" else 1.0)
	aggression = minf(100.0, aggression + float(profile.anger))
	var health_after: float = actor.health - dealt
	var frightened: bool = flee_cooldown <= 0.0 and float(profile.flee_health) > 0.0 and health_after > 0.0 and (health_after / actor.max_health <= float(profile.flee_health) or rng.randf() < float(profile.flee_chance))
	posture += 60.0 if attack_kind == "fireball" else 25.0
	dodge_delay = -1.0
	# Damage always lands. Resistance prevents infinite interruption, not damage.
	var threshold := 55.0 if kind == "golem" else 25.0
	if posture >= threshold and stagger_guard <= 0.0:
		posture = 0.0
		stagger_guard = 1.4 if kind == "golem" else 1.0
		direction = actor.global_position - source
		direction.y = 0.0
		direction = direction.normalized()
		follow_up = ("dodge" if kind == "spider" else "retreat") if kind != "golem" else ""
		if temperament == "agressif": follow_up = ""
		if frightened: follow_up = "flee"
		hit_done = true
		_enter("stagger", 0.75 if kind == "golem" else 0.23, "DÉSÉQUILIBRÉ !" if kind == "golem" else "INTERROMPU !", Color(0.6, 0.85, 1))
	elif frightened and phase != "flee":
		_evade("flee")
	elif phase.is_empty():
		actor.state = "chase"
		status_label.text = "ARMURE : %d / %d" % [int(posture), int(threshold)] if kind == "golem" else "RIPOSTE EN PRÉPARATION"
		status_label.modulate = Color(1, 0.65, 0.2)
		status_label.show()
	return dealt
