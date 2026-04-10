extends Node

## Persistent game state – saved to user:// on device.
## Loaded as an AutoLoad singleton named "GameState".

const SAVE_PATH := "user://pickle_mania_save.json"

var created: bool = false
var character: Dictionary = {"moveSpeed": 13, "power": 12, "health": 13, "accuracy": 12, "name": "Player"}
var level: int = 1
var xp: int = 0
var campaign_progress: int = 0
var equipped_paddle: String = "wooden"
var equipped_powers: Array = []
var inventory: Array = [{"type": "paddle", "id": "wooden"}]

func _ready() -> void:
	load_game()

func _defaults() -> Dictionary:
	return {
		"created": false,
		"character": {"moveSpeed": 13, "power": 12, "health": 13, "accuracy": 12, "name": "Player"},
		"level": 1,
		"xp": 0,
		"campaign_progress": 0,
		"equipped_paddle": "wooden",
		"equipped_powers": [],
		"inventory": [{"type": "paddle", "id": "wooden"}],
	}

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_defaults()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_apply_defaults()
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		_apply_defaults()
		return
	var d: Dictionary = _defaults()
	d.merge(parsed, true)
	_apply_dict(d)

func save_game() -> void:
	var d := {
		"created": created,
		"character": character,
		"level": level,
		"xp": xp,
		"campaign_progress": campaign_progress,
		"equipped_paddle": equipped_paddle,
		"equipped_powers": equipped_powers,
		"inventory": inventory,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: Could not open save file for writing.")
		return
	file.store_string(JSON.stringify(d))
	file.close()

func reset() -> void:
	_apply_defaults()
	save_game()

func add_xp(amount: int) -> void:
	xp += amount
	var thresholds := GameData.XP_THRESHOLDS
	while level < thresholds.size() - 1 and xp >= thresholds[level]:
		level += 1
	save_game()

func add_to_inventory(item_type: String, item_id: String) -> void:
	inventory.append({"type": item_type, "id": item_id})
	save_game()

func has_item(item_type: String, item_id: String) -> bool:
	for i in inventory:
		if i["type"] == item_type and i["id"] == item_id:
			return true
	return false

func xp_for_next_level() -> int:
	var thresholds := GameData.XP_THRESHOLDS
	if level >= thresholds.size() - 1:
		return 0
	return thresholds[level]

func xp_progress() -> float:
	var thresholds := GameData.XP_THRESHOLDS
	var prev: int = thresholds[level - 1] if level > 0 else 0
	var next: int = thresholds[level] if level < thresholds.size() else prev + 1
	if next == prev:
		return 1.0
	return float(xp - prev) / float(next - prev)

# ── Private helpers ────────────────────────────────────────────────────────────

func _apply_defaults() -> void:
	_apply_dict(_defaults())

func _apply_dict(d: Dictionary) -> void:
	created           = d.get("created", false)
	character         = d.get("character", {"moveSpeed": 13, "power": 12, "health": 13, "accuracy": 12, "name": "Player"})
	level             = d.get("level", 1)
	xp                = d.get("xp", 0)
	campaign_progress = d.get("campaign_progress", 0)
	equipped_paddle   = d.get("equipped_paddle", "wooden")
	equipped_powers   = d.get("equipped_powers", [])
	inventory         = d.get("inventory", [{"type": "paddle", "id": "wooden"}])
