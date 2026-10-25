class_name Hud
extends Control
## Hologramm-HUD: Werte oben links, Quest oben rechts, Joystick unten links, Aktionsknöpfe unten rechts.
## Dazu System-Meldungen, Erzähltexte, Gegner-Leisten, Boss-Leiste, Vignetten.

signal menu_pressed
signal interact_pressed
signal narration_done

const H := preload("res://scripts/ui/holo_ui.gd")
const STICK_R := 62.0

var world: Node
var stick := Vector2.ZERO
var _stick_idx := -1
var _stick_origin := Vector2.ZERO
var _attack_idx := -1
var _attack_hold := 0.0
var quest_open := false
var interact_text := ""
var _t := 0.0
var _press_fx := {}   # Knopf -> Zeit des letzten Drucks

# Meldungen
var msgs: Array = []      # {text, kind, t, life}
var minis: Array = []
# Erzählung
var narr: Array = []      # [{who, text}]
var narr_i := 0
var narr_chars := 0.0
var narr_lock_t := 0.0
# Effekte
var red_flash := 0.0
var death_t := -1.0
var title_mode := false
var banner := ""
var banner_t := 0.0
var zone_name := ""
var zone_t := 0.0
var perfect_t := 0.0

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
	var life := 3.4
	if kind == "level" or kind == "quest":
		life = 4.2
	msgs.append({"text": text, "kind": kind, "t": 0.0, "life": life})
	if msgs.size() > 3:
		msgs.pop_front()
	if kind == "level":
		world.sfx("level")
	elif kind in ["quest", "reward"]:
		world.sfx("quest")
	elif kind == "warn":
		world.sfx("warn")

func narrate(lines: Array) -> void:
	narr = lines
	narr_i = 0
	narr_chars = 0.0
	narr_lock_t = 0.35
	release_all()

func narrating() -> bool:
	return narr_i < narr.size()

func show_banner(text: String) -> void:
	banner = text
	banner_t = 0.0

func show_zone(text: String) -> void:
	zone_name = text
	zone_t = 0.0

func release_all() -> void:
	_stick_idx = -1
	_attack_idx = -1
	stick = Vector2.ZERO

# ---------- Layout ----------

func _buttons() -> Array:
	var w := size.x
	var h := size.y
	var out := [
		{"id": "attack", "p": Vector2(w - 86, h - 84), "r": 48.0, "c": H.FG},
		{"id": "dash", "p": Vector2(w - 192, h - 58), "r": 33.0, "c": H.CYAN},
		{"id": "skill1", "p": Vector2(w - 172, h - 158), "r": 31.0, "c": H.RED},
		{"id": "drink", "p": Vector2(w - 278, h - 46), "r": 25.0, "c": H.RED},
	]
	if PlayerStats.has_skill("blood_lance"):
		out.append({"id": "skill2", "p": Vector2(w - 78, h - 196), "r": 29.0, "c": H.RED})
	if PlayerStats.has_skill("eclipse"):
		out.append({"id": "skill3", "p": Vector2(w - 262, h - 128), "r": 28.0, "c": H.PURPLE})
	return out

func _menu_rect() -> Rect2:
	return Rect2(size.x - 112, 10, 100, 34)

func _quest_rect() -> Rect2:
	var hh := 110.0 if quest_open else 54.0
	return Rect2(size.x - 292, 50, 280, hh)

func _interact_rect() -> Rect2:
	return Rect2(size.x * 0.5 - 110, size.y - 78, 220, 50)

# ---------- Eingabe ----------

func _input(event: InputEvent) -> void:
	if title_mode or world == null or world.menu_open():
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		var p := e.position
		if e.pressed:
			if narrating():
				if narr_lock_t <= 0.0:
					_advance_narration()
				get_viewport().set_input_as_handled()
				return
			if world.input_locked():
				return
			if _menu_rect().grow(6).has_point(p):
				menu_pressed.emit()
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
			if p.x < size.x * 0.5 and _stick_idx < 0 and p.y > 90.0:
				_stick_idx = e.index
				_stick_origin = p
				stick = Vector2.ZERO
		else:
			if e.index == _stick_idx:
				_stick_idx = -1
				stick = Vector2.ZERO
			if e.index == _attack_idx:
				_attack_idx = -1
	elif event is InputEventScreenDrag:
		var e := event as InputEventScreenDrag
		if e.index == _stick_idx:
			var d := e.position - _stick_origin
			if d.length() > STICK_R:
				# Joystick wandert mit, wenn der Finger weiter zieht
				_stick_origin += d.normalized() * (d.length() - STICK_R)
				d = d.normalized() * STICK_R
			stick = d / STICK_R
	elif event is InputEventKey and event.pressed and not event.echo:
		if narrating():
			if event.physical_keycode in [KEY_SPACE, KEY_ENTER, KEY_E]:
				_advance_narration()
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
			KEY_I:
				_press("skill3")
			KEY_F:
				_press("drink")
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
		"skill1", "skill2", "skill3":
			p.skill(id)
		"drink":
			p.drink()

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
	return v.normalized() if v.length() > 0 else v

func move_input() -> Vector2:
	var k := keyboard_dir()
	return k if k.length() > 0.0 else stick

func _advance_narration() -> void:
	var cur: Dictionary = narr[narr_i]
	if narr_chars < String(cur.text).length():
		narr_chars = 9999.0
		return
	narr_i += 1
	narr_chars = 0.0
	narr_lock_t = 0.2
	world.sfx("tick")
	if narr_i >= narr.size():
		narr = []
		narr_i = 0
		narration_done.emit()

# ---------- Ablauf ----------

func _process(delta: float) -> void:
	var rd := delta / maxf(Engine.time_scale, 0.05)  # Echtzeit
	_t += rd
	narr_lock_t -= rd
	if narrating():
		narr_chars += rd * 55.0
	for m in msgs:
		m.t += rd
	msgs = msgs.filter(func(m): return m.t < m.life)
	for m in minis:
		m.t += rd
	minis = minis.filter(func(m): return m.t < 2.2)
	red_flash = max(0.0, red_flash - rd * 1.5)
	banner_t += rd
	zone_t += rd
	perfect_t -= rd
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

func _str_outline(pos: Vector2, text: String, fsize: int, color: Color, font: Font = H.F_BOLD, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	draw_string_outline(font, pos, text, align, width, fsize, 6, Color(0, 0, 0, color.a * 0.8))
	draw_string(font, pos, text, align, width, fsize, color)

func _panel(r: Rect2, border: Color, bg := H.PANEL) -> void:
	draw_rect(r, bg)
	draw_rect(r, border, false, 1.0)
	# Hologramm-Ecken
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
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(frac, 0.0, 1.0), r.size.y * 0.35)), Color(1, 1, 1, 0.18))
	if segments > 0:
		for i in range(1, segments):
			var x := r.position.x + r.size.x * i / segments
			draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Color(0, 0, 0, 0.5), 1.0)

func _draw() -> void:
	if world == null:
		return
	if not title_mode:
		_draw_vignettes()
		_draw_enemy_bars()
		_draw_stats()
		_draw_quest()
		_draw_controls()
		_draw_boss()
	_draw_msgs()
	_draw_banner()
	_draw_narration()
	if death_t >= 0.0:
		var a := clampf(death_t * 1.2, 0.0, 0.85)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.12, 0.0, 0.02, a))
		_str_outline(Vector2(0, size.y * 0.45), "WIRT KRITISCH", 34, Color(H.RED, clampf(death_t * 2.0, 0, 1)), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)
		_str(Vector2(0, size.y * 0.45 + 30), "Das Sanguine-Protokoll stabilisiert deinen Körper am Relikt …", 15, Color(H.FG, clampf(death_t - 0.6, 0, 1)), H.F_REG, HORIZONTAL_ALIGNMENT_CENTER, size.x)

func _draw_vignettes() -> void:
	var s := PlayerStats.s
	var low := 0.0
	var blood_frac := float(s.blood) / PlayerStats.max_blood()
	if blood_frac < 0.2:
		low = (0.2 - blood_frac) / 0.2 * (0.55 + 0.45 * sin(_t * 6.0))
	var hp_frac := float(s.hp) / PlayerStats.max_hp()
	if hp_frac < 0.3:
		low = max(low, (0.3 - hp_frac) / 0.3 * (0.6 + 0.4 * sin(_t * 8.0)))
	low = max(low, red_flash)
	if low > 0.01:
		var w := size.x
		var h := size.y
		var e := 90.0
		var c0 := Color(0.8, 0.0, 0.05, 0.55 * low)
		var c1 := Color(0.8, 0.0, 0.05, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w - e, e), Vector2(e, e)]), PackedColorArray([c0, c0, c1, c1]))
		draw_polygon(PackedVector2Array([Vector2(0, h), Vector2(e, h - e), Vector2(w - e, h - e), Vector2(w, h)]), PackedColorArray([c0, c1, c1, c0]))
		draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(e, e), Vector2(e, h - e), Vector2(0, h)]), PackedColorArray([c0, c1, c1, c0]))
		draw_polygon(PackedVector2Array([Vector2(w, 0), Vector2(w, h), Vector2(w - e, h - e), Vector2(w - e, e)]), PackedColorArray([c0, c0, c1, c1]))
	if world.eclipse_active():
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.02, 0.15, 0.35))
		draw_arc(size * 0.5, size.y * 0.62, 0, TAU, 64, Color(H.RED, 0.35), 3.0, true)
		draw_arc(size * 0.5, size.y * 0.58, 0, TAU, 64, Color(H.CYAN, 0.2), 1.5, true)
	if perfect_t > 0.0:
		var a := clampf(perfect_t * 2.0, 0.0, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.5, 0.8, 0.12 * a))
		_str_outline(Vector2(0, size.y * 0.32), "PERFEKTER DASH", 26, Color(H.CYAN, a), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)

func _draw_stats() -> void:
	var s := PlayerStats.s
	var x0 := 14.0
	var y0 := 12.0
	_panel(Rect2(x0, y0, 268, 84), H.CYAN_DIM)
	# Level-Abzeichen (Sechseck)
	var c := Vector2(x0 + 30, y0 + 32)
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0 + PI / 6.0
		pts.append(c + Vector2(cos(a), sin(a)) * 21.0)
	draw_colored_polygon(pts, Color(1.0, 0.16, 0.26, 0.18))
	pts.append(pts[0])
	draw_polyline(pts, H.RED, 2.0, true)
	_str(c + Vector2(-20, -5), "LV", 10, H.MUTED, H.F_SEMI, HORIZONTAL_ALIGNMENT_CENTER, 40)
	_str(c + Vector2(-20, 13), str(int(s.level)), 18, H.FG, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 40)
	# EXP-Ring unter dem Abzeichen
	var xp_frac := float(s.xp) / PlayerStats.xp_to_next()
	draw_rect(Rect2(x0 + 9, y0 + 60, 42, 3), Color(1, 1, 1, 0.08))
	draw_rect(Rect2(x0 + 9, y0 + 60, 42 * xp_frac, 3), H.CYAN)
	var bx := x0 + 62
	_str(Vector2(bx, y0 + 15), "KADETT-SUBJEKT 0", 11, H.CYAN, H.F_SEMI)
	_str(Vector2(bx + 120, y0 + 15), PlayerStats.clock_text(), 11, H.MUTED, H.F_MONO, HORIZONTAL_ALIGNMENT_RIGHT, 74)
	# HP
	var hp_frac := float(s.hp) / PlayerStats.max_hp()
	_str(Vector2(bx, y0 + 31), "HP", 10, H.MUTED)
	_bar(Rect2(bx + 22, y0 + 23, 172, 9), hp_frac, Color(0.85, 0.95, 1.0) if hp_frac > 0.3 else Color(1.0, 0.55, 0.4), Color(1, 1, 1, 0.08), 10)
	_str(Vector2(bx + 22, y0 + 44), "%d / %d" % [int(s.hp), int(PlayerStats.max_hp())], 10, H.MUTED, H.F_MONO)
	# Blut – pulsiert
	var bf := float(s.blood) / PlayerStats.max_blood()
	var pulse := 0.75 + 0.25 * sin(_t * (3.0 if bf > 0.2 else 9.0))
	_draw_drop(Vector2(bx + 6, y0 + 60), 6.0, Color(H.RED, pulse))
	var br := Rect2(bx + 22, y0 + 53, 172, 11)
	_bar(br, bf, Color(H.RED.r, H.RED.g, H.RED.b, pulse), Color(0.4, 0.0, 0.05, 0.35))
	if bf > 0.0:
		draw_rect(Rect2(br.position + Vector2(br.size.x * bf - 2, -2), Vector2(3, br.size.y + 4)), Color(1, 0.6, 0.6, pulse))
	_str(Vector2(bx + 22, y0 + 76), "BLUT %d%%" % int(bf * 100.0), 10, Color(1.0, 0.45, 0.5), H.F_SEMI)
	if not PlayerStats.s.awakened:
		_str(Vector2(bx + 80, y0 + 76), "– inaktiv", 10, H.MUTED, H.F_REG)
	# Buffs & Zustände
	var chips: Array = []
	if PlayerStats.buffs.has("karkosa"):
		chips.append(["CHITIN %ds" % int(PlayerStats.buffs.karkosa), H.TEAL])
	if PlayerStats.buffs.has("mutant"):
		chips.append(["SCHATTEN %ds" % int(PlayerStats.buffs.mutant), H.PURPLE])
	if PlayerStats.starving():
		chips.append(["BLUTMANGEL", H.RED])
	if PlayerStats.penalty_active():
		chips.append(["QUARANTÄNE", Color(1.0, 0.6, 0.2)])
	if int(s.attr_points) > 0 or int(s.skill_points) > 0:
		chips.append(["PUNKTE FREI", H.GOLD])
	var cx := x0
	var cy := y0 + 92
	for ch in chips:
		var tw := H.F_SEMI.get_string_size(ch[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 14
		draw_rect(Rect2(cx, cy, tw, 17), Color(ch[1], 0.14))
		draw_rect(Rect2(cx, cy, tw, 17), Color(ch[1], 0.6), false, 1.0)
		_str(Vector2(cx + 7, cy + 12.5), ch[0], 10, ch[1])
		cx += tw + 6
	# Verdacht
	var sus := float(s.suspicion)
	if sus > 0.5:
		var sy := cy + (24 if chips.size() > 0 else 0)
		var sc := Color(1.0, 0.7, 0.2) if sus < 80 else Color(1.0, 0.3, 0.2, 0.6 + 0.4 * sin(_t * 8.0))
		_draw_eye(Vector2(x0 + 10, sy + 8), sc)
		_bar(Rect2(x0 + 24, sy + 4, 90, 6), sus / 100.0, sc)
		_str(Vector2(x0 + 120, sy + 11), "VERDACHT %d%%" % int(sus), 10, sc)
	# kleine Meldungen
	var my := 200.0
	for m in minis:
		var a := clampf(2.2 - float(m.t), 0.0, 1.0)
		_str(Vector2(x0, my), m.text, 12, Color(H.FG, a * 0.9), H.F_SEMI)
		my += 16

func _draw_drop(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(_drop_points(c, r), col)

func _drop_points(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(c + Vector2(0, -r * 1.9))
	for i in 13:
		var a := -PI * 0.15 + (PI * 1.3) * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	return pts

func _draw_eye(c: Vector2, col: Color) -> void:
	draw_arc(c + Vector2(0, 5), 8.0, PI + 0.5, TAU - 0.5, 10, col, 1.5, true)
	draw_arc(c + Vector2(0, -5), 8.0, 0.5, PI - 0.5, 10, col, 1.5, true)
	draw_circle(c, 2.5, col)

func _draw_quest() -> void:
	var mr := _menu_rect()
	_panel(mr, H.CYAN)
	var pts_free := int(PlayerStats.s.attr_points) + int(PlayerStats.s.skill_points) > 0
	_str(mr.position + Vector2(0, 22), "SYSTEM", 14, H.CYAN, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, mr.size.x)
	if pts_free:
		draw_circle(mr.position + Vector2(mr.size.x - 6, 6), 5.0, Color(H.GOLD, 0.7 + 0.3 * sin(_t * 6.0)))
	var r := _quest_rect()
	_panel(r, H.CYAN_DIM, Color(0.02, 0.04, 0.07, 0.7))
	_str(r.position + Vector2(10, 16), "HAUPTQUEST", 10, H.CYAN)
	var d := 0
	if PlayerStats.s.daily.has("quests"):
		for q in PlayerStats.s.daily.quests:
			if q.done:
				d += 1
	_str(r.position + Vector2(10, 16), "TÄGLICH %d/3   %s" % [d, "▴" if quest_open else "▾"], 10, H.MUTED, H.F_SEMI, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 20)
	_str(r.position + Vector2(10, 36), PlayerStats.story_title(), 15, H.FG, H.F_BOLD)
	var txt := PlayerStats.story_text()
	if quest_open:
		_wrap_text(Rect2(r.position + Vector2(10, 44), Vector2(r.size.x - 20, 60)), txt, 12, H.MUTED)
	else:
		_str(r.position + Vector2(10, 50), _clip(txt, 12, r.size.x - 20), 12, H.MUTED, H.F_REG)

func _clip(text: String, fs: int, w: float) -> String:
	if H.F_REG.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= w:
		return text
	var t := text
	while t.length() > 3 and H.F_REG.get_string_size(t + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
		t = t.substr(0, t.length() - 1)
	return t + "…"

func _wrap_text(r: Rect2, text: String, fs: int, col: Color, font: Font = H.F_REG, line_h := 16.0, max_chars := -1) -> void:
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

func _draw_controls() -> void:
	var p: Player = world.player
	if world.input_locked() or narrating():
		return
	# Joystick
	if _stick_idx >= 0:
		draw_circle(_stick_origin, STICK_R + 8, Color(H.CYAN, 0.06))
		draw_arc(_stick_origin, STICK_R + 8, 0, TAU, 40, Color(H.CYAN, 0.45), 1.5, true)
		draw_circle(_stick_origin + stick * STICK_R, 24, Color(H.CYAN, 0.35))
		draw_arc(_stick_origin + stick * STICK_R, 24, 0, TAU, 24, H.CYAN, 2.0, true)
	else:
		var hc := Vector2(118, size.y - 100)
		draw_arc(hc, STICK_R + 8, 0, TAU, 40, Color(H.CYAN, 0.16), 1.5, true)
		draw_circle(hc, 18, Color(H.CYAN, 0.08))
	# Aktionsknöpfe
	for b in _buttons():
		var id: String = b.id
		var c: Vector2 = b.p
		var r: float = b.r
		var col: Color = b.c
		var cdv := 0.0
		var cdm := 1.0
		if p.cds.has(id):
			cdv = p.cds[id]
			cdm = max(0.01, p.cd_max[id] * (PlayerStats.cooldown_mult() if id in ["dash", "skill1", "skill2"] else 1.0))
		var pressed := _t - float(_press_fx.get(id, -9.0)) < 0.12
		var rr := r * (0.92 if pressed else 1.0)
		draw_circle(c, rr, Color(0.02, 0.04, 0.07, 0.62))
		draw_arc(c, rr, 0, TAU, 40, Color(col, 0.85), 2.0, true)
		draw_arc(c, rr - 5, 0, TAU, 40, Color(col, 0.18), 1.0, true)
		if cdv > 0.0:
			var frac := cdv / cdm
			draw_arc(c, rr - 3, -PI * 0.5, -PI * 0.5 + TAU * frac, 36, Color(0, 0, 0, 0.65), rr * 0.55, false)
			_str(c + Vector2(-20, 6), "%.1f" % cdv if cdv < 10 else str(int(cdv)), 14, H.FG, H.F_MONO, HORIZONTAL_ALIGNMENT_CENTER, 40)
		else:
			_icon(id, c, rr, col)
		if id == "drink":
			var n := PlayerStats.capsule_count()
			draw_circle(c + Vector2(r * 0.72, -r * 0.72), 10, Color(0.6, 0.0, 0.08) if n > 0 else Color(0.2, 0.2, 0.24))
			_str(c + Vector2(r * 0.72 - 10, -r * 0.72 + 4.5), str(n), 11, H.FG, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 20)
		if id == "skill1" or id == "skill2" or id == "skill3":
			var cost := {"skill1": 12, "skill2": 18, "skill3": 35}[id] as int
			var ok := float(PlayerStats.s.blood) >= cost
			_str(c + Vector2(-20, r + 13), str(cost), 10, H.RED if ok else H.MUTED, H.F_MONO, HORIZONTAL_ALIGNMENT_CENTER, 40)
	# Interaktion
	if interact_text != "":
		var ir := _interact_rect()
		var a := 0.75 + 0.25 * sin(_t * 4.0)
		_panel(ir, Color(H.RED, a), Color(0.1, 0.0, 0.03, 0.75))
		_str(ir.position + Vector2(0, 31), interact_text, 16, Color(1.0, 0.6, 0.65), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, ir.size.x)

func _icon(id: String, c: Vector2, r: float, col: Color) -> void:
	var s := r * 0.42
	match id:
		"attack":
			# gekreuzte Klinge
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 4.0, true)
			draw_line(c + Vector2(-s * 0.55, s * 0.05), c + Vector2(-s * 0.05, s * 0.55), col, 3.0, true)
			draw_line(c + Vector2(s * 0.6, -s), c + Vector2(s, -s * 0.6), Color(H.RED, 1.0), 3.0, true)
		"dash":
			for i in 2:
				var o := Vector2(-s * 0.5 + i * s * 0.7, 0)
				draw_polyline(PackedVector2Array([c + o + Vector2(-s * 0.35, -s * 0.6), c + o + Vector2(s * 0.3, 0), c + o + Vector2(-s * 0.35, s * 0.6)]), col, 3.5, true)
		"skill1":
			draw_arc(c, s * 1.05, -PI * 0.9, PI * 0.6, 20, col, 3.5, true)
			draw_arc(c, s * 0.6, PI * 0.1, PI * 1.6, 16, Color(col, 0.6), 2.5, true)
		"skill2":
			draw_line(c + Vector2(-s, s), c + Vector2(s, -s), col, 3.5, true)
			draw_colored_polygon(PackedVector2Array([c + Vector2(s * 1.15, -s * 1.15), c + Vector2(s * 0.25, -s * 0.85), c + Vector2(s * 0.85, -s * 0.25)]), col)
		"skill3":
			draw_circle(c, s * 0.95, Color(col, 0.9))
			draw_circle(c + Vector2(s * 0.35, -s * 0.2), s * 0.85, Color(0.02, 0.04, 0.07, 1.0))
			draw_arc(c, s * 1.25, 0, TAU, 24, Color(H.RED, 0.8), 1.5, true)
		"drink":
			draw_colored_polygon(_drop_points(c + Vector2(0, s * 0.25), s * 0.75), col)

func _draw_enemy_bars() -> void:
	var cam: Camera3D = world.camera
	if cam == null:
		return
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en.state == "dead" or en.is_boss() or not en.aggro:
			continue
		if en.hp >= en.max_hp and en.last_hit_t > 3.0:
			continue
		var wp := en.global_position + Vector3(0, 2.1, 0)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var w := 46.0
		var r := Rect2(sp - Vector2(w * 0.5, 0), Vector2(w, 5))
		draw_rect(r.grow(1), Color(0, 0, 0, 0.6))
		_bar(r, en.hp / en.max_hp, Color(1.0, 0.3, 0.3) if en.kind != "cadet" else Color(0.5, 0.75, 1.0), Color(0.3, 0.05, 0.05, 0.6))
		if en.state == "windup":
			_str_outline(sp + Vector2(-10, -6), "!", 18, H.RED, H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, 20)

func _draw_boss() -> void:
	var boss: Enemy = world.active_boss()
	if boss == null or narrating():
		return
	var w := minf(420.0, size.x * 0.44)
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y - 26, w, 9)
	_str_outline(Vector2(r.position.x, r.position.y - 6), boss.display_name().to_upper(), 13, Color(1.0, 0.75, 0.4), H.F_BOLD)
	_str(Vector2(r.position.x, r.position.y - 6), "LV %d" % int(round((boss.level_mult - 1.0) / 0.12 + 1)), 11, H.MUTED, H.F_MONO, HORIZONTAL_ALIGNMENT_RIGHT, w)
	draw_rect(r.grow(2), Color(0, 0, 0, 0.7))
	_bar(r, boss.hp / boss.max_hp, Color(1.0, 0.25, 0.25), Color(0.3, 0.05, 0.05, 0.6), 10)

func _msg_color(kind: String) -> Color:
	match kind:
		"blood":
			return H.RED
		"warn":
			return Color(1.0, 0.45, 0.25)
		"reward":
			return H.GOLD
		"level":
			return H.GOLD
		"quest":
			return H.CYAN
	return H.CYAN

func _draw_msgs() -> void:
	var y := 12.0
	var w := clampf(size.x - 620.0, 340.0, 470.0)
	var x := size.x * 0.5 - w * 0.5
	for m in msgs:
		var t: float = m.t
		var life: float = m.life
		var a := clampf(t * 5.0, 0.0, 1.0) * clampf((life - t) * 2.5, 0.0, 1.0)
		var slide := (1.0 - clampf(t * 5.0, 0.0, 1.0)) * 12.0
		var col := _msg_color(m.kind)
		var big: bool = m.kind == "level"
		var h := 48.0 if big else 41.0
		var r := Rect2(x, y - slide, w, h)
		_panel(r, Color(col, 0.7 * a), Color(0.01, 0.03, 0.06, 0.82 * a))
		# Scanline-Schimmer
		var sl := fmod(t * 120.0, r.size.y)
		draw_line(Vector2(r.position.x, r.position.y + sl), Vector2(r.end.x, r.position.y + sl), Color(col, 0.12 * a), 1.0)
		var head := "[ SYSTEM ]"
		match m.kind:
			"blood":
				head = "[ SANGUINE ]"
			"warn":
				head = "[ WARNUNG ]"
			"quest":
				head = "[ QUEST ]"
			"reward":
				head = "[ BELOHNUNG ]"
			"level":
				head = "[ EVOLUTION ]"
		_str(r.position + Vector2(10, 15), head, 10, Color(col, a), H.F_SEMI)
		_str(r.position + Vector2(10, 32 if not big else 38), _clip(m.text, 13 if not big else 16, w - 20), 13 if not big else 16, Color(H.FG, a), H.F_BOLD if big else H.F_SEMI)
		y += h + 5

func _draw_banner() -> void:
	if banner != "" and banner_t < 4.0:
		var a := clampf(banner_t * 2.0, 0.0, 1.0) * clampf((4.0 - banner_t) * 1.5, 0.0, 1.0)
		var yb := size.y * 0.6
		draw_rect(Rect2(0, yb - 34, size.x, 56), Color(0.0, 0.0, 0.02, 0.6 * a))
		draw_line(Vector2(size.x * 0.2, yb - 34), Vector2(size.x * 0.8, yb - 34), Color(H.RED, a), 1.0)
		draw_line(Vector2(size.x * 0.2, yb + 22), Vector2(size.x * 0.8, yb + 22), Color(H.CYAN, a), 1.0)
		_str_outline(Vector2(0, yb + 4), banner, 28, Color(H.FG, a), H.F_BOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x)
	if zone_name != "" and zone_t < 3.0 and not title_mode and not narrating():
		var a2 := clampf(zone_t * 3.0, 0.0, 1.0) * clampf((3.0 - zone_t) * 1.5, 0.0, 1.0)
		_str_outline(Vector2(0, size.y - 104), zone_name.to_upper(), 13, Color(H.CYAN, a2 * 0.9), H.F_SEMI, HORIZONTAL_ALIGNMENT_CENTER, size.x)

func _draw_narration() -> void:
	if not narrating():
		return
	var cur: Dictionary = narr[narr_i]
	var w := minf(640.0, size.x * 0.72)
	var r := Rect2(size.x * 0.5 - w * 0.5, size.y - 128, w, 104)
	var who: String = cur.get("who", "")
	var sys := who == "SYSTEM" or who == "PROTOKOLL"
	var col := H.CYAN if sys else (H.RED if who == "" else H.GOLD)
	_panel(r, Color(col, 0.75), Color(0.01, 0.02, 0.04, 0.9))
	if who != "":
		_str(r.position + Vector2(14, 20), "[ %s ]" % who if sys else who.to_upper(), 12, col, H.F_SEMI)
	var fnt: Font = H.F_SEMI if sys else H.F_REG
	_wrap_text(Rect2(r.position + Vector2(14, 28 if who != "" else 12), Vector2(w - 28, 70)), String(cur.text), 16, H.FG, fnt, 21.0, int(narr_chars))
	if narr_chars >= String(cur.text).length():
		_str(r.end + Vector2(-90, -10), "TIPPEN ▸", 10, Color(col, 0.5 + 0.5 * sin(_t * 5.0)), H.F_SEMI)
