extends Node3D
## Local review entry point: the normal world, starting in the castle quarter.
func _ready() -> void:
	for i in range(12):
		await get_tree().physics_frame
	var player := get_node("OpenWorld/Original/Player") as CharacterBody3D
	var p := Vector3(-16.0,-14.0,0.65) - Vector3(2.0,4.0,0.0)
	player.global_position = Basis(Vector3.UP,PI/2.0-.35) * Vector3(p.x,p.z,-p.y) + Vector3(-226,12,-32)
	player.velocity = Vector3.ZERO
	player.set("spawn_position",player.global_position)
	player.get_node("CameraPivot").rotation.y = PI/2.0-.35
	player.get_node("CameraPivot/SpringArm3D").rotation.x = -0.22
