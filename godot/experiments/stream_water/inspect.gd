extends SceneTree
func _initialize():
 var scene = load("res://assets/environment/forest.glb").instantiate()
 root.add_child(scene)
 var water = scene.find_child("Water", true, false)
 print("WATER transform ",water.global_transform)
 for s in water.mesh.get_surface_count():
  var a = water.mesh.surface_get_arrays(s)
  print("VERTS ",a[0].size()," UV ",a[4].size() if a[4] != null else 0)
  for i in range(mini(12,a[0].size())): print(a[0][i])
 quit()
