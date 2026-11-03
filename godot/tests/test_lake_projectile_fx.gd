extends SceneTree
var failures := 0

func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ", label)
	if not ok: failures += 1

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	current_scene = stage
	var projectile = load("res://scripts/lake_monster_projectile.gd").new()
	projectile.water_y = -100
	stage.add_child(projectile)
	projectile.set_physics_process(false)
	var effect = projectile.visual
	check(effect.trails.size() == 3 and effect.halo.mesh is QuadMesh, "Halo et trois couches de traînée")
	var budget := 0
	for trail in effect.trails:
		budget += trail.amount
		check(not trail.local_coords and trail.mesh is QuadMesh, "Particules sur plans en coordonnées mondiales")
	check(budget == 66, "Budget limité à 66 particules pour chaque tir")
	var old_position: Vector3 = effect.global_position
	projectile._impact()
	check(effect.get_parent() == stage and effect.global_position.is_equal_approx(old_position), "Impact conserve la traînée en place après suppression du projectile")
	for trail in effect.trails:
		check(not trail.emitting, "Émission arrêtée après impact")
	effect._process(0.8)
	check(effect.is_queued_for_deletion(), "Effet supprimé après le fondu")
	await process_frame
	check(get_nodes_in_group("lake_projectile_fx").is_empty(), "Aucun effet résiduel après suppression")
	print("LAKE_PROJECTILE_FX_RESULT: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)
