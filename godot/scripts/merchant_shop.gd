extends CanvasLayer
const WARES := {"bread": 12, "chicken": 10, "trout": 7, "mushroom": 3, "blueberry": 4, "raspberry": 4, "golden_berry": 5}
var bag: Node
var balance: Label
var message: Label
var buttons: Array[Button] = []

func _ready() -> void:
	bag = get_node("/root/Inventory")
	layer = 46
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.03, 0.03, 0.8)
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 560
	panel.add_theme_stylebox_override("panel", bag.ui.style(bag.ui.ink, bag.ui.gold, 2))
	center.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	panel.add_child(layout)
	layout.add_child(bag.ui.label("MERRICK · MARCHÉ DU CHÂTEAU", 25, bag.ui.gold))
	balance = bag.ui.label("", 21, bag.ui.gold)
	layout.add_child(balance)
	layout.add_child(bag.ui.label("Bienvenue ! Voici mes provisions du jour.", 17, Color("e8e1cc")))
	for id in WARES:
		var button := Button.new()
		button.text = "%s · +%d PV · %d pièces d’or" % [bag.ITEMS[id].name, int(bag.ITEMS[id].get("heal", 0)), WARES[id]]
		button.custom_minimum_size.y = 42
		button.pressed.connect(_buy.bind(str(id)))
		layout.add_child(button)
		buttons.append(button)
	message = bag.ui.label("", 16, Color("e8e1cc"))
	layout.add_child(message)
	var close := Button.new()
	close.text = "Au revoir [ F / I ]"
	close.pressed.connect(close_shop)
	layout.add_child(close)
	bag.changed.connect(refresh)
	hide()

func open_shop() -> void:
	bag.set_open(true)
	bag.ui.set_open(false)
	message.text = "Ramassez l’or des bandits avec F pour acheter des provisions."
	show()
	refresh()

func close_shop() -> void:
	hide()
	bag.set_open(false)

func _process(_delta: float) -> void:
	if visible and not bag.is_open: hide()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("interact") and not event.is_echo():
		close_shop()
		get_viewport().set_input_as_handled()

func refresh() -> void:
	if not visible: return
	balance.text = "Votre bourse : %d pièces d’or" % bag.gold
	var index := 0
	for id in WARES:
		buttons[index].disabled = bag.gold < WARES[id]
		index += 1

func _buy(id: String) -> void:
	if not visible: return
	if bag.buy_item(id, WARES[id]):
		message.text = "%s ajouté au sac. Merci !" % bag.ITEMS[id].name
	else:
		message.text = "Achat impossible : or insuffisant ou sac plein."
	refresh()
