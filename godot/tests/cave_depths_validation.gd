extends Node3D
var failures: Array[String] = []
var checks := 0
var travel: Node
var bag: Node

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func frames(n: int) -> void:
	for i in n: await get_tree().physics_frame

func settled() -> void:
	for i in 300:
		await frames(1)
		if not travel.busy: return
	check(false, "transition timeout")

func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/depths_"+label+".png")

func _ready() -> void:
	travel = get_node("/root/CabinTravel")
	bag = get_node("/root/Inventory")
	var lobby: Node3D = load("res://scenes/interiors/cave_room.tscn").instantiate()
	get_tree().root.call_deferred("add_child", lobby)
	await frames(20)
	get_tree().current_scene = lobby
	check(lobby.get_node_or_null("EchoChest")==null, "old entrance room contains no chest")
	var old_walls := lobby.get_node("Architecture").find_children("*Fond*", "MeshInstance3D", true, false)
	check(old_walls.size()>0 and not old_walls[0].visible, "original rear wall replaced by opening")
	var actor: CharacterBody3D = lobby.get_node("Player")
	actor.position = Vector3(0,.5,-10.7)
	actor.velocity = Vector3.ZERO
	await frames(4)
	var portal := lobby.get_node("DepthsPortal")
	check(portal.dialog.visible and travel.confirmation_open, "proximity asks permission to enter")
	await capture("entrance_confirmation")
	portal._cancel()
	await frames(5)
	check(not travel.busy and not portal.dialog.visible, "cancel restores play without repeat prompt")
	actor.health = 72
	portal.interact()
	portal._confirm()
	await frames(2)
	await settled()
	var cave: Node3D = travel.room
	check(cave!=null and cave.name=="CaveDepths", "confirm enters new model")
	if cave==null: finish(); return
	actor = cave.get_node("Player")
	await frames(30)
	check(actor.is_on_floor(), "new entrance spawn grounded")
	check(actor.health==72, "health preserved across interior transition")
	check(not lobby.is_inside_tree() and travel.interior_stack.size()==1, "entrance room parked intact")
	await capture("spawn")
	# Slabs/wedges/cylinders/boxes only: never the detailed mesh as trimesh.
	var shapes := cave.find_children("*", "CollisionShape3D", true, false)
	var expensive := 0
	for shape in shapes:
		if shape.shape is ConcavePolygonShape3D: expensive += 1
	check(expensive==0, "no complex concave mesh colliders")
	print("COLLIDERS ", shapes.size(), " perimeter segments ", cave.edge_segments.size())
	var space := cave.get_world_3d().direct_space_state
	var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/environment/cave_depths/layout.json"))
	var ramp_gaps := 0
	var blocked := 0
	for i in layout.ramps.size():
		var r: Dictionary = layout.ramps[i]
		var a := Vector2(r.start[0],-r.start[1]);var b := Vector2(r.end[0],-r.end[1])
		var side := (b-a).normalized().orthogonal()
		for j in 31:
			var t := j/30.0
			for offset in [-1.3,0.0,1.3]:
				var p: Vector2 = a.lerp(b,t)+side*float(offset)
				var h := lerpf(layout.rooms[i][3],layout.rooms[i+1][3],t)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,h+1,p.y),Vector3(p.x,h-1,p.y),1))
				if hit.is_empty() or absf(hit.position.y-h)>.16:
					ramp_gaps+=1
					if ramp_gaps<12: print("RAMP SAMPLE ",i," t=",t," offset=",offset," expected=",h," hit=",hit)
		# A capsule sweep along each full ramp catches walls mistakenly spanning joins.
		var start := Vector3(a.x,float(layout.rooms[i][3])+.46,a.y)
		var end := Vector3(b.x,float(layout.rooms[i+1][3])+.46,b.y)
		if actor.test_move(Transform3D(Basis.IDENTITY,start),end-start): blocked+=1
	check(ramp_gaps==0, "465 ramp ground samples continuous across full walking width")
	check(blocked==0, "capsule sweeps traverse all five ramps")
	# Drive the actual movement controller through every landing and ramp.
	actor.position = Vector3(27,8.5,-35)
	actor.velocity = Vector3.ZERO
	await frames(10)
	var route_ok := true
	Input.action_press("sprint")
	Input.action_press("move_forward")
	for i in layout.ramps.size():
		var r: Dictionary = layout.ramps[i]
		var next: Array = layout.rooms[i+1]
		var destination := Vector2(next[1],-next[2])
		if i == layout.ramps.size()-1: destination = Vector2(11,33.7) # Stand in front of the solid chest.
		for point in [Vector2(r.start[0],-r.start[1]),Vector2(r.end[0],-r.end[1]),destination]:
			var arrived := false
			for tick in 500:
				var delta: Vector2 = point-Vector2(actor.position.x,actor.position.z)
				if delta.length()<.4: arrived=true; break
				actor.pivot.rotation.y = atan2(-delta.x,-delta.y)
				await frames(1)
			if not arrived:
				route_ok=false
				print("WALK BLOCKED ramp ",i," target ",point," actor ",actor.position)
				break
		if not route_ok: break
	Input.action_release("sprint")
	Input.action_release("move_forward")
	check(route_ok, "actual character walks all five descents to final room")
	var missing_walls := 0
	for segment in cave.edge_segments:
		var a: Vector2 = segment[0];var b: Vector2 = segment[1];var mid := (a+b)*.5
		var normal := (b-a).normalized().orthogonal()
		for y in [-6.5,9.0,15.0]:
			var p := mid-normal*.8;var q := mid+normal*.8
			if space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x,y,p.y),Vector3(q.x,y,q.y),4)).is_empty():missing_walls+=1
	check(missing_walls==0, "all open edges block at floor and jump heights")
	# Exercise real movement, including jump+sprint, at an exposed rim.
	actor.position = Vector3(27,8.5,-36)
	actor.pivot.rotation.y = -PI*.5
	actor.velocity = Vector3.ZERO
	await frames(20)
	Input.action_press("move_forward");Input.action_press("sprint");Input.action_press("jump")
	await frames(150)
	Input.action_release("move_forward");Input.action_release("sprint");Input.action_release("jump")
	check(Geometry2D.is_point_in_polygon(Vector2(actor.position.x,actor.position.z),cave.walk_outline), "jump and sprint cannot leave map")
	check(actor.position.y>7.8, "edge collision prevents falling")
	# Treasure retains original open / take / capacity / no-duplication behavior.
	var chest := cave.get_node("EchoChest")
	actor.position = chest.position+Vector3(0,.5,-1.7)
	actor.pivot.rotation.y = PI
	actor.get_node("Nael").rotation.y = 0
	actor.velocity = Vector3.ZERO
	await frames(20)
	check(chest.can_interact(), "chest reachable in deepest room")
	await capture("chest_closed")
	chest.interact()
	await get_tree().create_timer(.95).timeout
	check(chest.opened and chest.relic.visible and not bag.equipment.has("first_echo"), "opening reveals original relic without auto collecting")
	bag.equipment.assign(["a","b","c","d","e","f"])
	chest.interact()
	check(chest.relic.visible and not bag.collected.has("cave/first_echo"), "full equipment preserves treasure")
	bag.equipment.clear()
	chest.interact()
	check(bag.equipment.has("first_echo") and not chest.relic.visible, "original relic collected in new room")
	chest.interact()
	check(bag.equipment.count("first_echo")==1, "treasure cannot duplicate")
	await capture("chest_collected")
	actor.position = Vector3(27,8.5,-38.4)
	actor.velocity = Vector3.ZERO
	await frames(4)
	var return_portal := cave.get_node("EntranceReturn")
	check(return_portal.dialog.visible, "return doorway also offers confirmation")
	return_portal._confirm()
	await frames(2)
	await settled()
	check(travel.room==lobby and lobby.is_inside_tree(), "return restores same entrance room")
	check(lobby.get_node("Player").health==72, "return preserves health")
	await frames(10)
	check(not travel.confirmation_open, "return spawn does not retrigger entry dialog")
	travel.enter_subroom("res://scenes/interiors/cave_depths.tscn")
	await settled()
	chest = travel.room.get_node("EchoChest")
	check(chest.opened and not chest.relic.visible, "empty chest persists after another visit")
	travel.leave_subroom()
	await settled()
	# Test nested travel with the real exterior retained in memory.
	lobby.get_parent().remove_child(lobby)
	lobby.queue_free()
	travel.room = null
	var world: Node3D = load("res://scenes/world/open_world.tscn").instantiate()
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	await frames(20)
	var outside: CharacterBody3D = world.get_node("Original/Player")
	var outside_position := outside.global_position
	var world_id := world.get_instance_id()
	travel.enter_cabin(world.get_node("GrotteEntree/Portal"),"res://scenes/interiors/cave_room.tscn")
	await settled()
	check(travel.inside, "forest enters preserved entrance room")
	travel.enter_subroom("res://scenes/interiors/cave_depths.tscn")
	await settled()
	check(travel.parked_world==world and not world.is_inside_tree(), "deeper travel preserves parked forest")
	travel.leave_subroom()
	await settled()
	travel.leave_cabin()
	await settled()
	check(not travel.inside and world.is_inside_tree() and world.get_instance_id()==world_id, "complete round trip restores same forest")
	check(outside.global_position.distance_to(outside_position)<.25, "forest return preserves exterior position")
	check(bag.equipment.count("first_echo")==1, "treasure survives full forest round trip")
	finish()

func finish() -> void:
	FileAccess.open("res://tests/cave_depths_report.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	print("DEPTHS RESULT ",checks," checks / ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)
