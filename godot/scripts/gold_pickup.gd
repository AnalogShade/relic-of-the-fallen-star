extends Node3D
## Kept beside the corpse so unclaimed gold survives its visual fade.
@export var amount := 8
var claimed := false
var elapsed := 0.0
var coins: Node3D

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("gold_pickups")
	coins = Node3D.new()
	add_child(coins)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("f8c83f")
	material.metallic = 0.8
	material.roughness = 0.26
	material.emission_enabled = true
	material.emission = Color("a66a06")
	material.emission_energy_multiplier = 0.55
	for i in range(3):
		var mesh := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.12
		disc.bottom_radius = 0.12
		disc.height = 0.05
		disc.radial_segments = 20
		mesh.mesh = disc
		mesh.material_override = material
		mesh.rotation = Vector3(PI / 2.0, i * 0.8, 0)
		mesh.position = Vector3((i - 1) * 0.22, 0.15 if i == 1 else 0.0, 0.04 * i)
		coins.add_child(mesh)
	var label := Label3D.new()
	label.text = "%d pièces d’or" % amount
	label.position.y = 1.25
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 24
	label.outline_size = 5
	label.modulate = Color("ffdc74")
	add_child(label)

func _process(delta: float) -> void:
	elapsed += delta
	coins.position.y = 0.85 + sin(elapsed * 2.8) * 0.09
	coins.rotation.y += delta * 1.5

func can_interact() -> bool:
	if claimed or is_queued_for_deletion(): return false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player or player.global_position.distance_to(global_position) > 2.6: return false
	var ray := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.8, global_position + Vector3.UP * 0.8, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func interaction_text() -> String:
	return "Ramasser %d pièces d’or" % amount

func interact() -> void:
	if not can_interact(): return
	claimed = true
	var bag = get_node("/root/Inventory")
	bag.add_gold(amount)
	bag.ui.notify("+ %d pièces d’or · Bourse : %d" % [amount, bag.gold])
	hide()
	queue_free()
