extends SceneTree
func _initialize():
 for path in ["res://assets/environment/forest.glb", "res://assets/environment/world/tile_02_vallee_des_sources.glb", "res://assets/environment/world/tile_07_meandres_du_sud.glb", "res://assets/environment/world/oasis_du_nord.glb"]:
  if not ResourceLoader.exists(path): continue
  var scene = load(path).instantiate()
  print("ASSET ",path)
  for mesh in scene.find_children("*", "MeshInstance3D", true, false):
   var names = []
   for s in mesh.mesh.get_surface_count():
    var mat = mesh.mesh.surface_get_material(s)
    names.append(mat.resource_name if mat else "none")
   if path.contains("forest") or str(mesh.name).to_lower().contains("water") or str(names).to_lower().contains("foam"):
    print(mesh.name," MATERIALS ",names)
  scene.free()
 quit()
