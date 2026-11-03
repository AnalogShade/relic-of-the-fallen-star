extends Node
## Suspend distant forest encounters; keep the full combat AI near the player.
const INTERVAL := 0.2
const HIDE_DISTANCE := 110.0
var entries: Array[Dictionary] = []
var player: Node3D
var elapsed := 0.0
var sleeping_count := 0

func _enter_tree() -> void:
	# CabinTravel reattaches the same forest; _ready() does not run again.
	# Defer until the player and all managed actors have reentered the tree.
	update_activity.call_deferred(true)

func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as Node3D
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var script = enemy.get_script()
		if script == null or script.resource_path not in ["res://scripts/bandit.gd", "res://scripts/araignee.gd"]:
			continue
		entries.append({"actor": enemy, "mode": enemy.process_mode, "visible": enemy.visible, "sleeping": false})
	update_activity(true)

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= INTERVAL:
		elapsed = 0.0
		update_activity()

func update_activity(initial := false) -> void:
	if not is_instance_valid(player):
		return
	sleeping_count = 0
	for entry in entries:
		var actor = entry.actor
		if not is_instance_valid(actor): continue
		# Death tweens and cleanup must finish, even outside the active area.
		if actor.health <= 0.0:
			if entry.sleeping:
				actor.process_mode = entry.mode
				entry.sleeping = false
			continue
		var home: Vector3 = actor.home if "home" in actor else actor.home_position
		var distance := minf(player.global_position.distance_to(actor.global_position), player.global_position.distance_to(home))
		var wake_distance := maxf(28.0, maxf(actor.leash_radius, actor.detection_radius) + 8.0)
		var sleep_distance := wake_distance if initial else wake_distance + 8.0
		var fighting: bool = is_instance_valid(actor.combat) and not actor.combat.phase.is_empty()
		if entry.sleeping and (distance < wake_distance or fighting):
			actor.process_mode = entry.mode
			entry.sleeping = false
		elif not entry.sleeping and distance > sleep_distance and not fighting:
			actor.process_mode = Node.PROCESS_MODE_DISABLED
			entry.sleeping = true
		# Keep encounters visible well beyond combat range; cull very distant models.
		actor.visible = entry.visible and distance < HIDE_DISTANCE
		if entry.sleeping: sleeping_count += 1

func _exit_tree() -> void:
	for entry in entries:
		if is_instance_valid(entry.actor):
			entry.actor.process_mode = entry.mode
			entry.actor.visible = entry.visible
			entry.sleeping = false
	sleeping_count = 0
