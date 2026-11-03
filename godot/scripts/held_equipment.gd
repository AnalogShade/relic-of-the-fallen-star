extends Node3D
var rod: Node3D
var axe: Node3D
var dart: Node3D
var aim_reticle: Label

func _enter_tree() -> void:
	call_deferred("refresh")

func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 11
	add_child(layer)
	aim_reticle = Label.new()
	layer.add_child(aim_reticle)
	aim_reticle.text = "+"
	aim_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_reticle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aim_reticle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	aim_reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	aim_reticle.offset_left = -10
	aim_reticle.offset_right = 10
	aim_reticle.offset_top = -12
	aim_reticle.offset_bottom = 12
	aim_reticle.add_theme_font_size_override("font_size", 20)
	aim_reticle.add_theme_color_override("font_shadow_color", Color.BLACK)
	aim_reticle.add_theme_constant_override("shadow_offset_x", 1)
	aim_reticle.add_theme_constant_override("shadow_offset_y", 1)
	aim_reticle.hide()
	get_node("/root/Inventory").changed.connect(refresh)
	call_deferred("refresh")

func refresh() -> void:
	if not is_inside_tree(): return
	var skeleton := get_parent().find_child("Skeleton3D", true, false) as Skeleton3D
	if not skeleton: return
	if not is_instance_valid(rod):
		var bone := skeleton.find_bone("RightHand")
		if bone < 0: return
		var attachment := BoneAttachment3D.new()
		attachment.name = "FishingRodHand"
		skeleton.add_child(attachment)
		attachment.bone_idx = bone
		rod = load("res://assets/items/fishing_rod.glb").instantiate()
		attachment.add_child(rod)
		rod.scale = Vector3.ONE * 0.8
	if not is_instance_valid(axe):
		var attachment := BoneAttachment3D.new()
		attachment.name = "AxeHand"
		skeleton.add_child(attachment)
		attachment.bone_idx = skeleton.find_bone("RightHand")
		axe = preload("res://assets/items/axe.glb").instantiate()
		attachment.add_child(axe)
		axe.scale = Vector3.ONE / skeleton.global_basis.get_scale()
		axe.rotation = Vector3(0, 0, PI * 0.5)
	if not is_instance_valid(dart):
		var attachment := BoneAttachment3D.new()
		attachment.name = "SleepDartHand"
		skeleton.add_child(attachment)
		attachment.bone_idx = skeleton.find_bone("RightHand")
		dart = preload("res://scripts/sleep_dart.gd").make_visual()
		attachment.add_child(dart)
		dart.scale = Vector3.ONE / skeleton.global_basis.get_scale()
	dart.visible = get_node("/root/Inventory").equipped == "sleep_dart" and get_node("/root/Inventory").get_item_count("sleep_dart") > 0
	axe.visible = get_node("/root/Inventory").equipped == "axe"
	rod.visible = get_node("/root/Inventory").equipped == "fishing_rod"

func _process(_delta: float) -> void:
	if is_instance_valid(aim_reticle):
		aim_reticle.visible = is_instance_valid(axe) and axe.visible and not get_parent()._is_ui_blocking() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not get_tree().paused
	if is_instance_valid(rod) and rod.visible:
		# Carry the tool upright while its grip follows the animated palm.
		rod.global_basis = get_parent().get_node("Nael").global_basis * Basis(Vector3.RIGHT, 0.4).scaled(Vector3.ONE * 0.8)

