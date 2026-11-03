extends Node3D

@export var item_id := "blueberry"
@export var item_name := "les bleuets"
@export var quantity := 5
@export var pickup_id := ""
@export var reach := 3.2
@export var respawn_time := 180.0 # 3 minutes

var berry_mesh: MeshInstance3D = null

func _ready() -> void:
	add_to_group("interactable")
	var parent_bush := get_parent()
	if parent_bush:
		for mi in parent_bush.find_children("*Baies*", "MeshInstance3D", true, false):
			berry_mesh = mi as MeshInstance3D
			break
	
	_check_harvest_state()

func is_harvested() -> bool:
	var inventory := get_node_or_null("/root/Inventory")
	if not inventory or not inventory.collected.has(pickup_id):
		return false
	var val = inventory.collected[pickup_id]
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		var now := Time.get_unix_time_from_system()
		if now >= float(val):
			inventory.collected.erase(pickup_id)
			return false
		return true
	return bool(val)

func _check_harvest_state() -> void:
	var inventory := get_node_or_null("/root/Inventory")
	if not inventory or not inventory.collected.has(pickup_id):
		if berry_mesh: berry_mesh.show()
		return
	var val = inventory.collected[pickup_id]
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		var now := Time.get_unix_time_from_system()
		var remaining := float(val) - now
		if remaining <= 0.0:
			inventory.collected.erase(pickup_id)
			if berry_mesh: berry_mesh.show()
		else:
			if berry_mesh: berry_mesh.hide()
			_start_respawn_timer(remaining)
	else:
		if bool(val) and berry_mesh:
			berry_mesh.hide()

func _start_respawn_timer(duration: float) -> void:
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		var inventory := get_node_or_null("/root/Inventory")
		if inventory:
			inventory.collected.erase(pickup_id)
		if berry_mesh:
			berry_mesh.show()
	)

func can_interact() -> bool:
	if not is_visible_in_tree():
		return false
	if is_harvested():
		return false
	if berry_mesh and not berry_mesh.visible:
		return false
		
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player:
		return false
		
	var target_pos := global_position + Vector3.UP * 1.0
	if player.global_position.distance_to(target_pos) > reach:
		return false
		
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.8, target_pos, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func interaction_text() -> String:
	return "Cueillir " + item_name

func interact() -> void:
	if not can_interact():
		return
	var inventory := get_node_or_null("/root/Inventory")
	if not inventory or is_harvested():
		return
	if not inventory.add_item(item_id, quantity):
		inventory.ui.notify("Inventaire plein")
		return
		
	var respawn_at := Time.get_unix_time_from_system() + respawn_time
	inventory.collected[pickup_id] = respawn_at
	if berry_mesh:
		berry_mesh.hide()
	inventory.ui.notify("+ %d  %s" % [quantity, inventory.ITEMS[item_id].name])
	_start_respawn_timer(respawn_time)
