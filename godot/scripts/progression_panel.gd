extends VBoxContainer
signal back_requested

var heading: Label
var rows := {}
var buttons := {}

func _ready() -> void:
	var ui = get_node("/root/Inventory").ui
	add_theme_constant_override("separation", 12)
	heading = ui.label("", 22, ui.gold)
	add_child(heading)
	add_child(ui.label("2 points par niveau · Choisissez votre spécialisation", 14, Color("8da79c")))
	var names := {"strength": "Force", "vitality": "Vitalité", "speed": "Rapidité", "magic": "Magie"}
	for key in Progression.ATTRIBUTES:
		var row := HBoxContainer.new()
		add_child(row)
		var label: Label = ui.label("", 16, Color("e8e1cc"))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		rows[key] = label
		var button: Button = ui.make_button("+1", 18, 48)
		button.custom_minimum_size.x = 64
		button.accessibility_name = "Augmenter " + names[key]
		button.pressed.connect(func(): Progression.spend_point(key))
		row.add_child(button)
		buttons[key] = button
	var back: Button = ui.make_button("Retour au personnage")
	add_child(back)
	back.pressed.connect(func(): back_requested.emit())
	Progression.changed.connect(refresh)
	refresh()

func refresh() -> void:
	heading.text = "NIVEAU %d   ·   %d %s" % [Progression.level, Progression.points, "point disponible" if Progression.points == 1 else "points disponibles"]
	rows.strength.text = "Force  %d\nDégâts physiques : +%d %%" % [Progression.attributes.strength, Progression.attributes.strength * 5]
	rows.vitality.text = "Vitalité  %d\nVie maximale : %d PV" % [Progression.attributes.vitality, int(Progression.maximum_health())]
	rows.speed.text = "Rapidité  %d\nMarche et course : +%.1f %%" % [Progression.attributes.speed, (Progression.movement_multiplier() - 1.0) * 100.0]
	rows.magic.text = "Magie  %d\nDégâts des sorts : +%d %%" % [Progression.attributes.magic, Progression.attributes.magic * 5]
	for button in buttons.values(): button.disabled = Progression.points <= 0
