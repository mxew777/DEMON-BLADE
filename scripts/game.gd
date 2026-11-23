extends Node2D

const WORLD_W := 960.0
const WORLD_H := 540.0
const PLAYER_SPEED := 220.0

var player_pos := Vector2(350, 300)
var player_face := Vector2.RIGHT
var player_hp := 100.0
var enemy_pos := Vector2(650, 270)
var enemy_hp := 100.0
var enemy_alive := true
var enemy_respawn := 0.0
var enemy_hit_flash := 0.0
var player_hit_flash := 0.0
var enemy_attack_timer := 0.0
var attack_cooldown := 0.0
var combo_timer := 0.0
var combo_step := 0
var slash_timer := 0.0
var slash_angle := 0.0
var screen_shake := 0.0
var elapsed := 0.0
var particles: Array[Dictionary] = []
var joystick_id := -1
var joystick_value := Vector2.ZERO
var mouse_joystick := false
var font: Font

func _ready() -> void:
	font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(queue_redraw)
	set_process(true)

func _process(delta: float) -> void:
	elapsed += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	slash_timer = maxf(0.0, slash_timer - delta)
	enemy_hit_flash = maxf(0.0, enemy_hit_flash - delta)
	player_hit_flash = maxf(0.0, player_hit_flash - delta)
	enemy_attack_timer = maxf(0.0, enemy_attack_timer - delta)
	screen_shake = maxf(0.0, screen_shake - delta * 18.0)

	var move := joystick_value
	move += Vector2(
		float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)),
		float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	)
	if move.length() > 1.0:
		move = move.normalized()
	if move.length() > 0.08:
		player_pos += move * PLAYER_SPEED * delta
		player_face = move.normalized()

	var bounds := get_viewport_rect().size
	player_pos.x = clampf(player_pos.x, 70.0, bounds.x - 70.0)
	player_pos.y = clampf(player_pos.y, 135.0, bounds.y - 75.0)

	if enemy_alive:
		var to_player := player_pos - enemy_pos
		var distance := to_player.length()
		if distance > 40.0:
			enemy_pos += to_player.normalized() * 82.0 * delta
		elif enemy_attack_timer <= 0.0:
			player_hp = maxf(0.0, player_hp - 9.0)
			player_hit_flash = 0.22
			enemy_attack_timer = 0.85
			screen_shake = 4.0
	else:
		enemy_respawn -= delta
		if enemy_respawn <= 0.0:
			enemy_alive = true
			enemy_hp = 100.0
			enemy_pos = Vector2(bounds.x * 0.70, bounds.y * 0.48)
			player_hp = minf(100.0, player_hp + 15.0)

	_update_particles(delta)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.keycode == KEY_ENTER:
			_attack()
	elif event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport_rect().size.x * 0.48 and event.position.y > get_viewport_rect().size.y * 0.48:
				joystick_id = event.index
				_update_joystick(event.position)
			else:
				_attack()
		elif event.index == joystick_id:
			joystick_id = -1
			joystick_value = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == joystick_id:
		_update_joystick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if event.position.x < get_viewport_rect().size.x * 0.48 and event.position.y > get_viewport_rect().size.y * 0.48:
				mouse_joystick = true
				_update_joystick(event.position)
			else:
				_attack()
		else:
			mouse_joystick = false
			joystick_value = Vector2.ZERO
	elif event is InputEventMouseMotion and mouse_joystick:
		_update_joystick(event.position)

func _update_joystick(point: Vector2) -> void:
	var center := Vector2(112, get_viewport_rect().size.y - 112)
	var offset := point - center
	joystick_value = offset.limit_length(58.0) / 58.0

func _attack() -> void:
	if attack_cooldown > 0.0 or not enemy_alive:
		return
	var distance := player_pos.distance_to(enemy_pos)
	if distance > 170.0:
		return
	player_face = (enemy_pos - player_pos).normalized()
	combo_step = (combo_step % 3) + 1 if combo_timer > 0.0 else 1
	combo_timer = 0.72
	attack_cooldown = 0.34 if combo_step < 3 else 0.58
	slash_timer = 0.22
	slash_angle = player_face.angle()
	if distance <= (142.0 if combo_step == 3 else 122.0):
		var damage := [0.0, 19.0, 24.0, 38.0][combo_step]
		enemy_hp = maxf(0.0, enemy_hp - damage)
		enemy_hit_flash = 0.16
		screen_shake = 3.0 if combo_step < 3 else 8.0
		_spawn_burst(enemy_pos, 13 if combo_step == 3 else 8, Color(1.0, 0.20, 0.34))
		if combo_step == 3:
			_spawn_burst(enemy_pos, 16, Color(0.75, 0.25, 1.0))
		if enemy_hp <= 0.0:
			enemy_alive = false
			enemy_respawn = 2.5
			_spawn_burst(enemy_pos, 35, Color(1.0, 0.18, 0.30))

func _spawn_burst(at: Vector2, amount: int, tint: Color) -> void:
	for i in range(amount):
		var angle := randf() * TAU
		var speed := randf_range(65.0, 260.0)
		particles.append({
			"pos": at,
			"vel": Vector2.RIGHT.rotated(angle) * speed,
			"life": randf_range(0.18, 0.48),
			"max": 0.48,
			"size": randf_range(2.0, 5.0),
			"color": tint
		})

func _update_particles(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p["life"] = float(p["life"]) - delta
		p["pos"] = p["pos"] + p["vel"] * delta
		p["vel"] = p["vel"] * 0.90
		particles[i] = p
		if float(p["life"]) <= 0.0:
			particles.remove_at(i)

func _draw() -> void:
	var size := get_viewport_rect().size
	if screen_shake > 0.1:
		draw_set_transform(Vector2(randf_range(-screen_shake, screen_shake), randf_range(-screen_shake, screen_shake)))
	_draw_dungeon(size)
	_draw_enemy()
	_draw_player()
	_draw_particles()
	_draw_hud(size)
	if screen_shake > 0.1:
		draw_set_transform(Vector2.ZERO)

func _draw_dungeon(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#100d17"))
	for y in range(54, int(size.y) - 25, 48):
		for x in range(18, int(size.x) - 18, 48):
			var shade := 0.0 if ((x / 48 + y / 48) % 2 == 0) else 0.035
			draw_rect(Rect2(x, y, 46, 46), Color(0.105 + shade, 0.085 + shade, 0.13 + shade))
			draw_line(Vector2(x + 3, y + 3), Vector2(x + 43, y + 3), Color(0.30, 0.22, 0.30, 0.28), 1.0)
			draw_line(Vector2(x + 3, y + 4), Vector2(x + 3, y + 43), Color(0.02, 0.015, 0.03, 0.55), 2.0)
	# outer masonry
	draw_rect(Rect2(0, 0, size.x, 45), Color("#090810"))
	draw_rect(Rect2(0, 42, size.x, 9), Color("#57414f"))
	draw_rect(Rect2(0, size.y - 28, size.x, 28), Color("#090810"))
	draw_rect(Rect2(0, 50, 18, size.y - 78), Color("#090810"))
	draw_rect(Rect2(size.x - 18, 50, 18, size.y - 78), Color("#090810"))
	# central ritual seal
	var center := size * 0.5
	for radius in [62.0, 54.0, 26.0]:
		draw_arc(center, radius, 0.0, TAU, 96, Color(0.64, 0.10, 0.25, 0.22), 2.0)
	var tri := PackedVector2Array([center + Vector2(0, -58), center + Vector2(51, 31), center + Vector2(-51, 31), center + Vector2(0, -58)])
	draw_polyline(tri, Color(0.75, 0.14, 0.30, 0.20), 2.0)
	# pillars and braziers
	for p in [Vector2(65, 88), Vector2(size.x - 65, 88), Vector2(65, size.y - 75), Vector2(size.x - 65, size.y - 75)]:
		_draw_pillar(p)
	# torch pools
	for p in [Vector2(145, 76), Vector2(size.x - 145, 76)]:
		draw_circle(p, 42.0, Color(0.80, 0.12, 0.22, 0.035))
		draw_circle(p, 23.0, Color(0.95, 0.16, 0.28, 0.055))
		draw_circle(p, 5.0 + sin(elapsed * 7.0) * 1.5, Color("#ff5267"))
	# subtle floor cracks
	for i in range(9):
		var x := 105.0 + float(i) * 91.0
		var y := 160.0 + sin(float(i) * 8.0) * 58.0
		draw_line(Vector2(x, y), Vector2(x + 12, y + 7), Color(0.62, 0.30, 0.38, 0.15), 1.0)

func _draw_pillar(p: Vector2) -> void:
	draw_rect(Rect2(p + Vector2(-17, -17), Vector2(34, 34)), Color("#090810"))
	draw_rect(Rect2(p + Vector2(-14, -14), Vector2(28, 28)), Color("#54414e"))
	draw_rect(Rect2(p + Vector2(-10, -10), Vector2(20, 20)), Color("#241b2a"))
	draw_rect(Rect2(p + Vector2(-4, -4), Vector2(8, 8)), Color("#8c354e"))
	draw_rect(Rect2(p + Vector2(-16, -16), Vector2(32, 3)), Color("#8c7180"))

func _draw_enemy() -> void:
	if not enemy_alive:
		return
	var bob := sin(elapsed * 3.4) * 5.0
	var p := enemy_pos + Vector2(0, bob)
	# spectral aura
	for i in range(5, 0, -1):
		draw_circle(p, 17.0 + i * 6.0, Color(0.65, 0.08, 0.34, 0.018))
	_draw_ellipse(p + Vector2(0, 22), Vector2(23, 8), Color(0.02, 0.01, 0.04, 0.7))
	var body := Color("#a52c67") if enemy_hit_flash > 0.0 else Color("#492344")
	var cloak := PackedVector2Array([p + Vector2(0, -27), p + Vector2(19, -8), p + Vector2(15, 17), p + Vector2(7, 29), p + Vector2(1, 18), p + Vector2(-7, 30), p + Vector2(-17, 14), p + Vector2(-20, -8)])
	draw_colored_polygon(cloak, body)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-12, -10), p + Vector2(0, -31), p + Vector2(13, -9), p + Vector2(7, 4), p + Vector2(-7, 4)]), Color("#24152f"))
	draw_line(p + Vector2(-12, 8), p + Vector2(-17, 26), Color("#d04a83"), 3.0)
	draw_line(p + Vector2(12, 7), p + Vector2(18, 24), Color("#d04a83"), 3.0)
	draw_circle(p + Vector2(-6, -7), 3.2, Color("#ff547d"))
	draw_circle(p + Vector2(6, -7), 3.2, Color("#ff547d"))
	draw_line(p + Vector2(-5, 3), p + Vector2(5, 3), Color("#e64b86"), 2.0)
	draw_circle(p + Vector2(0, -8), 19.0, Color(1.0, 0.08, 0.30, 0.055))

func _draw_player() -> void:
	var p := player_pos
	var bob := sin(elapsed * 8.0) * 2.0 if joystick_value.length() > 0.08 else sin(elapsed * 2.0) * 0.8
	p.y += bob
	if player_hit_flash > 0.0 and int(elapsed * 30.0) % 2 == 0:
		return
	# ground shadow and red rim light
	_draw_ellipse(p + Vector2(0, 22), Vector2(23, 8), Color(0.01, 0.008, 0.02, 0.75))
	draw_circle(p + Vector2(0, 2), 28.0, Color(0.72, 0.08, 0.20, 0.045))
	# long dark coat
	draw_colored_polygon(PackedVector2Array([p + Vector2(-13, -5), p + Vector2(12, -5), p + Vector2(18, 20), p + Vector2(8, 27), p + Vector2(0, 19), p + Vector2(-9, 28), p + Vector2(-18, 18)]), Color("#321d32"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-9, -12), p + Vector2(8, -12), p + Vector2(13, 8), p + Vector2(0, 19), p + Vector2(-13, 8)]), Color("#a83b50"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-8, -15), p + Vector2(0, -22), p + Vector2(9, -15), p + Vector2(8, -3), p + Vector2(-8, -3)]), Color("#e0c9c8"))
	# hair and hood details
	draw_colored_polygon(PackedVector2Array([p + Vector2(-10, -17), p + Vector2(-7, -27), p + Vector2(5, -27), p + Vector2(12, -16), p + Vector2(6, -10), p + Vector2(-8, -11)]), Color("#17131f"))
	draw_line(p + Vector2(-7, 0), p + Vector2(-13, 17), Color("#d9aeb7"), 2.0)
	draw_line(p + Vector2(7, 0), p + Vector2(13, 17), Color("#d9aeb7"), 2.0)
	# sword, angled toward current facing
	var side := Vector2(-player_face.y, player_face.x)
	var hilt := p + player_face * 9.0 + side * 13.0
	var tip := hilt + player_face * 43.0
	draw_line(hilt - side * 5.0, hilt + side * 5.0, Color("#c48a69"), 4.0)
	draw_line(hilt, tip, Color("#d7e3ec"), 4.0)
	draw_line(hilt + side * 1.0, tip, Color("#ffffff"), 1.3)
	draw_line(tip, tip + side * 2.0, Color("#ff879b"), 2.0)
	if slash_timer > 0.0:
		var alpha := slash_timer / 0.22
		var arc_center := p + player_face * 24.0
		draw_arc(arc_center, 48.0 if combo_step == 3 else 39.0, slash_angle - 1.15, slash_angle + 1.15, 36, Color(1.0, 0.18, 0.34, alpha), 7.0 if combo_step == 3 else 4.0)
		draw_arc(arc_center, 55.0, slash_angle - 0.95, slash_angle + 0.95, 36, Color(1.0, 0.72, 0.78, alpha * 0.55), 2.0)

func __draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in range(25):
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * radii.x, sin(a) * radii.y))
	draw_colored_polygon(points, color)

func _draw_particles() -> void:
	for p in particles:
		var ratio: float = clampf(float(p["life"]) / float(p["max"]), 0.0, 1.0)
		var col: Color = p["color"]
		col.a *= ratio
		draw_circle(p["pos"], float(p["size"]) * ratio, col)

func _draw_hud(size: Vector2) -> void:
	# top frame
	draw_rect(Rect2(20, 18, 260, 66), Color(0.035, 0.025, 0.05, 0.86))
	draw_rect(Rect2(20, 18, 260, 2), Color("#a83b55"))
	draw_string(font, Vector2(34, 43), "DEMON BLADE", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#ff7186"))
	draw_string(font, Vector2(34, 65), "FALLEN DISCIPLE  /  DUNGEON 01", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#b9a5b7"))
	# health bars
	_draw_bar(Vector2(size.x - 270, 25), 235.0, player_hp / 100.0, "DISCIPLE", Color("#d9425b"))
	_draw_bar(Vector2(size.x - 270, 61), 235.0, enemy_hp / 100.0 if enemy_alive else 0.0, "HOLLOW WRAITH", Color("#a44bd0"))
	if not enemy_alive:
		draw_string(font, Vector2(size.x * 0.5 - 55, 105), "ENEMY DEFEATED", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("#ff7186"))
	# controls hint
	draw_string(font, Vector2(size.x * 0.5 - 105, size.y - 20), "WASD / ARROWS  MOVE     SPACE  ATTACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.83, 0.75, 0.83, 0.72))
	# touch joystick
	var jc := Vector2(112, size.y - 112)
	draw_circle(jc, 57.0, Color(0.08, 0.05, 0.11, 0.56))
	draw_arc(jc, 57.0, 0.0, TAU, 64, Color(0.72, 0.48, 0.62, 0.55), 2.0)
	draw_circle(jc + joystick_value * 31.0, 23.0, Color(0.65, 0.48, 0.62, 0.70))
	draw_arc(jc + joystick_value * 31.0, 23.0, 0.0, TAU, 40, Color("#e3c3d4"), 2.0)
	# attack button
	var ac := Vector2(size.x - 112, size.y - 112)
	draw_circle(ac, 54.0, Color(0.48, 0.045, 0.13, 0.52))
	draw_circle(ac, 45.0, Color(0.42, 0.075, 0.17, 0.92))
	draw_arc(ac, 48.0, 0.0, TAU, 64, Color("#ff8395"), 3.0)
	draw_string(font, ac + Vector2(-29, 5), "ATTACK", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)

func _draw_bar(pos: Vector2, width: float, value: float, label: String, tint: Color) -> void:
	draw_string(font, pos + Vector2(0, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e5d5e1"))
	draw_rect(Rect2(pos.x, pos.y + 7, width, 9), Color("#302332"))
	draw_rect(Rect2(pos.x, pos.y + 7, width * clampf(value, 0.0, 1.0), 9), tint)
	draw_rect(Rect2(pos.x, pos.y + 7, width, 1), Color(1, 1, 1, 0.25))
