extends Node
## Persistent character progression, shared by the forest and interior players.
signal changed
signal experience_gained(amount: int, levels: int)

const POINTS_PER_LEVEL := 2
const ATTRIBUTES := ["strength", "vitality", "speed", "magic"]
var level := 1
var experience := 0
var points := 0
var attributes := {"strength": 0, "vitality": 0, "speed": 0, "magic": 0}

func experience_required(at_level: int = -1) -> int:
	if at_level < 1: at_level = level
	return 100 + 50 * (at_level - 1)

func add_experience(amount: int) -> void:
	if amount <= 0: return
	experience += amount
	var gained := 0
	while experience >= experience_required():
		experience -= experience_required()
		level += 1
		points += POINTS_PER_LEVEL
		gained += 1
	changed.emit()
	experience_gained.emit(amount, gained)

func reward_enemy(enemy: Node, amount: int) -> void:
	# Metadata belongs to this enemy instance, so corpses cannot grant XP twice.
	if enemy.has_meta("experience_rewarded"): return
	enemy.set_meta("experience_rewarded", true)
	add_experience(amount)

func spend_point(attribute: String) -> bool:
	if points <= 0 or not attributes.has(attribute): return false
	points -= 1
	attributes[attribute] += 1
	changed.emit()
	return true

func physical_multiplier() -> float:
	return 1.0 + 0.05 * attributes.strength

func magic_multiplier() -> float:
	return 1.0 + 0.05 * attributes.magic

func maximum_health() -> float:
	return 100.0 + 10.0 * attributes.vitality

func movement_multiplier() -> float:
	# Diminishing returns keep collisions and traversal manageable at any level.
	return 1.0 + 0.5 * float(attributes.speed) / (25.0 + float(attributes.speed))

func save_to_dict() -> Dictionary:
	return {"level": level, "experience": experience, "points": points, "attributes": attributes.duplicate()}

func normalize_data(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY: return {}
	var data: Dictionary = value
	var result := {}
	for key in ["level", "experience", "points"]:
		var number = data.get(key, 1 if key == "level" else 0)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT]: return {}
		if not is_finite(float(number)) or number != floor(float(number)) or number < (1 if key == "level" else 0) or number > 1000000000: return {}
		result[key] = int(number)
	if result.experience >= experience_required(result.level): return {}
	var stats = data.get("attributes", {})
	if typeof(stats) != TYPE_DICTIONARY: return {}
	result.attributes = {}
	var spent := 0
	for key in ATTRIBUTES:
		var number = stats.get(key, 0)
		if typeof(number) not in [TYPE_INT, TYPE_FLOAT]: return {}
		if not is_finite(float(number)) or number != floor(float(number)) or number < 0 or number > 2000000000: return {}
		result.attributes[key] = int(number)
		spent += int(number)
	if spent + result.points != (result.level - 1) * POINTS_PER_LEVEL: return {}
	return result

func load_from_dict(data: Dictionary) -> void:
	var normalized := normalize_data(data)
	if normalized.is_empty(): return
	level = normalized.level
	experience = normalized.experience
	points = normalized.points
	attributes = normalized.attributes.duplicate()
	changed.emit()
