extends SceneTree
func _initialize():
 call_deferred("capture")
func capture():
 var scene = load("res://scenes/world/open_world.tscn").instantiate()
 root.add_child(scene)
 current_scene = scene
 await process_frame
 await process_frame
 var lake = scene.get_node("Sectors/OasisDuNord/Water_Oasis_Reservoir")
 assert(lake.material_override.shader.resource_path == "res://shaders/lake_water.gdshader")
 for path in ["Original/EnvironmentArt/Water", "Sectors/Tile_02_vallee_des_sources/Art/Water", "Sectors/Tile_07_meandres_du_sud/Art/Water", "Sectors/OasisDuNord/Water_Oasis_Exutoire", "Sectors/OasisDuNord/Water_Oasis_Source"]:
  assert(scene.get_node(path).material_override.shader.resource_path == "res://shaders/stream_water.gdshader")
 assert(scene.get_node("Sectors/WesternPlains/ChateauDesPlaines/Water_Moat").material_override.shader.resource_path == "res://shaders/lake_water.gdshader")
 print("WATER_INTEGRATION_PASS: lake, original stream, both extensions, outlet and source")
 var camera = Camera3D.new()
 scene.add_child(camera)
 camera.position = Vector3(37,20,-187)
 camera.look_at(Vector3(8,5.5,-211))
 camera.current = true
 root.size = Vector2i(1280,720)
 await create_timer(1.5).timeout
 await RenderingServer.frame_post_draw
 if not DisplayServer.get_name() == "headless":
  root.get_texture().get_image().save_png("res://experiments/stream_water/lake_integrated.png")
 var new_material = lake.material_override
 var old = ShaderMaterial.new()
 old.shader = load("res://shaders/oasis_water.gdshader")
 lake.material_override = old
 await create_timer(0.4).timeout
 await RenderingServer.frame_post_draw
 if not DisplayServer.get_name() == "headless":
  root.get_texture().get_image().save_png("res://experiments/stream_water/lake_before.png")
 lake.material_override = new_material
 print("LAKE_CAPTURE_COMPLETE")
 scene.free()
 quit()
