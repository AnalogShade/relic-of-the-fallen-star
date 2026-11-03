extends MeshInstance3D

func _ready() -> void:
	add_to_group("interactable")

func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player: return false
	if player.rest_state != "":
		return player.rest_controller.seat == self and player.rest_state == "seated"
	return not player.swimming and not player.is_attacking and player.is_on_floor() and player.global_position.distance_to(global_position) < 2.3

func interaction_text() -> String:
	var player := get_tree().get_first_node_in_group("player")
	return "Se relever" if player and player.rest_state == "seated" else "S’asseoir près du feu · +1 PV / 5 s"

func interact() -> void:
	if not can_interact(): return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player.rest_state == "seated":
		player.rest_controller.stand()
		return
	var fire := get_parent().get_node("Flammes_Animees") as Node3D
	var facing := (fire.global_position - global_position).normalized()
	facing.y = 0.0
	facing = facing.normalized()
	var surface := seat_surface()
	# The underside of the authored seated hips is 5 cm above the player origin.
	# This includes Naël's model offset and the thickness of his seated body.
	player.rest_controller.begin(self, surface - Vector3.UP * 0.05, facing)

func footprint() -> Rect2:
	var bounds := get_aabb()
	var points: Array[Vector2] = []
	for i in range(8):
		var p := to_global(bounds.get_endpoint(i))
		points.append(Vector2(p.x, p.z))
	var rect := Rect2(points[0], Vector2.ZERO)
	for p in points: rect = rect.expand(p)
	return rect

func seat_surface() -> Vector3:
	# Intersect the rendered triangles, rather than the oversized collision proxy.
	var center := to_global(get_aabb().get_center())
	var top := center + Vector3.UP * 3.0
	var bottom := center - Vector3.UP * 3.0
	var highest := -INF
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var count := indices.size() if not indices.is_empty() else vertices.size()
		for i in range(0, count - 2, 3):
			var a := indices[i] if not indices.is_empty() else i
			var b := indices[i + 1] if not indices.is_empty() else i + 1
			var c := indices[i + 2] if not indices.is_empty() else i + 2
			var hit = Geometry3D.segment_intersects_triangle(top, bottom, to_global(vertices[a]), to_global(vertices[b]), to_global(vertices[c]))
			if hit != null: highest = maxf(highest, hit.y)
	assert(is_finite(highest), "No visible bench surface under seat")
	return Vector3(center.x, highest, center.z)
