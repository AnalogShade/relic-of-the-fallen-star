extends Node3D
const OPEN_KEY := "cave/echo_chest_open"
const LOOT_KEY := "cave/first_echo"
var opened := false
var animating := false
var lid: Node3D
var relic: Node3D
var glow: OmniLight3D
var time := 0.0

func _ready() -> void:
	add_to_group("interactable")
	var base: Node3D = load("res://assets/environment/world/echo_chest.glb").instantiate()
	add_child(base)
	lid = load("res://assets/environment/world/echo_chest_lid.glb").instantiate()
	lid.name = "Lid"
	lid.position = Vector3(0, 0.82, -0.5)
	add_child(lid)
	relic = load("res://assets/environment/world/first_echo.glb").instantiate()
	relic.name = "Relic"
	relic.position = Vector3(0, 1.08, 0)
	add_child(relic)
	glow = OmniLight3D.new()
	glow.position = Vector3(0, 1.4, 0)
	glow.light_color = Color("70eed8")
	glow.light_energy = 0.8
	glow.omni_range = 3.0
	add_child(glow)
	var body := StaticBody3D.new()
	body.name = "ChestCollision"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.85, 0.86, 1.12)
	shape.shape = box
	shape.position.y = 0.43
	body.add_child(shape)
	add_child(body)
	var inventory := get_node("/root/Inventory")
	opened = inventory.collected.has(OPEN_KEY)
	lid.rotation.x = -1.85 if opened else 0.0
	relic.visible = opened and not inventory.collected.has(LOOT_KEY)
	glow.visible = relic.visible

func interaction_text() -> String:
	return "Prendre l’Éclat du Premier Écho" if opened else "Ouvrir le coffre"

func can_interact() -> bool:
	var inventory := get_node("/root/Inventory")
	if animating or inventory.collected.has(LOOT_KEY) or get_node("/root/CabinTravel").busy: return false
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if not player: return false
	var p := to_local(player.global_position)
	return p.z > 0.5 and absf(p.x) < 1.6 and p.length() < 2.5

func interact() -> void:
	if not can_interact(): return
	var inventory := get_node("/root/Inventory")
	if not opened:
		animating = true
		opened = true
		inventory.collected[OPEN_KEY] = true
		var tween := create_tween()
		tween.tween_property(lid, "rotation:x", -1.85, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		await tween.finished
		relic.show()
		glow.show()
		animating = false
		return
	if not inventory.add_item("first_echo"):
		inventory.ui.notify("Plus de place dans l’équipement")
		return
	inventory.collected[LOOT_KEY] = true
	relic.hide()
	glow.hide()
	inventory.ui.notify("Éclat du Premier Écho ajouté à l’équipement")
	var qm = get_node_or_null("/root/QuestManager")
	if qm:
		if not qm.is_quest_active("echo_depths") and not qm.is_quest_completed("echo_depths"):
			qm.start_quest_from_cave("echo_depths")
		if qm.is_quest_active("echo_depths"):
			qm.complete_objective("echo_depths", 2)
			qm.complete_objective("echo_depths", 3)

func _process(delta: float) -> void:
	time += delta
	if is_instance_valid(relic) and relic.visible:
		relic.position.y = 1.65 + sin(time * 1.7) * 0.06
		relic.rotation.y += delta * 0.35
