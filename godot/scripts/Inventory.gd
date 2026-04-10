extends Node2D

## Inventory scene – view collected paddles & superpowers, equip items.

var _W: float
var _H: float

# Scroll container reference so we can add items into it
var _scroll: ScrollContainer = null
var _content: VBoxContainer  = null
var _tab: int = 0  # 0 = paddles, 1 = powers

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

	_add_label("INVENTORY", _W / 2.0, 28, 24, Color(0.0, 0.667, 1.0), true, Color(0, 0, 0.3))

	# Player level / stats bar
	_add_label("LVL %d  ·  %s" % [GameState.level, GameState.character.get("name", "Player")],
		_W / 2.0, 58, 13, Color(0.667, 0.667, 1.0))

	# Tab buttons
	_make_tab_button("Paddles", _W * 0.3, 82, 0)
	_make_tab_button("Powers",  _W * 0.7, 82, 1)

	# Scroll area for items
	_scroll = ScrollContainer.new()
	_scroll.size     = Vector2(_W, _H - 145)
	_scroll.position = Vector2(0, 100)
	add_child(_scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(_content)

	_populate_items()

	# Back button
	var back := _make_button("← BACK", _W / 2.0, _H - 28,
		Color(0.667, 0.667, 0.667), Color(0.1, 0.1, 0.1), func():
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	add_child(back)

func _populate_items() -> void:
	for c in _content.get_children():
		c.queue_free()

	if _tab == 0:
		_populate_paddles()
	else:
		_populate_powers()

func _populate_paddles() -> void:
	# Collect unique owned paddles
	var owned: Dictionary = {}
	for item in GameState.inventory:
		if item.get("type") == "paddle":
			owned[item.get("id", "")] = true

	if owned.is_empty():
		_add_empty_label("No paddles collected yet.")
		return

	for pid in owned:
		var paddle: Dictionary = GameData.get_paddle(pid)
		var is_equipped := GameState.equipped_paddle == pid
		var row := _make_item_row(
			paddle.get("name", "?"),
			paddle.get("desc", ""),
			paddle.get("rarity", "C"),
			paddle.get("color", Color.WHITE),
			"EQUIPPED" if is_equipped else "EQUIP",
			is_equipped,
			func():
				if not is_equipped:
					GameState.equipped_paddle = pid
					GameState.save_game()
					_populate_items()
		)
		_content.add_child(row)

func _populate_powers() -> void:
	# Collect unique owned powers
	var owned: Dictionary = {}
	for item in GameState.inventory:
		if item.get("type") == "power":
			owned[item.get("id", "")] = true

	if owned.is_empty():
		_add_empty_label("No superpowers collected yet.")
		return

	var equipped_set: Dictionary = {}
	for ep in GameState.equipped_powers:
		equipped_set[ep] = true

	for pid in owned:
		var power: Dictionary = GameData.get_superpower(pid)
		if power.is_empty():
			continue
		var is_equipped := equipped_set.has(pid)
		var row := _make_item_row(
			power.get("name", "?"),
			power.get("desc", ""),
			power.get("rarity", "C"),
			power.get("color", Color.WHITE),
			"EQUIPPED" if is_equipped else ("EQUIP" if GameState.equipped_powers.size() < 3 else "FULL"),
			is_equipped,
			func():
				if is_equipped:
					GameState.equipped_powers.erase(pid)
					GameState.save_game()
					_populate_items()
				elif GameState.equipped_powers.size() < 3:
					GameState.equipped_powers.append(pid)
					GameState.save_game()
					_populate_items()
		)
		_content.add_child(row)

func _make_item_row(name: String, desc: String, rarity: String, color: Color,
		btn_label: String, is_equipped: bool, callback: Callable) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.2, 0.0, 0.7) if is_equipped else Color(0.07, 0.07, 0.1)
	style.border_color = color if is_equipped else GameData.RARITY_COLORS.get(rarity, Color.WHITE)
	style.border_width_top    = 1
	style.border_width_bottom = 1
	style.border_width_left   = 3
	style.border_width_right  = 1
	style.content_margin_left   = 10
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_child(hbox)

	# Color dot
	var dot := ColorRect.new()
	dot.color        = color
	dot.custom_minimum_size = Vector2(10, 10)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(dot)

	# Text
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", color)
	vbox.add_child(name_lbl)

	var rarity_lbl := Label.new()
	rarity_lbl.text = "%s  ·  %s" % [GameData.RARITY_NAMES.get(rarity, "?"), desc]
	rarity_lbl.add_theme_font_size_override("font_size", 11)
	rarity_lbl.add_theme_color_override("font_color", GameData.RARITY_COLORS.get(rarity, Color.WHITE))
	vbox.add_child(rarity_lbl)

	# Equip button
	var btn := Button.new()
	btn.text = btn_label
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", Color.WHITE if not is_equipped else Color(0.486, 0.988, 0.0))
	btn.disabled = is_equipped
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.0, 0.267, 0.533) if not is_equipped else Color(0.0, 0.3, 0.0)
	bstyle.corner_radius_top_left     = 4
	bstyle.corner_radius_top_right    = 4
	bstyle.corner_radius_bottom_left  = 4
	bstyle.corner_radius_bottom_right = 4
	bstyle.content_margin_left   = 8
	bstyle.content_margin_right  = 8
	bstyle.content_margin_top    = 4
	bstyle.content_margin_bottom = 4
	btn.add_theme_stylebox_override("normal",   bstyle)
	btn.add_theme_stylebox_override("hover",    bstyle)
	btn.add_theme_stylebox_override("pressed",  bstyle)
	btn.add_theme_stylebox_override("focus",    bstyle)
	btn.pressed.connect(callback)
	hbox.add_child(btn)

	return panel

func _add_empty_label(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(lbl)

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

func _make_tab_button(text: String, cx: float, cy: float, tab_idx: int) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 14)
	var is_active := _tab == tab_idx
	btn.add_theme_color_override("font_color",
		Color(0.0, 0.667, 1.0) if is_active else Color(0.533, 0.533, 0.533))
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.2, 0.4) if is_active else Color(0.1, 0.1, 0.1)
	style.border_color = Color(0.0, 0.667, 1.0) if is_active else Color.TRANSPARENT
	style.border_width_bottom = 2 if is_active else 0
	style.content_margin_left   = 16
	style.content_margin_right  = 16
	style.content_margin_top    = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    style)
	btn.add_theme_stylebox_override("pressed",  style)
	btn.add_theme_stylebox_override("focus",    style)
	btn.size     = Vector2(140, 30)
	btn.position = Vector2(cx - 70, cy - 15)
	var captured := tab_idx
	btn.pressed.connect(func():
		_tab = captured
		# Rebuild UI
		for c in get_children():
			c.queue_free()
		_build_ui()
	)
	add_child(btn)

func _make_button(text: String, cx: float, cy: float, fg: Color, bg: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
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
