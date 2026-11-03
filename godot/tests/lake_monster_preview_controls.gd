extends Node
## Explicit test controls only; the main game never grants the relic here.
var player: CharacterBody3D
var boss: CharacterBody3D
var hint: Label

func _ready() -> void:
	set_test_fire(false)

func set_test_fire(enabled: bool) -> void:
	var bag := get_node("/root/Inventory")
	# This controller exists only in the standalone lake preview; nothing is saved.
	bag.equipment.erase("first_echo")
	for i in range(bag.stacks.size() - 1, -1, -1):
		if bag.stacks[i].id == "first_echo": bag.stacks.remove_at(i)
	if bag.equipped == "first_echo": bag.equipped = ""
	if enabled: bag.equipment.append("first_echo")
	bag.changed.emit()
	player.cancel_claw()
	player.fireball_cooldown = 0
	_refresh_hint()

func _refresh_hint() -> void:
	var enabled: bool = get_node("/root/Inventory").has_fireball_relic()
	hint.text = "TEST DU LAC — FEU " + ("ACTIVÉ" if enabled else "DÉSACTIVÉ") + "\nF9 : activer / désactiver le feu • F8 : recommencer\nClic droit maintenu : viser, relâcher : lancer\nCorps : aucun dégât • Gueule : 4 impacts pour vaincre\nWASD : bouger • Maj : courir • R : esquiver"

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_F8:
		for projectile in get_tree().get_nodes_in_group("lake_monster_projectiles"):
			projectile.queue_free()
		boss.reset_encounter()
		player.global_position = Vector3(38, 8, -213)
		player.velocity = Vector3.ZERO
		player.health = 100.0
		player.damage_invulnerability = 0.0
		player.cancel_claw()
		player.fireball_cooldown = 0.0
		get_node("/root/Inventory").collected.erase("story/lake_monster_defeated")
		_refresh_hint()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_F9:
		set_test_fire(not get_node("/root/Inventory").has_fireball_relic())
		get_viewport().set_input_as_handled()
