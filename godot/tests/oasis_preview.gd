extends Node3D
## Convenient play-session entry at the new pier; does not change the main spawn.
func _ready() -> void:
	var world=load("res://scenes/world/open_world.tscn").instantiate()
	add_child(world)
	for i in range(20):await get_tree().physics_frame
	var player=world.get_node("Original/Player")
	player.global_position=Vector3(18.5,6.9,-213)
	player.velocity=Vector3.ZERO
	player.pivot.rotation.y=PI/2
	player.arm.rotation.x=-.25
	player.arm.spring_length=6.0
	var bag=get_node("/root/Inventory")
	bag.add_item("fishing_rod")
	bag.toggle_equipment("fishing_rod")
