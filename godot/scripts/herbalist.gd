extends CharacterBody3D
## Maëlor l'Herboriste : ronde aller-retour entre sa maison et la caverne.
## S'arrête et se retourne vers Naël à son approche pour initier le système de quête et dialogue.

@export var route: Curve3D
@export var walk_speed := 0.85
@export var active_distance := 48.0
@export var start_distance := 0.0

@onready var visual: Node3D = $Visual
@onready var collider: CollisionShape3D = $CollisionShape3D
@onready var animator: AnimationPlayer = visual.find_child("AnimationPlayer", true, false)

const TALK_PROXIMITY := 3.6
const RESUME_DISTANCE := 4.8
const CAVE_WAIT_POS := Vector3(36.72, 2.22, -47.55)
const CAVE_LOOK_POS := Vector3(39.42, 2.95, -48.26)

var player: Node3D
var distance := 0.0
var route_length := 0.0
var distant := false
var lod_timer := 0.0
var far_elapsed := 0.0
var blocked_time := 0.0
var direction_sign := -1.0
var laps := 0
var walk_clip: StringName
var quest_marker: Label3D
var marker_time := 0.0

var is_talking := false
var is_engaged_with_player := false
var is_at_cave := false

func _find_cave_entrance() -> Node3D:
	if not is_inside_tree(): return null
	var scene := get_tree().current_scene
	if scene == null: return null
	return scene.find_child("GrotteEntree", true, false) as Node3D

func _is_waiting_at_cave() -> bool:
	var inv = get_node_or_null("/root/Inventory")
	var qm = get_node_or_null("/root/QuestManager")
	if inv and (inv.has_fireball_relic() or inv.collected.has("cave/first_echo")):
		return true
	if qm and (qm.is_objective_completed("echo_depths", 3) or qm.is_quest_completed("echo_depths")):
		return true
	return false

func _setup_cave_wait() -> void:
	is_at_cave = true
	distant = false
	if collider: collider.set_deferred("disabled", false)
	if visual: visual.visible = true
	if animator:
		animator.active = true
		animator.speed_scale = 0.0
	var cave := _find_cave_entrance()
	if cave:
		global_position = CAVE_WAIT_POS
		var to_cave := cave.global_position - global_position
		to_cave.y = 0.0
		if to_cave.length_squared() > 0.01:
			visual.rotation.y = atan2(to_cave.x, to_cave.z)

func _ready() -> void:
	add_to_group("interactable")
	_setup_quest_marker()
	player = get_tree().get_first_node_in_group("player") as Node3D
	lod_timer = float(get_instance_id() % 31) / 31.0
	for clip in animator.get_animation_list():
		if "cycle_marche" in clip or clip == "Animation":
			walk_clip = clip
			animator.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animator.play(walk_clip)
	# Les maillages importés partagent leurs ressources entre instances
	for mesh in visual.find_children("*", "GeometryInstance3D", true, false):
		mesh.visibility_range_end = active_distance + 10.0
		mesh.visibility_range_end_margin = 5.0
	
	if _is_waiting_at_cave() and _find_cave_entrance() != null:
		_setup_cave_wait()
		return

	if route == null or route.point_count < 2:
		# Permet les scènes de test unitaires sans route
		return
	route_length = route.get_baked_length()
	distance = clampf(start_distance, 0.0, route_length)
	global_position = route.sample_baked(distance) + Vector3.UP * 0.04
	var first_heading := route.sample_baked(clampf(distance + direction_sign * 0.6, 0.0, route_length)) - global_position
	visual.rotation.y = atan2(first_heading.x, first_heading.z)

func _advance(amount: float) -> void:
	var next := distance + amount * direction_sign
	# Reflect at each endpoint; wrapping would send him across the map.
	while next > route_length or next < 0.0:
		if next > route_length:
			next = 2.0 * route_length - next
		else:
			next = -next
		direction_sign *= -1.0
		laps += 1
	distance = next

func _setup_quest_marker() -> void:
	quest_marker = Label3D.new()
	quest_marker.name = "QuestAvailableMarker"
	quest_marker.text = "!"
	quest_marker.font_size = 112
	quest_marker.pixel_size = 0.0065
	quest_marker.modulate = Color("ffd35b")
	quest_marker.outline_modulate = Color("30200d")
	quest_marker.outline_size = 14
	quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	quest_marker.no_depth_test = false
	quest_marker.shaded = false
	quest_marker.visibility_range_end = active_distance
	quest_marker.position.y = 2.65
	add_child(quest_marker)
	_update_quest_marker()

func _update_quest_marker() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	var available: bool = qm != null and not qm.is_quest_active("echo_depths") and not qm.is_quest_completed("echo_depths")
	quest_marker.visible = available and not distant and not is_talking

func _process(delta: float) -> void:
	marker_time += delta
	quest_marker.position.y = 2.65 + sin(marker_time * 2.5) * 0.12
	_update_quest_marker()

func _physics_process(delta: float) -> void:
	if not is_at_cave and _is_waiting_at_cave() and _find_cave_entrance() != null:
		_setup_cave_wait()

	if is_at_cave:
		var dist_player := INF
		if not is_instance_valid(player): player = get_tree().get_first_node_in_group("player") as Node3D
		if is_instance_valid(player):
			dist_player = global_position.distance_to(player.global_position)

		if is_talking or dist_player <= TALK_PROXIMITY:
			is_engaged_with_player = true
		elif is_engaged_with_player and dist_player > RESUME_DISTANCE:
			is_engaged_with_player = false

		if is_engaged_with_player and is_instance_valid(player):
			var to_player := player.global_position - global_position
			to_player.y = 0.0
			if to_player.length_squared() > 0.04:
				var target_rot_y := atan2(to_player.x, to_player.z)
				visual.rotation.y = lerp_angle(visual.rotation.y, target_rot_y, minf(delta * 5.0, 1.0))
		else:
			var cave := _find_cave_entrance()
			var look_target: Vector3 = cave.global_position if cave else CAVE_LOOK_POS
			var to_cave := look_target - global_position
			to_cave.y = 0.0
			if to_cave.length_squared() > 0.01:
				var target_rot_y := atan2(to_cave.x, to_cave.z)
				visual.rotation.y = lerp_angle(visual.rotation.y, target_rot_y, minf(delta * 3.0, 1.0))

		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
		move_and_slide()
		animator.speed_scale = 0.0
		return

	if route == null or route.point_count < 2:
		# Comportement statique sans navigation sur courbe (ex: tests unitaires)
		if not is_instance_valid(player): player = get_tree().get_first_node_in_group("player") as Node3D
		var dist_player := INF
		if is_instance_valid(player):
			dist_player = global_position.distance_to(player.global_position)
		if is_talking or dist_player <= TALK_PROXIMITY:
			is_engaged_with_player = true
		elif is_engaged_with_player and dist_player > RESUME_DISTANCE:
			is_engaged_with_player = false
		if is_engaged_with_player and is_instance_valid(player):
			var to_player := player.global_position - global_position
			to_player.y = 0.0
			if to_player.length_squared() > 0.04:
				var target_rot_y := atan2(to_player.x, to_player.z)
				visual.rotation.y = lerp_angle(visual.rotation.y, target_rot_y, minf(delta * 5.0, 1.0))
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
		move_and_slide()
		animator.speed_scale = 0.0
		return

	lod_timer -= delta
	if lod_timer <= 0.0:
		lod_timer = 0.5
		if not is_instance_valid(player): player = get_tree().get_first_node_in_group("player") as Node3D
		var next_distant := is_instance_valid(player) and global_position.distance_squared_to(player.global_position) > pow(active_distance + (8.0 if not distant else 0.0), 2)
		if next_distant != distant:
			distant = next_distant
			collider.set_deferred("disabled", distant)
			visual.visible = not distant
			animator.active = not distant
			if not distant:
				_advance(walk_speed * far_elapsed)
				far_elapsed = 0.0
				global_position = route.sample_baked(distance) + Vector3.UP * 0.04
				velocity = Vector3.ZERO
	if distant:
		far_elapsed += delta
		if far_elapsed >= 0.5:
			_advance(walk_speed * far_elapsed)
			far_elapsed = 0.0
			global_position = route.sample_baked(distance) + Vector3.UP * 0.04
		return

	# Vérification de l'engagement avec le joueur (arrêt et regard attentif)
	var dist_player := INF
	if is_instance_valid(player):
		dist_player = global_position.distance_to(player.global_position)

	if is_talking or dist_player <= TALK_PROXIMITY:
		is_engaged_with_player = true
	elif is_engaged_with_player and dist_player > RESUME_DISTANCE:
		is_engaged_with_player = false

	if is_engaged_with_player and is_instance_valid(player):
		# S'arrête, se retourne vers le joueur et fige la marche
		velocity.x = 0.0
		velocity.z = 0.0
		velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
		move_and_slide()
		
		var to_player := player.global_position - global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.04:
			var target_rot_y := atan2(to_player.x, to_player.z)
			visual.rotation.y = lerp_angle(visual.rotation.y, target_rot_y, minf(delta * 5.0, 1.0))
		animator.speed_scale = move_toward(animator.speed_scale, 0.0, delta * 3.5)
		return

	# Navigation standard sur la courbe
	var target := route.sample_baked(clampf(distance + direction_sign * 0.6, 0.0, route_length))
	var heading := target - global_position
	heading.y = 0.0
	heading = heading.normalized()
	
	var yielding := false
	if is_instance_valid(player):
		var offset := player.global_position - global_position
		yielding = offset.length_squared() < 1.3 * 1.3 and heading.dot(offset.normalized()) > 0.3
		
	velocity.x = 0.0 if yielding else heading.x * walk_speed
	velocity.z = 0.0 if yielding else heading.z * walk_speed
	velocity.y = -0.5 if is_on_floor() else velocity.y - 18.0 * delta
	var before := global_position
	move_and_slide()
	var moved := Vector2(global_position.x-before.x, global_position.z-before.z).length()
	if not yielding:
		# Project actual progress onto the route, including changes in elevation.
		distance = route.get_closest_offset(global_position)
		if (direction_sign > 0.0 and distance >= route_length - 0.25) or (direction_sign < 0.0 and distance <= 0.25):
			direction_sign *= -1.0
			laps += 1
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(heading.x, heading.z), minf(delta * 4.0, 1.0))
	animator.speed_scale = clampf(moved / maxf(walk_speed * delta, 0.001), 0.0, 1.1)
	
	# Gestion des blocages temporaires
	blocked_time = blocked_time + delta if moved < walk_speed * delta * 0.15 else 0.0
	if blocked_time > 5.0:
		direction_sign *= -1.0
		# Rejoin the nearest point before trying the other direction.
		distance = route.get_closest_offset(global_position)
		blocked_time = 0.0

# --- Interface d'interaction avec le joueur (Touche F) ---

func can_interact() -> bool:
	var cabin = get_node_or_null("/root/CabinTravel")
	if cabin and cabin.busy: return false
	var dlg = get_node_or_null("/root/DialogueManager")
	if dlg and dlg.is_open: return false
	if not is_instance_valid(player) or distant: return false
	return global_position.distance_to(player.global_position) <= TALK_PROXIMITY

func interaction_text() -> String:
	return "Parler à Maëlor"

func interact() -> void:
	if not can_interact(): return
	_start_maelor_dialogue()

func _start_maelor_dialogue() -> void:
	var qm = get_node_or_null("/root/QuestManager")
	var dm = get_node_or_null("/root/DialogueManager")
	var inv = get_node_or_null("/root/Inventory")
	if not qm or not dm: return
	
	is_talking = true
	
	var has_relic: bool = false
	if inv:
		has_relic = inv.has_fireball_relic() or inv.collected.has("cave/first_echo")
	
	var skipped_intro: bool = false
	if qm.has_method("is_quest_intro_skipped"):
		skipped_intro = qm.is_quest_intro_skipped("echo_depths")
	if inv and inv.collected.get("quest/echo_depths_skipped_intro", false):
		skipped_intro = true

	var access := preload("res://scripts/cave_access.gd")
	if access.has_fact(self, access.REPELLED) and not access.passage_open(self):
		var pages: Array[String] = [
			"Naël : « Maëlor, un ogre garde l'entrée de la caverne. Il refuse de me laisser passer. Et je doute de pouvoir le vaincre... »",
			"« Tu as encore beaucoup à apprendre, Naël. Avec le peu d'expérience que tu possèdes, je doute que tu puisses vaincre une telle créature par la force. »",
			"« Mais la force n'est pas toujours la solution. »",
			"« Souviens-toi de ce que je t'ai enseigné lorsque tu étais plus jeune... particulièrement au sujet des plantes. »"
		]
		dm.show_dialogue("Maëlor", "D'anciennes leçons", pages, func():
			is_talking = false
			access.remember(self, access.HINT)
		)
		return

	if not qm.is_quest_completed("echo_depths") and has_relic:
		# 3. Quête achevée / Découverte de l'Écho (à la sortie de la caverne ou au ruisseau)
		# Assure que le joueur n'a jamais à refaire le donjon !
		if not qm.is_quest_active("echo_depths"):
			qm.start_quest_from_cave("echo_depths")
			skipped_intro = true
		qm.complete_objective("echo_depths", 1)
		qm.complete_objective("echo_depths", 2)
		qm.complete_objective("echo_depths", 3)

		var pages: Array[String]
		if skipped_intro:
			pages = [
				"« Naël ! Ciel... J'ai accouru à perdre haleine dès que la falaise s'est mise à gronder ! Quand j'ai compris que tu t'étais engouffré seul dans cette caverne sans m'attendre, mon vieux cœur a failli défaillir.\n\nMais regarde-toi... Tu te tiens debout, et tu portes en toi la lueur de l'Écho ancestral ! »",
				"« Bien des hivers ont passé depuis cette nuit d'orage où le ciel s'est fendu en deux, laissant choir une étoile embrasée dans nos bois. Quand je t'ai extirpé de ce berceau de pierre céleste, tu n'étais qu'un souffle fragile. Je t'ai élevé dans le secret pour te protéger... mais lors de la chute, un fragment primordial s'était disloqué sous cette montagne. »",
				"« Tu as affronté les sentinelles rocheuses et purifié le sanctuaire sans faiblir. Je sens la chaleur ardente qui vibre à travers toi : cet éclat chante à l'unisson avec ton âme et réveille le souffle igné de tes ancêtres. Tu as prouvé au-delà de toute espérance que tu étais prêt à affronter ton destin, mon enfant ! »"
			]
		else:
			pages = [
				"« Par les astres... Tu es sorti ! Je t'attendais ici avec inquiétude en surveillant l'entrée de la caverne.\n\nJe sens la chaleur ardente qui vibre à travers toi. Cet éclat chante à l'unisson avec ton âme. Tu as réveillé le souffle igné de tes ancêtres. Ce n'est que la première étape de ta quête, mais aujourd'hui, tu as prouvé que tu étais prêt à affronter ton destin. »"
			]
		dm.show_dialogue("Maëlor", "L'Herboriste / Victoire", pages, func():
			is_talking = false
			qm.complete_objective("echo_depths", 4)
			qm.complete_quest("echo_depths")
		)
	elif not qm.is_quest_active("echo_depths") and not qm.is_quest_completed("echo_depths"):
		# 1. Récit initial et amorce de la quête au bord du ruisseau
		var pages: Array[String] = [
			"« Ah, te voilà, Naël... Viens près de moi. Depuis le sentier, observe le ruisseau... L'eau semble paisible, n'est-ce pas ? Pourtant, depuis quelques lunes, son lit tremble et ses eaux se troublent.\n\nBien des hivers ont passé depuis cette nuit d'orage où le ciel s'est fendu en deux, laissant choir une étoile embrasée au cœur de nos bois. Quand j'ai brisé ce cocon de pierre et de nacre pour t'en extirper, tu n'étais qu'un souffle fragile venu d'au-delà des cieux. Je t'ai élevé ici, dans le secret de la canopée, pour te protéger de la peur et de la cruauté des hommes... Mais l'enfant sans défense a cédé la place à un être vif et vigoureux. »",
			"« Hier encore, un bûcheron égaré est venu frapper à ma cabane, le visage blême et les mains tremblantes. Il a entendu d'étranges grondements sourds émaner de la grande caverne qui plonge sous la falaise nord. Des bruits de roche broyée, des lamentations minérales... comme si les entrailles de la montagne prenaient vie.\n\nCe ne sont pas des chimères de vieillard, Naël. Lors de la chute de ton berceau céleste, un fragment primordial de l'étoile s'est disloqué et s'est engouffré tout au fond de ces galeries. Pendant des années, son énergie est restée enfouie... mais aujourd'hui, cette résonance extraterrestre s'est réveillée. Elle dénature la terre et donne naissance à des colosses de pierre agressifs qui verrouillent les profondeurs. »",
			"« Mes vieux os et mes décoctions d'herboriste ne suffiront plus à calmer ce qui fermente là-dessous. Tu as grandi, Naël. Ton agilité, ta force et ces marques de lumière qui parcourent ta peau... tout cela n'attendait que l'épreuve du monde.\n\nIl est temps de franchir le seuil. Rends-toi à l'entrée de la caverne au nord. Traverse ses boyaux, affronte les sentinelles de roche et récupère l'éclat qui gît au fond du sanctuaire. Ce n'est pas seulement pour sauver notre forêt... Ce fragment fait partie de toi. Va, mon enfant. Que le souffle des étoiles guide tes pas. »"
		]
		dm.show_dialogue("Maëlor", "L'Herboriste / La ronde du sage", pages, func():
			is_talking = false
			qm.start_quest("echo_depths")
			qm.complete_objective("echo_depths", 0) # Objectif : Parler à Maëlor validé
		)
	elif qm.is_quest_active("echo_depths") and not has_relic:
		# 2. Rappel et conseils pendant la quête
		var pages: Array[String] = [
			"« La caverne s'ouvre au pied des falaises septentrionales, en remontant le cours du ruisseau. Prends garde, Naël : les golems nés de la roche ne connaissent ni la peur ni le doute. Utilise ton agilité et ne reste jamais immobile face à leurs coups de masse. »"
		]
		dm.show_dialogue("Maëlor", "L'Herboriste / Conseils", pages, func():
			is_talking = false
		)
	else:
		# 4. Paroles bienveillantes une fois la quête terminée
		var pages: Array[String] = [
			"« Prends soin de toi, Naël. Les bois respirent plus paisiblement grâce à toi. Mais reste sur tes gardes : les mystères de ton étoile sont vastes, et d'autres secrets t'attendent au-delà de ces arbres. »"
		]
		dm.show_dialogue("Maëlor", "L'Herboriste / Bénédiction", pages, func():
			is_talking = false
		)
