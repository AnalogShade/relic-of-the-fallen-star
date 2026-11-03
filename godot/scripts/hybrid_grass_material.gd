@tool
extends RefCounted
## Shared image bindings for the full world, original forest and title backdrop.
const MEADOW = preload("res://assets/environment/grass_ground_hybrid/meadow_clover_v1.png")
const FINE = preload("res://assets/environment/grass_ground_hybrid/meadow_fine_v1.png")

static func configure(material: ShaderMaterial) -> void:
	material.set_shader_parameter("hybrid_grass_a", MEADOW)
	material.set_shader_parameter("hybrid_grass_b", FINE)
	material.set_shader_parameter("hybrid_grass_enabled", true)
