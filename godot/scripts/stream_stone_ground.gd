@tool
extends RefCounted
## Rasterize the actual stream footprint once for all shared ground materials.
static func apply(scene: Node) -> void:
	var cached = scene.get_meta("stream_stone_mask", {})
	if cached is Dictionary and cached.get("texture") is Texture2D:
		_bind_materials(scene, cached.texture, cached.rect)
		return
	var triangles: Array = []
	var low := Vector2(INF, INF)
	var high := Vector2(-INF, -INF)
	for water: MeshInstance3D in scene.find_children("Water", "MeshInstance3D", true, false):
		if water.mesh == null:
			continue
		var faces := water.mesh.get_faces()
		for i in range(0, faces.size(), 3):
			var tri: Array[Vector3] = []
			for j in 3:
				var p: Vector3 = water.global_transform * faces[i + j]
				tri.append(p)
				low = low.min(Vector2(p.x, p.z))
				high = high.max(Vector2(p.x, p.z))
			triangles.append(tri)
	if triangles.is_empty():
		return
	low -= Vector2(4, 4)
	high += Vector2(4, 4)
	var extent := high - low
	var resolution := Vector2i(ceili(extent.x / 0.18), ceili(extent.y / 0.18)).clamp(Vector2i(8, 8), Vector2i(2048, 2048))
	var image := Image.create(resolution.x, resolution.y, false, Image.FORMAT_RGF)
	for tri in triangles:
		var a := Vector2(tri[0].x, tri[0].z)
		var b := Vector2(tri[1].x, tri[1].z)
		var c := Vector2(tri[2].x, tri[2].z)
		var denominator: float = (b.y-c.y)*(a.x-c.x)+(c.x-b.x)*(a.y-c.y)
		if absf(denominator) < 0.000001:
			continue
		var start := Vector2i(((a.min(b).min(c)-low)/extent*Vector2(resolution)).floor()).max(Vector2i.ZERO)
		var end := Vector2i(((a.max(b).max(c)-low)/extent*Vector2(resolution)).ceil()).min(resolution-Vector2i.ONE)
		for y in range(start.y, end.y+1):
			for x in range(start.x, end.x+1):
				var p := low+(Vector2(x,y)+Vector2(0.5,0.5))/Vector2(resolution)*extent
				var u := ((b.y-c.y)*(p.x-c.x)+(c.x-b.x)*(p.y-c.y))/denominator
				var v := ((c.y-a.y)*(p.x-c.x)+(a.x-c.x)*(p.y-c.y))/denominator
				if u >= 0.0 and v >= 0.0 and u+v <= 1.0:
					image.set_pixel(x,y,Color(1.0,u*tri[0].y+v*tri[1].y+(1.0-u-v)*tri[2].y,0,1))
	var texture := ImageTexture.create_from_image(image)
	var rect := Vector4(low.x, low.y, extent.x, extent.y)
	scene.set_meta("stream_stone_mask", {"texture": texture, "rect": rect})
	_bind_materials(scene, texture, rect)

static func _bind_materials(scene: Node, texture: Texture2D, rect: Vector4) -> void:
	# Rebind cached coverage whenever editor reloads replace the ground materials.
	var ground: ShaderMaterial
	for terrain: MeshInstance3D in scene.find_children("Terrain*", "MeshInstance3D", true, false):
		if terrain.material_override is ShaderMaterial:
			ground = terrain.material_override
			break
	if ground != null:
		for seal: MeshInstance3D in scene.find_children("BankSeal", "MeshInstance3D", true, false):
			if str(seal.get_parent().name) == "Water":
				seal.material_override = ground
	for mesh: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.material_override as ShaderMaterial
		if material == null or material.shader == null:
			continue
		if material.shader.resource_path in ["res://shaders/ground.gdshader", "res://shaders/world_ground.gdshader"]:
			material.set_shader_parameter("stream_footprint", texture)
			material.set_shader_parameter("stream_rect", rect)
			material.set_shader_parameter("stream_stones_enabled", true)
