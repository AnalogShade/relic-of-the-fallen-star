@tool
extends RefCounted
## Shared source meshes + independent placement data. No meshes baked into the layout.
const DIRECTORY = "res://assets/environment/stream_grass_trial/"

static func apply(world: Node3D) -> void:
	if world.has_meta("disable_stream_grass_trial") or world.has_node("StreamGrassTrial"):
		return
	if not FileAccess.file_exists(DIRECTORY+"layout.json"):
		return
	var settings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"settings.json"))
	if not settings.enabled:
		return
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"catalog.json"))
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY+"layout.json"))
	var layer := Node3D.new()
	layer.name = "StreamGrassTrial"
	world.add_child(layer)
	for entry in catalog.variants:
		var placements: Array = layout.placements.get(entry.id, [])
		if placements.is_empty():
			continue
		var scene: PackedScene = load(entry.file)
		var source: Node3D = scene.instantiate()
		var meshes := source.find_children("*", "MeshInstance3D", true, false)
		if source is MeshInstance3D:
			meshes.push_front(source)
		# The named source avoids any unrelated exporter extension meshes.
		var source_mesh: MeshInstance3D = null
		for candidate in meshes:
			if str(candidate.name).begins_with("GrassSource"):
				source_mesh = candidate
				break
		if source_mesh == null:
			push_error("GrassSource missing from "+str(entry.file))
			source.free()
			continue
		var mesh: Mesh = source_mesh.mesh
		var height := mesh.get_aabb().size.y
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = placements.size()
		var node := MultiMeshInstance3D.new()
		node.name = entry.id
		node.multimesh = mm
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 65.0
		node.visibility_range_end_margin = 8.0
		# Materials are shared by all instances of this model; atlas controls come
		# from the source Blender material and are refreshed by the exporter.
		if entry.photo != null:
			var imported := mesh.surface_get_material(0) as StandardMaterial3D
			var material := ShaderMaterial.new()
			material.shader = load("res://shaders/grass_natural.gdshader")
			material.set_shader_parameter("blade_atlas", imported.albedo_texture)
			material.set_shader_parameter("saturation", entry.photo.saturation)
			material.set_shader_parameter("brightness", entry.photo.brightness)
			node.material_override = material
		else:
			var material := mesh.surface_get_material(0).duplicate() as StandardMaterial3D
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			node.material_override = material
		for i in placements.size():
			var p: Array = placements[i]
			var normal := Vector3(p[3],p[4],p[5]).normalized()
			var basis := Basis(Quaternion(Vector3.UP,normal))*Basis(Vector3.UP,float(p[6]))
			basis = basis.scaled(Vector3.ONE*float(p[7])/maxf(height,.001))
			mm.set_instance_transform(i,Transform3D(basis,Vector3(p[0],p[1]-.008,p[2])))
		layer.add_child(node)
		source.free()
	var r: Array = layout.rect
	var rect := Rect2(r[0],r[1],r[2],r[3])
	var old := world.get_node_or_null("HerbesDetaillees")
	var removed := 0
	if old != null:
		for node: MultiMeshInstance3D in old.find_children("*","MultiMeshInstance3D",true,false):
			var original := node.multimesh
			var keep: Array[int] = []
			for i in original.instance_count:
				var p := node.global_transform*original.get_instance_transform(i).origin
				if not rect.has_point(Vector2(p.x,p.z)):
					keep.append(i)
			if keep.size() == original.instance_count:
				continue
			var clean := MultiMesh.new()
			clean.transform_format = original.transform_format
			clean.mesh = original.mesh
			clean.instance_count = keep.size()
			for i in keep.size():
				clean.set_instance_transform(i,original.get_instance_transform(keep[i]))
			node.set_meta("stream_trial_original",original)
			node.set_meta("stream_trial_filtered",clean)
			node.multimesh = clean
			removed += original.instance_count-keep.size()
	layer.set_meta("legacy_replaced",removed)
	layer.set_meta("total",layout.total)
	print("STREAM_GRASS_TRIAL instances=",layout.total," variants=",layer.get_child_count()," legacy_replaced=",removed)

static func set_enabled(world: Node3D, enabled: bool) -> void:
	var layer := world.get_node_or_null("StreamGrassTrial")
	if layer == null:
		return
	layer.visible = enabled
	for node: MultiMeshInstance3D in world.get_node("HerbesDetaillees").find_children("*","MultiMeshInstance3D",true,false):
		if node.has_meta("stream_trial_original"):
			node.multimesh = node.get_meta("stream_trial_filtered" if enabled else "stream_trial_original")
