extends SceneTree
func _initialize():
 call_deferred("check")
func check():
 var art = load("res://assets/environment/forest.glb").instantiate()
 root.add_child(art)
 var water = art.find_child("Water", true, false)
 load("res://scripts/stream_water.gd").apply(water)
 # Freeze shader animation for exact comparisons without editing the source shader.
 var frozen = Shader.new()
 frozen.code = water.material_override.shader.code.replace("TIME", "1.0")
 water.material_override.shader = frozen
 var ripples = art.find_child("Ripples", true, false)
 if ripples: ripples.hide()
 var character = load("res://assets/characters/nael.glb").instantiate()
 root.add_child(character)
 var meshes = character.find_children("*", "MeshInstance3D", true, false)
 for mesh in meshes:
  print("CHAR_MATERIAL ", mesh.name, " transparency=", mesh.get_active_material(0).transparency, " bounds=", mesh.get_aabb())
 var env_node = WorldEnvironment.new()
 var env = Environment.new()
 env.background_mode = Environment.BG_COLOR
 env.background_color = Color(0.4,0.5,0.45)
 env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.ambient_light_color = Color.WHITE
 env.ambient_light_energy = 0.7
 env_node.environment = env
 root.add_child(env_node)
 var sun = DirectionalLight3D.new()
 root.add_child(sun)
 sun.rotation_degrees = Vector3(-50,-30,0)
 sun.light_energy = 0.65
 var camera = Camera3D.new()
 root.add_child(camera)
 camera.current = true
 root.size = Vector2i(960,720)
 var probe = load("res://scripts/water_surface.gd").new()
 root.add_child(probe)
 current_scene = art
 await process_frame
 await process_frame
 probe.rebuild()
 for scenario in [{"z":-15.0,"label":"-15"},{"z":-8.0,"label":"-8"},{"z":0.0,"label":"0"},{"z":8.0,"label":"8"},{"z":0.0,"label":"rear","offset":Vector3(0,2.2,-5.5)},{"z":0.0,"label":"side","offset":Vector3(5.5,2.2,0)},{"z":0.0,"label":"swim","y":-1.125}]:
  var z: float = scenario.z
  var t = (z + 40.0) / 64.0
  var banks = water.material_override.get_shader_parameter("banks").get_image()
  var center = banks.get_pixel(clampi(roundi(t*127),0,127),0).r
  character.position = Vector3(center,scenario.get("y",-0.425),z)
  camera.position = character.position + scenario.get("offset",Vector3(0,2.2,5.5))
  camera.look_at(character.position + Vector3(0,1.1,0))
  var animator = character.find_child("AnimationPlayer",true,false) as AnimationPlayer
  if scenario.label == "swim":
   animator.play("Nael_Float")
   animator.advance(0.5)
   animator.pause()
  print("POSITION ",character.position," WATER_HEIGHT ",probe.height_at(character.position))
  for mode in ["native","corrected","dry"]:
   for mesh in meshes:
    for i in mesh.mesh.get_surface_count():
     var material = mesh.mesh.surface_get_material(i).duplicate()
     material.transparency = mesh.mesh.surface_get_material(i).transparency
     mesh.set_surface_override_material(i,material)
   if mode != "native":
    load("res://scripts/nael_materials.gd").apply(character)
   water.visible = mode != "dry"
   await process_frame
   await process_frame
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png("res://experiments/water_immersion/%s_%s.png" % [mode,scenario.label])
 character.free()
 probe.free()
 art.free()
 print("IMMERSION_COMPARISON_COMPLETE")
 quit()

