extends SceneTree

var failures: Array[String] = []
var actor
var enemy
var level: Node3D

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures.append(label)

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame

func swing() -> void:
	actor.cancel_claw() # Isolated normal strikes; chaining is covered separately.
	check(actor.start_claw(), "Grounded claw starts")
	await frames(48)

func run() -> void:
	level = Node3D.new()
	root.add_child(level)
	current_scene = level
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(100, 1, 100)
	collider.shape = shape
	collider.position.y = -0.5
	floor_body.add_child(collider)
	level.add_child(floor_body)
	actor = load("res://scenes/player.tscn").instantiate()
	actor.position = Vector3(0, 0.5, 0)
	level.add_child(actor)
	actor.left_claw_chance = 0.0
	actor.pivot.rotation.y = 0.0
	enemy = load("res://scenes/bandit.tscn").instantiate()
	enemy.position = Vector3(0, 0, -1.25)
	level.add_child(enemy)
	enemy.set_physics_process(false)
	await frames(30)
	var animator: AnimationPlayer = actor.get_node("Nael/AnimationPlayer")
	check(animator.has_animation("Nael_Claw"), "New authored clip imported")
	check(animator.get_animation("Nael_Claw").loop_mode == Animation.LOOP_NONE, "Claw does not loop")
	check(actor.start_claw(), "Claw starts")
	check(not actor.start_claw(), "Rapid clicks cannot stack attacks")
	await frames(6)
	check(enemy.health == 100.0, "No damage during anticipation")
	check(animator.current_animation == actor.active_claw_clip, "Locomotion does not overwrite chosen attack variant")
	await frames(10)
	check(enemy.health == 100.0, "No damage while the arm is still swinging forward")
	animator.speed_scale = 0.0
	await frames(48)
	check(enemy.health == 100.0 and actor.is_attacking, "Frozen animation cannot deal damage or finish on a timer")
	animator.speed_scale = 0.5
	while animator.current_animation_position < actor.CLAW_IMPACT_TIME - 0.02:
		await frames(1)
	check(enemy.health == 100.0, "Slowed animation preserves anticipation")
	await frames(6)
	check(enemy.health == 75.0, "One strike deals exactly 25 damage")
	check(animator.current_animation_position >= actor.CLAW_IMPACT_TIME, "Damage follows the impact pose")
	animator.speed_scale = 1.0
	await frames(20)
	check(animator.current_animation == "Nael_Idle_Breathe", "Returns to idle")
	enemy.position.z = 1.25
	await swing()
	check(enemy.health == 75.0, "Cannot hit behind player")
	enemy.position.z = -4.0
	await swing()
	check(enemy.health == 75.0, "Cannot hit outside range")
	enemy.position = Vector3(0, 3, -1.25)
	await swing()
	check(enemy.health == 75.0, "Cannot hit another elevation")
	enemy.position = Vector3(0, 0, -1.25)
	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, 0.1)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	wall.position = Vector3(0, 1.5, -0.65)
	level.add_child(wall)
	await frames(3)
	await swing()
	check(enemy.health == 75.0, "Wall blocks damage")
	wall.queue_free()
	await frames(3)
	var inventory = root.get_node("Inventory")
	inventory.is_open = true
	check(not actor.start_claw(), "Inventory blocks attack")
	inventory.is_open = false
	actor.start_claw()
	inventory.is_open = true
	await frames(48)
	check(enemy.health == 75.0 and not actor.is_attacking, "Opening inventory cancels pending hit")
	inventory.is_open = false
	actor.start_claw()
	actor.respawn()
	await frames(48)
	check(enemy.health == 75.0 and not actor.is_attacking, "Respawn cancels pending hit")
	actor.position.y = 6.0
	await frames(3)
	check(not actor.start_claw(), "Airborne locomotion protected")
	actor.respawn()
	await frames(40)
	await swing()
	check(enemy.health == 50.0, "Second landed hit")
	await swing()
	check(enemy.health == 25.0, "Third landed hit")
	await swing()
	check(is_instance_valid(enemy) and enemy.health == 0 and enemy.state == "dead", "Fourth landed hit kills bandit and leaves its body")
	check(get_nodes_in_group("enemies").is_empty(), "Dead bandit removed from enemy group")
	print("CLAW_COMBAT_RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
