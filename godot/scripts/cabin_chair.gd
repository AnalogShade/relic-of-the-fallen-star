extends Node3D
## Seat anchor on the existing, rotated armchair cushion.
const FACING := Vector3(0.9285, 0.0, -0.3714)

func _ready() -> void:
	add_to_group("interactable")

func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return false
	if player.rest_state != "":
		return player.rest_controller.seat == self and player.rest_state == "seated"
	return not player.swimming and not player.is_attacking and player.is_on_floor() and player.global_position.distance_to(global_position) < 2.3

func interaction_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	return "Se relever" if player and player.rest_state == "seated" else "S’asseoir dans le fauteuil · +1 PV / 5 s"

func interact() -> void:
	if not can_interact(): return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player.rest_state == "seated":
		player.rest_controller.stand()
	else:
		player.rest_controller.begin(self, global_position - Vector3.UP * 0.05, FACING)

func footprint() -> Rect2:
	# Includes the back, armrests and legs of the imported armchair.
	return Rect2(Vector2(global_position.x - 0.85, global_position.z - 0.85), Vector2(1.7, 1.7))

func rest_fire() -> Node3D:
	return get_parent().get_node("HearthFire")

func walking_probe_height() -> float:
	return 0.4
