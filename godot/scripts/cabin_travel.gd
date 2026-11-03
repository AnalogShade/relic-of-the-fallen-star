extends Node
## Keep the forest instance intact while visiting the independent cabin scene.
var busy := false
var inside := false
var parked_world: Node
var parked_parent: Node
var room: Node3D
var was_current_scene := false
var outside_player: CharacterBody3D
var overlay: ColorRect
var interior_stack: Array[Node3D] = []
var confirmation_open := false

# A second interior must not overwrite the parked forest or its player.
func enter_subroom(path: String) -> void:
	if busy: return
	var origin := room if is_instance_valid(room) else get_tree().current_scene as Node3D
	if not origin: return
	var packed := load(path) as PackedScene
	if not packed: return
	busy = true
	var actor := origin.get_node("Player") as CharacterBody3D
	actor.velocity = Vector3.ZERO
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	await fade(1.0)
	var parent := origin.get_parent()
	parent.remove_child(origin)
	interior_stack.append(origin)
	room = packed.instantiate()
	parent.add_child(room)
	get_tree().current_scene = room
	var next_player := room.get_node("Player") as CharacterBody3D
	next_player.health = actor.health
	next_player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	await fade(0.0)
	next_player.process_mode = Node.PROCESS_MODE_INHERIT
	busy = false

func leave_subroom() -> void:
	if busy: return
	busy = true
	var current := room if is_instance_valid(room) else get_tree().current_scene as Node3D
	var actor := current.get_node("Player") as CharacterBody3D
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	await fade(1.0)
	var parent := current.get_parent()
	parent.remove_child(current)
	room = interior_stack.pop_back() if not interior_stack.is_empty() else load("res://scenes/interiors/cave_room.tscn").instantiate()
	parent.add_child(room)
	get_tree().current_scene = room
	var restored := room.get_node("Player") as CharacterBody3D
	restored.position = Vector3(0, 0.5, -10.0)
	restored.velocity = Vector3.ZERO
	restored.health = actor.health
	restored.pivot.rotation.y = PI
	restored.process_mode = Node.PROCESS_MODE_DISABLED
	restored.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
	current.queue_free()
	await get_tree().process_frame
	await fade(0.0)
	restored.process_mode = Node.PROCESS_MODE_INHERIT
	busy = false

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	overlay = ColorRect.new()
	overlay.color = Color(0.025, 0.018, 0.012, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", alpha, 0.28)
	await tween.finished

func enter_cabin(portal: Node3D, interior_path := "res://scenes/interiors/cabin_room.tscn") -> void:
	if busy or inside: return
	busy = true
	outside_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if not outside_player:
		busy = false
		return
	parked_world = portal
	while parked_world and parked_world.get_parent() and parked_world.get_parent() != get_tree().root:
		parked_world = parked_world.get_parent()
	if not parked_world or parked_world == get_tree().root:
		parked_world = get_tree().current_scene
	if not parked_world:
		busy = false
		return
	outside_player.velocity = Vector3.ZERO
	outside_player.process_mode = Node.PROCESS_MODE_DISABLED
	var door := portal.get_parent().get_node_or_null("CabinDoorArt") as Node3D
	if door: create_tween().tween_property(door, "rotation:y", float(door.get_meta("open_angle", 0.35)), 0.24)
	await fade(1.0)
	if door: door.rotation.y = 0.0
	parked_parent = parked_world.get_parent()
	was_current_scene = get_tree().current_scene == parked_world
	parked_parent.remove_child(parked_world)
	room = load(interior_path).instantiate()
	parked_parent.add_child(room)
	if was_current_scene: get_tree().current_scene = room
	inside = true
	var player := room.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_DISABLED
	await get_tree().process_frame
	await fade(0.0)
	player.process_mode = Node.PROCESS_MODE_INHERIT
	busy = false

func leave_cabin() -> void:
	if not interior_stack.is_empty():
		leave_subroom()
		return
	if busy: return
	busy = true
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player: player.process_mode = Node.PROCESS_MODE_DISABLED
	var door := player.get_parent().get_node_or_null("CabinDoorArt") as Node3D if player else null
	if door: create_tween().tween_property(door, "rotation:y", -0.35, 0.24)
	await fade(1.0)
	if is_instance_valid(parked_world):
		var old_room := room
		room.get_parent().remove_child(room)
		parked_parent.add_child(parked_world)
		if was_current_scene: get_tree().current_scene = parked_world
		outside_player.velocity = Vector3.ZERO
		outside_player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
		old_room.queue_free()
		room = null
		parked_world = null
		inside = false
		await get_tree().process_frame
		await fade(0.0)
		outside_player.process_mode = Node.PROCESS_MODE_INHERIT
	else:
		# Also support launching the room directly with F6 during editing.
		var fallback_scene: String = ProjectSettings.get_setting("application/run/main_scene", "res://scenes/world/open_world.tscn")
		get_tree().change_scene_to_file(fallback_scene)
		inside = false
		await get_tree().process_frame
		await fade(0.0)
	busy = false

func _exit_tree() -> void:
	for interior in interior_stack:
		if is_instance_valid(interior) and not interior.is_inside_tree(): interior.free()
	if is_instance_valid(parked_world) and not parked_world.is_inside_tree():
		parked_world.free()
