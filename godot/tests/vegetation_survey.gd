extends SceneTree
func _initialize():
 var mesh=load("res://assets/environment/vegetation/herbe_haute_prairie_batched.res")
 print("AABB ",mesh.get_aabb())
 var scene=load("res://scenes/world/vegetation_first_pass.tscn").instantiate()
 for category in ["HerbesCourtes","HerbesHautes","Fougeres"]:
  var n=scene.get_node(category).get_child(0)
  print(category," ",n.position," ",n.multimesh.get_aabb()," first ",n.multimesh.get_instance_transform(0))
 scene.free()
 quit()
