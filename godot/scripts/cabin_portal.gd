extends Node3D
@export var exit_to_forest := false
@export var reach := 2.6
var hint: Label

func _ready() -> void:
	add_to_group("interactable")

func interaction_text() -> String:
	return "Sortir dans la forêt" if exit_to_forest else "Entrer dans la cabane"

func interact() -> void:
	if not can_interact(): return
	if exit_to_forest: get_node("/root/CabinTravel").leave_cabin()
	else: get_node("/root/CabinTravel").enter_cabin(self)

func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player or get_node("/root/CabinTravel").busy: return false
	var p := player.global_position
	if absf(p.x - global_position.x) > 1.45: return false
	if exit_to_forest and p.z < 0.9: return false
	if not exit_to_forest and p.z < 1.7: return false
	return (p + Vector3.UP * 0.6).distance_to(global_position) < reach

