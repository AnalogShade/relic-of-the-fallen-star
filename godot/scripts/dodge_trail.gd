extends MeshInstance3D
## Short world-space wisps and frozen, tinted silhouettes during dodge movement.
@export var lifetime := 0.22
@export var ghost_lifetime := 0.20
var actor: CharacterBody3D
var samples: Array[Dictionary] = []
var ghosts: Array[Dictionary] = []
var ribbon := ImmediateMesh.new()
var ghost_shader: Shader
var ghost_timer := 0.0
var last_position := Vector3.ZERO
var halo: MeshInstance3D
var halo_material: ShaderMaterial
var halo_strength := 0.0
var aura: MeshInstance3D
var aura_material: ShaderMaterial

func _ready() -> void:
	actor = get_parent()
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = ribbon
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
void fragment(){
 float across=pow(max(0.0,1.0-abs(UV.y*2.0-1.0)),1.8);
 float fade=COLOR.a*across;
 vec3 tint=mix(vec3(0.38,0.025,0.78),vec3(0.90,0.56,1.0),across);
 ALBEDO=tint; EMISSION=tint*1.3; ALPHA=fade*0.85;
}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material_override = material
	ghost_shader = Shader.new()
	ghost_shader.code = """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform float opacity = 0.15;
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),2.0);
 vec3 tint=mix(vec3(0.46,0.14,0.78),vec3(0.80,0.52,1.0),rim);
 ALBEDO=tint; EMISSION=tint*0.9; ALPHA=opacity*(0.65+0.35*rim);
}"""
	last_position = actor.global_position
	_create_halo()
	_create_aura()

func _create_halo() -> void:
	for source in actor.get_node("Nael").find_children("*", "MeshInstance3D", true, false):
		if source.skin == null or source.mesh == null: continue
		var skeleton := source.get_node_or_null(source.skeleton)
		if skeleton == null: continue
		halo = MeshInstance3D.new()
		halo.name = "DodgeHalo"
		halo.mesh = source.mesh
		halo.skin = source.skin
		source.add_child(halo)
		halo.skeleton = halo.get_path_to(skeleton)
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shader := Shader.new()
		shader.code = """shader_type spatial;
render_mode unshaded, cull_front, blend_mix, depth_draw_never;
uniform float strength = 0.0;
void vertex(){ VERTEX += NORMAL * 0.32; }
void fragment(){
 float rim=pow(1.0-abs(dot(normalize(NORMAL),normalize(VIEW))),1.4);
 vec3 tint=mix(vec3(0.48,0.03,0.95),vec3(0.91,0.55,1.0),rim);
 ALBEDO=tint; EMISSION=tint*1.2; ALPHA=strength*(0.18+rim*0.6);
}"""
		halo_material = ShaderMaterial.new()
		halo_material.shader = shader
		halo.material_override = halo_material
		halo.hide()
		break

func _create_aura() -> void:
	aura = MeshInstance3D.new()
	aura.name = "DodgeAura"
	var quad := QuadMesh.new()
	quad.size = Vector2(1.4,2.1)
	aura.mesh = quad
	aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shader := Shader.new()
	shader.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float strength = 0.0;
void vertex(){ MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]); }
void fragment(){
 vec2 p=(UV-0.5)*2.0; float r=length(p);
 float soft=exp(-r*r*2.5)*(1.0-smoothstep(0.75,1.0,r));
 vec3 tint=vec3(0.64,0.10,1.0);
 ALBEDO=tint; EMISSION=tint*0.7; ALPHA=soft*strength*0.40;
}"""
	aura_material = ShaderMaterial.new()
	aura_material.shader = shader
	aura.material_override = aura_material
	add_child(aura)
	aura.hide()

func clear_trail() -> void:
	halo_strength = 0.0
	if is_instance_valid(halo): halo.hide()
	if is_instance_valid(aura): aura.hide()
	samples.clear()
	ribbon.clear_surfaces()
	for ghost in ghosts:
		if is_instance_valid(ghost.node): ghost.node.queue_free()
	ghosts.clear()
	ghost_timer = 0.0

func _process(delta: float) -> void:
	if actor.global_position.distance_to(last_position) > 4.0 or actor._is_ui_blocking() or actor.rest_state != "" or (DisplayServer.get_name() != "headless" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED):
		clear_trail()
		last_position = actor.global_position
		return
	last_position = actor.global_position
	for sample in samples: sample.age += delta
	while not samples.is_empty() and samples[0].age >= lifetime: samples.pop_front()
	for i in range(ghosts.size()-1,-1,-1):
		var ghost: Dictionary = ghosts[i]
		ghost.age += delta
		if ghost.age >= ghost_lifetime:
			ghost.node.queue_free()
			ghosts.remove_at(i)
		else:
			ghost.material.set_shader_parameter("opacity", 0.62 * pow(1.0-ghost.age/ghost_lifetime,2.0))
	var moving: bool = actor.dodge.active and Vector2(actor.velocity.x,actor.velocity.z).length() > 2.0
	halo_strength = 1.0 if moving else maxf(0.0, halo_strength - delta * 9.0)
	if is_instance_valid(halo):
		halo.visible = halo_strength > 0.0
		halo_material.set_shader_parameter("strength",halo_strength)
	if is_instance_valid(aura):
		aura.visible = halo_strength > 0.0
		var camera := get_viewport().get_camera_3d()
		var behind := Vector3.ZERO if camera == null else (actor.global_position-camera.global_position).normalized()*0.15
		aura.global_position = actor.global_position + Vector3.UP*0.45 + behind
		aura_material.set_shader_parameter("strength",halo_strength)
	if moving:
		var p := actor.global_position
		if samples.is_empty() or p.distance_to(samples.back().point) > 0.035:
			samples.append({"point":p,"age":0.0,"side":actor.dodge.direction.cross(Vector3.UP).normalized()})
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.025
			_snapshot()
	else:
		ghost_timer = 0.0
	_draw_ribbons()

func _snapshot() -> void:
	if DisplayServer.get_name() == "headless": return
	for source in actor.get_node("Nael").find_children("*", "MeshInstance3D", true, false):
		if source == halo or not source.is_visible_in_tree() or source.mesh == null or source.skin == null: continue
		var baked: ArrayMesh = source.bake_mesh_from_current_skeleton_pose()
		if baked == null: continue
		var ghost := MeshInstance3D.new()
		ghost.mesh = baked
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := ShaderMaterial.new()
		material.shader = ghost_shader
		material.set_shader_parameter("opacity",0.62)
		ghost.material_override = material
		add_child(ghost)
		ghost.global_transform = source.global_transform
		ghosts.append({"node":ghost,"material":material,"age":0.0})

func _vertex(point: Vector3, uv: Vector2, alpha: float) -> void:
	ribbon.surface_set_color(Color(1,1,1,alpha))
	ribbon.surface_set_uv(uv)
	ribbon.surface_add_vertex(point)

func _draw_ribbons() -> void:
	ribbon.clear_surfaces()
	if samples.size() < 2: return
	ribbon.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for band in [Vector3(0.15,-0.20,0.14), Vector3(0.62,0.0,0.27), Vector3(1.0,0.17,0.18)]:
		for i in range(samples.size()-1):
			var a: Dictionary = samples[i]
			var b: Dictionary = samples[i+1]
			var fa: float = pow(maxf(0.0,1.0-a.age/lifetime),1.5)
			var fb: float = pow(maxf(0.0,1.0-b.age/lifetime),1.5)
			var pa: Vector3 = a.point + Vector3.UP*band.x + a.side*band.y
			var pb: Vector3 = b.point + Vector3.UP*band.x + b.side*band.y
			var wa: Vector3 = Vector3.UP*band.z*fa
			var wb: Vector3 = Vector3.UP*band.z*fb
			_vertex(pa-wa,Vector2(0,0),fa);_vertex(pb-wb,Vector2(1,0),fb);_vertex(pb+wb,Vector2(1,1),fb)
			_vertex(pa-wa,Vector2(0,0),fa);_vertex(pb+wb,Vector2(1,1),fb);_vertex(pa+wa,Vector2(0,1),fa)
	ribbon.surface_end()
