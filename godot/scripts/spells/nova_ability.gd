extends Node
const COOLDOWN := 7.0
var cooldown := 0.0
var hint: Label
var actor: CharacterBody3D

func _ready() -> void:
	actor = get_parent() as CharacterBody3D
	hint = Label.new()
	hint.position = Vector2(24, 182)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_font_size_override("font_size", 17)
	hint.add_theme_color_override("font_color", Color("9aefe0"))
	hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	hint.add_theme_constant_override("shadow_offset_x", 2)
	hint.add_theme_constant_override("shadow_offset_y", 2)
	var hud := CanvasLayer.new()
	hud.layer = 14
	add_child(hud)
	hud.add_child(hint)

func _physics_process(delta: float) -> void:
	if not actor._is_ui_blocking(): cooldown = maxf(0, cooldown - delta)
	hint.visible = get_node("/root/Inventory").equipment.has("primordial_wave")
	hint.text = "Q · Onde primordiale  ·  %0.1f s" % cooldown if cooldown > 0 else "Q · Onde primordiale  ·  PRÊTE"

func try_cast() -> bool:
	var bag := get_node("/root/Inventory")
	if not bag.equipment.has("primordial_wave") or bag.is_open or actor._is_ui_blocking(): return false
	if get_tree().paused or get_node("/root/CabinTravel").busy or actor.health <= 0 or actor.guardian_knockback > 0 or actor.rest_state != "" or actor.swimming or actor.dodge.active or actor.is_attacking or cooldown > 0: return false
	actor.cancel_fireball_aim()
	var nova := preload("res://scripts/spells/primordial_nova.gd").new()
	nova.damage *= get_node("/root/Progression").magic_multiplier()
	actor.get_parent().add_child(nova)
	nova.global_position = actor.global_position
	cooldown = COOLDOWN
	return true
