extends Node2D

## Campaign level-select scene.

var _W: float
var _H: float

func _ready() -> void:
	_W = get_viewport_rect().size.x
	_H = get_viewport_rect().size.y
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color    = Color(0.039, 0.086, 0.157)
	bg.size     = Vector2(_W, _H)
	bg.position = Vector2.ZERO
	add_child(bg)

	_add_label("CAMPAIGN", _W / 2.0, 30, 28, Color(0.486, 0.988, 0.0), true, Color(0, 0.2, 0))
	_add_label("Progress: %d/%d" % [GameState.campaign_progress, GameData.CAMPAIGN_OPPONENTS.size()],
		_W / 2.0, 62, 14, Color(0.667, 0.667, 0.667))

	var start_y := 100.0
	var spacing := 90.0
	var progress := GameState.campaign_progress

	for i in GameData.CAMPAIGN_OPPONENTS.size():
		var opp: Dictionary = GameData.CAMPAIGN_OPPONENTS[i]
		var unlocked := i <= progress
		var beaten   := i < progress
		var card_y   := start_y + i * spacing

		# Card background
		var card := ColorRect.new()
		card.size     = Vector2(_W - 60, 75)
		card.position = Vector2(30, card_y)
		card.color    = Color(0.102, 0.227, 0.102) if beaten else (Color(0.102, 0.165, 0.227) if unlocked else Color(0.102, 0.102, 0.102))
		add_child(card)

		var border := _BorderRect.new(card.position, card.size,
			Color(0.486, 0.988, 0.0) if beaten else (Color(0.0, 0.667, 1.0) if unlocked else Color(0.2, 0.2, 0.2)))
		add_child(border)

		_add_label(opp["name"], _W / 2.0, card_y + 14,
			18, Color(0.486, 0.988, 0.0) if beaten else (Color(1.0, 1.0, 1.0) if unlocked else Color(0.333, 0.333, 0.333)), true)

		var status_str := "✓ BEATEN" if beaten else ("CHALLENGE" if unlocked else "LOCKED")
		_add_label("Level %d  ·  %s" % [opp["level"], status_str],
			_W / 2.0, card_y + 36, 12,
			Color(0.486, 0.988, 0.0) if beaten else (Color(0.667, 0.667, 0.667) if unlocked else Color(0.333, 0.333, 0.333)))

		var paddle: Dictionary = GameData.get_paddle(opp["paddle"])
		var rarity_color: Color = GameData.RARITY_COLORS.get(paddle.get("rarity", "C"), Color.WHITE)
		_add_label("Paddle: %s" % paddle.get("name", "?"), _W / 2.0, card_y + 56, 11, rarity_color)

		if unlocked:
			var btn := Button.new()
			btn.size        = Vector2(_W - 60, 75)
			btn.position    = Vector2(30, card_y)
			btn.flat        = true
			var style       := StyleBoxEmpty.new()
			btn.add_theme_stylebox_override("normal",  style)
			btn.add_theme_stylebox_override("hover",   style)
			btn.add_theme_stylebox_override("pressed", style)
			btn.add_theme_stylebox_override("focus",   style)
			var idx := i  # capture for closure
			btn.pressed.connect(func():
				GameState.store_scene_data({"opponent": GameData.CAMPAIGN_OPPONENTS[idx], "mode": "campaign", "level_index": idx})
				get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
			)
			add_child(btn)

	# Back button
	var back := _make_text_button("← BACK", _W / 2.0, _H - 30, func():
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	add_child(back)

# ── Helpers ────────────────────────────────────────────────────────────────────

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

func _make_text_button(text: String, cx: float, cy: float, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color(0.667, 0.667, 0.667))
	btn.add_theme_color_override("font_hover_color", Color(0.667, 0.667, 0.667))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1)
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left   = 12
	style.content_margin_right  = 12
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    style)
	btn.add_theme_stylebox_override("pressed",  style)
	btn.add_theme_stylebox_override("focus",    style)
	btn.size     = Vector2(160, 32)
	btn.position = Vector2(cx - 80, cy - 16)
	btn.pressed.connect(callback)
	return btn


class _BorderRect extends Node2D:
	var _pos: Vector2
	var _sz:  Vector2
	var _col: Color

	func _init(p: Vector2, s: Vector2, c: Color) -> void:
		_pos = p; _sz = s; _col = c

	func _draw() -> void:
		draw_rect(Rect2(_pos, _sz), _col, false, 2.0)
