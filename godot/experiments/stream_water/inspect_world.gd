extends SceneTree
func _initialize():
 call_deferred("inspect")
func inspect():
 var scene = load("res://scenes/world/open_world.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 for water in scene.find_children("*Water*", "MeshInstance3D", true, false):
  print("WATER ",water.get_path()," AABB ",water.mesh.get_aabb()," transform ",water.global_transform)
 scene.free()
 quit()
