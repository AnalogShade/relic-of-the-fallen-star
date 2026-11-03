extends Node3D
## Floor-wide mist follows every landing and ramp; no player tracking.

func build(layout: Dictionary) -> void:
	name = "DepthsAtmosphere"
	for layer in 5:
		var height := 0.07 + layer * 0.085
		var room_material := ShaderMaterial.new()
		room_material.shader = preload("res://shaders/cave_ground_mist.gdshader")
		room_material.set_shader_parameter("layer_phase", layer * 0.37)
		room_material.set_shader_parameter("mist_color", Color(0.48, 0.60, 0.65, 0.12 - layer * 0.016))
		var ramp_material := room_material.duplicate() as ShaderMaterial
		ramp_material.set_shader_parameter("round_patch", false)
		for room in layout.rooms:
			var center := Vector3(float(room[1]), float(room[3]) + height, -float(room[2]))
			var x := Vector3(float(room[4]) * 0.94, 0, 0)
			var z := Vector3(0, 0, float(room[5]) * 0.94)
			_patch([center-x-z, center+x-z, center+x+z, center-x+z], room_material)
		for i in layout.ramps.size():
			var ramp: Dictionary = layout.ramps[i]
			var a := Vector3(float(ramp.start[0]), float(layout.rooms[i][3]) + height, -float(ramp.start[1]))
			var b := Vector3(float(ramp.end[0]), float(layout.rooms[i+1][3]) + height, -float(ramp.end[1]))
			var side := Vector3(b.z-a.z, 0, a.x-b.x).normalized() * float(ramp.width_m) * 0.56
			_patch([a-side, a+side, b+side, b-side], ramp_material)
	var glow_material := ShaderMaterial.new()
	glow_material.shader = preload("res://shaders/cave_abyss_glow.gdshader")
	for y in [-23.0, -30.0, -39.0]:
		var plane := PlaneMesh.new()
		plane.size = Vector2(160, 180)
		var glow := MeshInstance3D.new()
		glow.name = "DeepRedHalo"
		glow.mesh = plane
		glow.position = Vector3(0, y, 0)
		glow.material_override = glow_material
		glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(glow)
	for p in [Vector3(8, -17, -19), Vector3(-12, -20, 18)]:
		var light := OmniLight3D.new()
		light.name = "RedLightFromBelow"
		light.position = p
		light.light_color = Color("b52b18")
		light.light_energy = 0.65
		light.omni_range = 48.0
		light.omni_attenuation = 1.4
		light.shadow_enabled = false
		add_child(light)

func _patch(corners: Array, material: ShaderMaterial) -> void:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(corners)
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,2,1,0,3,2])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var patch := MeshInstance3D.new()
	patch.name = "GroundMist"
	patch.mesh = mesh
	patch.material_override = material
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(patch)
