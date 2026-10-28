extends Node
## Test der Erkundung (v0.7): Truhen aller Arten, Logbuch, Altar, Schatzkarte, Elite, Schmieden,
## Login-Serie, Schnellreise, Welt-Tab, optionale Trink-Quest, Inspektion.

var m: Node
var shots := ""

func _ready() -> void:
	shots = OS.get_environment("SHOT_DIR")
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	await _frames(10)
	var ps := PlayerStats
	ps.system_message.connect(func(t, k): print("MSG [", k, "] ", t))
	ps.s.started = true
	ps.s.minutes = 13.0 * 60.0
	var tr: Treasure = m.treasure
	print("TEST schaetze=", tr.objs.size(), " seiten=", tr.pages.size(), " altaere=", tr.altars.size(), " grabstellen=", tr.digs.size())
	var kinds := {}
	for o in tr.objs:
		kinds[o.kind] = int(kinds.get(o.kind, 0)) + 1
	print("TEST arten=", kinds)
	await _frames(40)
	# Login-Serie
	m._streak_t = 0.0
	m._director_t = 0.0
	await _frames(10)
	print("TEST serie=", ps.s.streak, " splitter=", ps.s.shards)
	# Jede Art einmal öffnen
	var done := {}
	for i in tr.objs.size():
		var o: Dictionary = tr.objs[i]
		if done.has(o.kind) and o.kind != "truhe":
			continue
		if done.has(o.kind) and int(done[o.kind]) >= 2:
			continue
		done[o.kind] = int(done.get(o.kind, 0)) + 1
		m.player.global_position = (o.pos as Vector3) + Vector3(0, 0, 1.3).rotated(Vector3.UP, float(o.rot)) + Vector3(0, 0.4, 0)
		m.player.velocity = Vector3.ZERO
		m.rig.yaw = float(o.rot)
		if o.kind == "versteckt":
			m.toggle_sense()
		await _frames(20)
		print("TEST bei ", o.id, " (", o.kind, ") interact=", m.interact_id, " text=", m.hud.interact_text, " warn=", m.hud.interact_warn)
		if o.kind == "truhe" and int(done[o.kind]) == 2:
			ps.s.picks = 0
			await _frames(3)
			print("TEST ohne dietrich: ", m.interact_id, " ", m.hud.interact_text)
			ps.s.str = 7
			await _frames(3)
		await _shot("t_%s_closed" % o.kind)
		m._interact()
		await _frames(50)
		await _shot("t_%s_open" % o.kind)
		if o.kind == "versteckt":
			m.toggle_sense()
		await _resolve([])
		print("TEST geoeffnet ", o.id, " state=", ps.chest_state(String(o.id)), " splitter=", ps.s.shards, " kristalle=", ps.s.crystals, " beute_am_boden=", m.loot.size())
	# Grabwächter?
	var ghouls := 0
	for e in get_tree().get_nodes_in_group("hostile"):
		if e is Enemy and e.type == "ghoul":
			ghouls += 1
	print("TEST grabwaechter=", ghouls)
	# Beute einsammeln
	for e in get_tree().get_nodes_in_group("hostile"):
		if e is Enemy and e.type == "ghoul":
			e.queue_free()
	for d in m.loot.duplicate():
		if not is_instance_valid(d.n):
			continue
		m.player.global_position = (d.n as Node3D).global_position + Vector3(0, 0.4, 0)
		await _frames(25)
	print("TEST tasche=", ps.s.bag.size())
	# Logbuchseite
	var pg: Dictionary = tr.pages[0]
	m.player.global_position = (pg.pos as Vector3) + Vector3(0.5, 0.4, 0)
	await _frames(15)
	print("TEST seite interact=", m.interact_id)
	await _shot("t_page")
	m._interact()
	await _resolve([])
	print("TEST seiten=", ps.s.pages)
	# Altar
	ps.s.blood = 80.0
	var ap: Vector3 = tr.altars[0]
	m.player.global_position = ap + Vector3(0, 0.4, 2.0)
	m.rig.yaw = 0.0
	await _frames(15)
	print("TEST altar interact=", m.interact_id)
	await _shot("t_altar")
	var ap0 := int(ps.s.attr_points)
	m._interact()
	await _resolve([])
	print("TEST altar punkte ", ap0, " -> ", ps.s.attr_points, " blut=", int(ps.s.blood))
	# Schatzkarte und Graben
	ps.add_map()
	m.treasure_maps_changed()
	var di: int = ps.s.maps[0]
	m._update_compass()
	print("TEST kompass=", m.hud.compass_marks.size())
	m.player.global_position = (tr.digs[di] as Vector3) + Vector3(0.8, 0.4, 0)
	await _frames(15)
	print("TEST graben interact=", m.interact_id)
	await _shot("t_dig")
	m._interact()
	await _frames(80)
	print("TEST gegraben=", ps.s.dug, " karten=", ps.s.maps)
	# Schmieden
	ps.s.shards = 5000
	ps.s.crystals = [20, 20, 20, 20]
	var w0: float = ps.melee_damage()
	for k in 6:
		ps.upgrade("weapon")
	print("TEST waffe=", Items.title(ps.s.equip.weapon), " schaden ", int(w0), " -> ", int(ps.melee_damage()), " titel=", ps.s.titles)
	# Elite
	var den: Vector3 = m.places.spots.dens[0]
	m.player.global_position = m.terrain.ground(den + Vector3(0, 0, 9)) + Vector3(0, 0.4, 0)
	m.rig.yaw = 0.0
	await _frames(40)
	await _shot("t_den")
	var alpha: Enemy = m.dens.get(0)
	print("TEST alpha=", alpha != null and is_instance_valid(alpha), " lvl=", alpha.level if alpha else -1)
	if alpha:
		alpha.take_hit(99999.0, m.player.global_position)
		await _frames(30)
		print("TEST alpha tot, elites=", ps.count("elites"), " bau=", ps.s.elites, " kristalle=", ps.s.crystals, " inspect=", ps.has_skill("inspect"))
		await _resolve([])
	# Optionale Trink-Quest
	var b := Enemy.new()
	b.setup("bandit", m, m.terrain.ground(m.player.global_position + Vector3(2, 0, 0)) + Vector3(0, 0.3, 0), 2)
	m.add_child(b)
	await _frames(5)
	var tries := 0
	while m.drink_quest.is_empty() and tries < 30:
		tries += 1
		b.downed = false
		b.hp = 1.0
		b.take_hit(5.0, m.player.global_position)
		if m.drink_quest.is_empty():
			b.downed = false
			b.alive = true
	await _frames(5)
	print("TEST trinkquest=", not m.drink_quest.is_empty(), " hud=", m.hud.drink_t)
	await _shot("t_drinkquest")
	var apb := int(ps.s.attr_points)
	m.perform_feed(b, "sip", false)
	await get_tree().create_timer(2.5).timeout
	print("TEST nach trinken quest=", m.drink_quest.is_empty(), " punkte ", apb, " -> ", ps.s.attr_points)
	# Welt-Tab + Schnellreise
	ps.discover("mill", "Alte Mühle")
	m.toggle_menu()
	m.menu.tab = "world"
	m.menu.rebuild()
	await _frames(10)
	await _shot("t_world_tab")
	m.menu.tab = "shop"
	m.menu.shop_open = true
	m.menu.rebuild()
	await _frames(10)
	await _shot("t_shop")
	m.menu.tab = "gear"
	m.menu.rebuild()
	await _frames(5)
	m.toggle_menu()
	if is_instance_valid(b):
		b.queue_free()
	for e in get_tree().get_nodes_in_group("hostile"):
		e.aggro = false
	m.travel_to("mill")
	await get_tree().create_timer(1.0).timeout
	await _frames(20)
	print("TEST reise mill: dist=", m.player.global_position.distance_to(m.places.spots.mill), " zone=", m.last_zone)
	await _shot("t_mill")
	m.player.global_position = m.terrain.ground(m.places.spots.morrow + Vector3(0, 0, -16)) + Vector3(0, 0.4, 0)
	m.rig.yaw = PI
	await _frames(40)
	await _shot("t_morrow")
	m.player.global_position = m.terrain.ground(m.places.spots.barrow + Vector3(0, 0, 14)) + Vector3(0, 0.4, 0)
	m.rig.yaw = 0.0
	await _frames(40)
	await _shot("t_barrow")
	m.player.global_position = m.terrain.ground(m.places.spots.hut + Vector3(-3, 0, -9)) + Vector3(0, 0.4, 0)
	m.rig.yaw = PI * 0.85
	await _frames(40)
	await _shot("t_hut")
	print("TEST titel=", ps.s.titles, " zaehler=", ps.s.counts)
	print("TEST fertig")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots + "/" + name + ".png")

func _resolve(picks: Array) -> void:
	var guard := 0
	var hud = m.hud
	while guard < 600:
		guard += 1
		await get_tree().process_frame
		if not hud.in_dialog():
			var more := false
			for i in 30:
				await get_tree().process_frame
				if hud.in_dialog():
					more = true
					break
			if not more:
				return
			continue
		if hud.dlg_i < hud.dlg_lines.size() - 1:
			hud.dlg_i = hud.dlg_lines.size() - 1
			hud.dlg_chars = 9999.0
			continue
		if not hud.dlg_choices.is_empty():
			var p: int = picks.pop_front() if not picks.is_empty() else 0
			hud._pick(mini(p, hud.dlg_choices.size() - 1))
		else:
			hud._finish_dialog(-1)
