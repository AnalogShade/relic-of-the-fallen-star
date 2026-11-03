extends Node3D
var failures: Array[String] = []
var checks := 0
func check(ok: bool, message: String) -> void:
 checks += 1
 if not ok: failures.append(message)
 print(("PASS: " if ok else "FAIL: ") + message)
func frames(n: int) -> void:
 for i in range(n): await get_tree().physics_frame
func capture(filename: String) -> void:
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://tests/maison_maelor_20261024/"+filename)
func settle(travel: Node) -> void:
 for i in range(100):
  await get_tree().create_timer(0.05).timeout
  if not travel.busy: break
 check(not travel.busy,"Transition terminée")
func press_f() -> void:
 var event := InputEventKey.new()
 event.physical_keycode = KEY_F
 event.keycode = KEY_F
 event.pressed = true
 Input.parse_input_event(event)
 await frames(4)
 event = InputEventKey.new()
 event.physical_keycode = KEY_F
 event.keycode = KEY_F
 event.pressed = false
 Input.parse_input_event(event)
func _ready() -> void:
 await frames(100)
 var world := $World
 var player: CharacterBody3D = world.get_node("Original/Player")
 var travel := get_node("/root/CabinTravel")
 var tile: Node3D = world.get_node("Sectors/Tile_04_bois_du_foyer")
 var portal: Node3D = tile.get_node("CabinEntrance")
 var door: Node3D = tile.get_node("CabinDoorArt")
 var house: Node3D = tile.get_node("MaisonMaelor")
 var id := world.get_instance_id()
 world.reparent(get_tree().root)
 get_tree().current_scene = world
 player.global_position = Vector3(-54.8296,12.25,4.2)
 player.velocity = Vector3.ZERO
 player.pivot.rotation.y = 0
 await frames(80)
 var exterior_position := player.global_position
 check(house.scale.is_equal_approx(Vector3.ONE * 0.43),"Échelle uniforme de la maison")
 check(not tile.get_node("Art").find_children("CabinCour*","MeshInstance3D",true,false).is_empty(),"Cour d’origine présente")
 check(tile.get_node("EntreeNoire").get_child_count()==0,"Écran noir sans collision")
 check(not house.find_children("*","CollisionShape3D",true,false).is_empty(),"Collisions de la nouvelle structure")
 check(portal.can_interact(),"Entrée accessible devant les marches")
 var hud := world.get_node_or_null("Original/HUD")
 if hud: hud.hide()
 player.hide()
 var cam := Camera3D.new()
 world.add_child(cam)
 cam.global_position = Vector3(-47.6,16.7,11.6)
 cam.look_at(Vector3(-55.2,14.5,0))
 cam.fov=62
 cam.current=true
 await frames(12)
 await capture("maison_exterieur.png")
 cam.global_position = Vector3(-54.8296,13.38,5.2)
 cam.look_at(Vector3(-54.8296,13.34,1.65))
 cam.fov=60
 door.rotation.y=1.15
 await frames(12)
 await capture("porte_ouverte.png")
 door.rotation.y=0
 cam.queue_free()
 player.show()
 if hud: hud.show()
 player.get_node("CameraPivot/SpringArm3D/Camera3D").make_current()
 await capture("maison_gameplay.png")
 await press_f()
 await settle(travel)
 check(travel.inside and travel.room != null,"Entrée dans l’intérieur jouable")
 check(not world.is_inside_tree(),"Forêt préservée pendant la visite")
 if travel.room != null:
  var actor: CharacterBody3D = travel.room.get_node("Player")
  await frames(40)
  check(actor.is_on_floor(),"Personnage au sol à l’intérieur")
  actor.global_position=Vector3(-0.6875,0.46,2.1)
  actor.velocity=Vector3.ZERO
  await frames(20)
  await press_f()
  await settle(travel)
  check(not travel.inside and world.is_inside_tree(),"Retour dans la forêt")
  check(world.get_instance_id()==id,"Même instance de forêt au retour")
  check(player.global_position.distance_to(exterior_position)<0.15,"Retour au même endroit")
  check(player.process_mode!=Node.PROCESS_MODE_DISABLED,"Commandes rétablies")
  check(travel.overlay.color.a<0.01,"Fondu dégagé")
  await press_f()
  await settle(travel)
  check(travel.inside,"Deuxième entrée avec F")
  if travel.room != null:
   var second_actor: CharacterBody3D = travel.room.get_node("Player")
   second_actor.global_position=Vector3(-0.6875,0.46,2.1)
   second_actor.velocity=Vector3.ZERO
   await frames(20)
   await press_f()
   await settle(travel)
   check(not travel.inside,"Deuxième sortie avec F")
 var report := {"checks":checks,"failures":failures,"outside_position":str(exterior_position)}
 var f := FileAccess.open("res://tests/maison_maelor_20261024/report.json",FileAccess.WRITE)
 f.store_string(JSON.stringify(report,"  "))
 print("MAISON_VALIDATION: "+JSON.stringify(report))
 get_tree().quit(0 if failures.is_empty() else 1)
