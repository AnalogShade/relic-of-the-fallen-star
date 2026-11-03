extends Node3D
## Fishing at the original stream and the northern reservoir's actual water meshes.
var water_points := PackedVector3Array()
var cast_position := Vector3.ZERO
var state := "idle"
var remaining := 0.0
var cooldown := 0.0
var bobber: MeshInstance3D
var line: MeshInstance3D
var bag: Node

func _ready() -> void:
	bag = get_node("/root/Inventory")
	var water := get_parent().get_node("Original").find_child("Water", true, false) as MeshInstance3D
	if not water: return
	for surface in range(water.mesh.get_surface_count()):
		var vertices: PackedVector3Array = water.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for vertex in vertices: water_points.append(water.global_transform * vertex)
	var oasis := get_parent().get_node_or_null("Sectors/OasisDuNord")
	if oasis:
		var seen := {}
		for lake in oasis.find_children("Water_Oasis_Reservoir*", "MeshInstance3D", true, false):
			for surface in range(lake.mesh.get_surface_count()):
				var vertices: PackedVector3Array = lake.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
				for vertex in vertices:
					var point: Vector3 = lake.global_transform * vertex
					var key := Vector3i(roundi(point.x * 2.0), roundi(point.y * 2.0), roundi(point.z * 2.0))
					if not seen.has(key):
						seen[key] = true
						water_points.append(point)
	add_to_group("interactable")
	bobber = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.065
	sphere.height = 0.16
	bobber.mesh = sphere
	var red := StandardMaterial3D.new()
	red.albedo_color = Color("d38754")
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bobber.material_override = red
	add_child(bobber)
	line = MeshInstance3D.new()
	var thread := StandardMaterial3D.new()
	thread.albedo_color = Color("e3d7b7")
	thread.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = thread
	add_child(line)
	bobber.hide()
	line.hide()

func can_interact() -> bool:
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player or not player.is_on_floor() or bag.equipped != "fishing_rod" or cooldown > 0.0: return false
	if state != "idle": return true
	var closest := Vector3.ZERO
	var distance := INF
	for point in water_points:
		var d := player.global_position.distance_squared_to(point)
		if d < distance and d < 3.5 * 3.5:
			var sight := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 0.6, point + Vector3.UP * 0.1, 1)
			if not get_world_3d().direct_space_state.intersect_ray(sight).is_empty(): continue
			distance = d
			closest = point
	if distance == INF or player.global_position.y < closest.y: return false
	global_position = closest + Vector3.UP * 0.06
	return true

func interaction_text() -> String:
	if state == "bite": return "Ça mord ! Ferrer !"
	if state == "waiting": return "Patienter… / Annuler la pêche"
	return "Pêcher dans l’oasis" if global_position.z < -168.0 else "Pêcher dans le ruisseau"

func interact() -> void:
	if not can_interact(): return
	if state == "bite":
		if bag.add_item("trout"):
			bag.ui.notify("+ 1  Truite du ruisseau")
		else:
			bag.ui.notify("Inventaire plein — le poisson est relâché")
		cancel()
	elif state == "waiting": cancel()
	else:
		state = "waiting"
		remaining = randf_range(2.5, 5.0)
		cast_position = get_tree().get_first_node_in_group("player").global_position
		bobber.show()
		line.show()

func cancel() -> void:
	state = "idle"
	cooldown = 0.6
	bobber.hide()
	line.hide()

func _physics_process(delta: float) -> void:
	cooldown = maxf(0.0, cooldown - delta)
	if state == "idle": return
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not player or bag.is_open or bag.equipped != "fishing_rod" or player.global_position.distance_to(cast_position) > 0.6:
		cancel()
		return
	remaining -= delta
	bobber.position.y = sin(Time.get_ticks_msec() * (0.025 if state == "bite" else 0.004)) * 0.045
	var held: Node3D = player.get_node("HeldEquipment").rod
	if is_instance_valid(held):
		var thread := ImmediateMesh.new()
		thread.surface_begin(Mesh.PRIMITIVE_LINES)
		thread.surface_add_vertex(to_local(held.to_global(Vector3(0.08, 2.05, 0))))
		thread.surface_add_vertex(bobber.position)
		thread.surface_end()
		line.mesh = thread
	if remaining <= 0.0:
		if state == "waiting":
			state = "bite"
			remaining = 2.0
			bag.ui.notify("Ça mord ! Appuyez sur F")
		else:
			bag.ui.notify("Le poisson s’est échappé")
			cancel()
