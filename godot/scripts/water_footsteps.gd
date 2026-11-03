extends Node
## Uses existing step events; no continuous emission while swimming or idle.
const Splash = preload("res://scripts/water_splash.gd")
var player: CharacterBody3D
var skeleton: Skeleton3D
var foot_bones: Array[int] = []
var next_foot := 0
var previous_position := Vector3.ZERO
var initialized := false
var entry_cooldown := 0.0
var splash_count := 0

func _ready() -> void:
	player = get_parent()
	skeleton = player.get_node("Nael").find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton:
		for side in ["Left", "Right"]:
			var found := -1
			for i in skeleton.get_bone_count():
				var bone := skeleton.get_bone_name(i)
				if bone.ends_with(side + "Foot") or bone == side + "Foot":
					found = i
					break
			foot_bones.append(found)

func reset() -> void:
	initialized = false
	entry_cooldown = 0.0

func _physics_process(delta: float) -> void:
	entry_cooldown = maxf(0.0, entry_cooldown - delta)
	var position := player.global_position
	if initialized and position.distance_to(previous_position) < 2.0 and entry_cooldown <= 0.0:
		var height: float = player.water_surface.height_at(position)
		# The body origin sits about 0.425 m above the soles.
		if is_finite(height) and previous_position.y - 0.425 > height + 0.02 and position.y - 0.425 <= height + 0.02:
			var fall_speed := (previous_position.y - position.y) / maxf(delta, 0.001)
			if fall_speed > 1.5:
				emit_at(Vector3(position.x, height, position.z), clampf(fall_speed / 4.0, 1.2, 2.8))
				entry_cooldown = 0.45
	previous_position = position
	initialized = true

func step(foot: int = -1) -> bool:
	if player.swimming or not player.is_on_floor():
		return false
	if foot >= 0:
		next_foot = foot
	var position := player.global_position
	if skeleton and foot_bones.size() == 2 and foot_bones[next_foot] >= 0:
		position = skeleton.global_transform * skeleton.get_bone_global_pose(foot_bones[next_foot]).origin
	else:
		position += player.get_node("Nael").global_basis.x * (-0.14 if next_foot == 0 else 0.14)
	next_foot = 1 - next_foot
	var height: float = player.water_surface.height_at(position)
	var depth := height - (player.global_position.y - 0.425)
	if not is_finite(height) or depth < 0.025 or depth > player.swim_enter_depth + 0.425:
		return false
	position.y = height
	var pace := Vector2(player.velocity.x, player.velocity.z).length()
	emit_at(position, clampf(0.55 + pace * 0.14 + depth * 0.25, 0.6, 1.6))
	if player.has_method("_play_water_footstep"):
		player._play_water_footstep(depth)
	return true

func emit_at(position: Vector3, intensity: float) -> void:
	var world := get_tree().current_scene
	if world == null or get_tree().get_nodes_in_group("water_splashes").size() >= 24:
		return
	var effect := Splash.new()
	effect.strength = intensity
	effect.drift = Vector3(player.velocity.x, 0, player.velocity.z)
	effect.position = world.to_local(position + Vector3.UP * 0.018)
	effect.add_to_group("water_splashes")
	world.add_child(effect)
	splash_count += 1
