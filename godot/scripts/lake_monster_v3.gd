extends CharacterBody3D
## Crystalmaw: baked IK clips, slow pursuit near the lake, return to its home.
const Model = preload("res://assets/enemies/lake_monster/crystalmaw_v003.glb")
const Splash = preload("res://scripts/lake_monster_splash.gd")
const Projectile = preload("res://scripts/lake_monster_projectile.gd")
const WaterLookup = preload("res://scripts/lake_water_lookup.gd")
const DEFEATED_FLAG := "story/lake_monster_defeated"
const RELEASE_TIME := 56.0 / 24.0
const MODEL_SCALE := 1.0
const MOUTH_REST := Vector3(0, 6.5, 10.15)
@export var trigger_radius := 27.0
@export var leash_radius := 48.0
@export var max_health := 320.0
@export var projectile_damage := 60.0
@export var walk_speed := 0.45 * MODEL_SCALE
@export var maximum_excursion := 20.0
var health := 320.0
var enemy_name := "Dévoreur du lac"
var combat: Node # Player fireballs use this property to pass the damage type.
var state := "dormant"
var state_time := 0.0
var shots_fired := 0
var splash_count := 0
var player: CharacterBody3D
var visual: Node3D
var pivot: Node3D
var animator: AnimationPlayer
var skeleton: Skeleton3D
var mouth_area: Area3D
var health_label: Label3D
var shot_target := Vector3.ZERO
var shot_locked := false
var shot_released := false
var splash_phase := 0
var ripple_timer := 0.0
var contact_timer := 0.0
var clips := {}
var rest_head := Transform3D.IDENTITY
var head_index := -1
var body_collision: CollisionShape3D
var weak_collision: CollisionShape3D
var home_position := Vector3.ZERO
var water_y := 5.5
var immersion := -2.2
var carapace: AnimatableBody3D
var water_lookup: RefCounted

func _ready() -> void:
	add_to_group("enemies")
	add_to_group("lake_monster")
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 1.0
	floor_max_angle = deg_to_rad(48)
	health = max_health
	home_position = global_position
	water_y = global_position.y
	pivot = Node3D.new()
	pivot.name = "Facing"
	add_child(pivot)
	visual = Model.instantiate()
	visual.name = "Visual"
	visual.scale = Vector3.ONE * MODEL_SCALE
	visual.position.y = immersion
	pivot.add_child(visual)
	animator = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	skeleton = visual.find_child("Skeleton3D", true, false) as Skeleton3D
	assert(animator != null and skeleton != null, "Crystalmaw needs its rig and animations")
	for clip in animator.get_animation_list():
		for key in ["Idle", "Emerge", "Spit", "Walk"]:
			if key in clip: clips[key] = clip
	assert(clips.size() == 4, "Crystalmaw requires four sampled clips")
	for key in ["Idle", "Walk"]:
		animator.get_animation(clips[key]).loop_mode = Animation.LOOP_LINEAR
	for key in ["Emerge", "Spit"]:
		animator.get_animation(clips[key]).loop_mode = Animation.LOOP_NONE
	head_index = skeleton.find_bone("head")
	assert(head_index >= 0)
	rest_head = skeleton.get_bone_global_rest(head_index)
	body_collision = CollisionShape3D.new()
	body_collision.name = "CollisionShape3D"
	var body_shape := CapsuleShape3D.new()
	# Small ground-support capsule avoids sweeping a huge dense terrain footprint.
	body_shape.radius = 0.5
	body_shape.height = 6.0
	body_collision.shape = body_shape
	body_collision.position = Vector3(0, 3, 0)
	add_child(body_collision)
	# Keep the original broad blocking volume for Naël and his projectiles.
	# It never sweeps against terrain; only the support capsule performs that work.
	carapace = AnimatableBody3D.new()
	carapace.name = "Carapace"
	carapace.sync_to_physics = false
	carapace.collision_layer = 0
	carapace.collision_mask = 0
	var armor_shape := CollisionShape3D.new()
	var armor := CapsuleShape3D.new()
	armor.radius = 3.0
	armor.height = 6.0
	armor_shape.shape = armor
	armor_shape.position = Vector3(0, 3, 0)
	carapace.add_child(armor_shape)
	add_child(carapace)
	mouth_area = Area3D.new()
	mouth_area.name = "FireWeakPoint"
	mouth_area.collision_layer = 0
	mouth_area.collision_mask = 0
	mouth_area.monitoring = false
	weak_collision = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.35
	weak_collision.shape = sphere
	mouth_area.add_child(weak_collision)
	add_child(mouth_area)
	health_label = Label3D.new()
	health_label.position = Vector3(0, 11, 0)
	health_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	health_label.no_depth_test = true
	health_label.font_size = 42
	health_label.pixel_size = 0.014
	add_child(health_label)
	visual.hide()
	health_label.hide()
	var bag := get_node_or_null("/root/Inventory")
	if bag and bag.collected.has(DEFEATED_FLAG): state = "defeated"
	# Also restore an unclaimed fragment from saves made before this reward existed.
	var fragment := preload("res://scripts/lake_fragment.gd").new()
	fragment.name = "LakeFragment"
	add_child(fragment)

func _play(key: String, blend := 0.12) -> void:
	animator.play(clips[key], blend)
	animator.advance(0)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _distance() -> float:
	return _flat_distance(player.global_position, global_position)

func _face(point: Vector3, delta: float) -> void:
	var offset := point - global_position
	# Blender -Y becomes +Z in the exported model.
	pivot.rotation.y = lerp_angle(pivot.rotation.y, atan2(offset.x, offset.z), minf(1.0, delta * 0.8))

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not is_instance_valid(player) or state == "defeated": return
	_prepare_water_lookup()
	var bag := get_node_or_null("/root/Inventory")
	if bag and bag.is_open:
		if animator.is_playing(): animator.pause()
		return
	if not animator.is_playing() and state in ["emerging", "idle", "attack", "walking", "returning"]:
		animator.play()
	state_time += delta
	if state == "dormant":
		if _flat_distance(player.global_position, home_position) < trigger_radius: _begin_emerge()
		return
	if state not in ["sinking", "returning"] and (_distance() > leash_radius or _flat_distance(player.global_position, home_position) > leash_radius):
		_begin_return()
	if state == "sinking":
		_sync_mouth()
		if state_time >= animator.get_animation(clips.Emerge).length: _reset_hidden(health <= 0)
		return
	if state == "returning":
		_face(home_position, delta)
		_walk_towards(home_position, delta)
		if _flat_distance(global_position, home_position) < 0.45: _begin_sink(false)
	else:
		if state != "attack" or state_time < 1.65: _face(player.global_position, delta)
		if state == "emerging":
			if state_time > 1.25 and splash_phase == 0:
				_splash(global_position, true)
				splash_phase = 1
			if state_time > 2.5 and splash_phase == 1:
				_splash(global_position + pivot.basis * Vector3(2, 0, 4), true)
				splash_phase = 2
			if state_time >= animator.get_animation(clips.Emerge).length: _enter_idle()
		elif state == "idle":
			if state_time > 1.4: _begin_attack()
		elif state == "walking":
			if _distance() > 18.0 and _flat_distance(global_position, home_position) < maximum_excursion:
				_walk_towards(player.global_position, delta)
			if state_time >= 5.0 or _distance() <= 18.0: _begin_attack()
		elif state == "attack":
			if state_time >= 1.65 and not shot_locked:
				shot_target = player.global_position + Vector3.UP * 0.65
				shot_locked = true
			if state_time >= RELEASE_TIME and not shot_released: _fire()
			if state_time >= animator.get_animation(clips.Spit).length:
				if _distance() > 18.0 and _flat_distance(global_position, home_position) < maximum_excursion:
					state = "walking"
					state_time = 0
					_play("Walk")
				else: _enter_idle()
	_sync_mouth()
	ripple_timer -= delta
	if ripple_timer <= 0.0 and state != "emerging":
		ripple_timer = 1.4
		_splash(global_position + pivot.basis * Vector3(3, 0, 2), false)
		_splash(global_position + pivot.basis * Vector3(-3, 0, 2), false)
	contact_timer = maxf(0, contact_timer - delta)
	if state not in ["emerging", "returning"] and _distance() < 6.5 and contact_timer <= 0.0:
		contact_timer = 1.5
		player.take_damage(projectile_damage, global_position)
	_update_label()

func _walk_towards(point: Vector3, delta: float) -> void:
	var direction := point - global_position
	direction.y = 0
	# Turning before advancing prevents a backwards slide during the return.
	var forward := pivot.global_basis.z
	var aligned := maxf(0, forward.dot(direction.normalized()))
	velocity.x = forward.x * walk_speed * aligned
	velocity.z = forward.z * walk_speed * aligned
	velocity.y = -0.5 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	var surface := _water_height(global_position)
	var offset := surface - 3.0 - global_position.y if is_finite(surface) else 0.0
	immersion = move_toward(immersion, offset, delta * 0.65)
	visual.position.y = immersion

func _enter_idle() -> void:
	state = "idle"
	state_time = 0
	velocity = Vector3.ZERO
	_play("Idle")

func _begin_attack() -> void:
	state = "attack"
	state_time = 0
	shot_locked = false
	shot_released = false
	velocity = Vector3.ZERO
	_play("Spit")

func _begin_emerge() -> void:
	global_position = home_position
	var query := PhysicsRayQueryParameters3D.create(home_position + Vector3.UP * 15, home_position - Vector3.UP * 30, 1, [get_rid()])
	var ground := get_world_3d().direct_space_state.intersect_ray(query)
	if not ground.is_empty(): global_position.y = ground.position.y + 0.04
	home_position = global_position
	state = "emerging"
	state_time = 0
	splash_phase = 0
	immersion = water_y - 3.0 - global_position.y
	visual.position = Vector3(0, immersion, 0)
	visual.show()
	health_label.show()
	var offset := player.global_position - global_position
	pivot.rotation.y = atan2(offset.x, offset.z)
	collision_layer = 4
	carapace.collision_layer = 4
	mouth_area.collision_layer = 4
	_play("Emerge", 0.0)

func _sync_mouth() -> void:
	var deformation := skeleton.get_bone_global_pose(head_index) * rest_head.affine_inverse()
	mouth_area.global_position = skeleton.global_transform * (deformation * MOUTH_REST)

func is_vulnerable() -> bool:
	# The mouth itself is the weak point whenever it is accessible above water.
	# There is no separate target orb or arbitrary attack-charge window.
	return state not in ["dormant", "sinking", "defeated"] and visual.visible and mouth_area.global_position.y > water_y + 0.6

func take_damage(amount: float, hit_position: Vector3, kind: String = "claw") -> void:
	if kind != "fireball" or not is_vulnerable(): return
	if hit_position.distance_to(mouth_area.global_position) > 1.9: return
	health = maxf(0.0, health - maxf(0.0, amount) * 2.0)
	_update_label()
	if health <= 0:
		Progression.reward_enemy(self, 250)
		var bag := get_node_or_null("/root/Inventory")
		if bag: bag.collected[DEFEATED_FLAG] = true
		var fragment := get_node_or_null("LakeFragment")
		if fragment: fragment.release_from(mouth_area.global_position)
		_begin_sink(true)

func _fire() -> void:
	shot_released = true
	shots_fired += 1
	var projectile := Projectile.new()
	projectile.direction = (shot_target - mouth_area.global_position).normalized()
	projectile.damage = projectile_damage
	projectile.source_rid = get_rid()
	projectile.water_y = water_y
	projectile.position = get_parent().to_local(mouth_area.global_position + projectile.direction * 1.4)
	get_parent().add_child(projectile)
	_splash(global_position + pivot.basis * Vector3(0, 0, 4), false)

func _clear_shots() -> void:
	for projectile in get_tree().get_nodes_in_group("lake_monster_projectiles"): projectile.queue_free()

func _begin_return() -> void:
	state = "returning"
	state_time = 0
	_clear_shots()
	_play("Walk")

func _begin_sink(defeated: bool) -> void:
	state = "sinking"
	state_time = 0
	collision_layer = 0
	carapace.collision_layer = 0
	mouth_area.collision_layer = 0
	health_label.hide()
	velocity = Vector3.ZERO
	animator.play(clips.Emerge, 0.12, -1.0, true)
	animator.advance(0)
	_splash(global_position, true)
	_clear_shots()
	if defeated: health = 0

func _reset_hidden(defeated: bool) -> void:
	visual.hide()
	health_label.hide()
	collision_layer = 0
	carapace.collision_layer = 0
	mouth_area.collision_layer = 0
	velocity = Vector3.ZERO
	global_position = home_position
	immersion = water_y - 3.0 - global_position.y
	visual.position = Vector3(0, immersion, 0)
	state = "defeated" if defeated else "dormant"
	health = 0.0 if defeated else max_health
	state_time = 0
	animator.stop()

func reset_encounter() -> void:
	_clear_shots()
	_reset_hidden(false)
	shots_fired = 0
	ripple_timer = 0
	var bag := get_node_or_null("/root/Inventory")
	if bag: bag.collected.erase(DEFEATED_FLAG)

func _splash(point: Vector3, large: bool) -> void:
	if get_tree().get_nodes_in_group("water_splashes").size() >= 24 or player.water_surface == null: return
	var surface := _water_height(point)
	if not is_finite(surface): return
	var effect := Splash.new()
	effect.large = large
	effect.add_to_group("water_splashes")
	effect.position = get_parent().to_local(Vector3(point.x, surface + 0.04, point.z))
	get_parent().add_child(effect)
	splash_count += 1

func _prepare_water_lookup() -> void:
	if water_lookup != null or player.water_surface == null or player.water_surface.surfaces.is_empty(): return
	water_lookup = WaterLookup.new()
	water_lookup.build(player.water_surface.surfaces, home_position)

func _water_height(point: Vector3) -> float:
	_prepare_water_lookup()
	if water_lookup == null: return -INF
	return water_lookup.height_at(point)

func _update_label() -> void:
	health_label.text = "%s — %d / %d\n%s" % [enemy_name, ceili(health), ceili(max_health), "RETOUR AU LAC" if state == "returning" else "GUEULE VULNÉRABLE AU FEU" if is_vulnerable() else "CARAPACE"]
