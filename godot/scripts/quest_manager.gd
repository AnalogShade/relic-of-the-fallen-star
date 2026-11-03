extends Node
## Système central de gestion des quêtes et Journal de bord [ J ] pour Relic of the Fallen Star.
## Gère l'état narratif, la progression des objectifs, les notifications HUD et la persistance.

signal quest_started(quest_id: String)
signal objective_updated(quest_id: String, objective_idx: int, completed: bool)
signal quest_completed(quest_id: String)
signal journal_toggled(is_open: bool)

enum QuestState {
	NOT_STARTED = 0,
	IN_PROGRESS = 1,
	COMPLETED = 2
}

# Ordre figé du format v1, indépendant des définitions futures.
const LEGACY_OBJECTIVE_IDS := {
	"echo_depths": ["talk_maelor", "find_cave", "defeat_sentinels", "retrieve_echo", "report_maelor"]
}

# Quêtes enregistrées dans le jeu
var quests: Dictionary = {
	"cave_way_in": {
		"id": "cave_way_in", "title": "Un passage vers la caverne",
		"chapter": "Quête secondaire", "giver": "Exploration", "location": "Forêt des lueurs",
		"state": QuestState.NOT_STARTED, "skipped_intro": false,
		"description": "L'ogre m'a repoussé loin de l'entrée. Je dois parcourir la forêt pour trouver un moyen d'entrer dans la caverne.",
		"objectives": [
			{"id": "open_passage", "text": "Parcourir la forêt pour trouver un moyen d'entrer dans la caverne", "completed": false}
		]
	},
	"echo_depths": {
		"id": "echo_depths",
		"title": "L'Écho des Profondeurs",
		"chapter": "Chapitre I : L'Écho Céleste",
		"giver": "Maëlor l'Herboriste",
		"location": "Falaise nord — Caverne des Golems",
		"state": QuestState.NOT_STARTED,
		"skipped_intro": false,
		"description": "Maëlor m'a révélé l'origine des secousses qui troublent la vallée. Lors de la chute de l'étoile qui m'a conduit sur cette terre, un fragment primordial s'est écrasé au fond d'une caverne au nord. Son énergie a éveillé des sentinelles rocheuses menaçantes. Maëlor m'a demandé de braver ces profondeurs pour récupérer l'éclat ancestral et purifier le sanctuaire.",
		"objectives": [
			{"id": "talk_maelor", "text": "Parler à Maëlor entre sa maison et la caverne", "completed": false},
			{"id": "find_cave", "text": "Trouver l'entrée de la caverne au pied de la falaise nord", "completed": false},
			{"id": "defeat_sentinels", "text": "Explorer les galeries et affronter les sentinelles rocheuses", "completed": false},
			{"id": "retrieve_echo", "text": "Récupérer l'Éclat du Premier Écho dans le sanctuaire souterrain", "completed": false},
			{"id": "report_maelor", "text": "Rapporter la nouvelle à Maëlor", "completed": false}
		]
	}
}

var active_quest_id := ""
var is_journal_open := false
var previous_mouse := Input.MOUSE_MODE_CAPTURED

# Alertes et étincelles de quête active
var has_quest_alert := false
var alert_time := 0.0
var hud_btn_halo: Panel
var sparkle_particles: CPUParticles2D
var sparkle_icon_left: Label
var sparkle_icon_right: Label

# Composants d'interface (HUD + Fenêtre Journal)
var ui_layer: CanvasLayer
var hud_btn: Button
var journal_shade: ColorRect
var journal_panel: PanelContainer
var journal_title_lbl: Label
var journal_status_badge: Label
var journal_meta_lbl: Label
var journal_desc_lbl: RichTextLabel
var journal_objectives_box: VBoxContainer
var quest_picker: OptionButton

const GOLD := Color("d9ba7c")
const INK := Color("171e1d")
const SUB_GOLD := Color("8da79c")
const PARCHMENT := Color("e8e1cc")
const SUCCESS_GREEN := Color("68c287")
const BORDER_COLOR := Color("45514a")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	_update_hud_button()

func _style(bg: Color, border: Color, width := 1, radius := 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	return box

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "QuestJournalLayer"
	ui_layer.layer = 75
	add_child(ui_layer)
	
	# Bouton HUD [ J ] Journal (discret en bas à droite)
	hud_btn = Button.new()
	hud_btn.name = "HUDJournalButton"
	hud_btn.text = "J   Journal"
	hud_btn.focus_mode = Control.FOCUS_NONE
	hud_btn.custom_minimum_size = Vector2(110, 32)
	hud_btn.add_theme_font_size_override("font_size", 14)
	hud_btn.add_theme_color_override("font_color", SUB_GOLD)
	hud_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	hud_btn.add_theme_stylebox_override("normal", _style(Color("1a2422", 0.75), BORDER_COLOR, 1, 4))
	hud_btn.add_theme_stylebox_override("hover", _style(Color("253531", 0.9), GOLD, 1, 4))
	hud_btn.add_theme_stylebox_override("pressed", _style(Color("304840", 0.95), GOLD, 2, 4))
	ui_layer.add_child(hud_btn)
	
	hud_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	hud_btn.offset_left = -155
	hud_btn.offset_top = -65
	hud_btn.offset_right = -35
	hud_btn.offset_bottom = -33
	hud_btn.pressed.connect(func(): set_journal_open(not is_journal_open))
	
	# Halo lumineux doré autour du bouton HUD
	hud_btn_halo = Panel.new()
	hud_btn_halo.name = "HUDGlowHalo"
	hud_btn_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_btn_halo.add_theme_stylebox_override("panel", _style(Color(0.9, 0.75, 0.4, 0.15), Color("ffd700"), 2, 6))
	hud_btn_halo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_btn_halo.offset_left = -3
	hud_btn_halo.offset_top = -3
	hud_btn_halo.offset_right = 3
	hud_btn_halo.offset_bottom = 3
	hud_btn_halo.visible = false
	hud_btn.add_child(hud_btn_halo)
	
	# Particules d'étincelles dorées
	sparkle_particles = CPUParticles2D.new()
	sparkle_particles.name = "SparkleParticles"
	sparkle_particles.position = Vector2(55, 16)
	sparkle_particles.emitting = false
	sparkle_particles.amount = 14
	sparkle_particles.lifetime = 0.85
	sparkle_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	sparkle_particles.emission_rect_extents = Vector2(58, 18)
	sparkle_particles.direction = Vector2(0, -1)
	sparkle_particles.spread = 180.0
	sparkle_particles.gravity = Vector2(0, -20)
	sparkle_particles.initial_velocity_min = 8.0
	sparkle_particles.initial_velocity_max = 22.0
	sparkle_particles.scale_amount_min = 2.0
	sparkle_particles.scale_amount_max = 3.6
	sparkle_particles.color = Color("fff0a0")
	sparkle_particles.z_index = 2
	hud_btn.add_child(sparkle_particles)
	
	# Étincelles étoiles fixes animées
	sparkle_icon_left = Label.new()
	sparkle_icon_left.name = "SparkleLeft"
	sparkle_icon_left.text = "✦"
	sparkle_icon_left.add_theme_font_size_override("font_size", 14)
	sparkle_icon_left.add_theme_color_override("font_color", Color("fff4b8"))
	sparkle_icon_left.position = Vector2(-12, -8)
	sparkle_icon_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkle_icon_left.visible = false
	hud_btn.add_child(sparkle_icon_left)
	
	sparkle_icon_right = Label.new()
	sparkle_icon_right.name = "SparkleRight"
	sparkle_icon_right.text = "✦"
	sparkle_icon_right.add_theme_font_size_override("font_size", 13)
	sparkle_icon_right.add_theme_color_override("font_color", Color("ffd700"))
	sparkle_icon_right.position = Vector2(108, -6)
	sparkle_icon_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sparkle_icon_right.visible = false
	hud_btn.add_child(sparkle_icon_right)
	
	# Ombre d'arrière-plan du Journal (GARANTIE INVISIBLE AU DÉMARRAGE)
	journal_shade = ColorRect.new()
	journal_shade.color = Color(0.02, 0.03, 0.03, 0.65)
	journal_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	journal_shade.mouse_filter = Control.MOUSE_FILTER_PASS
	journal_shade.visible = false
	ui_layer.add_child(journal_shade)
	
	# Panneau Modal du Journal (GARANTI INVISIBLE AU DÉMARRAGE)
	journal_panel = PanelContainer.new()
	journal_panel.name = "JournalPanel"
	journal_panel.add_theme_stylebox_override("panel", _style(INK, GOLD, 2, 8))
	journal_panel.visible = false
	ui_layer.add_child(journal_panel)
	
	journal_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	journal_panel.offset_left = -380
	journal_panel.offset_right = 380
	journal_panel.offset_top = -260
	journal_panel.offset_bottom = 260
	
	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 12)
	journal_panel.add_child(main_vbox)
	
	# En-tête : Titre général + Sous-titre + Bouton Fermer
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_vbox.add_child(header)
	
	var header_titles := VBoxContainer.new()
	header_titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_titles.add_theme_constant_override("separation", 2)
	header.add_child(header_titles)
	
	var app_title := Label.new()
	app_title.text = "JOURNAL DE QUÊTES"
	app_title.add_theme_font_size_override("font_size", 24)
	app_title.add_theme_color_override("font_color", GOLD)
	app_title.add_theme_color_override("font_shadow_color", Color.BLACK)
	app_title.add_theme_constant_override("shadow_offset_x", 1)
	app_title.add_theme_constant_override("shadow_offset_y", 1)
	header_titles.add_child(app_title)
	
	var app_sub := Label.new()
	app_sub.text = "NAËL   /   FORÊT DES LUEURS"
	app_sub.add_theme_font_size_override("font_size", 12)
	app_sub.add_theme_color_override("font_color", SUB_GOLD)
	header_titles.add_child(app_sub)
	
	var close_btn := Button.new()
	close_btn.text = "Fermer  [ J ]"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(100, 34)
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_color_override("font_color", PARCHMENT)
	close_btn.add_theme_color_override("font_hover_color", GOLD)
	close_btn.add_theme_stylebox_override("normal", _style(Color("1e2926"), BORDER_COLOR, 1, 4))
	close_btn.add_theme_stylebox_override("hover", _style(Color("2a3a35"), GOLD, 1, 4))
	close_btn.add_theme_stylebox_override("pressed", _style(Color("3b4e46"), GOLD, 2, 4))
	close_btn.pressed.connect(func(): set_journal_open(false))
	header.add_child(close_btn)
	
	main_vbox.add_child(HSeparator.new())
	quest_picker = OptionButton.new()
	quest_picker.focus_mode = Control.FOCUS_NONE
	main_vbox.add_child(quest_picker)
	quest_picker.item_selected.connect(func(index: int):
		active_quest_id = str(quest_picker.get_item_metadata(index))
		refresh_journal_ui()
		_update_hud_button())
	
	# Conteneur défilable pour le contenu de la quête
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	main_vbox.add_child(scroll)
	
	var content_vbox := VBoxContainer.new()
	content_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_vbox.add_theme_constant_override("separation", 10)
	scroll.add_child(content_vbox)
	
	# Bandeau titre de quête avec badge de statut
	var q_header := HBoxContainer.new()
	q_header.add_theme_constant_override("separation", 10)
	content_vbox.add_child(q_header)
	
	journal_title_lbl = Label.new()
	journal_title_lbl.text = "Aucune quête active"
	journal_title_lbl.add_theme_font_size_override("font_size", 19)
	journal_title_lbl.add_theme_color_override("font_color", GOLD)
	journal_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_header.add_child(journal_title_lbl)
	
	journal_status_badge = Label.new()
	journal_status_badge.text = ""
	journal_status_badge.add_theme_font_size_override("font_size", 12)
	q_header.add_child(journal_status_badge)
	
	journal_meta_lbl = Label.new()
	journal_meta_lbl.text = ""
	journal_meta_lbl.add_theme_font_size_override("font_size", 13)
	journal_meta_lbl.add_theme_color_override("font_color", SUB_GOLD)
	content_vbox.add_child(journal_meta_lbl)
	
	# Récit de la quête
	journal_desc_lbl = RichTextLabel.new()
	journal_desc_lbl.bbcode_enabled = true
	journal_desc_lbl.fit_content = true
	journal_desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_desc_lbl.add_theme_font_size_override("normal_font_size", 14)
	journal_desc_lbl.add_theme_font_size_override("italics_font_size", 14)
	journal_desc_lbl.add_theme_color_override("default_color", PARCHMENT)
	journal_desc_lbl.add_theme_constant_override("line_separation", 4)
	content_vbox.add_child(journal_desc_lbl)
	
	content_vbox.add_child(HSeparator.new())
	
	var obj_title := Label.new()
	obj_title.text = "OBJECTIFS :"
	obj_title.add_theme_font_size_override("font_size", 15)
	obj_title.add_theme_color_override("font_color", GOLD)
	content_vbox.add_child(obj_title)
	
	journal_objectives_box = VBoxContainer.new()
	journal_objectives_box.add_theme_constant_override("separation", 6)
	content_vbox.add_child(journal_objectives_box)
	
	# Masquer le journal au démarrage de manière explicite
	is_journal_open = false
	journal_shade.visible = false
	journal_panel.visible = false

func _process(delta: float) -> void:
	if has_quest_alert and is_instance_valid(hud_btn):
		alert_time += delta * 4.5
		var pulse := (sin(alert_time) * 0.5) + 0.5
		
		if is_instance_valid(hud_btn_halo):
			hud_btn_halo.visible = true
			hud_btn_halo.modulate.a = 0.35 + (pulse * 0.65)
			
		if is_instance_valid(sparkle_icon_left):
			sparkle_icon_left.visible = true
			sparkle_icon_left.modulate.a = 0.4 + (pulse * 0.6)
			sparkle_icon_left.scale = Vector2.ONE * (0.8 + (pulse * 0.35))
			
		var pulse_r := (sin(alert_time + 2.0) * 0.5) + 0.5
		if is_instance_valid(sparkle_icon_right):
			sparkle_icon_right.visible = true
			sparkle_icon_right.modulate.a = 0.4 + (pulse_r * 0.6)
			sparkle_icon_right.scale = Vector2.ONE * (0.8 + (pulse_r * 0.35))
			
		if is_instance_valid(sparkle_particles) and not sparkle_particles.emitting:
			sparkle_particles.emitting = true
	else:
		if is_instance_valid(hud_btn_halo) and hud_btn_halo.visible:
			hud_btn_halo.visible = false
		if is_instance_valid(sparkle_icon_left) and sparkle_icon_left.visible:
			sparkle_icon_left.visible = false
		if is_instance_valid(sparkle_icon_right) and sparkle_icon_right.visible:
			sparkle_icon_right.visible = false
		if is_instance_valid(sparkle_particles) and sparkle_particles.emitting:
			sparkle_particles.emitting = false

func _update_hud_button() -> void:
	if not is_instance_valid(hud_btn): return
	var has_quest: bool = not active_quest_id.is_empty() and quests.has(active_quest_id)
	if has_quest_alert:
		hud_btn.text = "✦ J   Quête ✦"
		hud_btn.add_theme_color_override("font_color", Color("fff3a8"))
	elif has_quest and quests[active_quest_id].state == QuestState.IN_PROGRESS:
		hud_btn.text = "J   Quête  ●"
		hud_btn.add_theme_color_override("font_color", GOLD)
	elif has_quest and quests[active_quest_id].state == QuestState.COMPLETED:
		hud_btn.text = "J   Journal  ✓"
		hud_btn.add_theme_color_override("font_color", SUCCESS_GREEN)
	else:
		hud_btn.text = "J   Journal"
		hud_btn.add_theme_color_override("font_color", SUB_GOLD)

func start_guardian_search() -> void:
	if preload("res://scripts/cave_access.gd").passage_open(self): return
	if quests.cave_way_in.state == QuestState.NOT_STARTED:
		start_quest("cave_way_in")

func complete_guardian_search() -> void:
	if not is_quest_active("cave_way_in"): return
	complete_quest("cave_way_in")
	if is_quest_active("echo_depths"):
		active_quest_id = "echo_depths"
		_update_hud_button()
		refresh_journal_ui()

func start_quest(quest_id: String) -> void:
	if not quests.has(quest_id): return
	var q: Dictionary = quests[quest_id]
	q.state = QuestState.IN_PROGRESS
	active_quest_id = quest_id
	
	# Activer l'étincelle et le halo d'alerte autour du bouton HUD
	has_quest_alert = true
	alert_time = 0.0
	
	var inv = get_node_or_null("/root/Inventory")
	if inv:
		inv.ui.notify("Nouvelle quête : %s  [ J ]" % q.title)
		inv.collected["quest/" + quest_id + "_state"] = QuestState.IN_PROGRESS
		
	_update_hud_button()
	refresh_journal_ui()
	quest_started.emit(quest_id)

## Démarre automatiquement la quête si le joueur explore la caverne sans parler préalablement à Maëlor.
func start_quest_from_cave(quest_id: String = "echo_depths") -> void:
	if not quests.has(quest_id): return
	var q: Dictionary = quests[quest_id]
	if q.state != QuestState.NOT_STARTED:
		complete_objective(quest_id, 1)
		return
	
	q.skipped_intro = true
	q.description = "Attiré par de sourds grondements sous la falaise septentrionale, j'ai découvert l'entrée d'une mystérieuse caverne. Une étrange résonance minérale vibre depuis les profondeurs, comme si un fragment d'étoile y sommeillait, gardé par d'anciennes sentinelles de pierre."
	if q.objectives.size() > 0:
		q.objectives[0].text = "Découvrir l'origine des secousses sous la falaise nord"
	
	start_quest(quest_id)
	complete_objective(quest_id, 0) # Découverte initiale de la caverne
	complete_objective(quest_id, 1) # Entrée de la caverne trouvée
	
	var inv = get_node_or_null("/root/Inventory")
	if inv:
		inv.collected["quest/" + quest_id + "_skipped_intro"] = true

func is_quest_intro_skipped(quest_id: String) -> bool:
	if not quests.has(quest_id): return false
	return bool(quests[quest_id].get("skipped_intro", false))

func complete_objective(quest_id: String, objective_identifier) -> void:
	if not quests.has(quest_id): return
	var q: Dictionary = quests[quest_id]
	var objs: Array = q.objectives
	
	var idx := -1
	if typeof(objective_identifier) == TYPE_INT:
		idx = objective_identifier
	elif typeof(objective_identifier) == TYPE_STRING:
		for i in range(objs.size()):
			if objs[i].id == objective_identifier:
				idx = i
				break
				
	if idx < 0 or idx >= objs.size(): return
	if objs[idx].completed: return
	
	objs[idx].completed = true
	var inv = get_node_or_null("/root/Inventory")
	if inv:
		inv.ui.notify("Objectif accompli : %s" % objs[idx].text)
		inv.collected["quest/" + quest_id + "_obj_" + str(idx)] = true
		
	_update_hud_button()
	refresh_journal_ui()
	objective_updated.emit(quest_id, idx, true)

func is_objective_completed(quest_id: String, objective_idx: int) -> bool:
	if not quests.has(quest_id): return false
	var objs: Array = quests[quest_id].objectives
	if objective_idx < 0 or objective_idx >= objs.size(): return false
	return objs[objective_idx].completed

func complete_quest(quest_id: String) -> void:
	if not quests.has(quest_id): return
	var q: Dictionary = quests[quest_id]
	q.state = QuestState.COMPLETED
	has_quest_alert = false
	
	# Marquer tous les objectifs comme accomplis par précaution
	for obj in q.objectives:
		obj.completed = true
		
	var inv = get_node_or_null("/root/Inventory")
	if inv:
		inv.ui.notify("Quête accomplie : %s !" % q.title)
		inv.collected["quest/" + quest_id + "_state"] = QuestState.COMPLETED
		
	_update_hud_button()
	refresh_journal_ui()
	quest_completed.emit(quest_id)

func is_quest_active(quest_id: String) -> bool:
	if not quests.has(quest_id): return false
	return quests[quest_id].state == QuestState.IN_PROGRESS

func is_quest_completed(quest_id: String) -> bool:
	if not quests.has(quest_id): return false
	return quests[quest_id].state == QuestState.COMPLETED

func get_active_quest() -> Dictionary:
	if active_quest_id.is_empty() or not quests.has(active_quest_id):
		return {}
	return quests[active_quest_id]

func refresh_journal_ui() -> void:
	if not is_instance_valid(journal_panel): return
	quest_picker.clear()
	for quest in quests.values():
		if quest.state == QuestState.NOT_STARTED: continue
		var index := quest_picker.item_count
		quest_picker.add_item(quest.title + ("  ✓" if quest.state == QuestState.COMPLETED else ""))
		quest_picker.set_item_metadata(index, quest.id)
		if quest.id == active_quest_id: quest_picker.select(index)
	quest_picker.visible = quest_picker.item_count > 1
	
	# Vider les objectifs existants
	for child in journal_objectives_box.get_children():
		child.queue_free()
		
	var q := get_active_quest()
	if q.is_empty() or q.state == QuestState.NOT_STARTED:
		journal_title_lbl.text = "Aucune quête en cours"
		journal_status_badge.text = ""
		journal_meta_lbl.text = ""
		journal_desc_lbl.text = "[i]Explorez la forêt des lueurs et parlez aux habitants, tel que Maëlor l'herboriste près du ruisseau, pour trouver votre voie.[/i]"
		var empty_lbl := Label.new()
		empty_lbl.text = "— Aucun objectif pour le moment —"
		empty_lbl.add_theme_font_size_override("font_size", 14)
		empty_lbl.add_theme_color_override("font_color", SUB_GOLD)
		journal_objectives_box.add_child(empty_lbl)
		return
		
	journal_title_lbl.text = q.title.to_upper()
	journal_meta_lbl.text = "%s   ·   Commanditaire : %s   ·   Lieu : %s" % [q.chapter, q.giver, q.location]
	journal_desc_lbl.text = "[i]« %s »[/i]" % q.description
	if q.id == "echo_depths":
		var note := preload("res://scripts/cave_access.gd").journal_note(self)
		if not note.is_empty(): journal_desc_lbl.text += "\n\n" + note
	
	if q.state == QuestState.COMPLETED:
		journal_status_badge.text = "  ACCOMPLIE ✓  "
		journal_status_badge.add_theme_color_override("font_color", INK)
		journal_status_badge.add_theme_stylebox_override("normal", _style(SUCCESS_GREEN, Color.TRANSPARENT, 0, 4))
	elif q.state == QuestState.IN_PROGRESS:
		journal_status_badge.text = "  EN COURS  "
		journal_status_badge.add_theme_color_override("font_color", INK)
		journal_status_badge.add_theme_stylebox_override("normal", _style(GOLD, Color.TRANSPARENT, 0, 4))
	else:
		journal_status_badge.text = ""
		
	for obj in q.objectives:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		journal_objectives_box.add_child(row)
		
		var icon := Label.new()
		icon.add_theme_font_size_override("font_size", 15)
		var text := Label.new()
		text.text = obj.text
		text.add_theme_font_size_override("font_size", 14)
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		
		if obj.completed:
			icon.text = "[ ✓ ]"
			icon.add_theme_color_override("font_color", SUCCESS_GREEN)
			text.add_theme_color_override("font_color", SUCCESS_GREEN)
		else:
			icon.text = "[ ○ ]"
			icon.add_theme_color_override("font_color", SUB_GOLD)
			text.add_theme_color_override("font_color", PARCHMENT)
			
		row.add_child(icon)
		row.add_child(text)

func set_journal_open(value: bool) -> void:
	if value == is_journal_open:
		# S'assurer tout de même que les nœuds visuels correspondent
		journal_shade.visible = is_journal_open
		journal_panel.visible = is_journal_open
		return
	is_journal_open = value
	
	if is_journal_open:
		# Dès que le joueur ouvre le journal, l'alerte d'étincelles s'estompe
		has_quest_alert = false
		_update_hud_button()
		
		var inv = get_node_or_null("/root/Inventory")
		if inv and inv.is_open:
			inv.set_open(false)
			
		var dlg = get_node_or_null("/root/DialogueManager")
		if dlg and dlg.is_open:
			dlg.hide_dialogue()
			
		previous_mouse = Input.mouse_mode
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		refresh_journal_ui()
	else:
		var dlg = get_node_or_null("/root/DialogueManager")
		var inv = get_node_or_null("/root/Inventory")
		var pause = get_node_or_null("/root/PauseMenu")
		var other_open: bool = (dlg and dlg.is_open) or (inv and inv.is_open) or (pause and pause.is_open)
		if not other_open:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	journal_shade.visible = is_journal_open
	journal_panel.visible = is_journal_open
	journal_toggled.emit(is_journal_open)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		if is_journal_open:
			set_journal_open(false)
			get_viewport().set_input_as_handled()
		return
		
	# Action journal (touche J configurée) ou touche J directe
	var is_j_pressed := false
	if event.is_action_pressed("journal"):
		is_j_pressed = true
	elif event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_J:
		is_j_pressed = true
		
	if is_j_pressed:
		var cabin = get_node_or_null("/root/CabinTravel")
		if cabin and cabin.busy: return
		set_journal_open(not is_journal_open)
		get_viewport().set_input_as_handled()

func save_to_dict() -> Dictionary:
	var quests_save: Dictionary = {}
	for q_id in quests.keys():
		var q: Dictionary = quests[q_id]
		var objs_save: Dictionary = {}
		for o in q.objectives:
			objs_save[str(o.id)] = bool(o.completed)
		quests_save[q_id] = {
			"state": int(q.state),
			"skipped_intro": bool(q.get("skipped_intro", false)),
			"objectives": objs_save
		}
	return {
		"active_quest_id": active_quest_id,
		"quests": quests_save
	}

func load_from_dict(data: Dictionary) -> void:
	# Chaque chargement repart des définitions actuelles, y compris les nouveaux objectifs.
	for quest in quests.values():
		quest.state = QuestState.NOT_STARTED
		quest["skipped_intro"] = false
		for objective in quest.objectives:
			objective.completed = false
	active_quest_id = data.get("active_quest_id", "")
	var saved_quests: Dictionary = data.get("quests", {})
	for q_id in saved_quests.keys():
		if not quests.has(q_id): continue
		var q_data: Dictionary = saved_quests[q_id]
		quests[q_id].state = int(q_data.get("state", 0))
		var was_skipped: bool = bool(q_data.get("skipped_intro", false))
		var inv = get_node_or_null("/root/Inventory")
		if inv and inv.collected.get("quest/" + q_id + "_skipped_intro", false):
			was_skipped = true
		quests[q_id]["skipped_intro"] = was_skipped
		if was_skipped:
			quests[q_id].description = "Attiré par de sourds grondements sous la falaise septentrionale, j'ai découvert l'entrée d'une mystérieuse caverne. Une étrange résonance minérale vibre depuis les profondeurs, comme si un fragment d'étoile y sommeillait, gardé par d'anciennes sentinelles de pierre."
			if quests[q_id].objectives.size() > 0:
				quests[q_id].objectives[0].text = "Découvrir l'origine des secousses sous la falaise nord"
		var objs_save = q_data.get("objectives", {})
		var q_objs: Array = quests[q_id].objectives
		if typeof(objs_save) == TYPE_DICTIONARY:
			for objective in q_objs:
				objective.completed = bool(objs_save.get(str(objective.id), false))
		else: # Format historique v1 : objectifs dans leur ordre d'origine.
			var legacy_ids: Array = LEGACY_OBJECTIVE_IDS.get(q_id, [])
			for objective in q_objs:
				var legacy_index := legacy_ids.find(str(objective.id))
				if legacy_index >= 0 and legacy_index < objs_save.size():
					objective.completed = bool(objs_save[legacy_index])
			
	# Reconcile older saves and saves made during the sleep transition.
	var inventory := get_node_or_null("/root/Inventory")
	var access = preload("res://scripts/cave_access.gd")
	if inventory and inventory.collected.get(access.REPELLED, false):
		var search: Dictionary = quests.cave_way_in
		if access.passage_open(self):
			search.state = QuestState.COMPLETED
			search.objectives[0].completed = true
		elif search.state == QuestState.NOT_STARTED:
			search.state = QuestState.IN_PROGRESS
			active_quest_id = "cave_way_in"
	_update_hud_button()
	refresh_journal_ui()
