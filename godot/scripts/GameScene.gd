extends Node2D
class_name GameScene

## Core gameplay scene – top-down pickleball court, joystick movement, swipe to hit.
## All drawing is done via _draw() / queue_redraw() so the scene needs no external assets.

# ── Viewport ──────────────────────────────────────────────────────────────────
var W: float
var H: float
var NET_Y: float
var MARGIN: float = 28.0

# ── Scene data ────────────────────────────────────────────────────────────────
var opponent_data: Dictionary = {}
var mode: String = "campaign"
var level_index: int = 0

# ── Stats ─────────────────────────────────────────────────────────────────────
var player_stats: Dictionary = {}
var player_max_hp: int = 100
var player_hp: int = 100
var opponent_max_hp: int = 100
var opponent_hp: int = 100

# ── Player ────────────────────────────────────────────────────────────────────
var player_x: float = 0.0
var player_y: float = 0.0
var base_hit_zone: float = 55.0

# ── Opponent ──────────────────────────────────────────────────────────────────
var opp_x: float = 0.0
var opp_y: float = 0.0

# ── Ball ──────────────────────────────────────────────────────────────────────
var ball_x: float = 0.0
var ball_y: float = 0.0
var ball_vx: float = 0.0
var ball_vy: float = 0.0
var ball_active: bool = false
var ball_in_player_zone: bool = false
var ball_spin: int = 0

# ── Gameplay flags ────────────────────────────────────────────────────────────
var game_over: bool = false
var player_serving: bool = true
var can_hit: bool = false
var last_hit_time: float = 0.0
const HIT_COOLDOWN: float = 0.35  # seconds
var session_powers: Array = []
var active_powers: Dictionary = {}  # id -> true/expiry_time
var shield_active: bool = false

# ── Joystick ──────────────────────────────────────────────────────────────────
const JS_BASE_X: float = 80.0
var js_base_y: float = 0.0
const JS_RADIUS: float = 48.0
var js_active: bool = false
var js_pointer_id: int = -1
var js_dx: float = 0.0
var js_dy: float = 0.0

# ── Swipe ─────────────────────────────────────────────────────────────────────
var swipe_active: bool = false
var swipe_pointer_id: int = -1
var swipe_start: Vector2 = Vector2.ZERO
var swipe_start_time: float = 0.0

# ── UI nodes ──────────────────────────────────────────────────────────────────
var _player_hp_bar: ColorRect = null
var _opp_hp_bar: ColorRect = null
var _player_hp_text: Label = null
var _opp_hp_text: Label = null
var _hint_text: Label = null
var _power_buttons: Array[Dictionary] = []
var _canvas: _GameCanvas = null

# ── Timers ────────────────────────────────────────────────────────────────────
var _slow_time_until: float = -1.0
var _wingspan_until: float = -1.0

func _ready() -> void:
	W = get_viewport_rect().size.x
	H = get_viewport_rect().size.y
	NET_Y = round(H * 0.44)

	# Read scene data
	var data := GameState.pop_scene_data()
	opponent_data = data.get("opponent", GameData.CAMPAIGN_OPPONENTS[0])
	mode          = data.get("mode", "campaign")
	level_index   = data.get("level_index", 0)

	# Stats
	var cs := GameState.character
	player_stats   = cs.duplicate()
	player_max_hp  = int(50 + cs.get("health", 13) * 2.5)
	player_hp      = player_max_hp
	var os: Dictionary = opponent_data.get("stats", {})
	opponent_max_hp = int(50 + os.get("health", 15) * 2.5)
	opponent_hp     = opponent_max_hp

	# Positions
	player_x = W / 2.0
	player_y = H * 0.74
	opp_x    = W / 2.0
	opp_y    = H * 0.26
	ball_x   = W / 2.0
	ball_y   = NET_Y + 90
	base_hit_zone = 55.0 + cs.get("accuracy", 13) * 1.8
	js_base_y = H - 100

	session_powers = (GameState.equipped_powers as Array).duplicate()

	# Canvas for custom drawing
	_canvas = _GameCanvas.new(self)
	add_child(_canvas)

	_create_ui()
	_set_input_processing(true)

	# Serve after short delay
	get_tree().create_timer(0.8).timeout.connect(func(): _serve_ball())

func _set_input_processing(on: bool) -> void:
	set_process_input(on)
	set_process(on)

# ── Update ────────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if game_over:
		return
	_move_player(delta)
	_move_ball(delta)
	_update_ai(delta)
	_check_hit_zone()
	_canvas.queue_redraw()

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if game_over:
		return
	if event is InputEventScreenTouch:
		var te := event as InputEventScreenTouch
		if te.pressed:
			_on_down(te.index, te.position)
		else:
			_on_up(te.index, te.position)
	elif event is InputEventScreenDrag:
		var de := event as InputEventScreenDrag
		_on_move(de.index, de.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_on_down(0, mb.position)
			else:
				_on_up(0, mb.position)
	elif event is InputEventMouseMotion:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_on_move(0, (event as InputEventMouseMotion).position)

func _on_down(pid: int, pos: Vector2) -> void:
	var dx := pos.x - JS_BASE_X
	var dy := pos.y - js_base_y
	var dist := sqrt(dx * dx + dy * dy)
	if dist < JS_RADIUS * 1.8 and not js_active:
		js_active     = true
		js_pointer_id = pid
		_apply_joystick(pos)
	elif not swipe_active:
		swipe_active     = true
		swipe_pointer_id = pid
		swipe_start      = pos
		swipe_start_time = Time.get_ticks_msec() / 1000.0

func _on_move(pid: int, pos: Vector2) -> void:
	if pid == js_pointer_id and js_active:
		_apply_joystick(pos)

func _on_up(pid: int, pos: Vector2) -> void:
	if pid == js_pointer_id:
		js_active = false
		js_dx = 0.0
		js_dy = 0.0
	if pid == swipe_pointer_id and swipe_active:
		swipe_active = false
		if can_hit:
			var sdx := pos.x - swipe_start.x
			var sdy := pos.y - swipe_start.y
			var dur := Time.get_ticks_msec() / 1000.0 - swipe_start_time
			_execute_hit(sdx, sdy, dur)

func _apply_joystick(pos: Vector2) -> void:
	var dx := pos.x - JS_BASE_X
	var dy := pos.y - js_base_y
	var dist := sqrt(dx * dx + dy * dy)
	var clamped: float = min(dist, JS_RADIUS)
	var angle := atan2(dy, dx)
	js_dx = cos(angle) * clamped / JS_RADIUS
	js_dy = sin(angle) * clamped / JS_RADIUS

# ── Hit mechanics ─────────────────────────────────────────────────────────────

func _execute_hit(sdx: float, sdy: float, duration: float) -> void:
	if game_over or not ball_active:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_hit_time < HIT_COOLDOWN:
		return
	last_hit_time = now

	var len := sqrt(sdx * sdx + sdy * sdy)
	if len < 8.0:
		_flash_feedback("TAP HIT!", Color.WHITE, 1.0)
		return

	var nx := sdx / len
	var ny := sdy / len

	# Enforce upward direction
	if ny > -0.15:
		ny = -0.75
	var renorm := sqrt(nx * nx + ny * ny)
	nx /= renorm; ny /= renorm

	var paddle: Dictionary = GameData.get_paddle(GameState.equipped_paddle)
	var base_speed: float = 380.0 + float(player_stats.get("power", 12)) * 14.0 * float(paddle.get("power", 1.0))

	# Timing bonus
	var bonus := 1.0
	var bonus_label := ""
	if duration < 0.130:
		bonus = 1.8; bonus_label = "×1.8 PERFECT!"
	elif duration < 0.230:
		bonus = 1.5; bonus_label = "×1.5 GREAT!"
	elif duration < 0.380:
		bonus = 1.2; bonus_label = "×1.2 GOOD"

	# Faster Hit superpower
	if active_powers.has("faster_hit"):
		bonus *= 1.3
		active_powers.erase("faster_hit")

	# Spin Hit superpower
	if active_powers.has("spin_hit"):
		ball_spin = 1 if randf() > 0.5 else -1
		active_powers.erase("spin_hit")
	else:
		ball_spin = 0

	# Accuracy deviation
	var acc: float = float(player_stats.get("accuracy", 13)) * float(paddle.get("accuracy", 1.0))
	var deviation: float = max(0.0, (1.0 - acc / 45.0)) * 0.35
	nx += (randf() - 0.5) * deviation
	ny += (randf() - 0.5) * deviation * 0.4
	var renorm2 := sqrt(nx * nx + ny * ny)
	nx /= renorm2; ny /= renorm2

	ball_vx = nx * base_speed * bonus
	ball_vy = ny * base_speed * bonus
	ball_in_player_zone = false
	can_hit = false

	var color: Color
	if bonus >= 1.8:   color = Color(1.0, 0.843, 0.0)
	elif bonus >= 1.5: color = Color(0.0, 1.0, 0.533)
	elif bonus >= 1.2: color = Color(0.533, 1.0, 1.0)
	else:              color = Color.WHITE
	_flash_feedback(bonus_label if bonus_label != "" else "HIT!", color, bonus)

# ── Movement ──────────────────────────────────────────────────────────────────

func _move_player(dt: float) -> void:
	var speed: float = 100.0 + float(player_stats.get("moveSpeed", 13)) * 3.8
	player_x += js_dx * speed * dt
	player_y += js_dy * speed * dt
	player_x  = clamp(player_x, MARGIN + 20, W - MARGIN - 20)
	player_y  = clamp(player_y, NET_Y + 18, H - 50)

func _move_ball(dt: float) -> void:
	if not ball_active:
		return
	var slow := 0.38 if active_powers.has("slow_time") else 1.0

	ball_x += ball_vx * dt * slow
	ball_y += ball_vy * dt * slow

	# Spin drift
	if ball_spin != 0 and ball_vy < 0:
		ball_vx += ball_spin * 90.0 * dt

	# Wall bounces
	if ball_x < MARGIN + 10:
		ball_x  = MARGIN + 10
		ball_vx = abs(ball_vx) * 0.92
	if ball_x > W - MARGIN - 10:
		ball_x  = W - MARGIN - 10
		ball_vx = -abs(ball_vx) * 0.92

	# Track zone
	if ball_vy > 0 and ball_y > NET_Y + 5:
		ball_in_player_zone = true
	elif ball_vy < 0 and ball_y < NET_Y - 5:
		ball_in_player_zone = false

	# Scoring conditions
	if ball_y < 40:
		_player_scored()
		return
	if ball_y > H - 40:
		_opponent_scored()
		return

	# Net fault – ball going down hits net
	if ball_vy > 0 and abs(ball_y - NET_Y) < 7 and ball_x > MARGIN and ball_x < W - MARGIN:
		_player_scored()

# ── Hit zone ──────────────────────────────────────────────────────────────────

func _check_hit_zone() -> void:
	if not ball_in_player_zone or not ball_active:
		can_hit = false
		return
	var dx := ball_x - player_x
	var dy := ball_y - player_y
	var dist := sqrt(dx * dx + dy * dy)
	var radius := base_hit_zone * 2.0 if active_powers.has("wingspan") else base_hit_zone
	can_hit = dist < radius

# ── AI ────────────────────────────────────────────────────────────────────────

func _update_ai(dt: float) -> void:
	var stats: Dictionary = opponent_data.get("stats", {})
	var move_speed: int = stats.get("moveSpeed", 10)
	var power: int      = stats.get("power", 10)
	var accuracy: int   = stats.get("accuracy", 10)
	var ai_speed: float = 75.0 + move_speed * 3.2

	if abs(opp_x - ball_x) > 4:
		var dir := 1.0 if opp_x < ball_x else -1.0
		opp_x += dir * ai_speed * dt
		opp_x  = clamp(opp_x, MARGIN + 20, W - MARGIN - 20)

	if not ball_in_player_zone and ball_vy < 0 and ball_active and ball_y < NET_Y - 5:
		var dx := ball_x - opp_x
		var dy := ball_y - opp_y
		var dist := sqrt(dx * dx + dy * dy)
		var ai_zone: float = 55.0 + accuracy * 1.8
		if dist < ai_zone:
			var ai_base: float = 340.0 + power * 13.0
			var inaccuracy: float = max(0.0, 1.0 - accuracy / 40.0) * 120.0
			var target_px: float = player_x + (randf() - 0.5) * inaccuracy
			var target_py: float = H * 0.72
			var tdx: float = target_px - ball_x
			var tdy := target_py - ball_y
			var tlen := sqrt(tdx * tdx + tdy * tdy)
			ball_vx = (tdx / tlen) * ai_base
			ball_vy = (tdy / tlen) * ai_base
			ball_in_player_zone = false
			ball_spin = 0
			can_hit   = false

# ── Scoring ───────────────────────────────────────────────────────────────────

func _player_scored() -> void:
	ball_active = false
	can_hit     = false
	var paddle: Dictionary = GameData.get_paddle(GameState.equipped_paddle)
	var dmg := int((10 + player_stats.get("power", 12) * 2.2) * paddle.get("power", 1.0))
	opponent_hp = max(0, opponent_hp - dmg)
	_update_hp_bars()
	_show_damage(opp_x, opp_y, dmg, false)
	if opponent_hp <= 0:
		_end_match(true)
	else:
		player_serving = true
		get_tree().create_timer(1.1).timeout.connect(func(): _serve_ball())

func _opponent_scored() -> void:
	ball_active = false
	can_hit     = false
	if shield_active:
		shield_active = false
		_show_damage(player_x, player_y, 0, true, "SHIELD!")
		player_serving = false
		get_tree().create_timer(1.1).timeout.connect(func(): _serve_ball())
		return
	var stats: Dictionary = opponent_data.get("stats", {})
	var dmg := int(10 + float(stats.get("power", 10)) * 2.2)
	player_hp = max(0, player_hp - dmg)
	_update_hp_bars()
	_show_damage(player_x, player_y, dmg, true)
	if player_hp <= 0:
		_end_match(false)
	else:
		player_serving = false
		get_tree().create_timer(1.1).timeout.connect(func(): _serve_ball())

# ── Serve ─────────────────────────────────────────────────────────────────────

func _serve_ball() -> void:
	if game_over:
		return
	ball_x  = W / 2.0 + (randf() - 0.5) * 60
	ball_y  = H * 0.64 if player_serving else H * 0.36
	var speed := 260.0
	var angle := -PI / 2.0 + (randf() - 0.5) * 0.6 if player_serving else PI / 2.0 + (randf() - 0.5) * 0.6
	ball_vx = cos(angle) * speed
	ball_vy = sin(angle) * speed
	ball_active          = true
	ball_in_player_zone  = player_serving
	ball_spin            = 0
	can_hit              = false
	if _hint_text != null:
		_hint_text.show()

# ── Superpower activation ─────────────────────────────────────────────────────

func _activate_power(power_id: String) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	match power_id:
		"faster_hit":
			active_powers["faster_hit"] = true
			_flash_feedback("Faster Hit READY!", Color(0.0, 0.667, 1.0), 1.0)
		"dash":
			var dir: float = sign(js_dx) if js_dx != 0 else (1.0 if randf() > 0.5 else -1.0)
			player_x = clamp(player_x + dir * 90.0, MARGIN + 20, W - MARGIN - 20)
			_flash_feedback("DASH!", Color(0.533, 1.0, 0.0), 1.0)
		"slow_time":
			active_powers["slow_time"] = true
			_flash_feedback("SLOW TIME!", Color(0.667, 0.0, 1.0), 1.0)
			get_tree().create_timer(3.0).timeout.connect(func(): active_powers.erase("slow_time"))
		"spin_hit":
			active_powers["spin_hit"] = true
			_flash_feedback("Spin Ready!", Color(1.0, 0.533, 0.0), 1.0)
		"wingspan":
			active_powers["wingspan"] = true
			_flash_feedback("WINGSPAN!", Color(0.0, 1.0, 0.667), 1.0)
			get_tree().create_timer(8.0).timeout.connect(func(): active_powers.erase("wingspan"))
		"shield":
			shield_active = true
			_flash_feedback("SHIELD UP!", Color(1.0, 1.0, 0.0), 1.0)

# ── End match ─────────────────────────────────────────────────────────────────

func _end_match(player_won: bool) -> void:
	game_over   = false  # allow input briefly for buttons
	ball_active = false
	if _hint_text != null:
		_hint_text.hide()
	_set_input_processing(false)
	_canvas.queue_redraw()

	# Dim overlay
	var overlay := ColorRect.new()
	overlay.color    = Color(0, 0, 0, 0.72)
	overlay.size     = Vector2(W, H)
	overlay.position = Vector2.ZERO
	add_child(overlay)

	var result_text  := "VICTORY!" if player_won else "DEFEATED"
	var result_color := Color(1.0, 0.843, 0.0) if player_won else Color(1.0, 0.267, 0.267)

	_add_result_label(result_text, W / 2.0, H / 2.0 - 90, 46, result_color)

	if player_won:
		var xp_gain := int(40 + opponent_data.get("level", 1) * 18)
		GameState.add_xp(xp_gain)

		var roll := randf()
		var orb_type := "gold" if roll < 0.08 else ("silver" if roll < 0.32 else "bronze")

		_add_result_label("+%d XP  ·  Level %d" % [xp_gain, GameState.level],
			W / 2.0, H / 2.0 - 40, 18, Color(1.0, 0.843, 0.0))
		_add_result_label("Loot Orb: %s" % orb_type.to_upper(), W / 2.0, H / 2.0 - 10, 15,
			Color(1.0, 0.843, 0.0) if orb_type == "gold" else (Color(0.753, 0.753, 0.753) if orb_type == "silver" else Color(0.804, 0.498, 0.196)))

		# Advance campaign
		if mode == "campaign" and level_index >= GameState.campaign_progress:
			GameState.campaign_progress = level_index + 1
			GameState.save_game()

		var loot_btn := _make_result_button("OPEN LOOT", W / 2.0, H / 2.0 + 50,
			Color.WHITE, Color(0.2, 0.333, 0), func():
				GameState.store_scene_data({"orb_type": orb_type, "mode": mode, "level_index": level_index})
				get_tree().change_scene_to_file("res://scenes/LootScene.tscn")
		)
		add_child(loot_btn)
	else:
		_add_result_label("Better luck next time!", W / 2.0, H / 2.0 - 35, 16, Color(0.667, 0.667, 0.667))

		var retry_btn := _make_result_button("RETRY", W / 2.0, H / 2.0 + 50,
			Color.WHITE, Color(0.333, 0, 0), func():
				GameState.store_scene_data({"opponent": opponent_data, "mode": mode, "level_index": level_index})
				get_tree().change_scene_to_file("res://scenes/GameScene.tscn")
		)
		add_child(retry_btn)

	var menu_btn := _make_result_button("← Main Menu", W / 2.0, H / 2.0 + 115,
		Color(0.667, 0.667, 0.667), Color(0.1, 0.1, 0.1), func():
			get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	add_child(menu_btn)

# ── UI creation ───────────────────────────────────────────────────────────────

func _create_ui() -> void:
	# Player HP bar
	_add_small_label(GameState.character.get("name", "YOU"), 10, 8, Color(0.533, 0.667, 1.0))
	var php_bg := ColorRect.new()
	php_bg.color    = Color(0.2, 0.2, 0.2)
	php_bg.size     = Vector2(160, 13)
	php_bg.position = Vector2(10, 16)
	add_child(php_bg)
	_player_hp_bar = ColorRect.new()
	_player_hp_bar.color    = Color(0.0, 1.0, 0.267)
	_player_hp_bar.size     = Vector2(160, 13)
	_player_hp_bar.position = Vector2(10, 16)
	add_child(_player_hp_bar)
	_player_hp_text = Label.new()
	_player_hp_text.add_theme_font_size_override("font_size", 10)
	_player_hp_text.add_theme_color_override("font_color", Color.WHITE)
	_player_hp_text.text     = "%d/%d" % [player_hp, player_max_hp]
	_player_hp_text.position = Vector2(176, 14)
	add_child(_player_hp_text)

	# Opponent HP bar
	var opp_name: String = opponent_data.get("name", "Opponent")
	_add_small_label(opp_name, W - 10, 8, Color(1.0, 0.533, 0.533), true)
	var ohp_bg := ColorRect.new()
	ohp_bg.color    = Color(0.2, 0.2, 0.2)
	ohp_bg.size     = Vector2(160, 13)
	ohp_bg.position = Vector2(W - 170, 16)
	add_child(ohp_bg)
	_opp_hp_bar = ColorRect.new()
	_opp_hp_bar.color    = Color(1.0, 0.2, 0.2)
	_opp_hp_bar.size     = Vector2(160, 13)
	_opp_hp_bar.position = Vector2(W - 170, 16)
	add_child(_opp_hp_bar)
	_opp_hp_text = Label.new()
	_opp_hp_text.add_theme_font_size_override("font_size", 10)
	_opp_hp_text.add_theme_color_override("font_color", Color.WHITE)
	_opp_hp_text.text     = "%d/%d" % [opponent_hp, opponent_max_hp]
	_opp_hp_text.position = Vector2(W - 170 - 30, 14)
	add_child(_opp_hp_text)

	# Mode label
	var mode_label := "RANKED" if mode == "ranked" else "CAMPAIGN"
	_add_small_label(mode_label, W / 2.0, 15, Color(0.667, 0.667, 0.667))

	# Superpower buttons
	_create_power_buttons()

	# Hint
	_hint_text = Label.new()
	_hint_text.text = "Joystick: move  |  Swipe: hit"
	_hint_text.add_theme_font_size_override("font_size", 10)
	_hint_text.add_theme_color_override("font_color", Color(0.333, 0.333, 0.333))
	_hint_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_text.size     = Vector2(W, 16)
	_hint_text.position = Vector2(0, H - 24)
	add_child(_hint_text)

func _add_small_label(text: String, x: float, y: float, color: Color, right_align: bool = false) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", color)
	if right_align:
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lbl.size     = Vector2(160, 14)
		lbl.position = Vector2(x - 160, y)
	else:
		lbl.size     = Vector2(160, 14)
		lbl.position = Vector2(x, y)
	add_child(lbl)

func _create_power_buttons() -> void:
	for i in min(session_powers.size(), 3):
		var power_id: String = session_powers[i]
		var power: Dictionary = GameData.get_superpower(power_id)
		if power.is_empty():
			continue
		var bx: float = W - 35.0 - i * 55.0
		var by := js_base_y

		var btn := Button.new()
		btn.text = power.get("name", "?").substr(0, 5)
		btn.add_theme_font_size_override("font_size", 9)
		btn.add_theme_color_override("font_color", Color.WHITE)
		var style := StyleBoxFlat.new()
		style.bg_color = (power.get("color", Color.WHITE) as Color)
		style.bg_color.a = 0.85
		style.corner_radius_top_left     = 22
		style.corner_radius_top_right    = 22
		style.corner_radius_bottom_left  = 22
		style.corner_radius_bottom_right = 22
		btn.add_theme_stylebox_override("normal",  style)
		btn.add_theme_stylebox_override("hover",   style)
		btn.add_theme_stylebox_override("pressed", style)
		btn.add_theme_stylebox_override("focus",   style)
		btn.size     = Vector2(44, 44)
		btn.position = Vector2(bx - 22, by - 22)
		var pid := power_id
		btn.pressed.connect(func():
			_activate_power(pid)
			btn.queue_free()
		)
		add_child(btn)
		_power_buttons.append({"id": power_id, "btn": btn})

func _update_hp_bars() -> void:
	var p_pct := float(player_hp) / float(player_max_hp)
	_player_hp_bar.size.x = 160.0 * p_pct
	if p_pct > 0.5:   _player_hp_bar.color = Color(0.0, 1.0, 0.267)
	elif p_pct > 0.25: _player_hp_bar.color = Color(1.0, 0.667, 0.0)
	else:              _player_hp_bar.color = Color(1.0, 0.133, 0.133)
	_player_hp_text.text = "%d/%d" % [player_hp, player_max_hp]

	var o_pct := float(opponent_hp) / float(opponent_max_hp)
	_opp_hp_bar.size.x = 160.0 * o_pct
	if o_pct > 0.5:   _opp_hp_bar.color = Color(1.0, 0.2, 0.2)
	elif o_pct > 0.25: _opp_hp_bar.color = Color(1.0, 0.533, 0.0)
	else:              _opp_hp_bar.color = Color(1.0, 0.133, 0.133)
	_opp_hp_text.text = "%d/%d" % [opponent_hp, opponent_max_hp]

func _flash_feedback(text: String, color: Color, multiplier: float) -> void:
	var t := Label.new()
	t.text = text
	var fs := 26 if multiplier >= 1.5 else 20
	t.add_theme_font_size_override("font_size", fs)
	t.add_theme_color_override("font_color", color)
	t.add_theme_color_override("font_outline_color", Color.BLACK)
	t.add_theme_constant_override("outline_size", 3)
	t.position = Vector2(W * 0.6 - 60, H * 0.62)
	add_child(t)
	var tween := create_tween()
	tween.tween_property(t, "position:y", t.position.y - 55, 0.9)
	tween.parallel().tween_property(t, "modulate:a", 0.0, 0.9)
	tween.tween_callback(t.queue_free)

func _show_damage(x: float, y: float, amount: int, is_player: bool, override_text: String = "") -> void:
	var text := override_text if override_text != "" else ("-%d HP" % amount if amount > 0 else "0")
	var color := Color(1.0, 0.267, 0.267) if is_player else Color(1.0, 0.533, 0.0)
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", 20)
	t.add_theme_color_override("font_color", color)
	t.add_theme_color_override("font_outline_color", Color.BLACK)
	t.add_theme_constant_override("outline_size", 3)
	t.position = Vector2(x - 30, y - 10)
	add_child(t)
	var tween := create_tween()
	tween.tween_property(t, "position:y", y - 65, 1.0)
	tween.parallel().tween_property(t, "modulate:a", 0.0, 1.0)
	tween.tween_callback(t.queue_free)

func _add_result_label(text: String, cx: float, y: float, fs: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", fs)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size     = Vector2(W, fs + 10)
	lbl.position = Vector2(0, y - (fs + 10) / 2.0)
	add_child(lbl)
	return lbl

func _make_result_button(text: String, cx: float, cy: float, fg: Color, bg: Color, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", fg)
	btn.add_theme_color_override("font_hover_color", fg)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.corner_radius_top_left     = 6
	style.corner_radius_top_right    = 6
	style.corner_radius_bottom_left  = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left   = 18
	style.content_margin_right  = 18
	style.content_margin_top    = 10
	style.content_margin_bottom = 10
	btn.add_theme_stylebox_override("normal",   style)
	btn.add_theme_stylebox_override("hover",    style)
	btn.add_theme_stylebox_override("pressed",  style)
	btn.add_theme_stylebox_override("focus",    style)
	btn.size     = Vector2(220, 46)
	btn.position = Vector2(cx - 110, cy - 23)
	btn.pressed.connect(callback)
	return btn


# ── Inner drawing class ────────────────────────────────────────────────────────
## Handles all canvas drawing so the parent Node2D doesn't mix logic with draw calls.

class _GameCanvas extends Node2D:
	var _g: GameScene  # back-reference

	func _init(game: GameScene) -> void:
		_g = game

	func _draw() -> void:
		_draw_court()
		_draw_player()
		_draw_opponent()
		_draw_ball()
		_draw_hit_ring()
		_draw_joystick()

	func _draw_court() -> void:
		var W := _g.W; var H := _g.H
		var NET_Y := _g.NET_Y; var M := _g.MARGIN

		# Court surface
		draw_rect(Rect2(0, 0, W, H), Color(0.176, 0.353, 0.106))
		draw_rect(Rect2(M, 45, W - M * 2, NET_Y - 45 - 4), Color(0.204, 0.400, 0.125))
		draw_rect(Rect2(M, NET_Y + 4, W - M * 2, H - NET_Y - 4 - 45), Color(0.176, 0.353, 0.106))

		# Boundary
		draw_rect(Rect2(M, 45, W - M * 2, H - 90), Color(1, 1, 1, 0.9), false, 3.0)

		# Net
		draw_line(Vector2(M, NET_Y), Vector2(W - M, NET_Y), Color(0.933, 0.933, 0.933), 5.0)
		draw_circle(Vector2(M, NET_Y), 5, Color(0.8, 0.8, 0.8))
		draw_circle(Vector2(W - M, NET_Y), 5, Color(0.8, 0.8, 0.8))

		# Kitchen lines
		draw_line(Vector2(M, NET_Y - 65), Vector2(W - M, NET_Y - 65), Color(1, 1, 1, 0.45), 2.0)
		draw_line(Vector2(M, NET_Y + 65), Vector2(W - M, NET_Y + 65), Color(1, 1, 1, 0.45), 2.0)

		# Center service lines
		draw_line(Vector2(W / 2, 45), Vector2(W / 2, NET_Y - 65), Color(1, 1, 1, 0.35), 1.0)
		draw_line(Vector2(W / 2, NET_Y + 65), Vector2(W / 2, H - 45), Color(1, 1, 1, 0.35), 1.0)

		# Net shadow
		draw_line(Vector2(M, NET_Y + 3), Vector2(W - M, NET_Y + 3), Color(0, 0, 0, 0.2), 3.0)

	func _draw_player() -> void:
		var px := _g.player_x; var py := _g.player_y
		# Shadow
		draw_ellipse(Vector2(px, py + 18), Vector2(15, 5), Color(0, 0, 0, 0.3))
		# Body
		draw_circle(Vector2(px, py), 18, Color(0.0, 0.533, 1.0))
		draw_circle(Vector2(px - 5, py - 5), 8, Color(0.267, 0.667, 1.0, 0.6))
		# Paddle
		var paddle: Dictionary = GameData.get_paddle(GameState.equipped_paddle)
		var pcol: Color = paddle.get("color", Color.WHITE)
		draw_rect(Rect2(px + 10, py - 22, 8, 20), pcol)

	func _draw_opponent() -> void:
		var ox := _g.opp_x; var oy := _g.opp_y
		# Shadow
		draw_ellipse(Vector2(ox, oy + 18), Vector2(15, 5), Color(0, 0, 0, 0.3))
		# Body
		draw_circle(Vector2(ox, oy), 18, Color(1.0, 0.2, 0.2))
		draw_circle(Vector2(ox - 5, oy - 5), 8, Color(1.0, 0.467, 0.467, 0.6))
		# Opponent paddle
		var paddle: Dictionary = GameData.get_paddle(_g.opponent_data.get("paddle", "wooden"))
		draw_rect(Rect2(ox - 18, oy - 22, 8, 20), paddle.get("color", Color.WHITE))

	func _draw_ball() -> void:
		if not _g.ball_active:
			return
		var bx := _g.ball_x; var by := _g.ball_y
		draw_circle(Vector2(bx + 2, by + 4), 8, Color(0, 0, 0, 0.25))
		draw_circle(Vector2(bx, by), 9, Color.WHITE)
		draw_circle(Vector2(bx - 3, by - 3), 3, Color(1, 1, 1, 0.8))
		if _g.ball_spin != 0:
			draw_arc(Vector2(bx, by), 11, 0, TAU, 32, Color(1.0, 0.533, 0.0, 0.8), 2.0)

	func _draw_hit_ring() -> void:
		if not _g.can_hit:
			return
		var radius := _g.base_hit_zone * 2.0 if _g.active_powers.has("wingspan") else _g.base_hit_zone
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 150.0)
		draw_arc(Vector2(_g.player_x, _g.player_y), radius, 0, TAU, 48,
			Color(1.0, 1.0, 0.0, 0.4 + pulse * 0.4), 2.0)
		draw_arc(Vector2(_g.player_x, _g.player_y), radius + 4, 0, TAU, 48,
			Color(1.0, 1.0, 1.0, 0.2), 1.0)

	func _draw_joystick() -> void:
		var bx := _g.JS_BASE_X; var by := _g.js_base_y
		draw_circle(Vector2(bx, by), _g.JS_RADIUS, Color(0, 0, 0, 0.35))
		draw_arc(Vector2(bx, by), _g.JS_RADIUS, 0, TAU, 48, Color(1, 1, 1, 0.3), 2.0)

		var knob_x := bx + _g.js_dx * _g.JS_RADIUS
		var knob_y := by + _g.js_dy * _g.JS_RADIUS
		draw_circle(Vector2(knob_x, knob_y), 20, Color(1, 1, 1, 0.7))
		draw_circle(Vector2(knob_x - 4, knob_y - 4), 7, Color(1, 1, 1, 0.9))

	# Helper: draw_ellipse approximation
	func draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		var steps := 24
		for i in steps + 1:
			var a := (i / float(steps)) * TAU
			points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
		draw_colored_polygon(points, color)
