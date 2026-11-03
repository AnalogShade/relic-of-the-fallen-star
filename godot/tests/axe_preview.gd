extends Node3D
func _ready() -> void:
	var world = preload("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(5): await get_tree().process_frame
	var player = world.get_node("Original/Player")
	player.set_physics_process(false)
	player.hide()
	for layer in get_tree().root.find_children("*", "CanvasLayer", true, false): layer.hide()
	var camera := Camera3D.new()
	add_child(camera)
	camera.current = true
	camera.position = Vector3(29, 4.5, -52)
	camera.look_at(Vector3(26.3, 2.9, -55.9))
	camera.fov = 38
	for i in range(20): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/axe_camp_before.png")
	var axe = get_tree().get_first_node_in_group("world_axe")
	player.global_position = axe.global_position + Vector3(.5,0,.5)
	player.is_attacking = false
	player.swimming = false
	axe.interact()
	get_node("/root/Inventory").toggle_equipment("axe")
	print("EQUIP_DEBUG ", get_node("/root/Inventory").equipment, " / ", get_node("/root/Inventory").equipped)
	player.show()
	player.global_position = Vector3(27,2.6,-54.2)
	player.get_node("Nael").set_process(false)
	player.get_node("Nael").animator.play("Nael_Idle_Breathe")
	for i in range(30): await get_tree().process_frame
	print("HELD_DEBUG ", player.get_node("HeldEquipment").axe.visible, " ", player.get_node("HeldEquipment").axe.global_position)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/axe_equipped.png")
	get_tree().quit()

