extends Node3D
## Proximity invitation; cancel rearms only after stepping away.
@export var returning := false
@export var reach := 2.5
var was_near := false
var dialog: ConfirmationDialog
var actor: CharacterBody3D
var previous_mode: Node.ProcessMode
var previous_mouse: Input.MouseMode

func _ready() -> void:
	add_to_group("interactable")
	dialog = ConfirmationDialog.new()
	dialog.title = "La descente des échos"
	dialog.dialog_text = "Voulez-vous revenir dans la salle d’entrée ?" if returning else "Voulez-vous entrer dans la caverne ?"
	dialog.ok_button_text = "Revenir" if returning else "Entrer"
	dialog.cancel_button_text = "Rester ici"
	dialog.min_size = Vector2i(460, 160)
	var ui: CanvasLayer = get_node("/root/Inventory").ui
	dialog.add_theme_stylebox_override("panel", ui.style(Color("172321"), ui.gold, 2))
	dialog.add_theme_color_override("title_color", ui.gold)
	dialog.get_label().add_theme_color_override("font_color", Color("e8e1cc"))
	for button in [dialog.get_ok_button(), dialog.get_cancel_button()]:
		button.custom_minimum_size = Vector2(150, 42)
		button.add_theme_stylebox_override("normal", ui.style(Color("202e29"), Color("536052")))
		button.add_theme_stylebox_override("hover", ui.style(Color("35463d"), ui.gold))
		button.add_theme_stylebox_override("focus", ui.style(Color("35463d"), ui.gold, 2))
		button.add_theme_color_override("font_color", Color("e8e1cc"))
	dialog.confirmed.connect(_confirm)
	dialog.canceled.connect(_cancel)
	add_child(dialog)

func _near() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	return player != null and player.global_position.distance_to(global_position) < reach

func _physics_process(_delta: float) -> void:
	var near := _near()
	if near and not was_near and not get_node("/root/CabinTravel").busy and not get_node("/root/Inventory").is_open:
		interact()
	was_near = near

func interaction_text() -> String:
	return "Revenir à la salle d’entrée" if returning else "Entrer dans la caverne"

func can_interact() -> bool:
	return not get_node("/root/CabinTravel").busy and _near()

func interact() -> void:
	if not can_interact(): return
	actor = get_tree().get_first_node_in_group("player") as CharacterBody3D
	previous_mode = actor.process_mode
	previous_mouse = Input.mouse_mode
	actor.velocity = Vector3.ZERO
	actor.process_mode = Node.PROCESS_MODE_DISABLED
	var travel := get_node("/root/CabinTravel")
	travel.busy = true
	travel.confirmation_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	dialog.popup_centered()
	dialog.get_ok_button().grab_focus()

func _release() -> void:
	dialog.hide()
	if is_instance_valid(actor): actor.process_mode = previous_mode
	Input.mouse_mode = previous_mouse
	var travel := get_node("/root/CabinTravel")
	travel.busy = false
	travel.confirmation_open = false

func _cancel() -> void:
	_release()

func _confirm() -> void:
	_release()
	var travel := get_node("/root/CabinTravel")
	if returning: travel.call_deferred("leave_subroom")
	else: travel.call_deferred("enter_subroom", "res://scenes/interiors/cave_depths.tscn")
