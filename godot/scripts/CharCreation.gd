extends Node2D

## Character creation – choose a preset or customise stats, then enter a name.

var _W: float
var _H: float

var _selected_preset: int = 3  # default: Balanced
var _name_field: LineEdit = null
var _preset_btns: Array[Button] = []
var _stat_labels: Array[Label] = []
var _next_scene: String = "campaign"  # or "ranked"

func _ready() -> void:
	_W = get_viewport_rect().size.x
	_H = get_viewport_rect().size.y
	var data := MainMenu.pop_scene_data()
	_next_scene = data.get("next", "campaign")
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color    = Color(0.039, 0.086, 0.157)
	bg.size     = Vector2(_W, _H)
	bg.position = Vector2.ZERO
	add_child(bg)

	_add_label("CREATE CHARACTER", _W / 2.0, 28, 22, Color(0.486, 0.988, 0.0), true, Color(0, 0.2, 0))
	_add_label("Choose a preset:", _W / 2.0, 60, 14, Color(0.8, 0.8, 0.8))

	# Preset buttons
	var preset_y := 80.0
	var preset_spacing := 52.0
	for i in GameData.PRESET_CHARACTERS.size():
		var preset: Dictionary = GameData.PRESET_CHARACTERS[i]
		var btn := _make_preset_button(preset["name"], _W / 2.0, preset_y + i * preset_spacing, i)
		_preset_btns.append(btn)
		add_child(btn)

	_add_label("Stat Summary:", _W / 2.0, preset_y + GameData.PRESET_CHARACTERS.size() * preset_spacing + 10, 13, Color(0.667, 0.667, 0.667))

	# Stat labels
	var stat_y := preset_y + GameData.PRESET_CHARACTERS.size() * preset_spacing + 30
	for j in 4:
		var sl := Label.new()
		sl.add_theme_font_size_override("font_size", 12)
		sl.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0))
		sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sl.size     = Vector2(_W, 18)
		sl.position = Vector2(0, stat_y + j * 20)
		add_child(sl)
		_stat_labels.append(sl)
	_update_stat_labels()

	# Name entry
	var name_y := stat_y + 4 * 20 + 20
	_add_label("Your name:", _W / 2.0, name_y, 14, Color(0.8, 0.8, 0.8))
	_name_field = LineEdit.new()
	_name_field.text             = "Player"
	_name_field.max_length       = 16
	_name_field.size             = Vector2(200, 36)
	_name_field.position         = Vector2(_W / 2.0 - 100, name_y + 12)
	_name_field.add_theme_font_size_override("font_size", 16)
	add_child(_name_field)

	# Confirm button
	var confirm_y := name_y + 65
	var confirm := _make_button("START PLAYING", _W / 2.0, confirm_y,
		Color(0.486, 0.988, 0.0), Color(0, 0.2, 0), func(): _confirm())
	add_child(confirm)

	# Back
	var back := _make_button("← BACK", _W / 2.0, confirm_y + 55,
		Color(0.667, 0.667, 0.667), Color(0.1, 0.1, 0.1), func():
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"),
		true)
	add_child(back)

	_highlight_preset(_selected_preset)

# ── Interaction ────────────────────────────────────────────────────────────────

func _select_preset(idx: int) -> void:
	_selected_preset = idx
	_update_stat_labels()
	_highlight_preset(idx)

func _highlight_preset(idx: int) -> void:
	for i in _preset_btns.size():
		var style := StyleBoxFlat.new()
		if i == idx:
			style.bg_color = Color(0.0, 0.4, 0.0)
			style.border_color = Color(0.486, 0.988, 0.0)
			style.border_width_top    = 2
			style.border_width_bottom = 2
			style.border_width_left   = 2
			style.border_width_right  = 2
		else:
			style.bg_color = Color(0.1, 0.1, 0.15)
		style.corner_radius_top_left     = 5
		style.corner_radius_top_right    = 5
		style.corner_radius_bottom_left  = 5
		style.corner_radius_bottom_right = 5
		style.content_margin_left   = 16
		style.content_margin_right  = 16
		style.content_margin_top    = 8
		style.content_margin_bottom = 8
		_preset_btns[i].add_theme_stylebox_override("normal",   style)
		_preset_btns[i].add_theme_stylebox_override("hover",    style)
		_preset_btns[i].add_theme_stylebox_override("pressed",  style)
		_preset_btns[i].add_theme_stylebox_override("focus",    style)

func _update_stat_labels() -> void:
	if _stat_labels.is_empty():
		return
	var p: Dictionary = GameData.PRESET_CHARACTERS[_selected_preset]
	var keys   := ["moveSpeed", "power", "health", "accuracy"]
	var labels := ["Speed", "Power", "Health", "Accuracy"]
	for i in 4:
		_stat_labels[i].text = "%s: %d" % [labels[i], p[keys[i]]]

func _confirm() -> void:
	var preset: Dictionary = GameData.PRESET_CHARACTERS[_selected_preset]
	var player_name: String = _name_field.text.strip_edges()
	if player_name.is_empty():
		player_name = "Player"

	GameState.character     = preset.duplicate()
	GameState.character["name"] = player_name
	GameState.created       = true
	GameState.level         = 1
	GameState.xp            = 0
	GameState.campaign_progress = 0
	GameState.equipped_paddle   = "wooden"
	GameState.equipped_powers   = []
	GameState.inventory         = [{"type": "paddle", "id": "wooden"}]
	GameState.save_game()

	if _next_scene == "ranked":
		var opponents := GameData.CAMPAIGN_OPPONENTS
		var opp: Dictionary = opponents[randi() % opponents.size()]
		MainMenu._store_scene_data({"opponent": opp, "mode": "ranked", "level_index": 0})
		get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/Campaign.tscn")

# ── UI helpers ─────────────────────────────────────────────────────────────────

func _add_label(text: String, cx: float, y: float, font_size: int,
		color: Color, bold: bool = false, outline: Color = Color.TRANSPARENT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	if outline != Color.TRANSPARENT:
		lbl.add_theme_color_override("font_outline_color", outline)
		lbl.add_theme_constant_override("outline_size", 4)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(_W, font_size + 8)
	lbl.position = Vector2(0, y - (font_size + 8) / 2.0)
	add_child(lbl)
	return lbl

func _make_preset_button(text: String, cx: float, cy: float, idx: int) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(1, 1, 1))
	btn.add_theme_color_override("font_hover_color", Color(0.486, 0.988, 0.0))
	btn.size = Vector2(200, 38)
	btn.position = Vector2(cx - 100, cy)
	var captured := idx
	btn.pressed.connect(func(): _select_preset(captured))
	return btn

func _make_button(text: String, cx: float, cy: float,
		fg: Color, bg: Color, callback: Callable, small: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	var fs := 14 if small else 18
	btn.add_theme_font_size_override("font_size", fs)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 16 if not small else 12
	style.content_margin_right  = 16 if not small else 12
	style.content_margin_top    = 10 if not small else 6
	style.content_margin_bottom = 10 if not small else 6
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    style)
	btn.add_theme_stylebox_override("pressed",  style)
	btn.add_theme_stylebox_override("focus",    style)
	btn.size = Vector2(220 if not small else 160, fs + 24)
	btn.position = Vector2(cx - btn.size.x / 2.0, cy - btn.size.y / 2.0)
	btn.pressed.connect(callback)
	return btn
