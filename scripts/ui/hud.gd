class_name Hud
extends Control
## Hologramm-HUD für die offene Welt: Werte + Menschlichkeit oben links, Kompass oben Mitte,
## Ziel oben rechts, Joystick links, Umsehen per Wischen rechts, Aktionsknöpfe unten rechts.
## Dazu Dialoge mit Antwortmöglichkeiten, Meldungen, Vignetten (Hunger, Sonne, Blutsinn).

signal menu_pressed
signal interact_pressed
signal view_pressed
signal sense_pressed

const H := preload("res://scripts/ui/holo_ui.gd")
const STICK_R := 62.0

var world: Node
var stick := Vector2.ZERO
var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _look_idx := -1
var _look_last := Vector2.ZERO
var look_delta := Vector2.ZERO
var _attack_idx := -1
var _attack_hold := 0.0
var interact_text := ""
var interact_warn := ""
var _t := 0.0
var _press_fx := {}
var title_mode := false
var compass_marks: Array = []   # [Vector3, Farbe, Kürzel]
var quest_open := false

var msgs: Array = []
var minis: Array = []
# Dialog
var dlg_lines: Array = []
var dlg_i := 0
var dlg_chars := 0.0
var dlg_lock := 0.0
var dlg_choices: Array = []
var dlg_cb: Callable
var _choice_rects: Array = []
# Effekte
var red_flash := 0.0
var sun_burn := 0.0
var sense := 0.0
var death_t := -1.0
var banner := ""
var banner_t := 9.0
var zone_name := ""
var zone_t := 9.0
var perfect_t := 0.0
var fade_t := 9.0
var chronicle: Array = []
var chronicle_t := -1.0
var drink_t := -1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerStats.system_message.connect(_on_msg)

func _on_msg(text: String, kind: String) -> void:
	if kind == "mini":
		minis.append({"text": text, "t": 0.0})
		if minis.size() > 4:
			minis.pop_front()
		return
	var life := 3.6
	if kind in ["level", "quest", "choice", "humanity_down", "humanity_up"]:
		life = 4.4
	msgs.append({"text": text, "kind": kind, "t": 0.0, "life": life})
	if msgs.size() > 3:
		msgs.pop_front()
	if world:
		match kind:
			"level":
				world.sfx("level")
			"quest", "reward", "loot2", "loot3":
				world.sfx("quest")
			"warn", "humanity_down":
				world.sfx("warn")

# ---------- Dialoge ----------

## lines: [{who, text}], choices: ["Text", …] oder [] ; cb(index) wird am Ende gerufen (−1 ohne Auswahl)
func dialog(lines: Array, choices: Array = [], cb: Callable = Callable()) -> void:
	dlg_lines = lines
	dlg_i = 0
	dlg_chars = 0.0
	dlg_lock = 0.3
	dlg_choices = choices
	dlg_cb = cb
	release_all()

func in_dialog() -> bool:
	return dlg_i < dlg_lines.size() or (not dlg_choices.is_empty() and not dlg_lines.is_empty())

func _dialog_tap(p: Vector2) -> void:
	if dlg_lock > 0.0:
		return
	if dlg_i < dlg_lines.size():
		var cur: Dictionary = dlg_lines[dlg_i]
		if dlg_chars < String(cur.text).length():
			dlg_chars = 9999.0
			return
		if dlg_i == dlg_lines.size() - 1 and not dlg_choices.is_empty():
			# letzte Zeile bleibt stehen, bis gewählt wird
			for i in _choice_rects.size():
				if (_choice_rects[i] as Rect2).has_point(p):
					_pick(i)
			return
		dlg_i += 1
		dlg_chars = 0.0
		dlg_lock = 0.15
		if world:
			world.sfx("tick")
		if dlg_i >= dlg_lines.size():
			_finish_dialog(-1)

func _pick(i: int) -> void:
	if world:
		world.sfx("quest")
	_finish_dialog(i)

func _finish_dialog(i: int) -> void:
	var cb := dlg_cb
	dlg_lines = []
	dlg_choices = []
	dlg_i = 0
	dlg_cb = Callable()
	_choice_rects = []
	if cb.is_valid():
		cb.call(i)

func show_banner(text: String) -> void:
	banner = text
	banner_t = 0.0

func show_zone(text: String) -> void:
	zone_name = text
	zone_t = 0.0

func show_chronicle(lines: Array) -> void:
	chronicle = lines
	chronicle_t = 0.0

func release_all() -> void:
	_stick_idx = -1
	_look_idx = -1
	_attack_idx = -1
	stick = Vector2.ZERO

# ---------- Layout ----------

func _buttons() -> Array:
	var w := size.x
	var h := size.y
	var out := [
		{"id": "attack", "p": Vector2(w - 86, h - 84), "r": 46.0, "c": H.FG},
		{"id": "dash", "p": Vector2(w - 190, h - 56), "r": 32.0, "c": H.CYAN},
		{"id": "sense", "p": Vector2(w - 70, h - 192), "r": 26.0, "c": H.RED},
		{"id": "drink", "p": Vector2(w - 278, h - 44), "r": 24.0, "c": H.RED},
	]
	if PlayerStats.has_skill("blood_scythe"):
		out.append({"id": "skill1", "p": Vector2(w - 170, h - 152), "r": 29.0, "c": H.RED})
	if PlayerStats.has_skill("radiance") or PlayerStats.has_skill("dread"):
		out.append({"id": "skill2", "p": Vector2(w - 250, h - 120), "r": 27.0, "c": H.GOLD if PlayerStats.has_skill("radiance") else H.PURPLE})
	return out

func _menu_rect() -> Rect2:
	return Rect2(size.x - 112, 10, 100, 34)

func _view_rect() -> Rect2:
	return Rect2(size.x - 160, 10, 42, 34)

func _quest_rect() -> Rect2:
	return Rect2(size.x - 292, 50, 280, 104.0 if quest_open else 52.0)

func _interact_rect() -> Rect2:
	return Rect2(size.x * 0.5 - 120, size.y - 82, 240, 52)

# ---------- Eingabe ----------

func _input(event: InputEvent) -> void:
	if title_mode or world == null or world.menu_open():
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var p := e.position
		if e.pressed:
			if in_dialog():
				_dialog_tap(p)
				get_viewport().set_input_as_handled()
				return
			if world.input_locked():
				return
			if _menu_rect().grow(6).has_point(p):
				menu_pressed.emit()
				return
			if _view_rect().grow(6).has_point(p):
				view_pressed.emit()
				return
			if _quest_rect().has_point(p):
				quest_open = not quest_open
				return
			if interact_text != "" and _interact_rect().grow(6).has_point(p):
				interact_pressed.emit()
				return
			for b in _buttons():
				if p.distance_to(b.p) < float(b.r) + 12.0:
					_press(String(b.id))
					if b.id == "attack":
						_attack_idx = e.index
						_attack_hold = 0.0
					return
			if p.x < size.x * 0.42 and _stick_idx < 0 and p.y > 110.0:
				_stick_idx = e.index
				_stick_origin = p
				stick = Vector2.ZERO
			elif _look_idx < 0:
				_look_idx = e.index
				_look_last = p
		else:
			if e.index == _stick_idx:
				_stick_idx = -1
				stick = Vector2.ZERO
			if e.index == _look_idx:
				_look_idx = -1
			if e.index == _attack_idx:
				_attack_idx = -1
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _stick_idx:
			var d := e.position - _stick_origin
			if d.length() > STICK_R:
				_stick_origin += d.normalized() * (d.length() - STICK_R)
				d = d.normalized() * STICK_R
			stick = d / STICK_R
		elif e.index == _look_idx:
			look_delta += e.position - _look_last
			_look_last = e.position
	elif event is InputEventKey and event.pressed and not event.echo:
		if in_dialog():
			var k: int = event.physical_keycode
			if k >= KEY_1 and k <= KEY_4 and dlg_i == dlg_lines.size() - 1 and not dlg_choices.is_empty():
				if k - KEY_1 < dlg_choices.size():
					_pick(k - KEY_1)
			elif k in [KEY_SPACE, KEY_ENTER, KEY_E]:
				_dialog_tap(Vector2(-100, -100))
			return
		match event.physical_keycode:
			KEY_J:
				_press("attack")
			KEY_K, KEY_SPACE:
				_press("dash")
			KEY_L:
				_press("skill1")
			KEY_U:
				_press("skill2")
			KEY_F:
				_press("drink")
			KEY_Q:
				_press("sense")
			KEY_V:
				view_pressed.emit()
			KEY_E:
				if interact_text != "":
					interact_pressed.emit()
			KEY_TAB, KEY_M:
				menu_pressed.emit()

func _press(id: String) -> void:
	_press_fx[id] = _t
	var p: Player = world.player
	match id:
		"attack":
			p.attack()
		"dash":
			p.dash()
		"skill1", "skill2":
			p.skill(id)
		"drink":
			p.drink()
		"sense":
			sense_pressed.emit()

func keyboard_dir() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A):
		v.x -= 1
	if Input.is_physical_key_pressed(KEY_D):
		v.x += 1
	if Input.is_physical_key_pressed(KEY_W):
		v.y -= 1
	if Input.is_physical_key_pressed(KEY_S):
		v.y += 1
	if v.length() > 0 and Input.is_physical_key_pressed(KEY_SHIFT):
		return v.normalized()
	return v.normalized() * 0.8 if v.length() > 0 else v

func move_input() -> Vector2:
	var k := keyboard_dir()
	return k if k.length() > 0.0 else stick

func take_look() -> Vector2:
	var l := look_delta
	look_delta = Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_LEFT):
		l.x -= 6
	if Input.is_physical_key_pressed(KEY_RIGHT):
		l.x += 6
	if Input.is_physical_key_pressed(KEY_UP):
		l.y -= 4
	if Input.is_physical_key_pressed(KEY_DOWN):
		l.y += 4
	return l

# ---------- Ablauf ----------

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.05)
	_t += rd
	dlg_lock -= rd
	if dlg_i < dlg_lines.size():
		dlg_chars += rd * 55.0
	for m in msgs:
		m.t += rd
	msgs = msgs.filter(func(m): return m.t < m.life)
	for m in minis:
		m.t += rd
	minis = minis.filter(func(m): return m.t < 2.4)
	red_flash = maxf(0.0, red_flash - rd * 1.5)
	banner_t += rd
	zone_t += rd
	perfect_t -= rd
	fade_t += rd
	if chronicle_t >= 0.0:
		chronicle_t += rd
	if death_t >= 0.0:
		death_t += rd
	if _attack_idx >= 0 and world and not world.menu_open():
		_attack_hold += rd
		if _attack_hold > 0.28:
			world.player.attack()
	queue_redraw()

# ---------- Zeichnen ----------

func _str(pos: Vector2, text: String, fsize: int, color: Color, font: Font = H.F_SEMI, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string(font, pos, text, align, width, fsize, color)

func _str_o(pos: Vector2, text: String, fsize: int, color: Color, font: Font = H.F_BOLD, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos, text, align, width, fsize, 6, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, pos, text, align, width, fsize, color)

func _panel(r: Rect2, border: Color, bg := H.PANEL) -> void:
	draw_rect(r, bg)
	draw_rect(r, border, false, 1.0)
	var c := Color(border, 1.0)
	var l := 8.0
	for corner in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var sx := 1.0 if corner.x == r.position.x else -1.0
		var sy := 1.0 if corner.y == r.position.y else -1.0
		draw_line(corner, corner + Vector2(l * sx, 0), c, 2.0)
		draw_line(corner, corner + Vector2(0, l * sy), c, 2.0)

func _bar(r: Rect2, frac: float, col: Color, back := Color(1, 1, 1, 0.08), segments := 0) -> void:
	draw_rect(r, back)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y)), col)
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y * 0.35)), Color(1, 1, 1, 0.16))
	if segments > 0:
		for i in range(1, segments):
			var x := r.position.x + r.size.x * i / segments
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.5), 1.0)

func _wrap_text(r: Rect2, text: String, fs: int, col: Color, font: Font = H.F_REG, line_h := 16.0, max_chars := -1) -> float:
	var shown := text if max_chars < 0 else text.substr(0, max_chars)
	var words := shown.split(" ")
	var line := ""
	var y := r.position.y + fs
	for w in words:
		var test := w if line == "" else line + " " + w
		if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > r.size.x and line != "":
			_str(Vector2(r.position.x, y), line, fs, col, font)
			y += line_h
			line = w
		else:
			line = test
	if line != "":
		_str(Vector2(r.position.x, y), line, fs, col, font)
	return y

func _clip(text: String, fs: int, w: float, font: Font = H.F_REG) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return text
	var t := text
	while t.length() > 3 and font.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		t = t.substr(0, t.length() - 1)
	return t + "…"

func _draw() -> void:
	if world == null:
		return
	_draw_vignettes()
	if not title_mode:
		if not in_dialog():
			_draw_enemy_bars()
		_draw_stats()
		_draw_compass()
		_draw_quest()
		if not in_dialog():
			_draw_drink_quest()
		if not in_dialog():
			_draw_controls()
			_draw_boss()
	_draw_msgs()
	_draw_banner()
	_draw_dialog()
	_draw_chronicle()
	if fade_t < 1.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, sin(clampf(fade_t, 0.0, 1.0) * PI)))
	if death_t >= 0.0:
		var a := clampf(death_t * 1.2, 0.0, 0.88)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.0, 0.02, a))
		_str_o(Vector2(0, size.y * 0.45), "DIE NACHT LÄSST DICH NICHT GEHEN", 28, Color(H.RED, clampf(death_t * 2.0, 0, 1)), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_str(Vector2(0, size.y * 0.45 + 30), "Du erwachst an der Ruine. Was du getan hast, bleibt getan.", 15, Color(H.FG, clampf(death_t - 0.6, 0, 1)), H.F_REG, HORIZONTAL_ALIGNMENT_CENTER, size.x)

func _draw_vignettes() -> void:
	var s := PlayerStats.s
	var w := size.x
	var h := size.y
	var e := 100.0
	var amt := 0.0
	var col := Color(0.8, 0.0, 0.05)
	var bf := float(s.blood) / PlayerStats.max_blood()
	if bf < 0.2:
		amt = (0.2 - bf) / 0.2 * (0.55 + 0.45 * sin(_t * 6.0))
	var hp_frac := float(s.hp) / PlayerStats.max_hp()
	if hp_frac < 0.3:
		amt = maxf(amt, (0.3 - hp_frac) / 0.3 * (0.6 + 0.4 * sin(_t * 8.0)))
	amt = maxf(amt, red_flash)
	if sun_burn > 0.05:
		col = col.lerp(Color(1.0, 0.55, 0.15), clampf(sun_burn / maxf(amt + sun_burn, 0.01), 0.0, 1.0))
		amt = maxf(amt, sun_burn * (0.6 + 0.3 * sin(_t * 5.0)))
	if amt > 0.01:
		var c0 := Color(col, 0.55 * amt)
		var c1 := Color(col, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - e, e), Vector2(e, e)]), PackedColorArray([c0, c0, c1, c1]))
		draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(e, h - e), Vector2(w - e, h - e), Vector2(w, h)]), PackedColorArray([c0, c1, c1, c0]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, e), Vector2(e, h - e), Vector2(0, h)]), PackedColorArray([c0, c1, c1, c0]))
		draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - e, h - e), Vector2(w - e, e)]), PackedColorArray([c0, c0, c1, c1]))
	if perfect_t > 0.0:
		var a := clampf(perfect_t * 2.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.4, 0.7, 0.1 * a))
		_str_o(Vector2(0, size.y * 0.3), "PERFEKTER SCHATTENSCHRITT", 24, Color(H.CYAN, a), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)

func _draw_stats() -> void:
	var s := PlayerStats.s
	var x0 := 12.0
	var y0 := 10.0
	_panel(Rect2(x0, y0, 262, 98), H.CYAN_DIM)
	# Level
	var c := Vector2(x0 + 28, y0 + 30)
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * 19.0)
	draw_colored_polygon(pts, Color(1.0, 0.16, 0.26, 0.16))
	pts.append(pts[0])
	draw_polyline(pts, H.RED, 2.0, true)
	_str(c + Vector2(-20, -4), "LV", 9, H.MUTED, H.F_SEMI, HORIZONTAL_ALIGNMENT_CENTER, 40)
	_str(c + Vector2(-20, 13), str(int(s.level)), 17, H.FG, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 40)
	var xp_frac := float(s.xp) / PlayerStats.xp_to_next()
	draw_rect(Rect2(x0 + 9, y0 + 56, 38, 3), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(x0 + 9, y0 + 56, 38 * xp_frac, 3), H.CYAN)
	# Uhr mit Sonne/Mond
	var night: float = PlayerStats.night
	var icon_c := Vector2(x0 + 28, y0 + 78)
	if night > 0.5:
		draw_circle(icon_c, 7.0, Color(0.8, 0.85, 1.0))
		draw_circle(icon_c + Vector2(3, -2), 6.0, H.PANEL)
	else:
		draw_circle(icon_c, 6.0, Color(1.0, 0.8, 0.4))
		for i in 8:
			var a := TAU * i / 8.0
			draw_line(icon_c + Vector2(cos(a), sin(a)) * 8.0, icon_c + Vector2(cos(a), sin(a)) * 10.5, Color(1.0, 0.8, 0.4), 1.5)
	_str(Vector2(x0 + 4, y0 + 96), PlayerStats.clock_text(), 10, H.MUTED, H.F_MONO, HORIZONTAL_ALIGNMENT_CENTER, 48)
	var bx := x0 + 58
	_str(Vector2(bx, y0 + 14), "KAEL", 11, H.CYAN, H.F_SEMI)
	_str(Vector2(bx + 40, y0 + 14), "· TAG %d" % int(s.day), 10, H.MUTED, H.F_SEMI)
	var hp_frac := float(s.hp) / PlayerStats.max_hp()
	_str(Vector2(bx, y0 + 29), "HP", 9, H.MUTED)
	_bar(Rect2(bx + 22, y0 + 21, 172, 8), hp_frac, Color(0.85, 0.95, 1.0) if hp_frac > 0.3 else Color(1.0, 0.55, 0.4), Color(1, 1, 1, 0.08), 10)
	# Blut
	var bf := float(s.blood) / PlayerStats.max_blood()
	var pulse := 0.75 + 0.25 * sin(_t * (3.0 if bf > 0.2 else 9.0))
	draw_colored_polygon(_drop_points(Vector2(bx + 6, y0 + 46), 5.0), Color(H.RED, pulse))
	_bar(Rect2(bx + 22, y0 + 38, 172, 10), bf, Color(H.RED.r, H.RED.g, H.RED.b, pulse), Color(0.4, 0.0, 0.05, 0.35))
	_str(Vector2(bx + 22, y0 + 60), "BLUT %d%%" % int(bf * 100.0), 9, Color(1.0, 0.45, 0.5), H.F_SEMI)
	# Menschlichkeit: Skala von Bestie (links, rot) bis Mensch (rechts, warm)
	var hum := PlayerStats.humanity() / 100.0
	var hr := Rect2(bx + 22, y0 + 70, 172, 6)
	for i in 40:
		var f := float(i) / 40.0
		var cc := Color(0.75, 0.05, 0.1).lerp(Color(0.95, 0.85, 0.65), f)
		draw_rect(Rect2(hr.position.x + hr.size.x * f, hr.position.y, hr.size.x / 40.0 + 0.5, hr.size.y), Color(cc, 0.35))
	var mx := hr.position.x + hr.size.x * hum
	draw_rect(Rect2(mx - 2, hr.position.y - 3, 4, hr.size.y + 6), H.FG)
	for th: float in [0.25, 0.5, 0.75]:
		var tx := hr.position.x + hr.size.x * th
		draw_line(Vector2(tx, hr.position.y), Vector2(tx, hr.end.y), Color(0, 0, 0, 0.6), 1.0)
	_str(Vector2(bx + 22, y0 + 91), "MENSCHLICHKEIT", 9, H.MUTED, H.F_SEMI)
	var tier_col := Color(0.95, 0.85, 0.65).lerp(Color(1.0, 0.2, 0.25), 1.0 - hum)
	_str(Vector2(bx + 22, y0 + 91), "%s · %d" % [PlayerStats.tier_name().to_upper(), int(PlayerStats.humanity())], 9, tier_col, H.F_BOLD, HORIZONTAL_ALIGNMENT_RIGHT, 172)
	# Zustände
	var chips: Array = []
	if PlayerStats.buffs.has("beast"):
		chips.append(["BESTIENBLUT %ds" % int(PlayerStats.buffs.beast), H.PURPLE])
	if PlayerStats.starving():
		chips.append(["BLUTMANGEL", H.RED])
	if sun_burn > 0.05:
		chips.append(["SONNE BRENNT", Color(1.0, 0.6, 0.2)])
	if PlayerStats.flag("village_hostile"):
		chips.append(["ASCH-FURT FEINDLICH", Color(1.0, 0.45, 0.3)])
	if PlayerStats.penalty_active():
		chips.append(["SYSTEMSTRAFE", Color(1.0, 0.6, 0.2)])
	if int(s.attr_points) > 0 or int(s.skill_points) > 0:
		chips.append(["PUNKTE FREI", H.GOLD])
	var cx := x0
	var cy := y0 + 104
	for ch in chips:
		var tw := H.F_SEMI.get_string_size(ch[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14
		draw_rect(Rect2(cx, cy, tw, 17), Color(ch[1], 0.14))
		draw_rect(Rect2(cx, cy, tw, 17), Color(ch[1], 0.6), false, 1.0)
		_str(Vector2(cx + 7, cy + 12.5), ch[0], 10, ch[1])
		cx += tw + 6
	var my := cy + 36 + (36 if drink_t >= 0.0 else 0)
	for m in minis:
		var a := clampf(2.4 - float(m.t), 0.0, 1.0)
		_str(Vector2(x0, my), m.text, 12, Color(H.FG, a * 0.9), H.F_SEMI)
		my += 16

func _drop_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(0, -r * 1.9))
	for i in 13:
		var a := -PI * 0.15 + (PI * 1.3) * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw_compass() -> void:
	var w := minf(360.0, size.x * 0.34)
	var r := Rect2(size.x * 0.5 - w * 0.5, 10, w, 26)
	draw_rect(r, Color(0.02, 0.04, 0.07, 0.55))
	draw_rect(r, Color(H.CYAN, 0.25), false, 1.0)
	var rig: CameraRig = world.rig
	var yaw: float = rig.yaw
	var fov := PI * 0.9
	var dirs := [["N", PI], ["O", PI * 0.5], ["S", 0.0], ["W", -PI * 0.5]]
	# Himmelsrichtungen: Norden = −Z
	for d in dirs:
		var a := wrapf(float(d[1]) - yaw, -PI, PI)
		if absf(a) < fov * 0.5:
			var x := r.position.x + r.size.x * (0.5 - a / fov)
			_str(Vector2(x - 10, r.position.y + 18), d[0], 13, H.CYAN if d[0] == "N" else H.MUTED, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 20)
	for i in 24:
		var a := wrapf(TAU * i / 24.0 - yaw, -PI, PI)
		if absf(a) < fov * 0.5:
			var x := r.position.x + r.size.x * (0.5 - a / fov)
			draw_line(Vector2(x, r.end.y - 5), Vector2(x, r.end.y - 1), Color(1, 1, 1, 0.25), 1.0)
	var pp: Vector3 = world.player.global_position
	for m in compass_marks:
		var tp: Vector3 = m[0]
		var d := tp - pp
		var bearing := atan2(-d.x, -d.z)
		var a := wrapf(bearing - yaw, -PI, PI)
		var x := r.position.x + r.size.x * (0.5 - clampf(a, -fov * 0.5, fov * 0.5) / fov)
		var col: Color = m[1]
		var pts := PackedVector2Array([Vector2(x, r.end.y + 1), Vector2(x - 6, r.end.y + 9), Vector2(x + 6, r.end.y + 9)])
		draw_colored_polygon(pts, col)
		var dist := Vector2(d.x, d.z).length()
		_str(Vector2(x - 30, r.end.y + 21), "%s %dm" % [m[2], int(dist)], 9, col, H.F_SEMI, HORIZONTAL_ALIGNMENT_CENTER, 60)
	draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.position.y + 5), H.FG, 2.0)

func _draw_quest() -> void:
	var mr := _menu_rect()
	_panel(mr, H.CYAN)
	_str(mr.position + Vector2(0, 22), "SYSTEM", 14, H.CYAN, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
	if int(PlayerStats.s.attr_points) + int(PlayerStats.s.skill_points) > 0:
		draw_circle(mr.position + Vector2(mr.size.x - 6, 6), 5.0, Color(H.GOLD, 0.7 + 0.3 * sin(_t * 6.0)))
	var vr := _view_rect()
	_panel(vr, H.CYAN_DIM)
	var fp: bool = world.rig.first_person
	# Kamerasymbol: Auge (Ego) oder Figur (von hinten)
	var vc := vr.get_center()
	if fp:
		draw_arc(vc + Vector2(0, 4), 9.0, PI + 0.5, TAU - 0.5, 10, H.CYAN, 1.5, true)
		draw_arc(vc + Vector2(0, -4), 9.0, 0.5, PI - 0.5, 10, H.CYAN, 1.5, true)
		draw_circle(vc, 2.5, H.CYAN)
	else:
		draw_circle(vc + Vector2(0, -6), 3.5, H.CYAN)
		draw_line(vc + Vector2(0, -2), vc + Vector2(0, 7), H.CYAN, 2.0)
		draw_line(vc + Vector2(-5, 2), vc + Vector2(5, 2), H.CYAN, 1.5)
	var r := _quest_rect()
	_panel(r, H.CYAN_DIM, Color(0.02, 0.04, 0.07, 0.7))
	_str(r.position + Vector2(10, 15), "ZIEL", 10, H.CYAN)
	var d := 0
	if PlayerStats.s.daily.has("quests"):
		for q in PlayerStats.s.daily.quests:
			if q.done:
				d += 1
	_str(r.position + Vector2(10, 15), "TÄGLICH %d/3   %s" % [d, "▴" if quest_open else "▾"], 10, H.MUTED, H.F_SEMI, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20)
	_str(r.position + Vector2(10, 34), PlayerStats.story_title(), 14, H.FG, H.F_BOLD)
	var txt := PlayerStats.story_text()
	if quest_open:
		_wrap_text(Rect2(r.position + Vector2(10, 40), Vector2(r.size.x - 20, 60)), txt, 12, H.MUTED)
	else:
		_str(r.position + Vector2(10, 47), _clip(txt, 11, r.size.x - 20), 11, H.MUTED, H.F_REG)

func _draw_controls() -> void:
	var p: Player = world.player
	if world.input_locked():
		return
	if _stick_idx >= 0:
		draw_circle(_stick_origin, STICK_R + 8, Color(H.CYAN, 0.06))
		draw_arc(_stick_origin, STICK_R + 8, 0, TAU, 40, Color(H.CYAN, 0.45), 1.5, true)
		var run := stick.length() > 0.85
		draw_circle(_stick_origin + stick * STICK_R, 24, Color(H.RED if run else H.CYAN, 0.35))
		draw_arc(_stick_origin + stick * STICK_R, 24, 0, TAU, 24, H.RED if run else H.CYAN, 2.0, true)
	else:
		var hc := Vector2(118, size.y - 100)
		draw_arc(hc, STICK_R + 8, 0, TAU, 40, Color(H.CYAN, 0.14), 1.5, true)
		draw_circle(hc, 18, Color(H.CYAN, 0.07))
	for b in _buttons():
		var id: String = b.id
		var c: Vector2 = b.p
		var r: float = b.r
		var col: Color = b.c
		var cdv := 0.0
		var cdm := 1.0
		if p.cds.has(id):
			cdv = p.cds[id]
			cdm = maxf(0.01, p.cd_max[id] * PlayerStats.cooldown_mult())
		var pressed := _t - float(_press_fx.get(id, -9.0)) < 0.12
		var rr := r * (0.92 if pressed else 1.0)
		var active: bool = id == "sense" and world.sense_on
		draw_circle(c, rr, Color(0.02, 0.04, 0.07, 0.62) if not active else Color(0.35, 0.0, 0.05, 0.75))
		draw_arc(c, rr, 0, TAU, 40, Color(col, 0.85), 2.0, true)
		if cdv > 0.0:
			draw_arc(c, rr - 3, -PI * 0.5, -PI * 0.5 + TAU * (cdv / cdm), 36, Color(0, 0, 0, 0.65), rr * 0.55, false)
			_str(c + Vector2(-20, 6), "%.1f" % cdv, 13, H.FG, H.F_MONO, HORIZONTAL_ALIGNMENT_CENTER, 40)
		else:
			_icon(id, c, rr, col)
		if id == "drink":
			var n := PlayerStats.vial_count()
			draw_circle(c + Vector2(r * 0.72, -r * 0.72), 9, Color(0.6, 0.0, 0.08) if n > 0 else Color(0.2, 0.2, 0.24))
			_str(c + Vector2(r * 0.72 - 10, -r * 0.72 + 4), str(n), 10, H.FG, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 20)
	if interact_text != "":
		var ir := _interact_rect()
		var a := 0.75 + 0.25 * sin(_t * 4.0)
		_panel(ir, Color(H.RED, a), Color(0.1, 0.0, 0.03, 0.78))
		_str(ir.position + Vector2(0, 24 if interact_warn != "" else 32), interact_text, 15, Color(1.0, 0.65, 0.68), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, ir.size.x)
		if interact_warn != "":
			_str(ir.position + Vector2(0, 42), interact_warn, 10, Color(1.0, 0.75, 0.3, 0.6 + 0.4 * sin(_t * 8.0)), H.F_SEMI, HORIZONTAL_ALIGNMENT_CENTER, ir.size.x)

func _icon(id: String, c: Vector2, r: float, col: Color) -> void:
	var s := r * 0.42
	match id:
		"attack":
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 4.0, true)
			draw_line(c + Vector2(-s * 0.55, s * 0.05), c + Vector2(-s * 0.05, s * 0.55), col, 3.0, true)
		"dash":
			for i in 2:
				var o := Vector2(-s * 0.5 + i * s * 0.7, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.35, -s * 0.6), c + o + Vector2(s * 0.3, 0), c + o + Vector2(-s * 0.35, s * 0.6)]), col, 3.5, true)
		"skill1":
			draw_arc(c, s * 1.05, -PI * 0.9, PI * 0.6, 20, col, 3.5, true)
			draw_arc(c, s * 0.6, PI * 0.1, PI * 1.6, 16, Color(col, 0.6), 2.5, true)
		"skill2":
			for i in 3:
				draw_arc(c, s * (0.4 + i * 0.35), -PI * 0.75, -PI * 0.25, 10, Color(col, 1.0 - i * 0.25), 2.5, true)
		"drink":
			draw_colored_polygon(_drop_points(c + Vector2(0, s * 0.25), s * 0.75), col)
		"sense":
			draw_arc(c + Vector2(0, s * 0.5), s * 1.0, PI + 0.6, TAU - 0.6, 12, col, 2.0, true)
			draw_arc(c + Vector2(0, -s * 0.5), s * 1.0, 0.6, PI - 0.6, 12, col, 2.0, true)
			draw_circle(c, s * 0.35, col)

func _draw_enemy_bars() -> void:
	var cam: Camera3D = world.rig.camera
	var inspect := PlayerStats.has_skill("inspect")
	if inspect:
		_draw_inspect(cam)
	for e in get_tree().get_nodes_in_group("hostile"):
		var en := e as Actor
		if not en.alive or (en is Enemy and (en as Enemy).is_boss()):
			continue
		if en.hp >= en.max_hp and en.last_hit_t > 3.0 and not inspect:
			continue
		var wp := en.global_position + Vector3(0, en._height() + 0.35, 0)
		if cam.is_position_behind(wp) or wp.distance_to(cam.global_position) > 40.0:
			continue
		var sp := cam.unproject_position(wp)
		var r := Rect2(sp - Vector2(23, 0), Vector2(46, 5))
		draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
		_bar(r, en.hp / en.max_hp, Color(1.0, 0.3, 0.3), Color(0.3, 0.05, 0.05, 0.6))
		if en is Enemy and (en as Enemy).state == "windup":
			_str_o(sp + Vector2(-10, -6), "!", 18, H.RED, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 20)

## Inspektion: Stufe, Name und Blutgruppe über Gegnern (mit Blutsinn über allen Wesen)
func _draw_inspect(cam: Camera3D) -> void:
	var sense: bool = world.sense_on
	var group := "living" if sense else "hostile"
	var pp: Vector3 = world.player.global_position
	for e in get_tree().get_nodes_in_group(group):
		var en := e as Actor
		if en == null or not en.alive or en._far:
			continue
		var d := en.global_position.distance_to(pp)
		if d > (28.0 if sense else 22.0):
			continue
		var wp := en.global_position + Vector3(0, en._height() + 0.35, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var elite := en is Enemy and (en as Enemy).is_boss()
		var col := Color(1.0, 0.75, 0.3) if elite else (Color(1.0, 0.55, 0.5) if en.is_in_group("hostile") else Color(0.75, 0.9, 1.0))
		var bt := "Tier" if en.kind == "animal" else ("Bestie" if en.kind == "beast" else "Mensch")
		var txt := "Stufe %d  %s" % [en.level, en.display_name]
		_str_o(sp + Vector2(-80, -9), txt, 10, Color(col, 0.95), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 160)
		if sense or d < 10.0:
			_str_o(sp + Vector2(-80, -21), "%d/%d HP · %s" % [int(en.hp), int(en.max_hp), bt], 9, Color(H.FG, 0.75), H.F_SEMI, HORIZONTAL_ALIGNMENT_CENTER, 160)

func _draw_drink_quest() -> void:
	if drink_t < 0.0:
		return
	var w := 262.0
	var r := Rect2(12, 136, w, 30)
	var pulse := 0.6 + 0.4 * sin(_t * 6.0)
	_panel(r, Color(H.GOLD, 0.8), Color(0.05, 0.03, 0.0, 0.8))
	_str(r.position + Vector2(10, 13), "[ OPTIONALE QUEST ]", 9, Color(H.GOLD, pulse), H.F_SEMI)
	_str(r.position + Vector2(10, 13), "%d s" % int(ceil(drink_t)), 11, H.GOLD, H.F_BOLD, HORIZONTAL_ALIGNMENT_RIGHT, w - 20)
	_str(r.position + Vector2(10, 26), "Trinke das Blut deines Gegners", 11, H.FG, H.F_SEMI)

func _draw_boss() -> void:
	var boss: Actor = world.active_boss()
	if boss == null:
		return
	var w := minf(400.0, size.x * 0.42)
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y - 26, w, 9)
	_str_o(Vector2(r.position.x, r.position.y - 6), boss.display_name.to_upper(), 13, Color(1.0, 0.75, 0.4), H.F_BOLD)
	draw_rect(r.grow(2), Color(0, 0, 0, 0.7))
	_bar(r, boss.hp / boss.max_hp, Color(1.0, 0.25, 0.25), Color(0.3, 0.05, 0.05, 0.6), 10)

func _msg_color(kind: String) -> Color:
	if kind.begins_with("loot"):
		return Items.RARITY[int(kind.substr(4))].color
	match kind:
		"blood":
			return H.RED
		"warn", "humanity_down":
			return Color(1.0, 0.4, 0.3)
		"humanity_up":
			return Color(0.95, 0.85, 0.6)
		"reward", "level":
			return H.GOLD
		"choice":
			return Color(0.95, 0.85, 0.65)
	return H.CYAN

func _draw_msgs() -> void:
	var y := 64.0
	var w := clampf(size.x - 640.0, 320.0, 440.0)
	var x := size.x * 0.5 - w * 0.5
	for m in msgs:
		var t: float = m.t
		var life: float = m.life
		var a := clampf(t * 5.0, 0.0, 1.0) * clampf((life - t) * 2.5, 0.0, 1.0)
		var col := _msg_color(m.kind)
		var hgt := 40.0
		var rr := Rect2(x, y - (1.0 - clampf(t * 5.0, 0.0, 1.0)) * 10.0, w, hgt)
		_panel(rr, Color(col, 0.7 * a), Color(0.01, 0.03, 0.06, 0.82 * a))
		var head := "[ SYSTEM ]"
		match String(m.kind):
			"blood":
				head = "[ HUNGER ]"
			"warn":
				head = "[ WARNUNG ]"
			"quest":
				head = "[ ZIEL ]"
			"reward":
				head = "[ BELOHNUNG ]"
			"level":
				head = "[ EVOLUTION ]"
			"choice":
				head = "[ FOLGE ]"
			"humanity_down", "humanity_up":
				head = "[ MENSCHLICHKEIT ]"
			"loot0", "loot1", "loot2", "loot3":
				head = "[ BEUTE ]"
		_str(rr.position + Vector2(10, 14), head, 9, Color(col, a), H.F_SEMI)
		_str(rr.position + Vector2(10, 31), _clip(m.text, 13, w - 20, H.F_SEMI), 13, Color(H.FG, a), H.F_SEMI)
		y += hgt + 5

func _draw_banner() -> void:
	if banner != "" and banner_t < 4.0:
		var a := clampf(banner_t * 2.0, 0.0, 1.0) * clampf((4.0 - banner_t) * 1.5, 0.0, 1.0)
		var yb := size.y * 0.58
		draw_rect(Rect2(0, yb - 34, size.x, 56), Color(0.0, 0.0, 0.02, 0.6 * a))
		draw_line(Vector2(size.x * 0.2, yb - 34), Vector2(size.x * 0.8, yb - 34), Color(H.RED, a), 1.0)
		draw_line(Vector2(size.x * 0.2, yb + 22), Vector2(size.x * 0.8, yb + 22), Color(H.CYAN, a), 1.0)
		_str_o(Vector2(0, yb + 4), banner, 26, Color(H.FG, a), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if zone_name != "" and zone_t < 3.5 and not title_mode and not in_dialog():
		var a2 := clampf(zone_t * 3.0, 0.0, 1.0) * clampf((3.5 - zone_t) * 1.5, 0.0, 1.0)
		_str_o(Vector2(0, size.y * 0.24), zone_name.to_upper(), 18, Color(H.FG, a2 * 0.95), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)

func _draw_dialog() -> void:
	if dlg_lines.is_empty():
		return
	var cur: Dictionary = dlg_lines[mini(dlg_i, dlg_lines.size() - 1)]
	var w := minf(660.0, size.x * 0.74)
	var has_choices := not dlg_choices.is_empty() and dlg_i == dlg_lines.size() - 1 and dlg_chars >= String(cur.text).length()
	var ch_h := 40.0 * dlg_choices.size() if has_choices else 0.0
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y - 120 - ch_h, w, 100)
	var who: String = cur.get("who", "")
	var sys := who == "SYSTEM" or who == "DIE ERSTE NACHT"
	var col := H.CYAN if who == "SYSTEM" else (H.RED if who == "DIE ERSTE NACHT" or who == "" else H.GOLD)
	_panel(r, Color(col, 0.75), Color(0.01, 0.02, 0.04, 0.9))
	if who != "":
		_str(r.position + Vector2(14, 20), ("[ %s ]" % who) if sys else who.to_upper(), 12, col, H.F_SEMI)
	var fnt: Font = H.F_SEMI if sys else H.F_REG
	_wrap_text(Rect2(r.position + Vector2(14, 28 if who != "" else 12), Vector2(w - 28, 70)), String(cur.text), 15, H.FG, fnt, 20.0, int(dlg_chars))
	_choice_rects = []
	if has_choices:
		for i in dlg_choices.size():
			var cr := Rect2(r.position.x + 20, r.end.y + 6 + i * 40, w - 40, 34)
			_choice_rects.append(cr)
			var txt: String = dlg_choices[i]
			var bad := txt.begins_with("[")
			_panel(cr, Color(H.RED if bad else H.CYAN, 0.7), Color(0.03, 0.05, 0.09, 0.92))
			_str(cr.position + Vector2(12, 22), "%d" % (i + 1), 12, Color(H.MUTED, 0.8), H.F_MONO)
			_str(cr.position + Vector2(34, 22), _clip(txt, 14, cr.size.x - 46, H.F_SEMI), 14, Color(1.0, 0.7, 0.7) if bad else H.FG, H.F_SEMI)
	elif dlg_chars >= String(cur.text).length():
		_str(r.end + Vector2(-90, -10), "TIPPEN ▸", 10, Color(col, 0.5 + 0.5 * sin(_t * 5.0)), H.F_SEMI)

func _draw_chronicle() -> void:
	if chronicle_t < 0.0 or chronicle.is_empty():
		return
	var a := clampf(chronicle_t * 1.5, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.8 * a))
	_str_o(Vector2(0, 60), "WAS DU GETAN HAST", 22, Color(H.RED, a), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	var y := 100.0
	for i in chronicle.size():
		var la := clampf(chronicle_t * 1.5 - 0.6 - i * 0.5, 0.0, 1.0)
		_str(Vector2(size.x * 0.5 - 260, y), "◆  " + String(chronicle[i]), 15, Color(H.FG, la), H.F_SEMI)
		y += 28
