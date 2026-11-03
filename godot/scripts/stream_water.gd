@tool
extends RefCounted
## Shared river/lake rendering. Disable to restore legacy materials next scene load.
const ENABLED := true
const SHADER = preload("res://shaders/stream_water.gdshader")
const LAKE_SHADER = preload("res://shaders/lake_water.gdshader")

static func apply_lake(water: MeshInstance3D) -> void:
	if not ENABLED or water.mesh == null:
		return
	var material := ShaderMaterial.new()
	material.shader = LAKE_SHADER
	water.material_override = material

static func apply(water: MeshInstance3D) -> void:
	if not ENABLED or water.mesh == null:
		return
	# Derive the banks from the existing mesh; never edit the imported geometry.
	var vertices := PackedVector3Array()
	var z_min := INF
	var z_max := -INF
	for surface in water.mesh.get_surface_count():
		var points: PackedVector3Array = water.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for point in points:
			vertices.append(point)
			z_min = minf(z_min, point.z)
			z_max = maxf(z_max, point.z)
	if vertices.is_empty() or z_max - z_min < 0.01:
		return
	var count := 128
	var banks := Image.create(count, 1, false, Image.FORMAT_RGBAF)
	for i in count:
		var z := lerpf(z_min, z_max, float(i) / float(count - 1))
		var left := INF
		var right := -INF
		var radius := (z_max - z_min) / float(count - 1) * 0.8
		for point in vertices:
			if absf(point.z - z) <= radius:
				left = minf(left, point.x)
				right = maxf(right, point.x)
		if left == INF:
			var nearest := vertices[0]
			for point in vertices:
				if absf(point.z - z) < absf(nearest.z - z):
					nearest = point
			left = nearest.x - 2.0
			right = nearest.x + 2.0
		banks.set_pixel(i, 0, Color((left + right) * 0.5, maxf((right - left) * 0.5, 0.25), 0.0, 1.0))
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("banks", ImageTexture.create_from_image(banks))
	material.set_shader_parameter("z_limits", Vector2(z_min, z_max))
	water.material_override = material
	# Defer until the assembly has assigned the final terrain materials.
	_apply_bank_seal.call_deferred(water)

static func _apply_bank_seal(water: MeshInstance3D) -> void:
	if is_instance_valid(water):
		preload("res://scripts/stream_bank_seal.gd").apply(water)
