extends Node3D
## Cheap collision proxies: flat convex slabs, five wedges, cylinders and edge boxes.
const LAYOUT := "res://assets/environment/cave_depths/layout.json"
const DETAILS := "res://assets/environment/cave_depths/details.json"
@export var enable_enemies: bool = true
var walk_outline := PackedVector2Array()
var edge_segments: Array[PackedVector2Array] = []
var floor_body: StaticBody3D
var edge_body: StaticBody3D
var ramp_polygons: Array[PackedVector2Array] = []

func _ready() -> void:
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LAYOUT))
	var details: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DETAILS))
	floor_body = _body("SimpleFloors", 1)
	edge_body = _body("InvisibleEdges", 4)
	_build_floors(layout)
	_build_edges()
	_build_obstacles(details)
	_build_lighting(details)
	var atmosphere := preload("res://scripts/cave_depths_atmosphere.gd").new()
	add_child(atmosphere)
	atmosphere.build(layout)
	var chest := preload("res://scripts/echo_chest.gd").new()
	chest.name = "EchoChest"
	chest.position = Vector3(11, -6.97, 35.5)
	chest.rotation.y = PI
	add_child(chest)
	var return_halo := preload("res://scripts/relic_return_halo.gd").new()
	return_halo.name = "RelicReturnHalo"
	return_halo.position = Vector3(7.0, -6.94, 35.5)
	add_child(return_halo)
	var portal := preload("res://scripts/cave_depths_portal.gd").new()
	portal.name = "EntranceReturn"
	portal.returning = true
	portal.position = Vector3(27, 9, -40)
	add_child(portal)
	_build_return_marker()
	if enable_enemies and not _is_geometry_test():
		_build_golems()
	var player := $Player
	player.pivot.rotation.y = PI - 0.7
	player.get_node("Nael").rotation.y = player.pivot.rotation.y + PI
	player.arm.spring_length = 6.5
	player.arm.rotation.x = -0.40
	player.arm.collision_mask = 1
	player.get_node("CameraPivot/SpringArm3D/Camera3D").far = 180.0
	player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()

func _body(label: String, layer: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = layer
	body.collision_mask = 0
	add_child(body)
	return body

func _shape(body: StaticBody3D, shape: Shape3D, p := Vector3.ZERO) -> CollisionShape3D:
	var node := CollisionShape3D.new()
	node.shape = shape
	node.position = p
	body.add_child(node)
	return node

func _point(a: Array) -> Vector2:
	return Vector2(float(a[0]), -float(a[1]))

func _merge_outline(polygon: PackedVector2Array) -> void:
	if walk_outline.is_empty():
		walk_outline = polygon
		return
	var merged := Geometry2D.merge_polygons(walk_outline, polygon)
	assert(merged.size() == 1, "Cave floor outline must remain connected")
	walk_outline = merged[0]

func _prism(polygon: PackedVector2Array, height: float) -> void:
	for convex in Geometry2D.decompose_polygon_in_convex(polygon):
		var points := PackedVector3Array()
		for p in convex:
			points.append(Vector3(p.x, height, p.y))
			points.append(Vector3(p.x, height - 0.65, p.y))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		_shape(floor_body, shape)

func _build_floors(layout: Dictionary) -> void:
	var rooms: Array = layout.rooms
	var ramps: Array = layout.ramps
	for i in ramps.size():
		var data: Dictionary = ramps[i]
		var a := _point(data.start)
		var b := _point(data.end)
		var side := (b - a).normalized().orthogonal() * (float(data.width_m) * 0.5 - 0.22)
		var polygon := PackedVector2Array([a-side, a+side, b+side, b-side])
		if Geometry2D.is_polygon_clockwise(polygon): polygon.reverse()
		ramp_polygons.append(polygon)
		var points := PackedVector3Array()
		for p in polygon:
			var t := (p-a).dot(b-a) / a.distance_squared_to(b)
			var h := lerpf(float(rooms[i][3]), float(rooms[i+1][3]), t)
			# Tiny overlap avoids floating-point cracks at the clipped upper slab.
			if t < .001: p -= (b-a).normalized() * .05
			points.append(Vector3(p.x, h, p.y))
			points.append(Vector3(p.x, h-0.7, p.y))
		var wedge := ConvexPolygonShape3D.new()
		wedge.points = points
		_shape(floor_body, wedge)
	for i in rooms.size():
		var r: Array = rooms[i]
		var polygon := PackedVector2Array()
		for j in 20:
			var angle := TAU * j / 20.0
			polygon.append(Vector2(float(r[1])+cos(angle)*float(r[4])*.86, -float(r[2])+sin(angle)*float(r[5])*.86))
		# Carve the outgoing ramp overlap out of the upper slab to prevent a step.
		var floors: Array[PackedVector2Array] = [polygon]
		if i < ramps.size():
			floors = Geometry2D.clip_polygons(polygon, ramp_polygons[i])
		for piece in floors: _prism(piece, float(r[3]))
		if i > 0: _merge_outline(ramp_polygons[i-1])
		_merge_outline(polygon)

func _build_edges() -> void:
	# Continuous union perimeter: no wall across a landing or internal ramp seam.
	for i in walk_outline.size():
		var a := walk_outline[i]
		var b := walk_outline[(i+1) % walk_outline.size()]
		var d := b-a
		if d.length() < .01: continue
		var box := BoxShape3D.new()
		box.size = Vector3(.30, 45, d.length()+.30)
		var wall := _shape(edge_body, box, Vector3((a.x+b.x)*.5, 7, (a.y+b.y)*.5))
		wall.rotation.y = atan2(d.x, d.y)
		edge_segments.append(PackedVector2Array([a,b]))

func _build_obstacles(details: Dictionary) -> void:
	var body := _body("SimpleRockCollisions", 1)
	for item in details.obstacles:
		var p := Vector3(float(item.position[0]), float(item.position[1]), float(item.position[2]))
		if not Geometry2D.is_point_in_polygon(Vector2(p.x,p.z), walk_outline): continue
		var cylinder := CylinderShape3D.new()
		cylinder.radius = maxf(.2, float(item.radius))
		cylinder.height = maxf(.5, float(item.height))
		_shape(body, cylinder, p+Vector3.UP*cylinder.height*.5)

func _build_lighting(details: Dictionary) -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("03070b")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("819bad")
	env.ambient_light_energy = .48
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-58,-30,0)
	key.light_color = Color("9ab5c9")
	key.light_energy = .65
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 95
	add_child(key)
	for item in details.lights:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(item.position[0],item.position[1],item.position[2])
		lamp.light_color = Color("ffb469") if item.warm else Color("72cced")
		lamp.light_energy = 1.35 if item.warm else 1.0
		lamp.omni_range = 7.0
		lamp.shadow_enabled = false
		lamp.distance_fade_enabled = true
		lamp.distance_fade_begin = 30
		lamp.distance_fade_length = 12
		add_child(lamp)

func _build_return_marker() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("243944")
	for p in [Vector3(25.5,9.5,-40),Vector3(28.5,9.5,-40),Vector3(27,11.1,-40)]:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(3.6,.6,.8) if p.x==27 else Vector3(.6,3,.8)
		mesh.mesh = box
		mesh.material_override = stone
		mesh.position = p
		add_child(mesh)
	var label := Label3D.new()
	label.text = "SALLE D’ENTRÉE"
	label.position = Vector3(27,11.8,-40)
	label.font_size = 40
	label.pixel_size = .007
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)

func _build_golems() -> void:
	var golem_scene: PackedScene = preload("res://scenes/golem.tscn")
	var container := Node3D.new()
	container.name = "Golems"
	add_child(container)

	var golem_defs: Array[Dictionary] = [
		# Salle 1 - Seuil (Y=8.0)
		{
			"name": "Golem_Seuil_1",
			"type": "petit",
			"pos": Vector3(23.5, 8.0, -32.0),
			"patrol": [Vector3(23.5, 8.0, -32.0), Vector3(25.5, 8.0, -30.0), Vector3(22.0, 7.8, -28.0)]
		},
		# Salle 2 - Balcon (Y=5.0)
		{
			"name": "Golem_Balcon_1",
			"type": "standard",
			"pos": Vector3(16.5, 5.0, -22.5),
			"patrol": [Vector3(16.5, 5.0, -22.5), Vector3(14.0, 5.0, -24.5), Vector3(16.0, 5.0, -20.5)]
		},
		{
			"name": "Golem_Balcon_2",
			"type": "petit",
			"pos": Vector3(10.5, 5.0, -17.5),
			"patrol": [Vector3(10.5, 5.0, -17.5), Vector3(12.5, 5.0, -15.5), Vector3(9.5, 4.8, -14.0)]
		},
		# Salle 3 - Cathedrale (Y=1.0)
		{
			"name": "Grand_Golem_Cathedrale",
			"type": "grand",
			"pos": Vector3(3.0, 1.0, 0.0),
			"patrol": [Vector3(3.0, 1.0, 0.0), Vector3(4.5, 1.0, 3.5), Vector3(1.0, 1.0, 4.0), Vector3(0.0, 1.0, -1.5)]
		},
		{
			"name": "Golem_Cathedrale_2",
			"type": "standard",
			"pos": Vector3(-5.5, 1.0, -1.0),
			"patrol": [Vector3(-5.5, 1.0, -1.0), Vector3(-7.5, 1.0, 1.5), Vector3(-4.0, 1.0, 3.5)]
		},
		{
			"name": "Golem_Cathedrale_3",
			"type": "petit",
			"pos": Vector3(-8.5, 1.0, 4.5),
			"patrol": [Vector3(-8.5, 1.0, 4.5), Vector3(-10.5, 1.0, 2.5), Vector3(-7.0, 1.0, 5.5)]
		},
		# Salle 4 - Eboulis (Y=-2.0)
		{
			"name": "Golem_Eboulis_1",
			"type": "standard",
			"pos": Vector3(-23.5, -2.0, 6.0),
			"patrol": [Vector3(-23.5, -2.0, 6.0), Vector3(-27.0, -2.0, 6.5), Vector3(-25.0, -2.0, 9.5)]
		},
		{
			"name": "Golem_Eboulis_2",
			"type": "petit",
			"pos": Vector3(-24.5, -2.0, 11.5),
			"patrol": [Vector3(-24.5, -2.0, 11.5), Vector3(-22.5, -2.5, 14.0), Vector3(-26.0, -2.0, 10.0)]
		},
		# Salle 5 - Vasques (Y=-5.0)
		{
			"name": "Golem_Vasques_1",
			"type": "standard",
			"pos": Vector3(-17.5, -5.0, 26.5),
			"patrol": [Vector3(-17.5, -5.0, 26.5), Vector3(-21.0, -5.0, 28.5), Vector3(-17.0, -5.0, 31.0)]
		},
		{
			"name": "Golem_Vasques_2",
			"type": "petit",
			"pos": Vector3(-14.5, -5.0, 29.5),
			"patrol": [Vector3(-14.5, -5.0, 29.5), Vector3(-12.0, -5.2, 31.0), Vector3(-15.5, -5.0, 27.5)]
		},
		# Salle 6 - Salle profonde / Coffre (Y=-7.0)
		{
			"name": "Grand_Golem_Gardien",
			"type": "grand",
			"pos": Vector3(8.5, -7.0, 34.0),
			"patrol": [Vector3(8.5, -7.0, 34.0), Vector3(12.5, -7.0, 32.5), Vector3(10.0, -7.0, 36.5), Vector3(6.5, -7.0, 34.0)]
		},
		{
			"name": "Golem_Gardien_2",
			"type": "standard",
			"pos": Vector3(4.5, -7.0, 30.5),
			"patrol": [Vector3(4.5, -7.0, 30.5), Vector3(6.5, -7.0, 28.5), Vector3(3.5, -7.0, 33.5)]
		}
	]

	for data in golem_defs:
		var golem: CharacterBody3D = golem_scene.instantiate()
		golem.name = data.name
		golem.golem_type = data.type
		var pts: Array[Vector3] = []
		for p in data.patrol:
			pts.append(p)
		golem.patrol_points = pts
		golem.position = data.pos
		container.add_child(golem)

func _is_geometry_test() -> bool:
	var r := get_tree().root
	return r != null and (r.has_node("DepthsValidation") or r.has_node("CaveValidation"))
