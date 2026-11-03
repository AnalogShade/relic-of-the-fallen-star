extends RefCounted
## Behaviour only: archetype, health and damage remain defined by the enemy.
const PROFILES := {
	"equilibre": {"anger": 36.0, "decay": 5.0, "charge": 60.0, "dodge": 1.0, "evade_cooldown": 1.0, "windup": 1.0, "recovery": 1.0, "opening": 1.25, "rest": 0.3, "flee_health": 0.0, "flee_chance": 0.0},
	"agressif": {"anger": 52.0, "decay": 3.0, "charge": 48.0, "dodge": 0.15, "evade_cooldown": 1.5, "windup": 0.85, "recovery": 1.2, "opening": 1.5, "rest": 0.15, "flee_health": 0.0, "flee_chance": 0.0},
	"prudent": {"anger": 25.0, "decay": 7.0, "charge": 80.0, "dodge": 1.0, "evade_cooldown": 0.65, "windup": 1.1, "recovery": 1.0, "opening": 1.25, "rest": 0.5, "flee_health": 0.3, "flee_chance": 0.25},
	"peureux": {"anger": 16.0, "decay": 9.0, "charge": 95.0, "dodge": 1.0, "evade_cooldown": 0.45, "windup": 1.15, "recovery": 1.0, "opening": 1.25, "rest": 0.7, "flee_health": 0.65, "flee_chance": 0.6},
}
const AUTOMATIC: Array[String] = ["equilibre", "equilibre", "agressif", "agressif", "prudent", "peureux"]
