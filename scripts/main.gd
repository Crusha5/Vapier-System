extends Node3D
## Spielablauf: Titel, Intro, Erwachen, Story-Regie (Kapitel 1), Gegner-Spawns, Kamera, Effekte.
## Stellt die „world“-Schnittstelle für Spieler und Gegner bereit.

const H := preload("res://scripts/ui/holo_ui.gd")

var academy: Academy
var player: Player
var camera: Camera3D
var hud: Hud
var menu: SystemWindow
var title: Control
var audio: Sfx
var state := "title"   # title, play, cutscene, dead
var _eclipse_t := 0.0
var _slow_until := 0
var _slow_scale := 1.0
var _hitstop_until := 0
var _shake := 0.0
var _cam_focus := Vector3.ZERO
var _cam_dist := 1.0
var _cut_focus := Vector3.ZERO
var capsules: Array = []
var spits: Array = []
var fx: Array = []
var wave_spawned := 0
var drax: Enemy
var nest: Enemy
var instructor: Enemy
var ambient: Array = []
var ambient_t := 0.0
var hall_greeted := false
var last_zone := ""
var death_t := -1.0
var interact_id := ""
var _title_t := 0.0
var _after_narration: Callable
var _arc_mesh: ArrayMesh
var _ring_mesh: ArrayMesh
var _ribbon_red: ShaderMaterial
var _ribbon_dark: ShaderMaterial
var autotest := false
const SESSION_PATH := "user://session.json"
var _session_t := 0.0
var _session_last := 0.0
var _prev_session := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	autotest = (OS.get_environment("SP_AUTOTEST") == "1" or get_parent() != get_tree().root) and OS.get_environment("SP_TITLE") != "1"
	audio = Sfx.new()
	add_child(audio)
	academy = Academy.new()
	add_child(academy)
	player = Player.new()
	player.world = self
	add_child(player)
	player.global_position = Academy.PLAYER_START if not PlayerStats.s.awakened else Academy.RESPAWN
	camera = Camera3D.new()
	camera.fov = 46.0
	camera.near = 0.3
	camera.far = 120.0
	add_child(camera)
	camera.make_current()
	_cam_focus = player.global_position
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var ui_root := Control.new()
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	hud = Hud.new()
	hud.world = self
	ui_root.add_child(hud)
	hud.menu_pressed.connect(toggle_menu)
	hud.interact_pressed.connect(_interact)
	hud.narration_done.connect(_on_narration_done)
	menu = SystemWindow.new()
	menu.world = self
	menu.visible = false
	ui_root.add_child(menu)
	menu.closed.connect(toggle_menu)
	_build_fx_assets()
	PlayerStats.player_died.connect(_on_player_died)
	PlayerStats.suspicion_alarm.connect(_spawn_instructor)
	PlayerStats.quests_changed.connect(_sync_story)
	PlayerStats.leveled_up.connect(func(_l):
		burst(player.global_position + Vector3(0, 1.0, 0), H.GOLD, 2.0)
		hud.show_banner("STUFE %d" % _l))
	_prev_session = _read_session()
	_write_session(false)
	if autotest:
		state = "play"
		hud.title_mode = false
		_sync_story()
	else:
		_build_title()

# ---------- Titel ----------

func _build_title() -> void:
	state = "title"
	hud.title_mode = true
	title = Control.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.theme = H.make_theme()
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.get_parent().add_child(title)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.02, 0.62)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(bg)
	var box := H.hbox(28)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	title.add_child(box)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.png")
	icon.custom_minimum_size = Vector2(190, 190)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var v := H.vbox(5)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(v)
	v.add_child(H.caps("Vanguard-Akademie · Jahr 2185", H.CYAN, 12))
	var t1 := H.lbl("SANGUINE", 38, H.FG, H.F_BOLD)
	t1.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.05))
	t1.add_theme_constant_override("outline_size", 8)
	v.add_child(t1)
	var t2 := H.lbl("PROTOCOL", 38, H.RED, H.F_BOLD)
	v.add_child(t2)
	v.add_child(H.lbl("Kapitel 1 · Erwachen", 15, H.MUTED, H.F_SEMI))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 4)
	v.add_child(sp)
	var has_save: bool = PlayerStats.s.awakened or int(PlayerStats.s.story) > 0
	if has_save:
		var b1 := H.btn("Weiter  ·  Stufe %d" % int(PlayerStats.s.level), func(): _start_game(false), "BtnRed")
		b1.custom_minimum_size = Vector2(260, 46)
		v.add_child(b1)
	var b2 := H.btn("Neues Spiel", func(): _confirm_new(has_save), "" if has_save else "BtnRed")
	b2.custom_minimum_size = Vector2(260, 44)
	v.add_child(b2)
	v.add_child(H.lbl("v0.1.2 · Prototyp", 10, Color(H.MUTED, 0.6), H.F_MONO))
	if not _prev_session.is_empty() and not _prev_session.get("clean", true):
		var info := H.wrap("Letzte Sitzung wurde unerwartet beendet nach %d s (%s, Story %d)." % [int(_prev_session.get("uptime", 0)), _prev_session.get("state", "?"), int(_prev_session.get("story", 0))], 11, H.RED)
		info.custom_minimum_size = Vector2(260, 0)
		v.add_child(info)
		var rb := H.btn("Fehlerbericht kopieren", func(): _copy_report(), "BtnRed")
		rb.custom_minimum_size = Vector2(260, 36)
		v.add_child(rb)

var _new_armed := false
func _confirm_new(has_save: bool) -> void:
	if has_save and not _new_armed:
		_new_armed = true
		PlayerStats.system_message.emit("Spielstand wird überschrieben – zum Bestätigen erneut tippen.", "warn")
		return
	PlayerStats.reset_game()
	PlayerStats.save_game()
	_start_game(true)

func _start_game(fresh: bool) -> void:
	if title:
		title.queue_free()
		title = null
	hud.title_mode = false
	audio.start_ambient()
	audio.play("boom", -6.0)
	player.refresh_awakening()
	if fresh or not PlayerStats.s.awakened:
		player.revive(Academy.PLAYER_START)
		player.facing = (Academy.RELIC_POS - Academy.PLAYER_START).normalized()
		state = "cutscene"
		hud.narrate([
			{"who": "", "text": "Jahr 2185. Die Menschheit führt einen Vernichtungskrieg gegen die Karkosa – eine insektoide, hochentwickelte Alien-Rasse."},
			{"who": "", "text": "An der Vanguard-Akademie werden genetisch veredelte Kadetten zu Supersoldaten geformt."},
			{"who": "", "text": "Du bist Kadett-Subjekt 0. Keine Gen-Anpassungen. Kein Rang. Kein Schutz."},
			{"who": "", "text": "Auf der Flucht vor Drax und seiner Bande hast du dich in die Ruinen des alten Archivs gerettet. Etwas pulsiert dort im Dunkeln …"},
		])
		_after_narration = func():
			state = "play"
			PlayerStats.system_message.emit("Hauptquest: Untersuche das Relikt im Archiv.", "quest")
	else:
		player.revive(Academy.RESPAWN)
		state = "play"
		_sync_story()
		hud.show_zone(Academy.ZONE_NAMES.archive)

# ---------- Welt-Schnittstelle ----------

func input_locked() -> bool:
	return state != "play" or hud.narrating()

func menu_open() -> bool:
	return menu.visible

func player_dead() -> bool:
	return player.dead

func eclipse_active() -> bool:
	return _eclipse_t > 0.0

func start_eclipse(d: float) -> void:
	_eclipse_t = d
	audio.play("awaken", -4.0, 0.0)
	hud.show_banner("ECLIPSE")
	burst(player.global_position + Vector3(0, 1, 0), H.PURPLE, 3.0)

func sfx(name: String) -> void:
	var vol := {"step": -14.0, "swing": -6.0, "tick": -8.0, "hit": -3.0}.get(name, -4.0) as float
	audio.play(name, vol)

func shake(a: float) -> void:
	_shake = max(_shake, a)

func hitstop(t: float) -> void:
	_hitstop_until = Time.get_ticks_msec() + int(t * 1000.0)

func perfect_dash() -> void:
	_slow_until = Time.get_ticks_msec() + 650
	_slow_scale = 0.3
	hud.perfect_t = 0.9
	audio.play("perfect", -2.0, 0.0)

func active_boss() -> Enemy:
	for b in [instructor, drax, nest]:
		if b != null and is_instance_valid(b) and b.state != "dead" and b.aggro and b.global_position.distance_to(player.global_position) < 26.0:
			return b
	return null

func spawn_enemy(kind: String, pos: Vector3, lvl := -1) -> Enemy:
	if lvl < 0:
		lvl = max(1, int(PlayerStats.s.level) + randi_range(-1, 1))
	var e := Enemy.new()
	e.setup(kind, self, pos, lvl)
	add_child(e)
	e.rotation.y = randf() * TAU
	return e

func damage_number(pos: Vector3, amount: float, color: Color, crit: bool, text := "") -> void:
	var l := Label3D.new()
	l.text = text if text != "" else str(int(round(amount)))
	if crit and text == "":
		l.text += "!"
	l.font = H.F_BOLD
	l.font_size = 64 if crit else 48
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	l.render_priority = 10
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.2, 0.2))
	add_child(l)
	fx.append({"n": l, "t": 0.0, "life": 0.75, "kind": "num", "v": Vector3(0, 2.6, 0)})

func burst(pos: Vector3, color: Color, size := 1.0) -> void:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.09 * size
	p.mesh = m
	p.material_override = Toon.mat(color, {"emit": color, "energy": 2.5})
	p.amount = int(10 + 6 * size)
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0 * size
	p.initial_velocity_max = 5.5 * size
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.position = pos
	p.emitting = true
	add_child(p)
	fx.append({"n": p, "t": 0.0, "life": 1.0, "kind": "free"})

func afterimage(pos: Vector3, rot_y: float) -> void:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = 0.32
	c.height = 1.75
	c.radial_segments = 8
	c.rings = 2
	mi.mesh = c
	mi.material_override = Toon.holo(Color(0.75, 0.05, 0.2), 1.2, false, 0.5)
	mi.position = pos + Vector3(0, 0.9, 0)
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	fx.append({"n": mi, "t": 0.0, "life": 0.28, "kind": "fade"})

func shadow_echo(pos: Vector3) -> void:
	burst(pos + Vector3(0, 0.8, 0), Color(0.5, 0.2, 0.9), 1.6)
	fx.append({"n": null, "t": 0.0, "life": 0.18, "kind": "echo", "pos": pos})

func slash_fx(pos: Vector3, dir: Vector3, combo: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh if combo == 2 else _arc_mesh
	mi.material_override = _ribbon_red
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 1.0 if combo < 2 else 0.25, 0)
	mi.rotation.y = atan2(-dir.x, -dir.z)
	if combo == 1:
		mi.scale = Vector3(-1, 1, 1)
	add_child(mi)
	fx.append({"n": mi, "t": 0.0, "life": 0.2, "kind": "fade", "spin": 6.0 if combo == 0 else -6.0})

func scythe_fx(pos: Vector3) -> void:
	for k in 2:
		var mi := MeshInstance3D.new()
		mi.mesh = _ring_mesh
		mi.material_override = _ribbon_red if k == 0 else _ribbon_dark
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = pos + Vector3(0, 0.5 + k * 0.5, 0)
		mi.scale = Vector3.ONE * 0.4
		add_child(mi)
		fx.append({"n": mi, "t": 0.0, "life": 0.38, "kind": "grow", "to": 1.75 - k * 0.2, "spin": 14.0 * (1 if k == 0 else -1)})
	burst(pos + Vector3(0, 0.8, 0), Color(1.0, 0.1, 0.2), 1.4)

func lance_fx(pos: Vector3, dir: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.45, 0.25, 11.0)
	mi.mesh = b
	mi.material_override = Toon.holo(Color(1.0, 0.1, 0.2), 2.6, false, 0.3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 1.1, 0) + dir * 5.8
	mi.rotation.y = atan2(-dir.x, -dir.z)
	add_child(mi)
	fx.append({"n": mi, "t": 0.0, "life": 0.3, "kind": "fade"})
	burst(pos + Vector3(0, 1.1, 0) + dir * 11.0, Color(1.0, 0.2, 0.3), 1.2)

func spawn_capsule(kind: String, pos: Vector3) -> void:
	var n := Node3D.new()
	var c: Color = PlayerStats.BLOOD_TYPES[kind].color
	var glass := Toon.cyl(n, 0.14, 0.14, 0.42, Vector3.ZERO, Toon.mat(Color(0.75, 0.8, 0.9), {"outline": 0.02, "radial": 1.0, "rim": 0.6}), 8)
	glass.name = "Glass"
	Toon.cyl(n, 0.1, 0.1, 0.3, Vector3(0, 0.0, 0), Toon.mat(c, {"emit": c, "energy": 2.6}), 8)
	Toon.cyl(n, 0.16, 0.16, 0.06, Vector3(0, 0.23, 0), Toon.mat(Toon.METAL, {"outline": 0.02}), 8)
	Toon.cyl(n, 0.16, 0.16, 0.06, Vector3(0, -0.23, 0), Toon.mat(Toon.METAL, {"outline": 0.02}), 8)
	var ring := Toon.quad_holo(n, Vector2(1.2, 1.2), Vector3(0, -0.62, 0), Toon.holo(c, 1.2, true, 0.0))
	ring.name = "Ring"
	n.position = pos + Vector3(0, 0.7, 0)
	n.rotation.z = 0.35
	add_child(n)
	capsules.append({"n": n, "kind": kind, "t": 0.0, "base": pos})

func spawn_spit(from: Vector3, to: Vector3, dmg: float) -> void:
	var n := Node3D.new()
	Toon.sphere(n, 0.2, Vector3.ZERO, Toon.mat(Color(0.7, 0.3, 1.0), {"emit": Color(0.7, 0.3, 1.0), "energy": 3.0}), Vector3.ONE, 8)
	n.position = from
	add_child(n)
	var dir := (to - from)
	dir.y = 0
	spits.append({"n": n, "v": dir.normalized() * 11.0, "t": 0.0, "dmg": dmg})
	sfx("lance")

func spit_incoming(pos: Vector3) -> bool:
	for s in spits:
		var n: Node3D = s.n
		var d := pos - n.global_position
		d.y = 0
		if d.length() < 3.0 and d.dot(s.v) > 0.0:
			return true
	return false

# ---------- Effekt-Ressourcen ----------

func _build_fx_assets() -> void:
	_arc_mesh = _make_arc(1.1, 2.6, -1.25, 1.25, 18)
	_ring_mesh = _make_arc(1.3, 2.3, 0.0, TAU, 40)
	_ribbon_red = (Toon.holo(Color(1.0, 0.12, 0.22), 2.6, false, 0.0)).duplicate()
	_ribbon_red.set_shader_parameter("ribbon", 1.0)
	_ribbon_dark = (Toon.holo(Color(0.5, 0.1, 0.9), 1.8, false, 0.0)).duplicate()
	_ribbon_dark.set_shader_parameter("ribbon", 1.0)

func _make_arc(r0: float, r1: float, a0: float, a1: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var fa := float(i) / segs
		var fb := float(i + 1) / segs
		var aa := lerpf(a0, a1, fa)
		var ab := lerpf(a0, a1, fb)
		# Winkel 0 = vorne (−Z)
		var pa0 := Vector3(sin(aa) * r0, 0, -cos(aa) * r0)
		var pa1 := Vector3(sin(aa) * r1, 0, -cos(aa) * r1)
		var pb0 := Vector3(sin(ab) * r0, 0, -cos(ab) * r0)
		var pb1 := Vector3(sin(ab) * r1, 0, -cos(ab) * r1)
		for q in [[pa0, Vector2(fa, 0)], [pa1, Vector2(fa, 1)], [pb1, Vector2(fb, 1)], [pa0, Vector2(fa, 0)], [pb1, Vector2(fb, 1)], [pb0, Vector2(fb, 0)]]:
			st.set_uv(q[1])
			st.add_vertex(q[0])
	return st.commit()

# ---------- Menü ----------

func toggle_menu() -> void:
	if state == "title":
		return
	if menu.visible:
		menu.visible = false
		get_tree().paused = false
		PlayerStats.save_game()
	else:
		if hud.narrating() or state != "play":
			return
		hud.release_all()
		menu.open()
		get_tree().paused = true
	sfx("tick")

# ---------- Sitzungsprotokoll (für Absturzberichte) ----------

func _read_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH):
		return {}
	var f := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if typeof(d) == TYPE_DICTIONARY else {}

func _write_session(clean: bool) -> void:
	var f := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"clean": clean, "uptime": _session_t, "state": state, "story": int(PlayerStats.s.get("story", 0)),
		"fps": Engine.get_frames_per_second(), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"mem_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"enemies": get_tree().get_nodes_in_group("enemies").size() if is_inside_tree() else 0,
		"renderer": RenderingServer.get_current_rendering_method(), "gpu": RenderingServer.get_video_adapter_name(),
		"device": OS.get_model_name(), "os": OS.get_name() + " " + OS.get_version(),
	}))

func _copy_report() -> void:
	var txt := "Sanguine Protocol – Fehlerbericht\n" + JSON.stringify(_prev_session, "  ") + "\n\n"
	# vorheriges Godot-Log (das neueste außer dem aktuellen)
	var logs := DirAccess.get_files_at("user://logs")
	var files: Array = []
	for fn in logs:
		if fn.ends_with(".log") and fn != "godot.log":
			files.append(fn)
	files.sort()
	if files.size() > 0:
		var f := FileAccess.open("user://logs/" + String(files[-1]), FileAccess.READ)
		if f:
			var lines := f.get_as_text().split("\n")
			txt += "--- " + String(files[-1]) + " ---\n" + "\n".join(lines.slice(max(0, lines.size() - 60)))
	DisplayServer.clipboard_set(txt)
	PlayerStats.system_message.emit("Fehlerbericht kopiert – einfach im Chat einfügen.", "sys")

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write_session(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		_write_session(false)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if state == "play" or menu.visible:
			toggle_menu()

# ---------- Ablauf ----------

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	var ts := 1.0
	if now < _slow_until:
		ts = _slow_scale
	if death_t >= 0.0:
		ts = min(ts, 0.35)
	if now < _hitstop_until:
		ts = 0.06
	Engine.time_scale = ts
	var rd := delta / maxf(ts, 0.01)
	_session_t += rd
	if _session_t - _session_last > 2.0:
		_session_last = _session_t
		_write_session(false)
	if _eclipse_t > 0.0:
		_eclipse_t -= delta
	PlayerStats.paused_world = state != "play" or hud.narrating() or player.dead
	player.input_dir = hud.move_input() if not input_locked() else Vector2.ZERO
	if state == "title":
		_title_t += rd
		var a := _title_t * 0.15
		_cam_focus = Academy.RELIC_POS + Vector3(0, 1.0, 0)
		camera.global_position = _cam_focus + Vector3(sin(a) * 7.5, 3.4, cos(a) * 7.5)
		camera.look_at(_cam_focus, Vector3.UP)
	else:
		_update_camera(delta, rd)
	Toon.update_fade(player.global_position, camera.global_position)
	if state == "title":
		return
	_update_interact()
	_update_zone()
	_update_capsules(delta)
	_update_spits(delta)
	_update_fx(delta, rd)
	_director(delta)
	_check_midnight()
	if death_t >= 0.0:
		death_t += rd
		if death_t > 3.2:
			_respawn()

func _update_camera(delta: float, rd: float) -> void:
	var target := player.global_position + player.facing * 0.8
	var dist := 1.0
	if state == "cutscene":
		target = _cut_focus
		dist = 0.62
	_cam_focus = _cam_focus.lerp(target, clamp(rd * 5.0, 0.0, 1.0))
	_cam_dist = lerpf(_cam_dist, dist, clamp(rd * 2.0, 0.0, 1.0))
	var off := Vector3(0, 10.4, 7.3) * _cam_dist
	var sh := Vector3.ZERO
	if _shake > 0.0:
		sh = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.35
		_shake = max(0.0, _shake - rd * 2.5)
	camera.global_position = _cam_focus + off + sh
	camera.look_at(_cam_focus + Vector3(0, 0.6, 0) + sh * 0.5, Vector3.UP)

func _update_zone() -> void:
	var z := academy.zone_at(player.global_position)
	if z != "" and z != last_zone:
		last_zone = z
		hud.show_zone(Academy.ZONE_NAMES[z])
		if z == "hall" and int(PlayerStats.s.story) == 2 and not hall_greeted and drax and is_instance_valid(drax):
			hall_greeted = true
			drax.aggro = false
			_cutscene_at(drax.global_position, [
				{"who": "Drax", "text": "Sieh an – Subjekt Null kriecht aus den Ruinen. Du riechst nach Blut … ist das deins?"},
				{"who": "Drax", "text": "Heute bringen wir zu Ende, was wir im Archiv angefangen haben. Packt ihn!"},
				{"who": "SYSTEM", "text": "Menschliches Blut stellt am meisten her und gibt viel EXP. Es erhöht aber den Verdacht der Akademie."},
			], func():
				for e in get_tree().get_nodes_in_group("enemies"):
					if academy.zone_at((e as Node3D).global_position) == "hall":
						(e as Enemy).aggro = true)

func _update_interact() -> void:
	interact_id = ""
	hud.interact_text = ""
	if state != "play" or player.dead:
		return
	if player.global_position.distance_to(Academy.RELIC_POS) < 3.0:
		var st := int(PlayerStats.s.story)
		if st == 0:
			interact_id = "awaken"
			hud.interact_text = "RELIKT BERÜHREN"
		elif st == 4:
			interact_id = "relic_talk"
			hud.interact_text = "MIT DEM PROTOKOLL SPRECHEN"
		else:
			interact_id = "rest"
			hud.interact_text = "AM RELIKT RUHEN"

func _interact() -> void:
	match interact_id:
		"awaken":
			_awaken()
		"relic_talk":
			_cutscene_at(Academy.RELIC_POS, [
				{"who": "PROTOKOLL", "text": "Das Nest ist verbrannt. Gut. Die Karkosa haben dich gerochen, Wirt – so wie ich dich gerochen habe."},
				{"who": "PROTOKOLL", "text": "Ich wurde erschaffen, um gegen sie zu kämpfen. Von denen, die diese Akademie gegründet haben."},
				{"who": "PROTOKOLL", "text": "Sie haben mich begraben, als ihre Wirte zu hungrig wurden. Frag dich, warum – und wer sich noch erinnert."},
				{"who": "SYSTEM", "text": "Kapitel 1 abgeschlossen. Tägliche Quests, verborgene Quests und die Jagd gehen weiter."},
			], func():
				PlayerStats.set_story(5)
				hud.show_banner("KAPITEL 1 ABGESCHLOSSEN")
				audio.play("level", -2.0, 0.0))
		"rest":
			for e in get_tree().get_nodes_in_group("enemies"):
				var en := e as Enemy
				if en.aggro and en.state != "dead" and en.global_position.distance_to(player.global_position) < 14.0:
					PlayerStats.system_message.emit("Nicht möglich – Feinde in der Nähe.", "warn")
					return
			PlayerStats.heal(9999.0)
			PlayerStats.save_game()
			burst(player.global_position + Vector3(0, 1, 0), H.CYAN, 1.0)
			PlayerStats.system_message.emit("HP wiederhergestellt. Fortschritt gesichert. (Blut regeneriert sich nicht.)", "sys")

func _cutscene_at(focus: Vector3, lines: Array, after: Callable) -> void:
	state = "cutscene"
	_cut_focus = focus
	hud.narrate(lines)
	_after_narration = after

func _on_narration_done() -> void:
	if state == "cutscene":
		state = "play"
	if _after_narration.is_valid():
		var cb := _after_narration
		_after_narration = Callable()
		cb.call()

func _awaken() -> void:
	state = "cutscene"
	_cut_focus = Academy.RELIC_POS
	audio.play("awaken", 0.0, 0.0)
	shake(0.8)
	hud.red_flash = 1.0
	burst(Academy.RELIC_POS + Vector3(0, 1.5, 0), Toon.RED, 2.5)
	hud.narrate([
		{"who": "", "text": "Deine aufgeschürfte Hand streift die Dornen des Relikts. Ein Tropfen Blut fällt auf das pulsierende Herz."},
		{"who": "SYSTEM", "text": "Blutsignatur erkannt … Wirt kompatibel."},
		{"who": "SYSTEM", "text": "Sanguine-Protokoll wird initialisiert … 12 % … 47 % … 100 %."},
		{"who": "PROTOKOLL", "text": "Willkommen, Wirt. Du warst schwach. Das endet jetzt."},
		{"who": "PROTOKOLL", "text": "Meine Bedingung: Deine Lebensenergie zehrt von Blut. Versiegt dein Blut, verzehrst du dich selbst."},
		{"who": "SYSTEM", "text": "Freigeschaltet: Schatten-Dash, Blutsichel, Status-Interface. Attribute: STR · AGI · END · SHD."},
	])
	_after_narration = func():
		PlayerStats.s.awakened = true
		PlayerStats.s.inventory.karkosa = int(PlayerStats.s.inventory.karkosa) + 1
		player.refresh_awakening()
		hud.show_banner("SANGUINE-PROTOKOLL AKTIV")
		audio.play("boom", 0.0, 0.0)
		burst(player.global_position + Vector3(0, 1, 0), Toon.RED, 2.0)
		PlayerStats.set_story(1)
		PlayerStats.system_message.emit("Startreserve: +1 Karkosa-Blut. Trinken mit dem Tropfen-Knopf.", "blood")
		PlayerStats.system_message.emit("Karkosa durchbrechen die Nordwand!", "warn")
		shake(0.6)

# ---------- Story-Regie ----------

func _sync_story() -> void:
	if state == "title":
		return
	var st := int(PlayerStats.s.story)
	if st >= 2 and (drax == null or not is_instance_valid(drax)) and st == 2:
		drax = spawn_enemy("drax", Academy.DRAX_POS, max(2, int(PlayerStats.s.level)))
		drax.rotation.y = PI * 0.5
		drax.died.connect(func(_e):
			PlayerStats.story_advance_progress(2)
			PlayerStats.system_message.emit("Drax liegt am Boden. Die Rangordnung hat sich verschoben.", "quest"))
		for p in [Academy.DRAX_POS + Vector3(-2.2, 0, 1.5), Academy.DRAX_POS + Vector3(2.2, 0, 1.5)]:
			spawn_enemy("cadet", p, max(1, int(PlayerStats.s.level) - 1))
	if st == 3 and (nest == null or not is_instance_valid(nest)):
		nest = spawn_enemy("nest", Academy.NEST_POS, max(2, int(PlayerStats.s.level)))
		nest.died.connect(func(_e):
			PlayerStats.story_advance_progress(3)
			shake(1.0)
			audio.play("boom", 0.0, 0.0)
			PlayerStats.system_message.emit("Das Nest ist zerstört. Kehre zum Relikt zurück.", "quest"))
		PlayerStats.system_message.emit("Ein Karkosa-Riss wurde im Ostflügel geortet.", "warn")

func _director(delta: float) -> void:
	if state != "play" or player.dead:
		return
	var st := int(PlayerStats.s.story)
	# Kapitel-1-Welle im Archiv
	if st == 1:
		var alive := 0
		for e in get_tree().get_nodes_in_group("enemies"):
			if (e as Enemy).has_meta("wave") and (e as Enemy).state != "dead":
				alive += 1
		var goal := 6
		var killed := int(PlayerStats.s.story_progress)
		if alive < 3 and killed + alive < goal:
			ambient_t -= delta
			if ambient_t <= 0.0:
				ambient_t = 1.2
				var sp: Vector3 = academy.spawns.breach[randi() % academy.spawns.breach.size()]
				var e := spawn_enemy("karkosa", sp + Vector3(randf_range(-0.5, 0.5), 0, 0), 1)
				e.set_meta("wave", true)
				e.aggro = true
				e.died.connect(func(_e): PlayerStats.story_advance_progress(1))
				burst(sp + Vector3(0, 0.8, 0), Color(0.6, 1.0, 0.2), 1.2)
				sfx("hit")
		return
	if st < 2:
		return
	# Umherstreifende Gegner
	ambient = ambient.filter(func(e): return is_instance_valid(e) and (e as Enemy).state != "dead")
	var target := mini(9, 4 + int(PlayerStats.s.level) / 3)
	ambient_t -= delta
	if ambient.size() < target and ambient_t <= 0.0:
		ambient_t = 3.0
		_spawn_ambient()

func _spawn_ambient() -> void:
	var h := PlayerStats.clock_hour()
	var night := h >= 22 or h < 5
	var options := []
	for zone in academy.spawns:
		if zone == "breach":
			continue
		for p in academy.spawns[zone]:
			var d: float = (p as Vector3).distance_to(player.global_position)
			if d > 13.0 and d < 48.0:
				options.append([zone, p])
	if options.is_empty():
		return
	var pick: Array = options[randi() % options.size()]
	var zone: String = pick[0]
	var kind := "karkosa"
	var r := randf()
	match zone:
		"archive":
			kind = "mutant" if (night and r < 0.6) or r < 0.25 else "karkosa"
		"corridor", "passage":
			kind = "mutant" if r < 0.45 else "karkosa"
		"hall":
			var cadets := 0
			for e in ambient:
				if (e as Enemy).kind == "cadet":
					cadets += 1
			kind = "cadet" if cadets < 2 and r < 0.7 else "karkosa"
		"eastwing":
			kind = "karkosa_elite" if r < 0.18 + int(PlayerStats.s.level) * 0.01 else ("mutant" if r < 0.45 else "karkosa")
	var e := spawn_enemy(kind, (pick[1] as Vector3) + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))
	ambient.append(e)

func _spawn_instructor() -> void:
	if instructor != null and is_instance_valid(instructor) and instructor.state != "dead":
		return
	var best := Vector3.ZERO
	var bd := 0.0
	for zone in ["hall", "corridor", "archive"]:
		for p in academy.spawns[zone]:
			var d: float = (p as Vector3).distance_to(player.global_position)
			if d > bd and d < 50.0:
				bd = d
				best = p
	instructor = spawn_enemy("instructor", best, int(PlayerStats.s.level) + 1)
	instructor.aggro = true
	instructor.died.connect(func(_e):
		PlayerStats.system_message.emit("Ausbilder Varek ist gefallen. Niemand darf je davon erfahren …", "warn")
		PlayerStats.add_suspicion(10.0))

func _check_midnight() -> void:
	if PlayerStats.s.hidden.midnight_vault or state != "play":
		return
	if PlayerStats.clock_hour() == 0 and player.global_position.distance_to(Academy.VAULT_SIGIL) < 2.4:
		PlayerStats.s.hidden.midnight_vault = true
		audio.play("awaken", 0.0, 0.0)
		hud.red_flash = 0.8
		_cutscene_at(Academy.VAULT_SIGIL, [
			{"who": "SYSTEM", "text": "VERBORGENE QUEST ENTDECKT: „Stunde Null“."},
			{"who": "PROTOKOLL", "text": "Hier ruhte mein erster Wirt. Er hat die Sonne verschlungen, bevor sie ihn verbrannten."},
			{"who": "PROTOKOLL", "text": "Nimm, was von ihm blieb."},
			{"who": "SYSTEM", "text": "Verborgener Skill erhalten: ECLIPSE. Permanenter Bonus: +2 SHD."},
		], func():
			PlayerStats.grant_skill("eclipse")
			PlayerStats.s.shd = int(PlayerStats.s.shd) + 2
			PlayerStats.add_xp(300)
			PlayerStats.system_message.emit("Verborgene Quest abgeschlossen: Stunde Null", "quest")
			hud.show_banner("ECLIPSE ERWACHT")
			PlayerStats.save_game())

# ---------- Tod & Wiederbelebung ----------

func _on_player_died() -> void:
	if player.dead:
		return
	player.die()
	death_t = 0.0
	hud.death_t = 0.0
	audio.play("boom", 0.0, 0.0)
	if menu.visible:
		toggle_menu()

func _respawn() -> void:
	death_t = -1.0
	hud.death_t = -1.0
	var s := PlayerStats.s
	s.xp = int(int(s.xp) * 0.8)
	s.hp = PlayerStats.max_hp()
	s.blood = max(float(s.blood), 45.0)
	player.revive(Academy.RESPAWN)
	_cam_focus = player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en.global_position.distance_to(Academy.RESPAWN) < 12.0 and not en.is_boss() and not en.has_meta("wave"):
			en.aggro = false
			en.global_position = en.home
	PlayerStats.system_message.emit("Wirt stabilisiert. −20 % EXP der aktuellen Stufe.", "sys")
	PlayerStats.stats_changed.emit()

# ---------- Kapseln, Geschosse, Effekte ----------

func _update_capsules(delta: float) -> void:
	var keep: Array = []
	for c in capsules:
		var n: Node3D = c.n
		c.t += delta
		var base: Vector3 = c.base
		n.rotation.y += delta * 2.0
		var target := base + Vector3(0, 0.7 + sin(c.t * 3.0) * 0.1, 0)
		var d := player.global_position.distance_to(n.global_position - Vector3(0, 0.7, 0))
		if PlayerStats.s.awakened and not player.dead and d < 3.4 and c.t > 0.35:
			c.base = base.lerp(player.global_position, clamp(delta * 8.0, 0.0, 1.0))
			target = c.base + Vector3(0, 0.9, 0)
		n.global_position = n.global_position.lerp(target, clamp(delta * 10.0, 0.0, 1.0))
		if d < 0.9 and PlayerStats.s.awakened and not player.dead:
			PlayerStats.pick_capsule(c.kind)
			sfx("tick")
			burst(n.global_position, PlayerStats.BLOOD_TYPES[c.kind].color, 0.6)
			n.queue_free()
			continue
		if c.t > 90.0:
			n.queue_free()
			continue
		keep.append(c)
	capsules = keep

func _update_spits(delta: float) -> void:
	var keep: Array = []
	var space := get_world_3d().direct_space_state
	for s in spits:
		var n: Node3D = s.n
		s.t += delta
		if eclipse_active():
			keep.append(s)
			continue
		var from := n.global_position
		var to: Vector3 = from + s.v * delta
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		var pd := player.global_position + Vector3(0, 1.0, 0) - to
		if pd.length() < 0.75 and not player.is_invulnerable():
			player.receive_hit(float(s.dmg), from)
			burst(to, Color(0.7, 0.3, 1.0), 0.7)
			n.queue_free()
			continue
		if not hit.is_empty() or s.t > 2.2:
			burst(to, Color(0.7, 0.3, 1.0), 0.5)
			n.queue_free()
			continue
		n.global_position = to
		keep.append(s)
	spits = keep

func _update_fx(delta: float, rd: float) -> void:
	var keep: Array = []
	for f in fx:
		f.t += rd if f.kind == "num" else delta
		var k: float = f.t / f.life
		var n = f.n
		match f.kind:
			"num":
				(n as Node3D).position += (f.v as Vector3) * rd * (1.0 - k)
				(n as Label3D).modulate.a = clampf(1.6 - k * 1.6, 0.0, 1.0)
			"fade":
				Toon.set_alpha(n, 1.0 - k)
				if f.has("spin"):
					(n as Node3D).rotation.y += float(f.spin) * delta * (1.0 - k)
			"grow":
				var s: float = lerpf(0.4, float(f.to), 1.0 - pow(1.0 - k, 3.0))
				(n as Node3D).scale = Vector3(s, 1, s)
				(n as Node3D).rotation.y += float(f.spin) * delta
				Toon.set_alpha(n, 1.0 - k * k)
			"echo":
				if k >= 1.0:
					var pos: Vector3 = f.pos
					for e in get_tree().get_nodes_in_group("enemies"):
						var en := e as Enemy
						if en.state != "dead" and en.global_position.distance_to(pos) < 2.8:
							en.take_hit(PlayerStats.shadow_damage() * 0.8, pos, 6.0, false, Color(0.75, 0.5, 1.0))
					burst(pos + Vector3(0, 0.8, 0), Color(0.5, 0.2, 0.9), 1.8)
		if k >= 1.0:
			if n != null and is_instance_valid(n):
				(n as Node).queue_free()
			continue
		keep.append(f)
	fx = keep
