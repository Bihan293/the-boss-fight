extends Node2D

const ARENA := Rect2(70, 70, 1140, 580)
const PLAYER_SPEED := 285.0
const PLAYER_MAX_HP := 100.0
const BOSS_MAX_HP := 360.0
const BULLET_RADIUS := 3.0

var player_pos := Vector2(260, 360)
var player_hp := PLAYER_MAX_HP
var player_invuln := 0.0
var player_facing := Vector2.RIGHT
var boss_pos := Vector2(930, 350)
var boss_hp := BOSS_MAX_HP
var boss_state := "intro"
var player_shot_cooldown := 0.0
var boss_shot_cooldown := 1.0
var grenade_timer := 2.5
var melee_timer := 0.0
var intro_index := 0
var intro_timer := 0.0
var dialogue_visible := true
var bullets: Array[Dictionary] = []
var grenades: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var game_over := false
var win := false
var time_scale_flash := 0.0
var rng := RandomNumberGenerator.new()
var hp_player_bar: ProgressBar
var hp_boss_bar: ProgressBar
var status_label: Label
var dialogue_label: Label
var help_label: Label
var vignette: ColorRect
var boss_title_label: Label
var mobile_controls: Control
var touch_move := Vector2.ZERO
var touch_left_pressed := false
var touch_right_pressed := false
var touch_up_pressed := false
var touch_down_pressed := false
var touch_shoot := false
var touch_melee_queued := false
var touch_restart_queued := false

const INTRO := [
	{"speaker":"BOSS", "line":"Say my name."},
	{"speaker":"YOU", "line":"Boss."},
	{"speaker":"BOSS", "line":"Let's begin."}
]

func _ready() -> void:
	rng.randomize()
	_build_ui()
	_start_intro()
	RenderingServer.set_default_clear_color(Color("080b12"))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var title := Label.new()
	title.text = "THE BOSS FIGHT  /  PROTOTYPE 0.2"
	title.position = Vector2(28, 18)
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color("b8c9e8"))
	root.add_child(title)

	var player_title := Label.new()
	player_title.text = "PLAYER"
	player_title.position = Vector2(28, 54)
	player_title.add_theme_font_size_override("font_size", 13)
	root.add_child(player_title)
	hp_player_bar = ProgressBar.new()
	hp_player_bar.position = Vector2(28, 76)
	hp_player_bar.size = Vector2(260, 16)
	hp_player_bar.max_value = PLAYER_MAX_HP
	hp_player_bar.show_percentage = false
	root.add_child(hp_player_bar)

	boss_title_label = Label.new()
	boss_title_label.text = "BOSS  /  PHASE 1"
	boss_title_label.position = Vector2(820, 18)
	boss_title_label.size = Vector2(430, 26)
	boss_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_title_label.add_theme_font_size_override("font_size", 16)
	root.add_child(boss_title_label)
	hp_boss_bar = ProgressBar.new()
	hp_boss_bar.position = Vector2(820, 48)
	hp_boss_bar.size = Vector2(430, 16)
	hp_boss_bar.max_value = BOSS_MAX_HP
	hp_boss_bar.show_percentage = false
	root.add_child(hp_boss_bar)

	status_label = Label.new()
	status_label.position = Vector2(28, 105)
	status_label.size = Vector2(540, 24)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("8be9fd"))
	root.add_child(status_label)

	dialogue_label = Label.new()
	dialogue_label.position = Vector2(250, 545)
	dialogue_label.size = Vector2(780, 88)
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 25)
	dialogue_label.add_theme_color_override("font_color", Color("f7f4e8"))
	root.add_child(dialogue_label)

	help_label = Label.new()
	help_label.position = Vector2(28, 680)
	help_label.text = "PC: WASD/arrows move • LMB shoot • SPACE melee • R restart"
	help_label.add_theme_font_size_override("font_size", 12)
	help_label.add_theme_color_override("font_color", Color("9ba8bd"))
	root.add_child(help_label)

	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0.01, 0.015, 0.03, 0.20)
	root.add_child(vignette)
	vignette.z_index = 10

	_build_mobile_controls(layer)

func _build_mobile_controls(layer: CanvasLayer) -> void:
	mobile_controls = Control.new()
	mobile_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mobile_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(mobile_controls)
	if not OS.has_feature("mobile"):
		mobile_controls.visible = false
		return

	# Large touch areas at the bottom; independent areas allow movement plus shooting.
	var move_left_btn := _make_touch_button("◀", Vector2(24, -138), Vector2(72, 72), mobile_controls)
	_configure_bottom_left(move_left_btn)
	move_left_btn.button_down.connect(_on_touch_left_down)
	move_left_btn.button_up.connect(_on_touch_left_up)

	var move_right_btn := _make_touch_button("▶", Vector2(180, -138), Vector2(72, 72), mobile_controls)
	_configure_bottom_left(move_right_btn)
	move_right_btn.button_down.connect(_on_touch_right_down)
	move_right_btn.button_up.connect(_on_touch_right_up)

	var move_up_btn := _make_touch_button("▲", Vector2(102, -216), Vector2(72, 72), mobile_controls)
	_configure_bottom_left(move_up_btn)
	move_up_btn.button_down.connect(_on_touch_up_down)
	move_up_btn.button_up.connect(_on_touch_up_up)

	var move_down_btn := _make_touch_button("▼", Vector2(102, -60), Vector2(72, 72), mobile_controls)
	_configure_bottom_left(move_down_btn)
	move_down_btn.button_down.connect(_on_touch_down_down)
	move_down_btn.button_up.connect(_on_touch_down_up)

	var shoot_btn := _make_touch_button("FIRE", Vector2(-184, -130), Vector2(142, 88), mobile_controls)
	shoot_btn.anchor_left = 1.0
	shoot_btn.anchor_right = 1.0
	shoot_btn.anchor_top = 1.0
	shoot_btn.anchor_bottom = 1.0
	shoot_btn.button_down.connect(_on_touch_shoot_down)
	shoot_btn.button_up.connect(_on_touch_shoot_up)

	var melee_btn := _make_touch_button("HIT", Vector2(-172, -230), Vector2(112, 72), mobile_controls)
	melee_btn.anchor_left = 1.0
	melee_btn.anchor_right = 1.0
	melee_btn.anchor_top = 1.0
	melee_btn.anchor_bottom = 1.0
	melee_btn.pressed.connect(_on_touch_melee)

	var restart_btn := _make_touch_button("RETRY", Vector2(-112, -322), Vector2(92, 48), mobile_controls)
	restart_btn.anchor_left = 1.0
	restart_btn.anchor_right = 1.0
	restart_btn.anchor_top = 1.0
	restart_btn.anchor_bottom = 1.0
	restart_btn.pressed.connect(_on_touch_restart)

func _on_touch_left_down() -> void:
	touch_left_pressed = true
	_update_touch_move()

func _on_touch_left_up() -> void:
	touch_left_pressed = false
	_update_touch_move()

func _on_touch_right_down() -> void:
	touch_right_pressed = true
	_update_touch_move()

func _on_touch_right_up() -> void:
	touch_right_pressed = false
	_update_touch_move()

func _on_touch_up_down() -> void:
	touch_up_pressed = true
	_update_touch_move()

func _on_touch_up_up() -> void:
	touch_up_pressed = false
	_update_touch_move()

func _on_touch_down_down() -> void:
	touch_down_pressed = true
	_update_touch_move()

func _on_touch_down_up() -> void:
	touch_down_pressed = false
	_update_touch_move()

func _on_touch_shoot_down() -> void:
	touch_shoot = true

func _on_touch_shoot_up() -> void:
	touch_shoot = false

func _on_touch_melee() -> void:
	touch_melee_queued = true

func _on_touch_restart() -> void:
	touch_restart_queued = true

func _update_touch_move() -> void:
	touch_move.x = float(touch_right_pressed) - float(touch_left_pressed)
	touch_move.y = float(touch_down_pressed) - float(touch_up_pressed)

func _configure_bottom_left(button: Button) -> void:
	button.anchor_left = 0.0
	button.anchor_right = 0.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0

func _make_touch_button(text_value: String, offset: Vector2, button_size: Vector2, parent: Control) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = offset
	button.size = button_size
	button.add_theme_font_size_override("font_size", 18)
	button.modulate = Color(1.0, 1.0, 1.0, 0.88)
	parent.add_child(button)
	return button

func _start_intro() -> void:
	boss_state = "intro"
	intro_index = 0
	intro_timer = 2.4
	_set_dialogue(INTRO[0]["speaker"], INTRO[0]["line"])

func _set_dialogue(speaker: String, line: String) -> void:
	dialogue_visible = true
	dialogue_label.text = speaker + "\n\"" + line + "\""

func _process(delta: float) -> void:
	if time_scale_flash > 0.0:
		time_scale_flash = maxf(0.0, time_scale_flash - delta)
		vignette.color = Color(0.20, 0.025, 0.02, 0.28)
	else:
		vignette.color = Color(0.01, 0.015, 0.03, 0.20)

	if Input.is_action_just_pressed("restart") or touch_restart_queued:
		touch_restart_queued = false
		get_tree().reload_current_scene()
		return

	if boss_state == "intro":
		intro_timer -= delta
		if intro_timer <= 0.0:
			intro_index += 1
			if intro_index < INTRO.size():
				intro_timer = 2.2
				_set_dialogue(INTRO[intro_index]["speaker"], INTRO[intro_index]["line"])
			else:
				boss_state = "combat"
				dialogue_label.text = ""
				dialogue_visible = false
	elif not game_over and not win:
		_update_player(delta)
		_update_boss(delta)
		_update_bullets(delta)
		_update_grenades(delta)
		_update_effects(delta)
	_update_hud()
	queue_redraw()

func _update_player(delta: float) -> void:
	var keyboard_dir := Vector2(Input.get_axis("move_left", "move_right"), Input.get_axis("move_up", "move_down"))
	var input_dir := (keyboard_dir + touch_move).limit_length(1.0).normalized()
	player_pos += input_dir * PLAYER_SPEED * delta
	player_pos.x = clampf(player_pos.x, ARENA.position.x + 24, ARENA.end.x - 24)
	player_pos.y = clampf(player_pos.y, ARENA.position.y + 24, ARENA.end.y - 24)

	if not OS.has_feature("mobile") and get_global_mouse_position().distance_to(player_pos) > 2.0:
		player_facing = (get_global_mouse_position() - player_pos).normalized()
	elif input_dir.length_squared() > 0.01:
		player_facing = input_dir.normalized()

	player_invuln = maxf(0.0, player_invuln - delta)
	melee_timer = maxf(0.0, melee_timer - delta)
	player_shot_cooldown = maxf(0.0, player_shot_cooldown - delta)

	if (Input.is_action_pressed("shoot") or touch_shoot) and not dialogue_visible and player_shot_cooldown <= 0.0:
		_fire_player_bullet()
		player_shot_cooldown = 0.22

	if (Input.is_action_just_pressed("melee") or touch_melee_queued) and melee_timer <= 0.0 and not dialogue_visible:
		touch_melee_queued = false
		melee_timer = 0.48
		_add_effect(player_pos + player_facing * 42.0, "slash", 0.22, 58.0)
		if player_pos.distance_to(boss_pos) < 92.0 and (boss_pos - player_pos).length_squared() > 0.01 and player_facing.dot((boss_pos - player_pos).normalized()) > 0.2:
			_damage_boss(32.0)
			_add_effect(boss_pos, "hit", 0.28, 36.0)
	else:
		touch_melee_queued = false

func _fire_player_bullet() -> void:
	var aim := player_facing
	if not OS.has_feature("mobile"):
		var mouse_aim := get_global_mouse_position() - player_pos
		if mouse_aim.length_squared() > 0.01:
			aim = mouse_aim.normalized()
	bullets.append({"pos": player_pos + aim * 22.0, "vel": aim * 780.0, "owner": "player", "life": 1.15, "damage": 12.0})
	_add_effect(player_pos + aim * 20.0, "muzzle", 0.08, 18.0)

func _update_boss(delta: float) -> void:
	if boss_state != "combat":
		return
	var low_phase := boss_hp <= BOSS_MAX_HP * 0.30
	var toward_player := player_pos - boss_pos
	var distance := toward_player.length()
	if distance > (250.0 if not low_phase else 205.0) and distance > 0.01:
		boss_pos += toward_player / distance * (58.0 if not low_phase else 78.0) * delta
	boss_pos.x = clampf(boss_pos.x, ARENA.position.x + 34, ARENA.end.x - 34)
	boss_pos.y = clampf(boss_pos.y, ARENA.position.y + 34, ARENA.end.y - 34)

	boss_shot_cooldown = maxf(0.0, boss_shot_cooldown - delta)
	if boss_shot_cooldown <= 0.0:
		_fire_boss_bullet()
		boss_shot_cooldown = 1.05 if not low_phase else 0.72

	grenade_timer -= delta
	if low_phase and grenade_timer <= 0.0:
		_throw_grenade()
		grenade_timer = 2.1

func _fire_boss_bullet() -> void:
	var aim_vector := player_pos - boss_pos
	if aim_vector.length_squared() < 0.01:
		return
	var aim := aim_vector.normalized()
	for offset in [-0.045, 0.0, 0.045]:
		var direction: Vector2 = aim.rotated(offset)
		bullets.append({"pos": boss_pos + direction * 25.0, "vel": direction * 540.0, "owner": "boss", "life": 1.6, "damage": 13.0})
	_add_effect(boss_pos + aim * 22.0, "muzzle", 0.12, 26.0)

func _throw_grenade() -> void:
	var target := player_pos + Vector2(rng.randf_range(-48, 48), rng.randf_range(-38, 38))
	target.x = clampf(target.x, ARENA.position.x + 24, ARENA.end.x - 24)
	target.y = clampf(target.y, ARENA.position.y + 24, ARENA.end.y - 24)
	grenades.append({"pos": boss_pos, "target": target, "t": 0.0, "duration": 0.72, "life": 1.9, "radius": 92.0})
	_add_effect(target, "warning", 0.74, 70.0)

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		var previous: Vector2 = b["pos"]
		var next_position: Vector2 = previous + b["vel"] * delta
		b["pos"] = next_position
		b["life"] = float(b["life"]) - delta
		if float(b["life"]) <= 0.0 or not ARENA.grow(80).has_point(next_position):
			bullets.remove_at(i)
			continue

		if b["owner"] == "player":
			if _segment_hits_circle(previous, next_position, boss_pos, 28.0 + BULLET_RADIUS):
				_damage_boss(float(b["damage"]))
				_add_effect(next_position, "hit", 0.18, 25.0)
				bullets.remove_at(i)
				continue
		elif player_invuln <= 0.0 and _segment_hits_circle(previous, next_position, player_pos, 20.0 + BULLET_RADIUS):
			_damage_player(float(b["damage"]))
			bullets.remove_at(i)
			continue
		bullets[i] = b

func _segment_hits_circle(start: Vector2, finish: Vector2, center: Vector2, radius: float) -> bool:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return start.distance_squared_to(center) <= radius * radius
	var t := clampf((center - start).dot(segment) / length_squared, 0.0, 1.0)
	var closest := start + segment * t
	return closest.distance_squared_to(center) <= radius * radius

func _update_grenades(delta: float) -> void:
	for i in range(grenades.size() - 1, -1, -1):
		var g: Dictionary = grenades[i]
		g["t"] = float(g["t"]) + delta
		var t: float = minf(1.0, float(g["t"]) / float(g["duration"]))
		var start: Vector2 = g["pos"]
		var target: Vector2 = g["target"]
		g["current"] = start.lerp(target, t)
		if float(g["t"]) >= float(g["duration"]):
			_add_effect(target, "explosion", 0.46, float(g["radius"]))
			time_scale_flash = 0.12
			if target.distance_to(player_pos) < float(g["radius"]) and player_invuln <= 0.0:
				_damage_player(28.0)
			grenades.remove_at(i)
		else:
			grenades[i] = g

func _update_effects(delta: float) -> void:
	for i in range(effects.size() - 1, -1, -1):
		effects[i]["life"] = float(effects[i]["life"]) - delta
		if float(effects[i]["life"]) <= 0.0:
			effects.remove_at(i)

func _damage_player(amount: float) -> void:
	if game_over or win:
		return
	player_hp = maxf(0.0, player_hp - amount)
	player_invuln = 0.42
	_add_effect(player_pos, "hit", 0.24, 28.0)
	if player_hp <= 0.0:
		game_over = true
		dialogue_visible = true
		dialogue_label.text = "YOU WERE DEFEATED\nPress R or RETRY to restart"

func _damage_boss(amount: float) -> void:
	if boss_state != "combat" or win or game_over:
		return
	boss_hp = maxf(0.0, boss_hp - amount)
	if boss_hp <= 0.0:
		win = true
		dialogue_visible = true
		dialogue_label.text = "BOSS DEFEATED\nPress R or RETRY to play again"

func _add_effect(pos: Vector2, kind: String, life: float, radius: float) -> void:
	effects.append({"pos": pos, "kind": kind, "life": life, "max_life": life, "radius": radius})

func _update_hud() -> void:
	hp_player_bar.value = player_hp
	hp_boss_bar.value = boss_hp
	var low_phase := boss_hp <= BOSS_MAX_HP * 0.30
	boss_title_label.text = "BOSS  /  PHASE 2" if low_phase else "BOSS  /  PHASE 1"
	var phase := "PHASE 2 — EXPLOSIVES" if low_phase else "PHASE 1 — REVOLVER"
	status_label.text = phase + "    |    HP " + str(roundi(player_hp)) + " / 100"

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("070a10"), true)
	draw_rect(ARENA, Color("111923"), true)
	var tile := 32
	for x in range(int(ARENA.position.x), int(ARENA.end.x), tile):
		for y in range(int(ARENA.position.y), int(ARENA.end.y), tile):
			var shade := ((x / tile + y / tile) % 2 == 0)
			draw_rect(Rect2(x, y, tile - 1, tile - 1), Color("151f2b") if shade else Color("121b25"), true)
	for x in range(int(ARENA.position.x) + 16, int(ARENA.end.x) - 16, 64):
		draw_rect(Rect2(x, ARENA.position.y + 8, 24, 3), Color(0.1, 0.72, 0.92, 0.65), true)
		draw_rect(Rect2(x, ARENA.end.y - 11, 24, 3), Color(0.1, 0.72, 0.92, 0.45), true)
	draw_rect(ARENA, Color("35445a"), false, 5.0)
	draw_circle(player_pos + Vector2(0, 13), 17.0, Color(0, 0, 0, 0.45))
	draw_circle(boss_pos + Vector2(0, 15), 22.0, Color(0, 0, 0, 0.55))
	var pcol := Color("52d8d1") if player_invuln <= 0.0 or int(Time.get_ticks_msec() / 70) % 2 == 0 else Color("ffffff")
	draw_rect(Rect2(player_pos + Vector2(-10, -12), Vector2(20, 24)), pcol, true)
	draw_rect(Rect2(player_pos + Vector2(-7, -17), Vector2(14, 9)), Color("d9c7a1"), true)
	draw_rect(Rect2(player_pos + player_facing * 12.0 + Vector2(-4, -3), Vector2(18, 6)), Color("b5c4d9"), true)
	draw_line(player_pos, player_pos + player_facing * 35.0, Color("b8f8ff"), 2.0)
	draw_rect(Rect2(boss_pos + Vector2(-13, -15), Vector2(26, 31)), Color("1d2632"), true)
	draw_rect(Rect2(boss_pos + Vector2(-10, -21), Vector2(20, 12)), Color("d4c9b3"), true)
	draw_rect(Rect2(boss_pos + Vector2(-16, -27), Vector2(32, 6)), Color("080b10"), true)
	draw_rect(Rect2(boss_pos + Vector2(-9, -35), Vector2(18, 9)), Color("080b10"), true)
	var boss_aim_vector := player_pos - boss_pos
	if boss_aim_vector.length_squared() > 0.01:
		var boss_aim := boss_aim_vector.normalized()
		draw_line(boss_pos + boss_aim * 18.0, boss_pos + boss_aim * 39.0, Color("c5d1dc"), 5.0)
	for b in bullets:
		var bp: Vector2 = b["pos"]
		var col := Color("ffd27d") if b["owner"] == "player" else Color("ff5964")
		draw_rect(Rect2(bp - Vector2(3, 3), Vector2(6, 6)), col, true)
	for g in grenades:
		var gp: Vector2 = g.get("current", g["pos"])
		draw_circle(gp + Vector2(0, 7), 9.0, Color(0, 0, 0, 0.35))
		draw_circle(gp, 7.0, Color("d6e65b"))
		draw_circle(gp, 12.0, Color(0.84, 0.93, 0.27, 0.25))
		draw_circle(g["target"], 22.0, Color(0.9, 0.8, 0.15, 0.65), false, 2.0)
	for e in effects:
		var ratio: float = clampf(float(e["life"]) / float(e["max_life"]), 0.0, 1.0)
		var ep: Vector2 = e["pos"]
		var r: float = float(e["radius"])
		match e["kind"]:
			"muzzle":
				draw_circle(ep, r * ratio, Color(1.0, 0.72, 0.28, ratio))
			"hit":
				draw_circle(ep, r * (1.2 - ratio), Color(1.0, 0.3, 0.27, ratio * 0.7), false, 3.0)
			"slash":
				draw_arc(ep, r, -0.9, 0.9, 16, Color("9efaff"), 4.0)
			"warning":
				draw_circle(ep, r * (1.0 - ratio * 0.15), Color(1.0, 0.78, 0.12, ratio * 0.75), false, 3.0)
			"explosion":
				draw_circle(ep, r * (1.0 - ratio * 0.4), Color(1.0, 0.48, 0.12, ratio * 0.32))
				draw_circle(ep, r * (1.0 - ratio * 0.5), Color(1.0, 0.79, 0.38, ratio * 0.8), false, 5.0)
	draw_circle(player_pos, 110.0, Color(0.10, 0.65, 0.78, 0.045))
	draw_circle(boss_pos, 125.0, Color(0.75, 0.10, 0.18, 0.055))
