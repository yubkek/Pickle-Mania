extends Node

## Static game data – paddles, superpowers, loot tables, opponents, etc.
## Loaded as an AutoLoad singleton named "GameData".

const PADDLES: Array[Dictionary] = [
	{"id": "wooden",    "name": "Wooden Paddle",   "rarity": "C", "power": 1.0, "accuracy": 1.0, "color": Color(0.545, 0.271, 0.075), "desc": "A humble beginning."},
	{"id": "carbon",    "name": "Carbon Fiber",     "rarity": "C", "power": 1.1, "accuracy": 1.1, "color": Color(0.333, 0.333, 0.333), "desc": "Light and responsive."},
	{"id": "thunder",   "name": "Thunderbolt",      "rarity": "C", "power": 1.2, "accuracy": 0.9, "color": Color(1.0,  0.667, 0.0),   "desc": "Raw power, less precision."},
	{"id": "lightning", "name": "Lightning Strike", "rarity": "B", "power": 1.3, "accuracy": 1.0, "color": Color(0.0,  0.667, 1.0),   "desc": "Speed meets power."},
	{"id": "precision", "name": "Precision Pro",    "rarity": "B", "power": 1.0, "accuracy": 1.5, "color": Color(0.0,  1.0,  0.533),  "desc": "Every shot counts."},
	{"id": "storm",     "name": "Storm Chaser",     "rarity": "B", "power": 1.25,"accuracy": 1.2, "color": Color(0.533, 0.0, 1.0),    "desc": "Unpredictable and fierce."},
	{"id": "dragon",    "name": "Dragon Scale",     "rarity": "A", "power": 1.5, "accuracy": 1.2, "color": Color(1.0,  0.267, 0.0),   "desc": "Forged in dragon fire."},
	{"id": "phoenix",   "name": "Phoenix Wing",     "rarity": "A", "power": 1.4, "accuracy": 1.4, "color": Color(1.0,  0.533, 0.0),   "desc": "Rises above all others."},
	{"id": "cosmos",    "name": "Cosmos",           "rarity": "A", "power": 1.6, "accuracy": 1.3, "color": Color(1.0,  0.0,  1.0),    "desc": "Beyond the stars."},
]

const SUPERPOWERS: Array[Dictionary] = [
	{"id": "faster_hit", "name": "Faster Hit", "rarity": "B", "color": Color(0.0,  0.667, 1.0),   "desc": "Next hit travels 30% faster.",       "duration": 0,    "cooldown": 0},
	{"id": "dash",       "name": "Side Dash",  "rarity": "C", "color": Color(0.533, 1.0,  0.0),   "desc": "Instantly dash left or right.",       "duration": 0,    "cooldown": 8.0},
	{"id": "slow_time",  "name": "Slow Time",  "rarity": "B", "color": Color(0.667, 0.0,  1.0),   "desc": "Slows enemy time for 3 seconds.",     "duration": 3.0,  "cooldown": 0},
	{"id": "spin_hit",   "name": "Spin Hit",   "rarity": "A", "color": Color(1.0,  0.533, 0.0),   "desc": "Ball curves unpredictably.",          "duration": 0,    "cooldown": 0},
	{"id": "wingspan",   "name": "Wingspan",   "rarity": "C", "color": Color(0.0,  1.0,  0.667),  "desc": "Hit zone doubled for 8 seconds.",     "duration": 8.0,  "cooldown": 0},
	{"id": "shield",     "name": "Shield",     "rarity": "C", "color": Color(1.0,  1.0,  0.0),    "desc": "Block the next damage taken.",        "duration": 0,    "cooldown": 0},
]

const LOOT_TABLES: Dictionary = {
	"bronze": {"C": 0.80, "B": 0.18, "A": 0.02},
	"silver": {"C": 0.55, "B": 0.35, "A": 0.10},
	"gold":   {"C": 0.25, "B": 0.45, "A": 0.30},
}

const PRESET_CHARACTERS: Array[Dictionary] = [
	{"name": "Speedster",    "moveSpeed": 20, "power": 5,  "health": 10, "accuracy": 15},
	{"name": "Tank",         "moveSpeed": 5,  "power": 20, "health": 20, "accuracy": 5},
	{"name": "Sharpshooter", "moveSpeed": 10, "power": 10, "health": 10, "accuracy": 20},
	{"name": "Balanced",     "moveSpeed": 13, "power": 12, "health": 13, "accuracy": 12},
]

const CAMPAIGN_OPPONENTS: Array[Dictionary] = [
	{"name": "Rookie Randy", "level": 1,  "stats": {"moveSpeed": 8,  "power": 8,  "health": 15, "accuracy": 8},  "paddle": "wooden"},
	{"name": "Club Casey",   "level": 3,  "stats": {"moveSpeed": 12, "power": 12, "health": 18, "accuracy": 12}, "paddle": "carbon"},
	{"name": "Pro Pete",     "level": 5,  "stats": {"moveSpeed": 16, "power": 16, "health": 20, "accuracy": 16}, "paddle": "lightning"},
	{"name": "Elite Elena",  "level": 8,  "stats": {"moveSpeed": 20, "power": 20, "health": 22, "accuracy": 20}, "paddle": "precision"},
	{"name": "Champion Rex", "level": 12, "stats": {"moveSpeed": 24, "power": 24, "health": 26, "accuracy": 22}, "paddle": "dragon"},
]

const RARITY_COLORS: Dictionary = {"C": Color(0.533, 0.533, 0.533), "B": Color(0.0, 0.533, 1.0), "A": Color(1.0, 0.533, 0.0)}
const RARITY_NAMES: Dictionary  = {"C": "Common", "B": "Rare", "A": "Legendary"}
const XP_THRESHOLDS: Array[int] = [0, 100, 250, 500, 900, 1400, 2100, 3000, 4200, 6000, 9999999]
const RANK_UNLOCK_LEVEL: int = 5

func get_paddle(id: String) -> Dictionary:
	for p in PADDLES:
		if p["id"] == id:
			return p
	return PADDLES[0]

func get_superpower(id: String) -> Dictionary:
	for sp in SUPERPOWERS:
		if sp["id"] == id:
			return sp
	return {}

func roll_loot(orb_type: String) -> Dictionary:
	## Returns a random item dict {"type": "paddle"|"power", "id": ...}
	var weights: Dictionary = LOOT_TABLES.get(orb_type, LOOT_TABLES["bronze"])
	var roll := randf()
	var rarity: String
	if roll < weights["A"]:
		rarity = "A"
	elif roll < weights["A"] + weights["B"]:
		rarity = "B"
	else:
		rarity = "C"

	# Collect eligible items (paddles + superpowers) of this rarity
	var pool: Array[Dictionary] = []
	for p in PADDLES:
		if p["rarity"] == rarity:
			pool.append({"type": "paddle", "id": p["id"]})
	for sp in SUPERPOWERS:
		if sp["rarity"] == rarity:
			pool.append({"type": "power", "id": sp["id"]})

	if pool.is_empty():
		return {"type": "paddle", "id": "wooden"}
	return pool[randi() % pool.size()]
