extends SceneTree

func own(n: Node, camp: Node) -> void:
	n.owner=camp
	for c in n.get_children(): own(c,camp)

func _initialize() -> void:
	var camp: Node3D=load("res://scenes/world/camp_bandits.tscn").instantiate()
	var changed:=0
	for prop in camp.get_children():
		if not prop is MeshInstance3D: continue
		var bodies:=prop.find_children("*","StaticBody3D",true,false)
		if bodies.is_empty(): continue
		for body in bodies: body.free()
		preload("res://tests/camp_collision_shapes.gd").create(prop)
		own(prop,camp)
		changed+=1
	var packed:=PackedScene.new()
	assert(packed.pack(camp)==OK)
	assert(ResourceSaver.save(packed,"res://scenes/world/camp_bandits.tscn")==OK)
	print("SIMPLIFIED_PROPS ",changed)
	camp.free()
	quit()
