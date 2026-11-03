extends Node
## Gestionnaire universel de sauvegarde et de chargement pour Relic of the Fallen Star.
## Gère la persistance de l'inventaire, des reliques, des points de vie, de la position et de la scène.
## Régénère automatiquement les ennemis et les ressources de la nature au chargement.

signal game_saved(file_path: String, save_name: String)
signal game_loaded(file_path: String, save_name: String)
signal saves_updated

const SAVE_VERSION := 3

const SAVES_DIR := "user://saves"

func _ready() -> void:
	_ensure_saves_dir()

func _ensure_saves_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_recursive_absolute(SAVES_DIR)

## Renvoie le nom convivial du lieu actuel selon la scène chargée
func get_current_location_name() -> String:
	var current := get_tree().current_scene
	if not current:
		return "Aventure"
	var path := current.scene_file_path
	if path.ends_with("cave_depths.tscn"):
		return "Profondeurs de la grotte"
	elif path.ends_with("cave_room.tscn"):
		return "Entrée de la grotte"
	elif path.ends_with("cabin_room.tscn"):
		return "Cabane du forestier"
	elif path.ends_with("open_world.tscn") or path.ends_with("forest_test.tscn") or path.ends_with("playable_world.tscn"):
		return "Forêt des lueurs"
	elif path.is_empty() or current.name.begins_with("@"):
		return "Forêt des lueurs"
	else:
		return path.get_file().get_basename().capitalize()

## Liste toutes les sauvegardes existantes, triées par date décroissante
func list_saves() -> Array[Dictionary]:
	_ensure_saves_dir()
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(SAVES_DIR)
	if not dir:
		return results
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file_path := SAVES_DIR.path_join(file_name)
			var content := FileAccess.get_file_as_string(file_path)
			var json_val = JSON.parse_string(content)
			if typeof(json_val) == TYPE_DICTIONARY:
				var data: Dictionary = json_val
				data["file_path"] = file_path
				data["file_name"] = file_name
				if not data.has("timestamp"):
					data["timestamp"] = FileAccess.get_modified_time(file_path)
				results.append(data)
		file_name = dir.get_next()
	dir.list_dir_end()
	
	results.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("timestamp", 0)) > int(b.get("timestamp", 0))
	)
	return results

## Sauvegarde l'état actuel du jeu dans un fichier JSON
func save_game(custom_name: String = "", target_file_path: String = "") -> String:
	_ensure_saves_dir()
	
	var now := Time.get_unix_time_from_system()
	var date_dict := Time.get_datetime_dict_from_system()
	var datetime_str := "%04d-%02d-%02d %02d:%02d" % [
		date_dict.year, date_dict.month, date_dict.day,
		date_dict.hour, date_dict.minute
	]
	
	var loc_name := get_current_location_name()
	var final_name := custom_name.strip_edges()
	if final_name.is_empty():
		final_name = "%s (%02d:%02d)" % [loc_name, date_dict.hour, date_dict.minute]
	
	# Récupérer la scène courante
	var current_scene := get_tree().current_scene
	var scene_path := "res://scenes/world/open_world.tscn"
	if current_scene and not current_scene.scene_file_path.is_empty():
		scene_path = current_scene.scene_file_path
	
	# Récupérer l'état du joueur
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var player_health := 100.0
	var player_pos := Vector3.ZERO
	var player_rot_y := 0.0
	var camera_pitch := -0.35
	
	if player:
		player_health = player.health
		player_pos = player.global_position
		if "pivot" in player and player.pivot:
			player_rot_y = player.pivot.rotation.y
		if "arm" in player and player.arm:
			camera_pitch = player.arm.rotation.x
	
	# Récupérer l'état de l'inventaire
	var inv_stacks: Array[Dictionary] = []
	var inv_equipment: Array[String] = []
	var inv_equipped := ""
	var story_flags: Dictionary = {}
	
	var inventory := get_node_or_null("/root/Inventory")
	if inventory:
		for s in inventory.stacks:
			inv_stacks.append({"id": s.id, "quantity": int(s.quantity)})
		for eq in inventory.equipment:
			inv_equipment.append(str(eq))
		inv_equipped = str(inventory.equipped)
		
		# Filtrer les story_flags : uniquement coffres / quêtes / reliques permanentes
		# IMPORTANT : Ne JAMAIS inclure les fruits / champignons / récoltes de la nature
		# afin qu'ils réapparaissent frais et pleins au rechargement.
		for k in inventory.collected.keys():
			var key_str := str(k)
			if key_str == "camp/roast_chicken" or key_str.begins_with("cave/") or key_str.begins_with("chest/") or key_str.begins_with("relic/") or key_str.begins_with("story/") or key_str.begins_with("quest/"):
				story_flags[key_str] = inventory.collected[k]
	
	var quest_mgr = get_node_or_null("/root/QuestManager")
	var quests_save := {}
	if quest_mgr:
		quests_save = quest_mgr.save_to_dict()

	var save_data := {
		"version": SAVE_VERSION,
		"save_name": final_name,
		"timestamp": now,
		"datetime_string": datetime_str,
		"location_name": loc_name,
		"scene_file_path": scene_path,
		"player": {
			"health": player_health,
			"position": [player_pos.x, player_pos.y, player_pos.z],
			"rotation_y": player_rot_y,
			"camera_pitch": camera_pitch
		},
		"inventory": {
			"gold": inventory.gold if inventory else 0,
			"stacks": inv_stacks,
			"equipment": inv_equipment,
			"equipped": inv_equipped,
			"axe_state": inventory.axe_state if inventory else {}
		},
		"story_flags": story_flags,
		"quests": quests_save,
		"progression": Progression.save_to_dict()
	}
	
	# Déterminer le chemin du fichier
	var file_path := target_file_path
	if file_path.is_empty():
		file_path = SAVES_DIR.path_join("save_%d.json" % int(now))
	
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		push_error("Impossible d'écrire la sauvegarde : %s" % file_path)
		return ""
	
	file.store_string(JSON.stringify(save_data, "\t"))
	file.close()
	
	game_saved.emit(file_path, final_name)
	saves_updated.emit()
	return file_path

## Charge et applique une sauvegarde depuis un fichier
func load_game(file_path: String) -> bool:
	return await load_game_from_file(file_path)

func load_game_from_file(file_path: String) -> bool:
	if not FileAccess.file_exists(file_path):
		push_error("Fichier de sauvegarde introuvable : %s" % file_path)
		return false
	
	var text := FileAccess.get_file_as_string(file_path)
	var json_val = JSON.parse_string(text)
	if typeof(json_val) != TYPE_DICTIONARY:
		push_error("Données de sauvegarde corrompues dans : %s" % file_path)
		return false
	
	var data: Dictionary = json_val
	return await apply_save_data(data, file_path)

## Migration en mémoire : les fichiers originaux restent intacts.
## Les champs absents des anciennes versions utilisent les valeurs actuelles.
func normalize_save_data(source: Dictionary) -> Dictionary:
	var version = source.get("version", 1)
	if typeof(version) not in [TYPE_INT, TYPE_FLOAT] or version < 1 or version > SAVE_VERSION:
		return {}
	var data := source.duplicate(true)
	for key in ["player", "inventory", "story_flags", "quests"]:
		if typeof(data.get(key, {})) != TYPE_DICTIONARY:
			return {}
		data[key] = data.get(key, {})
	var progression_data := Progression.normalize_data(data.get("progression", {}))
	if progression_data.is_empty(): return {}
	data["progression"] = progression_data
	var saved_max_health := 100.0 + 10.0 * int(progression_data.attributes.vitality)
	var pdata: Dictionary = data.player
	var hp = pdata.get("health", 100.0)
	if typeof(hp) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(hp)):
		return {}
	pdata["health"] = clampf(float(hp), 0.0, saved_max_health)
	if pdata.has("position"):
		var pos = pdata.position
		if typeof(pos) != TYPE_ARRAY or pos.size() != 3:
			return {}
		for component in pos:
			if typeof(component) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(component)):
				return {}
	for key in ["rotation_y", "camera_pitch"]:
		if pdata.has(key):
			if typeof(pdata[key]) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(pdata[key])):
				return {}
	var inv: Dictionary = data.inventory
	var saved_gold = inv.get("gold", 0)
	if typeof(saved_gold) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(saved_gold)) or float(saved_gold) < 0:
		return {}
	inv["gold"] = int(saved_gold)
	for key in ["stacks", "equipment"]:
		if typeof(inv.get(key, [])) != TYPE_ARRAY:
			return {}
	for stack in inv.get("stacks", []):
		if typeof(stack) != TYPE_DICTIONARY:
			return {}
		if typeof(stack.get("id")) != TYPE_STRING or typeof(stack.get("quantity")) not in [TYPE_INT, TYPE_FLOAT]:
			return {}
	if typeof(inv.get("axe_state", {})) != TYPE_DICTIONARY:
		return {}
	if typeof(data.get("scene_file_path", "")) != TYPE_STRING:
		return {}
	var quests: Dictionary = data.quests
	if typeof(quests.get("active_quest_id", "")) != TYPE_STRING or typeof(quests.get("quests", {})) != TYPE_DICTIONARY:
		return {}
	for quest in quests.get("quests", {}).values():
		if typeof(quest) != TYPE_DICTIONARY:
			return {}
		if typeof(quest.get("state", 0)) not in [TYPE_INT, TYPE_FLOAT]:
			return {}
		if typeof(quest.get("objectives", {})) not in [TYPE_DICTIONARY, TYPE_ARRAY]:
			return {}
	data["version"] = SAVE_VERSION
	return data

## Applique les données de sauvegarde au jeu
func apply_save_data(data: Dictionary, file_path := "") -> bool:
	data = normalize_save_data(data)
	if data.is_empty():
		push_warning("Sauvegarde invalide ou créée par une version plus récente.")
		return false
	var inventory := get_node_or_null("/root/Inventory")
	if inventory and data.has("inventory"):
		var inv_data: Dictionary = data.inventory
		inventory.gold = int(inv_data.get("gold", 0))
		inventory.stacks.clear()
		for s in inv_data.get("stacks", []):
			inventory.stacks.append({"id": str(s.id), "quantity": int(s.quantity)})
		
		inventory.equipment.clear()
		for eq in inv_data.get("equipment", []):
			inventory.equipment.append(str(eq))
			
		inventory.equipped = str(inv_data.get("equipped", ""))
		inventory.axe_state = inv_data.get("axe_state", {})
		
		# Réinitialiser collected avec les story_flags permanents
		# Tous les fruits et champignons de la nature seront absents de collected,
		# donc ils réapparaîtront immédiatement dans la nature !
		inventory.collected.clear()
		var story_flags: Dictionary = data.get("story_flags", {})
		for k in story_flags:
			inventory.collected[k] = story_flags[k]
			
		inventory.changed.emit()

	var quest_mgr = get_node_or_null("/root/QuestManager")
	if quest_mgr and data.has("quests"):
		quest_mgr.load_from_dict(data.quests)
	
	Progression.load_from_dict(data.progression)
	
	# Réinitialiser CabinTravel si actif
	var cabin_travel := get_node_or_null("/root/CabinTravel")
	if cabin_travel:
		cabin_travel.inside = false
		cabin_travel.busy = false
		cabin_travel.interior_stack.clear()
		cabin_travel.parked_world = null
		cabin_travel.parked_parent = null
	
	# Changer de scène ou recharger
	var target_scene_path: String = data.get("scene_file_path", "res://scenes/world/open_world.tscn")
	# Ancienne scène de test, désormais réunifiée dans le monde principal.
	if target_scene_path == "res://experiments/arbres_20261014/playable_world.tscn":
		target_scene_path = "res://scenes/world/open_world.tscn"
	if not ResourceLoader.exists(target_scene_path):
		target_scene_path = "res://scenes/world/open_world.tscn"
	
	# Si la pause est active, la débloquer
	get_tree().paused = false
	
	if get_tree().change_scene_to_file(target_scene_path) != OK:
		return false
	
	# Attendre que la scène soit chargée et instanciée
	await get_tree().process_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	
	# Repositionner le joueur et restaurer ses caractéristiques
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	if player and data.has("player"):
		var pdata: Dictionary = data.player
		var pos_arr: Array = pdata.get("position", [])
		if pos_arr.size() >= 3:
			player.global_position = Vector3(float(pos_arr[0]), float(pos_arr[1]), float(pos_arr[2]))
		player.velocity = Vector3.ZERO
		player.restore_health(float(pdata.get("health", 100.0)))
		
		if pdata.has("rotation_y") and "pivot" in player and player.pivot:
			player.pivot.rotation.y = float(pdata.rotation_y)
			var nael = player.get_node_or_null("Nael")
			if nael:
				nael.rotation.y = player.pivot.rotation.y + PI
		
		if pdata.has("camera_pitch") and "arm" in player and player.arm:
			player.arm.rotation.x = float(pdata.camera_pitch)
	
	if not player:
		return false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	game_loaded.emit(file_path, str(data.get("save_name", "Sauvegarde")))
	return true

## Supprime une sauvegarde
func delete_save(file_path: String) -> bool:
	if FileAccess.file_exists(file_path):
		var err := DirAccess.remove_absolute(file_path)
		if err == OK:
			saves_updated.emit()
			return true
	return false
