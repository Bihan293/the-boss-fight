extends Node2D

# The prototype keeps combat state in one local simulation layer. Visual effects
# and UI observe state; input is converted into commands. This is a useful seam
# for a future network authority without implementing networking now.
const ARENA := Rect2(70, 70, 1140, 580)
const PLAYER_SPEED := 285.0
const PLAYER_MAX_HP := 100.0
const BOSS_MAX_HP := 360.0

var player_pos := Vector2(260, 360)
var player_hp := PLAYER_MAX_HP
var player_invuln := 0.0
var player_facing := Vector2.RIGHT
var boss_pos := Vector2(930, 350)
var boss_hp := BOSS_MAX_HP
var boss_state := "intro"
var boss_timer := 0.0
var shot_timer := 1.0
var grenade_timer := 2.5
var melee_timer := 0.0
var intro_index := 0
var intro_timer := 0.0
var dialogue_text := ""
var dialogue_visible := true
var bullets: Array[Dictionary] = []
var grenades: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var game_over := false
var win := false
var time_scale_flash := 0.0
var rng := RandomNumberGenerator.new()
var ui_layer: CanvasLayer
var hp_player_bar: ProgressBar
var hp_boss_bar: ProgressBar
var status_label: Label
var dialogue_label: Label
var help_label: Label
var vignette: ColorRect

const INTRO := [
	{"speaker":"HEISENBERG", "line":"Say my name."},
	{"speaker":"YOU", "line":"Heisenberg."},
	{"speaker":"HEISENBERG", "line":"Damn right."}
]

func _ready() -> void:
	rng.randomize()
	_build_ui()
	_start_intro()
	RenderingServer.set_default_clear_color(Color("080b12"))

func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_layer.add_child(root)
	var title := Label.new()
	title.text = "THE BOSS FIGHT  /  PROTOTYPE 0.1"
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
	hp_player_bar.value = player_hp
	hp_player_bar.show_percentage = false
	root.add_child(hp_player_bar)
	var boss_title := Label.new()
	boss_title.text = "HEISENBERG  /  PHASE 1"
	boss_title.position = Vector2(820, 18)
	boss_title.size = Vector2(430, 26)
	boss_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	boss_title.add_theme_font_size_override("font_size", 16)
	root.add_child(boss_title)
	hp_boss_bar = ProgressBar.new()
	hp_boss_bar.position = Vector2(820, 48)
	hp_boss_bar.size = Vector2(430, 16)
	hp_boss_bar.max_value = BOSS_MAX_HP
	hp_boss_bar.value = boss_hp
	hp_boss_bar.show_percentage = false
	root.add_child(hp_boss_bar)
	status_label = Label.new()
	status_label.position = Vector2(28, 105)
	status_label.size = Vector2(500, 24)
	status_label.add_theme_font_size_override("font_size", 14)
	status_label.add_theme_color_override("font_color", Color("8be9fd"))
	root.add_child(status_label)
	dialogue_label = Label.new()
	dialogue_label.position = Vector2(250, 560)
	dialogue_label.size = Vector2(780, 80)
	dialogue_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialogue_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_label.add_theme_font_size_override("font_size", 27)
	dialogue_label.add_theme_color_override("font_color", Color("f7f4e8"))
	root.add_child(dialogue_label)
	help_label = Label.new()
	help_label.position = Vector2(28, 675)
	help_label.text = "WASD / arrows: move    LMB: revolver    SPACE: melee    R: restart"
	help_label.add_theme_font_size_override("font_size", 13)
	help_label.add_theme_color_override("font_color", Color("9ba8bd"))
	root.add_child(help_label)
	vignette = ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.color = Color(0.01, 0.015, 0.03, 0.20)
	root.add_child(vignette)
	vignette.z_index = 10

func _start_intro() -> void:
	boss_state = "intro"
	intro_index = 0
	intro_timer = 2.4
	_set_dialogue(INTRO[0]["speaker"], INTRO[0]["line"])

func _set_dialogue(speaker: String, line: String) -> void:
	dialogue_visible = true
	dialogue_label.text = speaker + "\n\"" + line + "\""

func _process(delta: float) -> void:
	var dt := delta
	if time_scale_flash > 0.0:
		time_scale_flash = maxf(0.0, time_scale_flash - delta)
		vignette.color = Color(0.20, 0.025, 0.02, 0.28)
	else:
		vignette.color = Color(0.01, 0.015, 0.03, 0.20)
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
	if boss_state == "intro":
		intro_timer -= dt
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
		_update_player(dt)
		_update_boss(dt)
		_update_bullets(dt)
		_update_grenades(dt)
		_update_effects(dt)
	_update_hud()
	queue_redraw()

func _update_player(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	player_pos += input_dir * PLAYER_SPEED * delta
	player_pos.x = clampf(player_pos.x, ARENA.position.x + 24, ARENA.end.x - 24)
	player_pos.y = clampf(player_pos.y, ARENA.position.y + 24, ARENA.end.y - 24)
	if get_global_mouse_position().distance_to(player_pos) > 2.0:
		player_facing = (get_global_mouse_position() - player_pos).normalized()
	player_invuln = maxf(0.0, player_invuln - delta)
	melee_timer = maxf(0.0, melee_timer - delta)
	if Input.is_action_pressed("shoot") and not dialogue_visible:
		if shot_timer <= 0.0:
			_fire_player_bullet()
			shot_timer = 0.22
	shot_timer -= delta
	if Input.is_action_just_pressed("melee") and melee_timer <= 0.0 and not dialogue_visible:
		melee_timer = 0.48
		_add_effect(player_pos + player_facing * 42.0, "slash", 0.22, 58.0)
		if player_pos.distance_to(boss_pos) < 92.0 and player_facing.dot((boss_pos - player_pos).normalized()) > 0.2:
			_damage_boss(32.0)
			_add_effect(boss_pos, "hit", 0.28, 36.0)

func _fire_player_bullet() -> void:
	var aim := (get_global_mouse_position() - player_pos).normalized()
	if aim == Vector2.ZERO: aim = player_facing
	bullets.append({"pos": player_pos + aim * 22.0, "vel": aim * 780.0, "owner": "player", "life": 1.15, "damage": 12.0})
	_add_effect(player_pos + aim * 20.0, "muzzle", 0.08, 18.0)

func _update_boss(delta: float) -> void:
	boss_timer += delta
	if boss_state != "combat": return
	var low_phase := boss_hp <= BOSS_MAX_HP * 0.30
	var toward_player := player_pos - boss_pos
	var distance := toward_player.length()
	# Deliberately simple state machine; replaceable with a per-boss script/resource later.
	if distance > (250.0 if not low_phase else 205.0):
		boss_pos += toward_player.normalized() * (58.0 if not low_phase else 78.0) * delta
	boss_pos.x = clampf(boss_pos.x, ARENA.position.x + 34, ARENA.end.x - 34)
	boss_pos.y = clampf(boss_pos.y, ARENA.position.y + 34, ARENA.end.y - 34)
	shot_timer -= delta
	if shot_timer <= 0.0:
		_fire_boss_bullet()
		shot_timer = 1.05 if not low_phase else 0.72
	grenade_timer -= delta
	if low_phase and grenade_timer <= 0.0:
		_throw_grenade()
		grenade_timer = 2.1

func _fire_boss_bullet() -> void:
	var aim := (player_pos - boss_pos).normalized()
	# Slight spread gives the player a readable dodge window.
	for offset in [-0.045, 0.0, 0.045]:
		var direction := aim.rotated(offset)
		bullets.append({"pos": boss_pos + direction * 25.0, "vel": direction * 540.0, "owner": "boss", "life": 1.6, "damage": 13.0})
	_add_effect(boss_pos + aim * 22.0, "muzzle", 0.12, 26.0)

func _throw_grenade() -> void:
	var target := player_pos + Vector2(rng.randf_range(-48, 48), rng.randf_range(-38, 38))
	grenades.append({"pos": boss_pos, "target": target, "t": 0.0, "duration": 0.72, "life": 1.9, "radius": 92.0})
	_add_effect(target, "warning", 0.74, 70.0)

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var b: Dictionary = bullets[i]
		b["pos"] += b["vel"] * delta
		b["life"] -= delta
		var pos: Vector2 = b["pos"]
		if b["life"] <= 0.0 or not ARENA.grow(80).has_point(pos):
			bullets.remove_at(i)
			continue
		if b["owner"] == "player" and pos.distance_to(boss_pos) < 28.0:
			_damage_boss(float(b["damage"]))
			_add_effect(pos, "hit", 0.18, 25.0)
			bullets.remove_at(i)
		elif b["owner"] == "boss" and pos.distance_to(player_pos) < 20.0 and player_invuln <= 0.0:
			_damage_player(float(b["damage"]))
			bullets.remove_at(i)
		else:
			bullets[i] = b

func _update_grenades(delta: float) -> void:
	for i in range(grenades.size() - 1, -1, -1):
		var g: Dictionary = grenades[i]
		g["t"] += delta
		g["life"] -= delta
		var t: float = minf(1.0, float(g["t"]) / float(g["duration"]))
		var start: Vector2 = g["pos"]
		var target: Vector2 = g["target"]
		var p: Vector2 = start.lerp(target, t)
		g["current"] = p
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
		effects[i]["life"] -= delta
		if effects[i]["life"] <= 0.0:
			effects.remove_at(i)

func _damage_player(amount: float) -> void:
	player_hp = maxf(0.0, player_hp - amount)
	player_invuln = 0.42
	_add_effect(player_pos, "hit", 0.24, 28.0)
	if player_hp <= 0.0:
		game_over = true
		dialogue_label.text = "YOU WERE DEFEATED\nPress R to retry"

func _damage_boss(amount: float) -> void:
	if boss_state != "combat" or win: return
	boss_hp = maxf(0.0, boss_hp - amount)
	if boss_hp <= 0.0:
		win = true
		dialogue_label.text = "BOSS DEFEATED\nPrototype encounter complete — press R to retry"
		dialogue_visible = true

func _add_effect(pos: Vector2, kind: String, life: float, radius: float) -> void:
	effects.append({"pos": pos, "kind": kind, "life": life, "max_life": life, "radius": radius})

func _update_hud() -> void:
	hp_player_bar.value = player_hp
	hp_boss_bar.value = boss_hp
	var phase := "PHASE 2 — CHEMICAL BOMBS" if boss_hp <= BOSS_MAX_HP * 0.30 else "PHASE 1 — REVOLVER"
	status_label.text = phase + "    |    HP " + str(roundi(player_hp)) + " / 100"

func _draw() -> void:
	# Arena floor: tiled dark pixel-art blocks, hazard stripes, walls.
	draw_rect(Rect2(Vector2.ZERO, Vector2(1280, 720)), Color("070a10"), true)
	draw_rect(ARENA, Color("111923"), true)
	var tile := 32
	for x in range(int(ARENA.position.x), int(ARENA.end.x), tile):
		for y in range(int(ARENA.position.y), int(ARENA.end.y), tile):
			var shade := ((x / tile + y / tile) % 2 == 0)
			draw_rect(Rect2(x, y, tile - 1, tile - 1), Color("151f2b") if shade else Color("121b25"), true)
	# Decorative floor markings and perimeter lights.
	for x in range(int(ARENA.position.x) + 16, int(ARENA.end.x) - 16, 64):
		draw_rect(Rect2(x, ARENA.position.y + 8, 24, 3), Color(0.1, 0.72, 0.92, 0.65), true)
		draw_rect(Rect2(x, ARENA.end.y - 11, 24, 3), Color(0.1, 0.72, 0.92, 0.45), true)
	draw_rect(ARENA, Color("35445a"), false, 5.0)
	# Shadows under characters.
	draw_circle(player_pos + Vector2(0, 13), 17.0, Color(0, 0, 0, 0.45))
	draw_circle(boss_pos + Vector2(0, 15), 22.0, Color(0, 0, 0, 0.55))
	# Player: teal jacket, pixel-like limbs, weapon follows aim.
	var pcol := Color("52d8d1") if player_invuln <= 0.0 or int(Time.get_ticks_msec() / 70) % 2 == 0 else Color("ffffff")
	draw_rect(Rect2(player_pos + Vector2(-10, -12), Vector2(20, 24)), pcol, true)
	draw_rect(Rect2(player_pos + Vector2(-7, -17), Vector2(14, 9)), Color("d9c7a1"), true)
	draw_rect(Rect2(player_pos + player_facing * 12.0 + Vector2(-4, -3), Vector2(18, 6)), Color("b5c4d9"), true)
	draw_line(player_pos, player_pos + player_facing * 35.0, Color("b8f8ff"), 2.0)
	# Boss silhouette: black coat, pale face, hat and revolver.
	draw_rect(Rect2(boss_pos + Vector2(-13, -15), Vector2(26, 31)), Color("1d2632"), true)
	draw_rect(Rect2(boss_pos + Vector2(-10, -21), Vector2(20, 12)), Color("d4c9b3"), true)
	draw_rect(Rect2(boss_pos + Vector2(-16, -27), Vector2(32, 6)), Color("080b10"), true)
	draw_rect(Rect2(boss_pos + Vector2(-9, -35), Vector2(18, 9)), Color("080b10"), true)
	var boss_aim := (player_pos - boss_pos).normalized()
	draw_line(boss_pos + boss_aim * 18.0, boss_pos + boss_aim * 39.0, Color("c5d1dc"), 5.0)
	# Bullets and grenade arcs.
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
	# Combat effects.
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
	# Lighting impression: layered radial glows rendered as translucent circles.
	draw_circle(player_pos, 110.0, Color(0.10, 0.65, 0.78, 0.045))
	draw_circle(boss_pos, 125.0, Color(0.75, 0.10, 0.18, 0.055))
