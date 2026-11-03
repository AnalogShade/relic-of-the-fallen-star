extends Node3D
func _ready() -> void:
	var body := StaticBody3D.new()
	body.name = "CabinDoorCollision"
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.4, 2.46, 0.18)
	collider.shape = shape
	collider.position = Vector3(0.70, 1.25, 0)
	body.add_child(collider)
	add_child(body)
