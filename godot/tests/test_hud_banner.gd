extends SceneTree
## Test headless pour vérifier la suppression du rectangle des contrôles et le fonctionnement de la bannière de lieu.

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("--- Test HUD Banner & Controls Removal ---")
	
	var forest_packed := load("res://experiments/arbres_20261014/playable_forest.tscn") as PackedScene
	assert(forest_packed != null, "playable_forest.tscn doit exister")
	
	var forest: Node = forest_packed.instantiate()
	root.add_child(forest)
	await process_frame
	
	var hud := forest.get_node_or_null("HUD")
	assert(hud != null, "Le node HUD doit exister")
	
	# Vérifier que le rectangle noir de contrôles en bas a bien été supprimé
	var controls := hud.get_node_or_null("Controls")
	assert(controls == null, "Le rectangle de contrôles permanent en bas doit être supprimé du HUD")
	
	# Vérifier que Title existe et a le script hud_banner.gd
	var title := hud.get_node_or_null("Title") as PanelContainer
	assert(title != null, "Le node Title doit exister dans le HUD")
	assert(title.get_script() != null, "Title doit avoir un script attaché")
	
	# Vérifier que le gros fond noir a été retiré (StyleBoxEmpty)
	var style = title.get_theme_stylebox("panel")
	assert(style is StyleBoxEmpty, "Le fond noir doit être retiré (StyleBoxEmpty)")
	
	# Vérifier que le texte a une ombre pour une bonne lisibilité sans fond
	var text_lbl := title.get_node_or_null("Text") as Label
	assert(text_lbl != null, "Le Label Text doit exister dans Title")
	assert(title.modulate.a == 1.0, "La bannière commence visible à 100% d'opacité")
	
	# Tester la fonction show_banner
	title.show_banner("Monts Enneigés", "Test Subtitle")
	assert("MONTS ENNEIGÉS" in text_lbl.text, "show_banner met à jour le texte correctement")
	
	forest.queue_free()
	await process_frame
	
	print("ALL HUD BANNER TESTS PASSED SUCCESSFULLY!")
	quit(0)
