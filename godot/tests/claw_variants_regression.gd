extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
	print("PASS " if ok else "FAIL ", label)
	if not ok: failures += 1
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var player = load("res://scenes/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)
	var model = player.get_node("Nael")
	model.set_process(false)
	var trail = player.get_node("ClawTrail")
	var seen := {}
	var previous := ""
	for i in range(60):
		var clip: String = model.choose_primary_claw()
		check(clip != previous, "Variation sans répétition immédiate")
		seen[clip] = true
		previous = clip
		model.play_claw(false, clip)
		check(model.animator.current_animation == clip, "Lecture " + clip)
		check(trail._animator_playing_claw(), "Traînée reconnaît " + clip)
		check(model.animator.current_animation_length > player.CLAW_IMPACT_TIME, "Impact dans la durée du clip")
	check(seen.size() == 3, "Les trois variantes sont sélectionnées")
	check(player.claw_damage == 25.0, "Dégâts principaux conservés à 25")
	check(player.left_claw_damage_multiplier == 2.0, "Multiplicateur gauche conservé")
	model.play_claw(true)
	check(model.animator.current_animation == "Nael_Claw_Left", "Attaque gauche conservée")
	model.play_claw()
	check(model.animator.current_animation == "Nael_Claw", "Clip historique disponible pour sorts et hache")
	player.queue_free()
	await process_frame
	print("CLAW_VARIANTS_FAILURES=", failures)
	quit(1 if failures else 0)
