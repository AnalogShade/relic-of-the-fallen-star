extends Node
var current_scene: Node
func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if scene == current_scene or not scene: return
	current_scene = scene
	call_deferred("restore_axe", scene)
func restore_axe(scene: Node) -> void:
	if not is_instance_valid(scene): return
	var bag := get_node("/root/Inventory")
	if bag.equipment.has("axe") or not get_tree().get_nodes_in_group("world_axe").is_empty(): return
	var state: Dictionary = bag.axe_state
	if state.get("scene", "") != scene.scene_file_path or not state.has("position"): return
	var axe := preload("res://scripts/world_axe.gd").new()
	scene.add_child(axe)
	var p: Array = state.position
	axe.global_position = Vector3(p[0], p[1], p[2])
	axe.last_safe = axe.global_position
	axe.flight = true
