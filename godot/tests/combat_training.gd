extends Node3D
## F6 this scene. Number keys replace the opponent and reset both combatants.
var player
var opponent
var info: Label
var selected_temperament := "equilibre"
var selected_archetype := "bandit"
var selected_variant := "standard"

func _ready() -> void:
	get_node("/root/Inventory").add_item("first_echo")
	var floor_body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(36, 1, 36)
	collider.shape = box
	floor_body.position.y = -0.5
	floor_body.add_child(collider)
	var mesh := MeshInstance3D.new()
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = box.size
	mesh.mesh = floor_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.23, 0.24)
	mesh.material_override = material
	floor_body.add_child(mesh)
	add_child(floor_body)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.4
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.07, 0.11, 0.16)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.8, 1)
	env.environment.ambient_light_energy = 0.6
	add_child(env)
	player = preload("res://scenes/player.tscn").instantiate()
	player.position = Vector3(0, 0.1, 3)
	player.world_bounds = Rect2(-17, -17, 34, 34)
	add_child(player)
	var ui := CanvasLayer.new()
	add_child(ui)
	info = Label.new()
	info.position = Vector2(24, 220)
	info.add_theme_font_size_override("font_size", 19)
	info.add_theme_color_override("font_shadow_color", Color.BLACK)
	info.add_theme_constant_override("shadow_offset_x", 2)
	info.add_theme_constant_override("shadow_offset_y", 2)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(info)
	_spawn("bandit")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo(): return
	var key := event as InputEventKey
	if key == null or get_node("/root/Inventory").is_open: return
	match key.physical_keycode:
		KEY_1: _spawn("bandit")
		KEY_2: _spawn("araignee")
		KEY_3: _spawn("golem")
		KEY_4: _spawn("golem", "petit")
		KEY_5: _spawn("golem", "grand")
		KEY_T:
			var profiles := ["equilibre", "agressif", "prudent", "peureux", "auto"]
			selected_temperament = profiles[(profiles.find(selected_temperament) + 1) % profiles.size()]
			_spawn(selected_archetype, selected_variant)

func _spawn(archetype: String, variant := "standard") -> void:
	selected_archetype = archetype
	selected_variant = variant
	if is_instance_valid(opponent):
		remove_child(opponent)
		opponent.queue_free()
	# Clear in-flight spells when resetting the training duel.
	for child in get_children():
		if child is Area3D and child.get_script() == preload("res://scripts/spells/fireball_projectile.gd"):
			child.queue_free()
	player.respawn()
	player.pivot.rotation.y = 0
	player.fireball_cooldown = 0
	opponent = load("res://scenes/%s.tscn" % archetype).instantiate()
	opponent.temperament = selected_temperament
	opponent.name = "TrainingOpponent"
	if archetype == "golem": opponent.golem_type = variant
	opponent.position = Vector3(0, 0.1, -2)
	add_child(opponent)
	info.text = "ENTRAÎNEMENT — %s (%s)\n1 Bandit · 2 Araignée · 3 Golem · 4 Petit · 5 Grand\nT : changer de tempérament et recommencer\nClic gauche : griffe · Clic droit : boule de feu\nOrange : prépare son coup · Vert : ouverture (+%d %% dégâts)\nEsquivez sur le côté, interrompez, puis profitez de la récupération." % [archetype.capitalize(), opponent.combat.temperament, roundi((float(opponent.combat.profile.opening) - 1.0) * 100)]
