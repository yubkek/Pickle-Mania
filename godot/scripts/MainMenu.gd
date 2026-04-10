extends Node2D

## Main menu scene – title, campaign/ranked/inventory buttons, player info.

const BTN_FONT_SIZE  := 18
const BTN_PADDING    := Vector2(22, 10)
const BTN_SMALL_SIZE := 14

var _W: float
var _H: float
var _msg_label: Label = null

func _ready() -> void:
	_W = get_viewport_rect().size.x
	_H = get_viewport_rect().size.y
	_build_ui()

func _build_ui() -> void:
	_draw_background()
	_draw_title()
	_draw_player_info()
	_draw_buttons()
	_draw_version()

# ── Background ─────────────────────────────────────────────────────────────────

func _draw_background() -> void:
	var bg := ColorRect.new()
	bg.color    = Color(0.039, 0.086, 0.157)
	bg.size     = Vector2(_W, _H)
	bg.position = Vector2.ZERO
	add_child(bg)

	# Decorative court outline
	var lines := MeshInstance2D.new()
	add_child(lines)
	var c := CanvasGroup.new()
	add_child(c)
	# Draw using a simple Node2D child that overrides _draw
	var deco := _CourtDeco.new(_W, _H)
	add_child(deco)

# ── Title ──────────────────────────────────────────────────────────────────────

func _draw_title() -> void:
	_add_label("PICKLE", _W / 2.0, _H * 0.12, 56, Color(0.486, 0.988, 0.0), true, Color(0, 0.2, 0))
	_add_label("MANIA",  _W / 2.0, _H * 0.12 + 62, 42, Color(1.0, 0.843, 0.0), true, Color(0.333, 0.2, 0))
	_add_label("Pickleball Evolved", _W / 2.0, _H * 0.12 + 108, 14, Color(0.667, 1.0, 0.667))

# ── Player info ────────────────────────────────────────────────────────────────

func _draw_player_info() -> void:
	if not GameState.created:
		return
	_add_label("LVL %d · %s" % [GameState.level, GameState.character.get("name", "Player")],
		_W / 2.0, _H * 0.32, 14, Color(0.667, 0.667, 1.0))

	# XP bar background
	var xp_bg := ColorRect.new()
	xp_bg.color    = Color(0.2, 0.2, 0.2)
	xp_bg.size     = Vector2(180, 10)
	xp_bg.position = Vector2(_W / 2.0 - 90, _H * 0.32 + 18)
	add_child(xp_bg)

	var xp_fill := ColorRect.new()
	xp_fill.color    = Color(0.0, 0.667, 1.0)
	xp_fill.size     = Vector2(180.0 * GameState.xp_progress(), 10)
	xp_fill.position = Vector2(_W / 2.0 - 90, _H * 0.32 + 18)
	add_child(xp_fill)

	_add_label("%d XP" % GameState.xp, _W / 2.0, _H * 0.32 + 32, 10, Color(0.533, 0.533, 1.0))

# ── Buttons ────────────────────────────────────────────────────────────────────

func _draw_buttons() -> void:
	var btn_y   := _H * 0.50
	var spacing := 62.0

	_make_button("CAMPAIGN", _W / 2.0, btn_y, Color(0.486, 0.988, 0.0), Color(0, 0.2, 0), func():
		if not GameState.created:
			_go_to("res://scenes/CharCreation.tscn", {"next": "campaign"})
		else:
			get_tree().change_scene_to_file("res://scenes/Campaign.tscn")
	)

	var rank_locked := GameState.level < GameData.RANK_UNLOCK_LEVEL
	var rank_label  := "RANKED" if not rank_locked else "RANKED (LVL %d)" % GameData.RANK_UNLOCK_LEVEL
	_make_button(rank_label, _W / 2.0, btn_y + spacing,
		Color(0.4, 0.4, 0.4) if rank_locked else Color(1.0, 0.843, 0.0),
		Color(0.133, 0.133, 0.133) if rank_locked else Color(0.267, 0.2, 0),
		func():
			if rank_locked:
				_flash_msg("Unlock Ranked at Level %d!" % GameData.RANK_UNLOCK_LEVEL)
				return
			if not GameState.created:
				_go_to("res://scenes/CharCreation.tscn", {"next": "ranked"})
			else:
				_start_ranked()
	)

	_make_button("INVENTORY", _W / 2.0, btn_y + spacing * 2, Color(0.0, 0.667, 1.0), Color(0, 0.067, 0.2), func():
		get_tree().change_scene_to_file("res://scenes/Inventory.tscn")
	)

	if GameState.created:
		_make_button("RESET SAVE", _W / 2.0, btn_y + spacing * 3,
			Color(1.0, 0.267, 0.267), Color(0.2, 0, 0), func():
				GameState.reset()
				get_tree().reload_current_scene()
		, true)

# ── Version label ──────────────────────────────────────────────────────────────

func _draw_version() -> void:
	var lbl := Label.new()
	lbl.text              = "v1.0"
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0.267, 0.267, 0.267))
	lbl.position          = Vector2(_W - 40, _H - 20)
	add_child(lbl)

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
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(_W, font_size + 8)
	lbl.position = Vector2(0, y - (font_size + 8) / 2.0)
	add_child(lbl)
	return lbl

func _make_button(text: String, cx: float, cy: float,
		fg: Color, bg: Color, callback: Callable, small: bool = false) -> Button:
	var btn := Button.new()
	btn.text = text
	var fs   := BTN_SMALL_SIZE if small else BTN_FONT_SIZE
	btn.add_theme_font_size_override("font_size", fs)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	btn.add_theme_color_override("font_pressed_color", fg)
	var style := StyleBoxFlat.new()
	style.bg_color           = bg
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = BTN_PADDING.x if not small else 14
	style.content_margin_right  = BTN_PADDING.x if not small else 14
	style.content_margin_top    = BTN_PADDING.y if not small else 6
	style.content_margin_bottom = BTN_PADDING.y if not small else 6
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    style)
	btn.add_theme_stylebox_override("pressed",  style)
	btn.add_theme_stylebox_override("focus",    style)
	btn.pressed.connect(callback)
	btn.size = Vector2(240 if not small else 160, fs + 24)
	btn.position = Vector2(cx - btn.size.x / 2.0, cy - btn.size.y / 2.0)
	add_child(btn)
	return btn

func _go_to(scene_path: String, _meta: Dictionary = {}) -> void:
	# Store meta in a scene-agnostic way via a global dict on the tree root
	get_tree().change_scene_to_file(scene_path)

func _start_ranked() -> void:
	var opponents := GameData.CAMPAIGN_OPPONENTS
	var opp: Dictionary = opponents[randi() % opponents.size()]
	# Pass data through a temporary node on the root
	_store_scene_data({"opponent": opp, "mode": "ranked", "level_index": 0})
	get_tree().change_scene_to_file("res://scenes/GameScene.tscn")

func _flash_msg(msg: String) -> void:
	if _msg_label != null:
		_msg_label.queue_free()
	_msg_label = _add_label(msg, _W / 2.0, _H * 0.9, 16, Color(1.0, 0.843, 0.0))
	get_tree().create_timer(2.0).timeout.connect(func():
		if _msg_label != null:
			_msg_label.queue_free()
			_msg_label = null
	)

## Stashes data into a persistent node so the next scene can read it.
static func _store_scene_data(data: Dictionary) -> void:
	var root := Engine.get_main_loop().root
	var existing := root.get_node_or_null("SceneData")
	if existing != null:
		existing.queue_free()
	var node := Node.new()
	node.name = "SceneData"
	node.set_meta("data", data)
	root.add_child(node)

## Reads and clears the stashed scene data.
static func pop_scene_data() -> Dictionary:
	var root := Engine.get_main_loop().root
	var node := root.get_node_or_null("SceneData")
	if node == null:
		return {}
	var data: Dictionary = node.get_meta("data", {})
	node.queue_free()
	return data


# ── Inner draw helper ──────────────────────────────────────────────────────────

class _CourtDeco extends Node2D:
	var _W: float
	var _H: float

	func _init(w: float, h: float) -> void:
		_W = w
		_H = h

	func _draw() -> void:
		draw_rect(Rect2(30, _H * 0.3, _W - 60, _H * 0.4), Color(0.176, 0.353, 0.106, 0.6), false, 1.0)
		draw_line(Vector2(30, _H * 0.5), Vector2(_W - 30, _H * 0.5), Color(0.227, 0.478, 0.145, 0.4), 2.0)
		draw_line(Vector2(_W / 2.0, _H * 0.3), Vector2(_W / 2.0, _H * 0.7), Color(0.227, 0.478, 0.145, 0.4), 1.0)
