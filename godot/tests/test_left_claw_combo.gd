extends SceneTree

class Target extends Node3D:
	var health := 1000.0
	var enemy_name := "Cible"
	func take_damage(amount: float, _source: Vector3) -> void:
		health -= amount

var failures: Array[String] = []
var actor
var enemy: Target

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ") + label)
	if not ok: failures.append(label)

func frames(n: int) -> void:
	for i in range(n):
		await physics_frame
		await process_frame

func finish_strike() -> void:
	for i in range(120):
		if not actor.is_attacking: return
		await frames(1)
	check(false, "Attack finishes within two seconds")

func run() -> void:
	var level := Node3D.new()
	root.add_child(level)
	current_scene = level
	var floor_body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 1, 20)
	col.shape = shape
	col.position.y = -0.5
	floor_body.add_child(col)
	level.add_child(floor_body)
	actor = load("res://scenes/player.tscn").instantiate()
	actor.position.y = 0.5
	level.add_child(actor)
	enemy = Target.new()
	enemy.position = Vector3(0, 0, -1.25)
	level.add_child(enemy)
	enemy.add_to_group("enemies")
	await frames(30)
	actor.left_claw_chance = 1.0
	var ap: AnimationPlayer = actor.get_node("Nael").animator
	check(ap.has_animation("Nael_Claw_Left"), "Corrected Blender left clip imported")
	check(ap.get_animation("Nael_Claw_Left").loop_mode == Animation.LOOP_NONE, "Left strike does not loop")
	check(actor.start_claw() and not actor.active_claw_left, "First click always uses normal claw")
	await finish_strike()
	check(enemy.health == 975.0, "Normal strike deals 25")
	check(actor.start_claw() and actor.active_claw_left, "Rapid follow-up can use left claw")
	check(ap.current_animation == "Nael_Claw_Left", "Animation controller selects left clip")
	await frames(1)
	var trail = actor.get_node("ClawTrail")
	check(trail._bone_idx == trail._skeleton.find_bone("LeftHand"), "Powerful trail follows the left hand")
	ap.speed_scale = 0.0
	await frames(10)
	check(enemy.health == 975.0 and actor.is_attacking, "Paused left anticipation cannot cause damage")
	ap.speed_scale = 1.6
	await finish_strike()
	check(enemy.health == 925.0, "Left strike deals exactly 50 once")
	await frames(2)
	check(ap.current_animation == "Nael_Idle_Breathe", "Left recovery returns to neutral idle")
	check(trail._bone_idx == trail._skeleton.find_bone("RightHand"), "Trail restores the right hand after recovery")
	check(actor.claw_chain_count == 0, "Powerful strike resets the chain")
	actor.cancel_claw()
	actor.start_claw()
	actor.request_claw()
	actor.request_claw()
	check(actor.claw_buffer_remaining > 0.0, "Repeated input queues one follow-up")
	await frames(70)
	check(enemy.health == 850.0, "Buffered normal + left chain delivers 25 + 50")
	check(not actor.is_attacking, "Spam does not create an unlimited attack queue")
	actor.cancel_claw()
	actor.left_claw_chance = 0.0
	for i in range(4):
		check(actor.start_claw(), "Chain strike %d starts" % (i + 1))
		check(actor.active_claw_left == (i == 3), "Powerful variation guaranteed by fourth strike")
		await finish_strike()
	await frames(45)
	actor.start_claw()
	check(not actor.active_claw_left, "Pause resets to a normal first strike")
	actor.request_claw()
	root.get_node("Inventory").is_open = true
	await frames(2)
	check(not actor.is_attacking and actor.claw_buffer_remaining == 0.0 and actor.claw_chain_count == 0, "Inventory cancels attack and buffered combo")
	root.get_node("Inventory").is_open = false
	actor.start_claw()
	actor.request_claw()
	actor.respawn()
	check(not actor.is_attacking and actor.claw_buffer_remaining == 0.0, "Respawn clears buffered attacks")
	print("LEFT_CLAW_COMBO_RESULT: %d failures" % failures.size())
	level.free()
	quit(0 if failures.is_empty() else 1)
