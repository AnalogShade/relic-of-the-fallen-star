extends SceneTree
func _initialize():
 var scene = load("res://assets/environment/world/chateau_des_plaines.glb").instantiate()
 for mesh in scene.find_children("*", "MeshInstance3D", true, false):
  var names = []
  for s in mesh.mesh.get_surface_count():
   var mat = mesh.mesh.surface_get_material(s)
   names.append(mat.resource_name if mat else "none")
  print(mesh.name," MATERIALS ",names)
 scene.free()
 quit()
