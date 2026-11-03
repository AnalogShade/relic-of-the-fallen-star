extends StaticBody3D
const Access = preload("res://scripts/cave_access.gd")
const KICK_IMPACT := 16.0 / 24.0 # Blender frame 17, action starts at frame 1.
const GUARD_POSITION := Vector3(0, 0, 1.25)
const SLEEP_POSITION := Vector3(2.0, 0, 1.65)

var state := "guard"
var health := 1000.0
var max_health := 1000.0
var enemy_name := "Ogre gardien"
var visual: Node3D
var animator: AnimationPlayer
var barrier: StaticBody3D
var body_shape: CollisionShape3D
var kick_applied := false
var cooldown := 0.0
var sleep_position := SLEEP_POSITION
var guard_position := GUARD_POSITION

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("cave_guardian")
	add_to_group("enemies")
	collision_layer = 5
	collision_mask = 2
	body_shape = CollisionShape3D.new()
	body_shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	capsule.height = 3.4
	capsule.radius = 0.93
	body_shape.shape = capsule
	body_shape.position.y = 1.7
	add_child(body_shape)
	visual = load("res://assets/characters/ogre_guardian.glb").instantiate()
	visual.name = "Visual"
	visual.scale = Vector3.ONE * 1.95
	add_child(visual)
	animator = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for clip in ["Idle_Respiration", "Walk_Relaxed", "Guardian_Sleep"]:
		animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.animation_finished.connect(_animation_finished)
	animator.play("Idle_Respiration")

func configure(cave: Node3D) -> void:
	barrier = StaticBody3D.new()
	barrier.name = "GuardianPassage"
	cave.add_child(barrier)
	barrier.position = Vector3(0, 2.8, -1.5)
	var frame := cave.get_node_or_null("EntranceFrame") as Node3D
	if frame:
		barrier.transform = frame.transform * barrier.transform
		guard_position = frame.transform * GUARD_POSITION
		sleep_position = frame.transform * SLEEP_POSITION
		position = guard_position
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.9, 6.0, 0.65)
	shape.shape = box
	barrier.add_child(shape)
	if Access.passage_open(self): _restore_sleep()
	_settle_on_ground()

func _settle_on_ground() -> void:
	await get_tree().physics_frame
	for sleeping in [false, true]:
		var target: Vector3 = sleep_position if sleeping else guard_position
		var point: Vector3 = get_parent().to_global(target)
		var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 0.4, point - Vector3.UP * 4, 1, [get_rid(), barrier.get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y > 0.5:
			target.y = get_parent().to_local(hit.position).y
		if sleeping: sleep_position = target
		else: guard_position = target
	if state == "sleeping": position = sleep_position
	elif state == "guard": position = guard_position

func passage_open() -> bool:
	return state == "sleeping"

func _restore_sleep() -> void:
	state = "sleeping"
	position = sleep_position
	animator.play("Guardian_Sleep")
	animator.advance(0)
	_open_passage()

func _open_passage() -> void:
	barrier.collision_layer = 0
	body_shape.set_deferred("disabled", true)
	remove_from_group("enemies")
	get_node("/root/QuestManager").complete_guardian_search()

func _player() -> CharacterBody3D:
	return get_tree().get_first_node_in_group("player") as CharacterBody3D

func can_interact() -> bool:
	var player := _player()
	if not player or state not in ["guard", "sleeping"]: return false
	if get_node("/root/CabinTravel").busy: return false
	if get_node("/root/DialogueManager").is_open: return false
	if player.rest_state != "" or player.is_attacking or player.swimming: return false
	return player.global_position.distance_to(global_position) <= 4.0

func interaction_text() -> String:
	return "Observer l'ogre endormi" if state == "sleeping" else "Parler à l'ogre"

func interact() -> void:
	if not can_interact(): return
	var dm := get_node("/root/DialogueManager")
	if state == "sleeping":
		var sleeping_pages: Array[String] = ["Il respire profondément. Il dort, bien vivant. Je peux passer sans lui faire de mal."]
		dm.show_dialogue("Naël", "Le gardien", sleeping_pages)
		return
	Access.remember(self, Access.MET)
	var options: Array[String] = ["Je comprends. Je vais rebrousser chemin.", "Je dois entrer dans cette caverne. Écarte-toi."]
	if get_node("/root/Inventory").get_item_count(Access.DART) > 0:
		options.append("Préparer mes fléchettes soporifiques.")
	var pages: Array[String] = ["Halte-là, voyageur. Je ne peux te laisser entrer. Une puissance obscure sommeille dans les profondeurs de cette caverne. Et je ne laisserai personne risquer de la réveiller."]
	dm.show_choices("L'ogre", "Gardien de la caverne", pages, options, _answer)

func _answer(index: int) -> void:
	if state != "guard": return
	if index == 1:
		var dm := get_node("/root/DialogueManager")
		var pages: Array[String] = ["Je t'aurai prévenu. Si tu tiens tant à passer, il faudra d'abord me passer sur le corps."]
		dm.show_dialogue("L'ogre", "Dernier avertissement", pages, func():
			if is_instance_valid(self): start_kick()
		)
	elif index == 2:
		var bag := get_node("/root/Inventory")
		if bag.equipped != Access.DART: bag.toggle_equipment(Access.DART)
		bag.ui.notify("Maintenez le clic droit pour viser, puis relâchez pour lancer.")

func start_kick() -> void:
	var player := _player()
	if state != "guard" or cooldown > 0 or not player: return
	if global_position.distance_to(player.global_position) > 4.6: return
	state = "kick"
	kick_applied = false
	var direction := to_local(player.global_position)
	visual.rotation.y = atan2(direction.x, direction.z)
	animator.play("Guardian_Kick", 0.12)

func _physics_process(delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if state != "kick" or kick_applied: return
	if animator.current_animation_position < KICK_IMPACT: return
	kick_applied = true
	var player := _player()
	if player and player.global_position.distance_to(global_position) <= 4.8:
		player.receive_guardian_kick(global_position)
		Access.remember(self, Access.REPELLED)

func _animation_finished(clip: StringName) -> void:
	if clip == "Guardian_Kick" and state == "kick":
		state = "guard"
		cooldown = 1.0
		visual.rotation.y = 0
		animator.play("Idle_Respiration", 0.25)
	elif clip == "Guardian_Drowsy" and state == "drowsy":
		state = "sitting"
		animator.play("Guardian_Sit_Sleep", 0.3)
		create_tween().tween_property(self, "position", sleep_position, 3.8).set_trans(Tween.TRANS_SINE)
	elif clip == "Guardian_Sit_Sleep" and state == "sitting":
		state = "sleeping"
		position = sleep_position
		animator.play("Guardian_Sleep", 0.25)
		_open_passage()
		get_node("/root/QuestManager").refresh_journal_ui()
		get_node("/root/Inventory").ui.notify("Le gardien s'est endormi. Sa respiration est paisible.")

func take_damage(_amount: float, _source: Vector3, _attack_kind: String = "claw") -> void:
	# A territorial response only; no chase, death, loot or XP farming.
	if state == "guard": start_kick()

func receive_sleep_dart() -> bool:
	if state not in ["guard", "kick"]: return false
	state = "drowsy"
	kick_applied = true
	visual.rotation.y = 0
	# Permanent encounter resolution is committed on impact, never on a missed throw.
	Access.remember(self, Access.SEDATED)
	animator.play("Guardian_Drowsy", 0.2)
	return true
