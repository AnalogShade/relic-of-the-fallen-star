extends Node3D
var flight := false
var velocity := Vector3.ZERO
var shooter: CharacterBody3D
var attached_enemy: Node3D
var attachment_offset := Vector3.ZERO
var model: Node3D
var reach := 2.2
var last_safe := Vector3.ZERO
var source_billot: MeshInstance3D

func _ready() -> void:
	model = Node3D.new()
	add_child(model)
	var visual := preload("res://assets/items/axe.glb").instantiate()
	model.add_child(visual)
	# Spin around the middle of the axe, rather than around the hand grip.
	visual.position.y = -0.24
	model.visible = not is_instance_valid(source_billot)
	add_to_group("interactable")
	add_to_group("world_axe")

func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	return not flight and player != null and player.rest_state == "" and not player.is_attacking and not player.swimming and player.global_position.distance_to(global_position) <= reach

func interaction_text() -> String:
	return "Prendre la hache"

func interact() -> void:
	if not can_interact(): return
	var bag := get_node("/root/Inventory")
	if not bag.add_item("axe"):
		bag.ui.notify("Inventaire plein")
		return
	bag.axe_state = {"taken": true}
	if is_instance_valid(source_billot):
		source_billot.remove_original_axe()
	bag.ui.notify("Hache ajoutée au sac · Cliquez dessus pour l’équiper")
	queue_free()

func _physics_process(delta: float) -> void:
	# The original combined mesh supplies the visual until the first pickup.
	if is_instance_valid(source_billot): return
	if is_instance_valid(attached_enemy):
		if attached_enemy.is_queued_for_deletion() or ("health" in attached_enemy and attached_enemy.health <= 0):
			attached_enemy = null
			flight = true
			velocity = Vector3.ZERO
		else:
			global_position = attached_enemy.to_global(attachment_offset)
	if flight:
		velocity.y -= 18.0 * delta
		var next := global_position + velocity * delta
		var excluded: Array[RID] = []
		if is_instance_valid(shooter): excluded.append(shooter.get_rid())
		var ray := PhysicsRayQueryParameters3D.create(global_position, next, 5, excluded)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty():
			global_position = next
			# Local Z is perpendicular to the flight plane: an end-over-end tumble.
			model.rotate_z(-18.0 * delta)
		else:
			global_position = hit.position + hit.normal * 0.06
			flight = false
			velocity = Vector3.ZERO
			var enemy: Node = hit.collider
			while enemy and not enemy.has_method("take_damage"): enemy = enemy.get_parent()
			if enemy and enemy.is_in_group("enemies"):
				enemy.take_damage(40.0 * Progression.physical_multiplier(), shooter.global_position if is_instance_valid(shooter) else global_position)
				if not enemy.is_queued_for_deletion() and enemy.health > 0:
					attached_enemy = enemy
					attachment_offset = enemy.to_local(global_position)
			model.rotation = Vector3(0, 0, PI * 0.5)
		if global_position.y < -25.0:
			global_position = last_safe
			flight = false
			velocity = Vector3.ZERO
	store_state()

func store_state() -> void:
	var scene := get_tree().current_scene
	if not scene: return
	get_node("/root/Inventory").axe_state = {"taken": true, "scene": scene.scene_file_path, "position": [global_position.x, global_position.y, global_position.z]}
