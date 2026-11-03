extends Node3D
@export var reach := 2.8
@export var exit_to_forest := false

func _ready() -> void:
	add_to_group("interactable")

func interaction_text() -> String:
	return "Sortir dans la forêt" if exit_to_forest else "Entrer dans la caverne"

func can_interact() -> bool:
	if not exit_to_forest:
		var guardian := get_parent().get_node_or_null("OgreGuardian")
		if guardian and not guardian.passage_open(): return false
		if not guardian and not preload("res://scripts/cave_access.gd").passage_open(self): return false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player or get_node("/root/CabinTravel").busy: return false
	var p := to_local(player.global_position)
	if (not exit_to_forest and p.z < 0.05) or (exit_to_forest and p.z > -0.05): return false
	return absf(p.x) < 1.65 and (player.global_position + Vector3.UP * 0.6).distance_to(global_position) < reach

func _process(_delta: float) -> void:
	if exit_to_forest: return
	var qm = get_node_or_null("/root/QuestManager")
	if not qm: return
	if not qm.is_quest_active("echo_depths") and not qm.is_quest_completed("echo_depths"):
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player and global_position.distance_to(player.global_position) <= 12.0:
			qm.start_quest_from_cave("echo_depths")

func interact() -> void:
	if not can_interact(): return
	if exit_to_forest: 
		get_node("/root/CabinTravel").leave_cabin()
	else:
		var qm = get_node_or_null("/root/QuestManager")
		if qm:
			if not qm.is_quest_active("echo_depths") and not qm.is_quest_completed("echo_depths"):
				qm.start_quest_from_cave("echo_depths")
			elif qm.is_quest_active("echo_depths"):
				qm.complete_objective("echo_depths", 1)
		get_node("/root/CabinTravel").enter_cabin(self, "res://scenes/interiors/cave_room.tscn")
