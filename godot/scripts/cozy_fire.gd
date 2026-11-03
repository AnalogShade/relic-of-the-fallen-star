extends Node3D
## Low-poly, continuously deforming flames and warm flickering light.
@export_range(0.0, 2.0, 0.01) var light_energy_scale := 1.0
var elapsed := 0.0
var light: OmniLight3D
var tongues: Array[MeshInstance3D] = []

func _ready() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float phase = 0.0;
varying float height;
void vertex() {
	height = UV.y;
	VERTEX.x += sin(TIME * 4.4 + UV.y * 6.0 + phase) * UV.y * 0.13;
	VERTEX.z += cos(TIME * 3.7 + UV.y * 5.0 + phase) * UV.y * 0.08;
	VERTEX.y *= 0.87 + 0.13 * sin(TIME * 5.3 + phase);
}
void fragment() {
	vec3 base = mix(vec3(1.0, 0.88, 0.22), vec3(1.0, 0.20, 0.025), smoothstep(0.12, 0.92, height));
	ALBEDO = base;
	EMISSION = base * 1.4;
}
"""
	for i in range(5):
		var flame := MeshInstance3D.new()
		flame.name = "Flame%d" % i
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var radii := [0.19, 0.22, 0.14, 0.065, 0.001]
		for ring in range(4):
			for side in range(7):
				for point in [[ring, side], [ring + 1, side], [ring + 1, side + 1], [ring, side], [ring + 1, side + 1], [ring, side + 1]]:
					var r: int = point[0]
					var angle := float(point[1]) * TAU / 7.0
					st.set_uv(Vector2(float(point[1]) / 7.0, r / 4.0))
					st.add_vertex(Vector3(cos(angle) * radii[r] + 0.08 * sin(r * 1.4), r * 0.22, sin(angle) * radii[r]))
		st.generate_normals()
		flame.mesh = st.commit()
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("phase", i * 1.71)
		flame.material_override = mat
		flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flame.position = Vector3((i - 2) * 0.15, 0, sin(i * 2.0) * 0.11)
		flame.scale = Vector3.ONE * (0.72 + 0.22 * sin(i * 1.9 + 0.4))
		add_child(flame)
		tongues.append(flame)
	light = OmniLight3D.new()
	light.name = "FireLight"
	light.position = Vector3(0, 0.43, 0.55)
	light.light_color = Color(1.0, 0.48, 0.16)
	light.light_energy = 2.8 * light_energy_scale
	light.omni_range = 6.2
	light.omni_attenuation = 1.25
	light.shadow_enabled = true
	light.shadow_bias = 0.04
	add_child(light)
	var embers := MeshInstance3D.new()
	embers.name = "Embers"
	var bed := SphereMesh.new()
	bed.radius = 0.34
	bed.height = 0.075
	bed.radial_segments = 12
	bed.rings = 4
	embers.mesh = bed
	var coal := StandardMaterial3D.new()
	coal.albedo_color = Color(0.30, 0.025, 0.004)
	coal.emission_enabled = true
	coal.emission = Color(1.0, 0.12, 0.008)
	coal.emission_energy_multiplier = 1.4
	embers.material_override = coal
	embers.position.y = -0.06
	add_child(embers)

	# 3D Positional Campfire Audio
	var fire_audio := AudioStreamPlayer3D.new()
	fire_audio.name = "CampfireAudio"
	fire_audio.bus = "SFX"
	fire_audio.max_distance = 18.0
	fire_audio.unit_size = 2.5
	add_child(fire_audio)

func _process(delta: float) -> void:
	elapsed += delta
	light.light_energy = light_energy_scale * (0.82 + 0.055 * sin(elapsed * 7.3) + 0.035 * sin(elapsed * 11.7))
	for i in range(tongues.size()):
		tongues[i].scale.y = 0.85 + 0.17 * sin(elapsed * 3.7 + i * 1.8)
