@tool
extends RefCounted
## Material-only detail on existing flat-colour bark and natural rocks.
## Source GLBs, mesh data, transforms, visibility and physics are never modified.
const DETAIL := preload("res://shaders/natural_surface_detail.gdshader")

static func apply(world: Node) -> void:
	var cache := {}
	for mesh: MeshInstance3D in world.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null or mesh.material_override != null: continue
		for surface in range(mesh.mesh.get_surface_count()):
			var source := mesh.get_active_material(surface) as StandardMaterial3D
			if source == null or source.albedo_texture != null: continue
			if source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED: continue
			var name := source.resource_name.to_lower()
			var node_name := str(mesh.name).to_lower()
			var kind := -1
			if "écorce" in name or "ecorce" in name or "bark" in name or name == "mat_tronc":
				kind = 0
			elif "rock" in node_name or "roche" in node_name or "schiste" in node_name:
				if "schiste" in name or name.begins_with("oasis") or name == "mat_roche": kind = 1
				elif name.begins_with("mousse velours"): kind = 2
			if kind < 0: continue
			var key := source.get_instance_id()
			if not cache.has(key):
				var detail := ShaderMaterial.new()
				detail.shader = DETAIL
				detail.resource_name = source.resource_name + " — grain procédural"
				detail.set_shader_parameter("base_color", source.albedo_color)
				detail.set_shader_parameter("base_roughness", source.roughness)
				detail.set_shader_parameter("base_specular", source.metallic_specular)
				detail.set_shader_parameter("use_vertex_color", source.vertex_color_use_as_albedo)
				detail.set_shader_parameter("detail_kind", kind)
				cache[key] = detail
			mesh.set_surface_override_material(surface, cache[key])
