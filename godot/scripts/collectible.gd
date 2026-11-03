extends Node3D

@export var item_id := "mushroom"
@export var quantity := 1
@export var pickup_id := ""
@export var reach := 2.1
@export var respawn_time := 180.0 # 3 minutes pour les ressources renouvelables (0 = permanent)

func _ready() -> void:
	add_to_group("interactable")
	if item_id == "fishing_rod":
		respawn_time = 0.0
		
	if respawn_time <= 0.0:
		var inventory := get_node_or_null("/root/Inventory")
		if inventory and inventory.collected.has(pickup_id):
			hide()
			queue_free()
	else:
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
		show()
		return
	var val = inventory.collected[pickup_id]
	if typeof(val) == TYPE_FLOAT or typeof(val) == TYPE_INT:
		var now := Time.get_unix_time_from_system()
		var remaining := float(val) - now
		if remaining <= 0.0:
			inventory.collected.erase(pickup_id)
			show()
		else:
			hide()
			_start_respawn_timer(remaining)
	else:
		if bool(val):
			hide()

func _start_respawn_timer(duration: float) -> void:
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func():
		var inventory := get_node_or_null("/root/Inventory")
		if inventory:
			inventory.collected.erase(pickup_id)
		show()
	)

func can_interact() -> bool:
	if not is_visible_in_tree() or is_queued_for_deletion(): return false
	if is_harvested(): return false
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player or player.global_position.distance_to(global_position) > reach: return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.65, global_position, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func interaction_text() -> String:
	if item_id == "fishing_rod":
		return "Prendre la canne à pêche"
	elif item_id == "blueberry":
		return "Cueillir les bleuets"
	elif item_id == "raspberry":
		return "Cueillir les framboises"
	elif item_id == "golden_berry":
		return "Cueillir les baies dorées"
	return "Cueillir les champignons"

func interact() -> void:
	if not can_interact(): return
	var inventory := get_node_or_null("/root/Inventory")
	if not inventory or is_harvested(): return
	if not inventory.add_item(item_id, quantity):
		inventory.ui.notify("Inventaire plein")
		return
		
	if respawn_time > 0.0:
		var respawn_at := Time.get_unix_time_from_system() + respawn_time
		inventory.collected[pickup_id] = respawn_at
		hide()
		_start_respawn_timer(respawn_time)
	else:
		inventory.collected[pickup_id] = true
		hide()
		queue_free()
		
	inventory.ui.notify("+ %d  %s" % [quantity, inventory.ITEMS[item_id].name])
