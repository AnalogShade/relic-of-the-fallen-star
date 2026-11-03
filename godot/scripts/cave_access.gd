extends RefCounted
## Shared facts, deliberately independent of discovery order and journal objectives.
const PREFIX := "story/cave_guardian/"
const MET := PREFIX + "met"
const REPELLED := PREFIX + "repelled"
const HINT := PREFIX + "hint"
const RECIPE := PREFIX + "recipe"
const SEDATED := PREFIX + "sedated"
const FERN := "dream_fern"
const DART := "sleep_dart"

static func has_fact(context: Node, fact: String) -> bool:
	var bag := context.get_node("/root/Inventory")
	return bool(bag.collected.get(fact, false))

static func remember(context: Node, fact: String) -> void:
	var bag := context.get_node("/root/Inventory")
	bag.collected[fact] = true
	var journal := context.get_node_or_null("/root/QuestManager")
	if journal:
		if fact == REPELLED: journal.start_guardian_search()
		journal.refresh_journal_ui()

static func passage_open(context: Node) -> bool:
	if has_fact(context, SEDATED): return true
	# Existing saves that already reached the relic keep their established progress.
	var bag := context.get_node("/root/Inventory")
	var quests := context.get_node("/root/QuestManager")
	return bag.has_fireball_relic() or bag.collected.has("cave/first_echo") or quests.is_objective_completed("echo_depths", 3) or quests.is_quest_completed("echo_depths")

static func journal_note(context: Node) -> String:
	if not has_fact(context, MET): return ""
	if passage_open(context):
		var guardian := context.get_tree().get_first_node_in_group("cave_guardian")
		if guardian and guardian.state != "sleeping": return "La préparation fait effet. L'ogre lutte contre le sommeil."
		return "L'ogre dort paisiblement. Le passage vers les profondeurs est libre."
	var note := "Un ogre garde le seuil pour empêcher le réveil d'une puissance obscure. Il refuse de me laisser passer."
	if has_fact(context, REPELLED): note += " Sa force me dépasse largement."
	if has_fact(context, HINT): note += " Maëlor m'a rappelé ses anciennes leçons sur les plantes."
	return note
