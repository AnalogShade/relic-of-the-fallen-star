extends CharacterBody3D
## Merrick stays in the market aisle and welcomes nearby visitors.
@export var approach_radius := 5.0
@export var leash_radius := 2.2
@export var stop_distance := 1.9
@export var walk_speed := 0.78
var home: Vector3
var player: Node3D
var engaged := false
var shop: CanvasLayer
var animator: AnimationPlayer
var clips := {}
@onready var visual: Node3D = $Visual

func _ready() -> void:
	home = global_position
	add_to_group("interactable")
	add_to_group("merchant")
	animator = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animator:
		for clip in animator.get_animation_list():
			for kind in ["Walk", "Idle", "Talk"]:
				if str(clip).ends_with("Merchant_" + kind):
					clips[kind] = clip
					animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	shop = preload("res://scripts/merchant_shop.gd").new()
	add_child(shop)
	_play("Idle")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player") as Node3D
	var direction := Vector3.ZERO
	var talking := shop.visible
	if is_instance_valid(player):
		var home_offset := player.global_position - home
		home_offset.y = 0.0
		var height_ok := absf(player.global_position.y - global_position.y) < 2.0
		if height_ok and home_offset.length() < approach_radius:
			engaged = true
		elif not height_ok or home_offset.length() > approach_radius + 2.0:
			engaged = false
		var offset := player.global_position - global_position
		offset.y = 0.0
		if engaged:
			if offset.length() > stop_distance + 0.15 and not talking:
				var destination := player.global_position - offset.normalized() * stop_distance
				var from_home := destination - home
				from_home.y = 0.0
				destination = home + from_home.limit_length(leash_radius)
				direction = destination - global_position
				direction.y = 0.0
				direction = direction.normalized() if direction.length() > 0.12 else Vector3.ZERO
			else:
				talking = true
			_face(offset, delta)
		elif shop.visible:
			shop.close_shop()
	if not engaged:
		direction = home - global_position
		direction.y = 0.0
		direction = direction.normalized() if direction.length() > 0.12 else Vector3.ZERO
		_face(direction, delta)
	velocity.x = direction.x * walk_speed
	velocity.z = direction.z * walk_speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	if moved > delta * 0.08:
		_play("Walk")
		if animator: animator.speed_scale = clampf(moved / (walk_speed * delta), 0.2, 1.1)
	else:
		_play("Talk" if talking else "Idle")
		if animator: animator.speed_scale = 1.0

func _face(offset: Vector3, delta: float) -> void:
	if offset.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(offset.x, offset.z), minf(delta * 5.0, 1.0))

func _play(kind: String) -> void:
	if animator and clips.has(kind) and animator.current_animation != clips[kind]:
		animator.play(clips[kind], 0.25)

func can_interact() -> bool:
	var bag = get_node("/root/Inventory")
	var dialogue = get_node("/root/DialogueManager")
	if not is_instance_valid(player) or bag.is_open or dialogue.is_open or shop.visible: return false
	if get_node("/root/CabinTravel").busy or player.global_position.distance_to(global_position) > 2.8: return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP, global_position + Vector3.UP, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func interaction_text() -> String:
	return "Commercer avec Merrick"

func interact() -> void:
	if can_interact(): shop.open_shop()
