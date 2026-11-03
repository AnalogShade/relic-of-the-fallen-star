extends SceneTree
func _initialize():
 call_deferred("check")
func check():
 var scene = load("res://scenes/player.tscn").instantiate()
 root.add_child(scene)
 await process_frame
 for node in scene.get_node("Nael").find_children("*", "MeshInstance3D", true, false):
  for i in node.mesh.get_surface_count():
   assert(node.get_active_material(i).transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
 print("PLAYER_PRODUCTION_MATERIAL_PASS")
 scene.free()
 quit()
