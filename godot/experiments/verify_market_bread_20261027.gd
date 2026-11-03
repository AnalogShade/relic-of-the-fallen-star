extends SceneTree

class TestPlayer extends CharacterBody3D:
	var health := 50.0
	var max_health := 100.0
	func heal(amount: float) -> void:
		health = minf(max_health, health + amount)

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	print(("PASS " if ok else "FAIL ") + message)
	if not ok: failures.append(message)

func run() -> void:
	var bag = root.get_node("Inventory")
	var player := TestPlayer.new()
	root.add_child(player)
	player.add_to_group("player")
	var shop = load("res://scripts/merchant_shop.gd").new()
	root.add_child(shop)
	shop.open_shop()
	await process_frame
	check(shop.buttons.size() == 7 and shop.buttons[0].text.contains("Pain du marché · +18 PV · 12"), "Bread appears first with healing and price; seven foods available")
	check(shop.buttons[0].disabled, "Bread cannot be purchased without gold")
	bag.add_gold(24)
	shop.buttons[0].pressed.emit()
	check(bag.gold == 12 and bag.get_item_count("bread") == 1, "Shop purchase adds bread and deducts 12 gold")
	check(bag.consume_item("bread") and player.health == 68.0 and bag.get_item_count("bread") == 0, "Eating purchased bread restores 18 HP and consumes one loaf")
	for id in bag.FRUIT_IDS:
		check(bag.ITEMS.bread.heal > bag.ITEMS[id].heal, "Bread heals more than " + id)
	shop.buttons[0].pressed.emit()
	player.health = 95.0
	check(bag.consume_item("bread") and player.health == 100.0, "Healing respects maximum HP")
	bag.add_gold(12)
	shop.buttons[0].pressed.emit()
	check(not bag.consume_item("bread") and bag.get_item_count("bread") == 1, "Full health preserves bread")
	bag.stacks.clear()
	for i in range(bag.CAPACITY):
		bag.stacks.append({"id": "blueberry", "quantity": bag.STACK_LIMIT})
	bag.add_gold(12)
	shop.buttons[0].pressed.emit()
	check(bag.gold == 12 and bag.get_item_count("bread") == 0, "Full inventory refuses bread without spending gold")
	var image := Image.new()
	check(image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/ui/items/bread.svg")) == OK and image.get_size() == Vector2i(96, 96), "Bread inventory icon renders")
	await process_frame
	await process_frame
	var panel = shop.buttons[0].get_parent().get_parent()
	check(panel.size.y <= 720.0 and panel.size.x <= 1280.0, "Expanded shop fits the 1280 by 720 game viewport")
	print("MARKET_BREAD_VALIDATION ", JSON.stringify({"failures": failures, "menu_size": str(panel.size)}))
	shop.close_shop()
	shop.queue_free()
	player.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
