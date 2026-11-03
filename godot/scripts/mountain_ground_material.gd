@tool
extends RefCounted
## Project-local generated textures. The two masks remain independently tunable.
const GRANITE = preload("res://assets/environment/mountain_ground/granite_v1.png")
const SCHIST = preload("res://assets/environment/mountain_ground/schist_v1.png")
const SNOW = preload("res://assets/environment/mountain_ground/snow_v1.png")

static func configure(material: ShaderMaterial) -> void:
	material.set_shader_parameter("mountain_granite", GRANITE)
	material.set_shader_parameter("mountain_schist", SCHIST)
	material.set_shader_parameter("mountain_snow", SNOW)
	material.set_shader_parameter("mountain_textures_enabled", true)
