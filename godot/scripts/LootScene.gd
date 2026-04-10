extends Node2D

## Post-match loot reveal scene – shows a random item based on orb rarity.

var _W: float
var _H: float
var _orb_type: String  = "bronze"
var _mode: String      = "campaign"
var _level_index: int  = 0
var _item: Dictionary  = {}
var _revealed: bool    = false

func _ready() -> void:
	_W = get_viewport_rect().size.x
	_H = get_viewport_rect().size.y
	var data := MainMenu.pop_scene_data()
	_orb_type    = data.get("orb_type",    "bronze")
	_mode        = data.get("mode",        "campaign")
	_level_index = data.get("level_index", 0)
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color    = Color(0.039, 0.086, 0.157)
	bg.size     = Vector2(_W, _H)
	bg.position = Vector2.ZERO
	add_child(bg)

	# Orb title
	var orb_color: Color
	match _orb_type:
		"gold":   orb_color = Color(1.0, 0.843, 0.0)
		"silver": orb_color = Color(0.753, 0.753, 0.753)
		_:        orb_color = Color(0.804, 0.498, 0.196)  # bronze

	_add_label("%s ORB" % _orb_type.to_upper(), _W / 2.0, _H * 0.18, 36, orb_color, true)
	_add_label("Tap the orb to reveal your reward!", _W / 2.0, _H * 0.26, 14, Color(0.8, 0.8, 0.8))

	# Orb button
	var orb_btn := Button.new()
	orb_btn.size     = Vector2(120, 120)
	orb_btn.position = Vector2(_W / 2.0 - 60, _H * 0.35)
	var style := StyleBoxFlat.new()
	style.bg_color = orb_color
	style.corner_radius_top_left     = 60
	style.corner_radius_top_right    = 60
	style.corner_radius_bottom_left  = 60
	style.corner_radius_bottom_right = 60
	orb_btn.add_theme_stylebox_override("normal",  style)
	orb_btn.add_theme_stylebox_override("hover",   style)
	orb_btn.add_theme_stylebox_override("pressed", style)
	orb_btn.add_theme_stylebox_override("focus",   style)
	orb_btn.pressed.connect(func():
		if not _revealed:
			_reveal_item(orb_btn)
	)
	add_child(orb_btn)

func _reveal_item(orb_btn: Button) -> void:
	_revealed = true
	orb_btn.disabled = true

	_item = GameData.roll_loot(_orb_type)
	GameState.add_to_inventory(_item.get("type", "paddle"), _item.get("id", "wooden"))

	# Determine display info
	var display_name: String
	var display_rarity: String
	var display_desc: String
	var item_color: Color

	if _item.get("type") == "paddle":
		var paddle: Dictionary = GameData.get_paddle(_item.get("id", "wooden"))
		display_name   = paddle.get("name", "?")
		display_rarity = paddle.get("rarity", "C")
		display_desc   = paddle.get("desc", "")
		item_color     = paddle.get("color", Color.WHITE)
	else:
		var power: Dictionary = GameData.get_superpower(_item.get("id", ""))
		display_name   = power.get("name", "?")
		display_rarity = power.get("rarity", "C")
		display_desc   = power.get("desc", "")
		item_color     = power.get("color", Color.WHITE)

	var rarity_name: String = GameData.RARITY_NAMES.get(display_rarity, "Common")
	var rarity_color: Color = GameData.RARITY_COLORS.get(display_rarity, Color.WHITE)

	_add_label("YOU GOT:", _W / 2.0, _H * 0.62, 16, Color(0.667, 0.667, 0.667))
	_add_label(display_name,  _W / 2.0, _H * 0.62 + 30, 26, item_color, true)
	_add_label(rarity_name,   _W / 2.0, _H * 0.62 + 60, 16, rarity_color)
	_add_label(display_desc,  _W / 2.0, _H * 0.62 + 82, 12, Color(0.667, 0.667, 0.667))

	var type_label := "Paddle" if _item.get("type") == "paddle" else "Superpower"
	_add_label("Type: %s" % type_label, _W / 2.0, _H * 0.62 + 100, 11, Color(0.533, 0.533, 0.533))

	# Added to inventory notice
	_add_label("Added to inventory!", _W / 2.0, _H * 0.62 + 120, 13, Color(0.486, 0.988, 0.0))

	# Continue button
	var cont_btn := _make_button("CONTINUE", _W / 2.0, _H * 0.82,
		Color.WHITE, Color(0, 0.2, 0.4), func():
			get_tree().change_scene_to_file("res://scenes/Campaign.tscn" if _mode == "campaign" else "res://scenes/MainMenu.tscn")
	)
	add_child(cont_btn)

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
	lbl.size     = Vector2(_W, font_size + 10)
	lbl.position = Vector2(0, y - (font_size + 10) / 2.0)
	add_child(lbl)
	return lbl

func _make_button(text: String, cx: float, cy: float, fg: Color, bg: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 20
	style.content_margin_right  = 20
	style.content_margin_top    = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    style)
	btn.add_theme_stylebox_override("pressed",  style)
	btn.add_theme_stylebox_override("focus",    style)
	btn.size     = Vector2(220, 44)
	btn.position = Vector2(cx - 110, cy - 22)
	btn.pressed.connect(callback)
	return btn
