extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var root_node := Node3D.new()
	root.add_child(root_node)
	
	# Sol physique pour que is_on_floor() soit vrai
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collider.shape = shape
	floor_body.add_child(collider)
	root_node.add_child(floor_body)
	
	var scene = load("res://scenes/player.tscn").instantiate()
	scene.position = Vector3(0, 0.5, 0)
	root_node.add_child(scene)
	
	for i in range(10):
		await physics_frame
		
	print("--- Test de synchronisation animation / bruits de pas ---")
	print("Player on floor: ", scene.is_on_floor())
	
	var anim: AnimationPlayer = scene.get_node("Nael").animator
	assert(anim != null, "L'AnimationPlayer de Nael doit exister")
	
	# Simuler la marche (horizontal_speed = 2.16 m/s)
	scene.velocity = Vector3(2.16, 0.0, 0.0)
	anim.play("Nael_Walk")
	anim.speed_scale = 2.16 / 2.0 # 1.08
	
	var walk_steps := 0
	var last_time := 0.0
	
	# Simuler 3 secondes de marche a 60 fps
	for f in range(180):
		var dt: float = 1.0 / 60.0
		anim.advance(dt)
		var played_before: bool = scene.footstep_player.playing
		scene._process_footsteps(dt)
		if scene.footstep_player.playing and not played_before:
			walk_steps += 1
			var t := f * dt
			var interval := t - last_time if walk_steps > 1 else 0.0
			last_time = t
			print("  Pas de marche #%d a t = %.3fs (intervalle = %.3fs, anim_pos = %.3fs)" % [
				walk_steps, t, interval, anim.current_animation_position
			])
			scene.footstep_player.stop() # reset pour detecter le prochain
			
	print("Total pas en marche (3s) : %d (attendu : ~5-6 pas)" % walk_steps)
	assert(walk_steps >= 4 and walk_steps <= 7, "Le nombre de pas en marche doit correspondre au cycle de marche")
	
	root_node.queue_free()
	print("--- TEST DE SYNCHRONISATION VALIDE AVEC SUCCES ! ---")
	quit(0)
