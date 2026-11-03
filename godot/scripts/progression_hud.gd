extends CanvasLayer

var summary: Label
var bar: ProgressBar
var notice: Label
var notice_time := 0.0

func _ready() -> void:
	layer = 15
	var box := VBoxContainer.new()
	add_child(box)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -250
	box.offset_right = 250
	box.offset_top = -78
	box.offset_bottom = -12
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary = Label.new()
	summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	summary.add_theme_color_override("font_color", Color("e8d59b"))
	summary.add_theme_color_override("font_shadow_color", Color.BLACK)
	summary.add_theme_constant_override("shadow_offset_x", 2)
	summary.add_theme_constant_override("shadow_offset_y", 2)
	box.add_child(summary)
	bar = ProgressBar.new()
	bar.custom_minimum_size.y = 10
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("c4a55b")
	bar.add_theme_stylebox_override("fill", fill)
	box.add_child(bar)
	notice = Label.new()
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.add_theme_color_override("font_color", Color("f3dda1"))
	box.add_child(notice)
	Progression.changed.connect(refresh)
	Progression.experience_gained.connect(_on_experience)
	refresh()

func refresh() -> void:
	bar.max_value = Progression.experience_required()
	bar.value = Progression.experience
	summary.text = "Niv. %d   ·   XP %d / %d   ·   %d%%" % [Progression.level, Progression.experience, Progression.experience_required(), int(100.0 * bar.value / bar.max_value)]
	if Progression.points > 0:
		summary.text += "   ·   %d %s (I · Personnage)" % [Progression.points, "point" if Progression.points == 1 else "points"]

func _on_experience(amount: int, levels: int) -> void:
	notice.text = "+%d XP" % amount
	if levels > 0: notice.text += "   ·   Niveau %d ! +%d points" % [Progression.level, levels * Progression.POINTS_PER_LEVEL]
	notice_time = 5.0

func _process(delta: float) -> void:
	notice_time = maxf(0.0, notice_time - delta)
	notice.visible = notice_time > 0.0
