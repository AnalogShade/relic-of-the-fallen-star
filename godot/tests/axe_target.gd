extends CharacterBody3D
var health := 100.0
var enemy_name := "Cible de test"
func take_damage(amount: float, _source: Vector3) -> void:
	health -= amount
