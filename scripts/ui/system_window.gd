class_name SystemWindow
extends Control
## Zentrales Hologramm-Fenster: Status (Attribute mit +), Inventar (Blut-Essenzen), Skill-Baum, Quests.

signal closed

const H := preload("res://scripts/ui/holo_ui.gd")
const ATTRS := [
	["str", "STR", "Stärke", "Physischer Nahkampfschaden"],
	["agi", "AGI", "Beweglichkeit", "Angriffs-/Bewegungstempo, Ausweichen, Krit"],
	["end", "END", "Ausdauer", "Max. HP, Rüstung, langsamerer Blutverbrauch"],
	["shd", "SHD", "Schatten-Kraft", "Schattenschaden, Abklingzeiten, Skill-Freischaltung"],
]

var tab := "status"
var world: Node
var shop_open := false
var sel_bag := -1
var panel: PanelContainer
var body: VBoxContainer
var tabs_box: HBoxContainer
var scroll: ScrollContainer
var points_lbl: Label
var _dirty := false
var _scan := 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = H.make_theme()
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.01, 0.03, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	panel = PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = 14
	panel.offset_bottom = -14
	add_child(panel)
	var v := H.vbox(6)
	panel.add_child(v)
	var top := H.hbox(4)
	v.add_child(top)
	tabs_box = H.hbox(2)
	top.add_child(tabs_box)
	top.add_child(H.spacer())
	points_lbl = H.lbl("", 12, H.GOLD, H.F_SEMI)
	points_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(points_lbl)
	var close := H.btn("✕", func(): closed.emit(), "BtnRed")
	close.custom_minimum_size = Vector2(44, 34)
	top.add_child(close)
	var line := ColorRect.new()
	line.color = Color(H.CYAN, 0.25)
	line.custom_minimum_size = Vector2(0, 1)
	v.add_child(line)
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	TouchScroll.attach(scroll)
	body = H.vbox(6)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	PlayerStats.stats_changed.connect(func(): _dirty = true)
	PlayerStats.quests_changed.connect(func(): _dirty = true)
	visibility_changed.connect(func():
		if visible:
			rebuild())

func open(t := "") -> void:
	if t != "":
		tab = t
	visible = true
	rebuild()

func _process(delta: float) -> void:
	_scan += delta
	if _dirty and visible:
		_dirty = false
		rebuild()
	queue_redraw()

func _draw() -> void:
	# langsam laufende Scanline über dem Fenster
	var r := panel.get_rect()
	var y := r.position.y + fmod(_scan * 60.0, r.size.y)
	draw_line(Vector2(r.position.x + 2, y), Vector2(r.end.x - 2, y), Color(H.CYAN, 0.08), 2.0)

func _tabs() -> void:
	for c in tabs_box.get_children():
		c.queue_free()
	var free_attr := int(PlayerStats.s.attr_points)
	var free_sk := int(PlayerStats.s.skill_points)
	var tabs := [["status", "STATUS" + (" •" if free_attr > 0 else "")], ["gear", "AUSRÜSTUNG"], ["inventory", "BLUT"], ["skills", "SKILLS" + (" •" if free_sk > 0 else "")], ["quests", "QUESTS"]]
	if shop_open:
		tabs.insert(0, ["shop", "LADEN"])
	for t in tabs:
		var id: String = t[0]
		var cb := func():
			tab = id
			rebuild()
		var b := H.btn(t[1], cb, "TabOn" if tab == id else "Tab")
		b.custom_minimum_size = Vector2(0, 34)
		tabs_box.add_child(b)
	points_lbl.text = "◆ %d" % int(PlayerStats.s.shards)

func rebuild() -> void:
	if not is_inside_tree():
		return
	_tabs()
	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()
	match tab:
		"status":
			_status()
		"inventory":
			_inventory()
		"skills":
			_skills()
		"quests":
			_quests()
		"gear":
			_gear()
		"shop":
			_shop()

func _row(left: Control, right: Control) -> HBoxContainer:
	var h := H.hbox(8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(left)
	h.add_child(right)
	return h

# ---------- Status ----------

func _status() -> void:
	var s := PlayerStats.s
	var head := H.hbox(14)
	body.add_child(head)
	var l := H.vbox(2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	l.add_child(H.caps("Wirt", H.CYAN))
	l.add_child(H.lbl("Kadett-Subjekt 0", 19, H.FG, H.F_BOLD))
	var titles := ["Ungeformt", "Erwachter", "Blutjäger", "Schattengänger", "Nachtfürst"]
	l.add_child(H.lbl("Stufe %d  ·  %s" % [int(s.level), titles[min(int(s.level) / 4, titles.size() - 1)]], 13, H.MUTED, H.F_SEMI))
	var xpb := H.Bar.new(200, 5)
	xpb.set_value(float(s.xp) / PlayerStats.xp_to_next(), H.CYAN)
	l.add_child(xpb)
	l.add_child(H.lbl("EXP %d / %d" % [int(s.xp), PlayerStats.xp_to_next()], 11, H.MUTED, H.F_MONO))
	var r := H.vbox(2)
	r.custom_minimum_size = Vector2(240, 0)
	head.add_child(r)
	r.add_child(_kv("HP", "%d / %d" % [int(s.hp), int(PlayerStats.max_hp())]))
	r.add_child(_kv("Blut", "%d / %d" % [int(s.blood), int(PlayerStats.max_blood())], H.RED))
	r.add_child(_kv("Verbrauch", "%.2f / s" % PlayerStats.blood_drain(), H.RED))
	r.add_child(_kv("Verdacht", "%d %%" % int(s.suspicion), Color(1.0, 0.7, 0.2)))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for a in ATTRS:
		var key: String = a[0]
		var c := H.card()
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := H.hbox(10)
		c.add_child(h)
		var col := H.vbox(0)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		var t := H.hbox(6)
		t.add_child(H.lbl(a[1], 16, H.CYAN, H.F_BOLD))
		t.add_child(H.lbl(a[2], 12, H.MUTED, H.F_SEMI))
		col.add_child(t)
		col.add_child(H.lbl(a[3], 10, H.MUTED, H.F_REG))
		var bonus := " (+2)" if s.chimera else ""
		h.add_child(H.lbl(str(int(s[key])) + bonus, 22, H.FG, H.F_BOLD))
		var plus := H.btn("+", func(): PlayerStats.raise_attr(key), "", int(s.attr_points) <= 0)
		plus.custom_minimum_size = Vector2(42, 42)
		plus.add_theme_font_size_override("font_size", 20)
		h.add_child(plus)
		grid.add_child(c)
	var d := H.card("CardDim")
	body.add_child(d)
	var dg := GridContainer.new()
	dg.columns = 3
	dg.add_theme_constant_override("h_separation", 18)
	d.add_child(dg)
	for kv in [
		["Nahkampf", "%d" % int(PlayerStats.melee_damage())], ["Schatten", "%d" % int(PlayerStats.shadow_damage())],
		["Rüstung", "%d %%" % int(PlayerStats.armor() * 100)], ["Ausweichen", "%d %%" % int(PlayerStats.dodge_chance() * 100)],
		["Krit", "%d %%" % int(PlayerStats.crit_chance() * 100)], ["Tempo", "%.1f m/s" % PlayerStats.move_speed()]]:
		dg.add_child(_kv(kv[0], kv[1]))

func _kv(k: String, v: String, vc := H.FG) -> HBoxContainer:
	var h := H.hbox(6)
	var kl := H.lbl(k, 12, H.MUTED, H.F_REG)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(kl)
	h.add_child(H.lbl(v, 12, vc, H.F_MONO))
	return h

# ---------- Inventar ----------

func _inventory() -> void:
	body.add_child(H.caps("Blut-Essenz-Kapseln", H.RED))
	for k in ["karkosa", "mutant", "human"]:
		var bt: Dictionary = PlayerStats.BLOOD_TYPES[k]
		var n := int(PlayerStats.s.inventory[k])
		var c := H.card("Card" if n > 0 else "CardDim")
		var h := H.hbox(12)
		c.add_child(h)
		var sw := ColorRect.new()
		sw.color = bt.color
		sw.custom_minimum_size = Vector2(8, 44)
		h.add_child(sw)
		var col := H.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		col.add_child(H.lbl("%s   ×%d" % [bt.name, n], 15, H.FG, H.F_BOLD))
		col.add_child(H.wrap(bt.desc, 11))
		var cb := func():
			if PlayerStats.drink(k) and world:
				world.sfx("drink")
		var b := H.btn("Trinken", cb, "BtnRed", n <= 0)
		b.custom_minimum_size = Vector2(96, 40)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		body.add_child(c)
	body.add_child(H.caps("Legendäre Gegenstände", H.GOLD))
	if PlayerStats.s.chimera:
		var c2 := H.card("CardOn")
		var v2 := H.vbox(1)
		c2.add_child(v2)
		v2.add_child(H.lbl("Chimären-Herz", 15, H.GOLD, H.F_BOLD))
		v2.add_child(H.wrap("Drei Blutlinien in einem Herzen vereint. +2 auf alle Attribute.", 11))
		body.add_child(c2)
	else:
		body.add_child(H.wrap("Noch keine. Manche Belohnungen schaltet das Protokoll nur verborgen frei.", 12))

# ---------- Skills ----------

func _skills() -> void:
	body.add_child(H.caps("Sanguine-Skillbaum  ·  freie Skillpunkte: %d" % int(PlayerStats.s.skill_points), H.CYAN))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	body.add_child(grid)
	for id in PlayerStats.SKILLS:
		var sk: Dictionary = PlayerStats.SKILLS[id]
		var st := PlayerStats.skill_state(id)
		if sk.get("hidden", false) and st != "owned":
			var hc := H.card("CardDim")
			hc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var hv := H.vbox(1)
			hc.add_child(hv)
			hv.add_child(H.lbl("??? – Verborgener Skill", 14, H.MUTED, H.F_BOLD))
			hv.add_child(H.wrap("Wird durch eine verborgene Quest freigeschaltet.", 11))
			grid.add_child(hc)
			continue
		var c := H.card("CardOn" if st == "owned" else ("Card" if st == "ready" else "CardDim"))
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := H.hbox(8)
		c.add_child(h)
		var v := H.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(H.lbl(sk.name, 14, H.RED if st == "owned" else H.FG, H.F_BOLD))
		v.add_child(H.wrap(sk.desc, 10))
		var req := []
		for k in sk.req:
			var ok := PlayerStats.stat(k) >= int(sk.req[k])
			req.append("%s %d%s" % [String(k).to_upper(), int(sk.req[k]), "" if ok else " ✗"])
		if st != "owned":
			var info := "Benötigt: " + (", ".join(req) if req.size() > 0 else "–") + "  ·  Kosten: %d SP" % int(sk.cost)
			v.add_child(H.lbl(info, 10, H.GOLD if st == "ready" else H.MUTED, H.F_MONO))
		if st == "ready":
			var b := H.btn("Lernen", func(): PlayerStats.learn_skill(id))
			b.custom_minimum_size = Vector2(76, 38)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
		elif st == "owned":
			h.add_child(H.lbl("✓", 18, H.RED, H.F_BOLD))
		grid.add_child(c)

# ---------- Quests ----------

func _quests() -> void:
	body.add_child(H.caps("Hauptquest – Kapitel 1", H.CYAN))
	var c := H.card("CardOn")
	var v := H.vbox(2)
	c.add_child(v)
	v.add_child(H.lbl(PlayerStats.story_title(), 15, H.FG, H.F_BOLD))
	v.add_child(H.wrap(PlayerStats.story_text(), 12))
	v.add_child(H.wrap("Daueraufgabe: Verhindere, dass Ausbilder oder Rivalen dich als Vampir entlarven (Verdacht unter 100 %).", 11, Color(1.0, 0.7, 0.2)))
	body.add_child(c)
	body.add_child(H.caps("Tägliche System-Quests  ·  neu ab Mitternacht (Echtzeit)", H.CYAN))
	if PlayerStats.s.daily.has("quests"):
		for q in PlayerStats.s.daily.quests:
			var qc := H.card("Card" if not q.done else "CardDim")
			var h := H.hbox(10)
			qc.add_child(h)
			var t := H.lbl(PlayerStats.daily_text(q), 13, H.FG if not q.done else H.MUTED, H.F_SEMI)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(t)
			var b := H.Bar.new(90, 5)
			b.size_flags_horizontal = Control.SIZE_SHRINK_END
			b.set_value(float(q.progress) / float(q.goal), H.CYAN)
			h.add_child(b)
			h.add_child(H.lbl("%d/%d" % [int(q.progress), int(q.goal)] if not q.done else "✓", 12, H.CYAN, H.F_MONO))
			body.add_child(qc)
	body.add_child(H.wrap("Belohnung je Quest: 120 EXP + 1 Attributpunkt. Alle drei: +1 Skillpunkt. Verfehlt: Systemstrafe (Quarantäne, −15 % max. HP).", 11))
	body.add_child(H.caps("Nebenquests", H.CYAN))
	var any := false
	for sid in PlayerStats.SIDE:
		var stt := PlayerStats.side_state(sid)
		if stt == "":
			continue
		any = true
		var sq: Dictionary = PlayerStats.SIDE[sid]
		var sc := H.card("Card" if stt != "done" else "CardDim")
		var sh := H.hbox(10)
		sc.add_child(sh)
		var sv := H.vbox(1)
		sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sh.add_child(sv)
		sv.add_child(H.lbl("%s  ·  %s" % [sq.title, sq.giver], 13, H.FG if stt != "done" else H.MUTED, H.F_SEMI))
		sv.add_child(H.wrap(sq.text, 11))
		var prog := int(PlayerStats.s.side[sid].progress)
		sh.add_child(H.lbl("✓" if stt == "done" else ("Abgeben!" if stt == "ready" else "%d/%d" % [prog, int(sq.goal)]), 12, H.GOLD if stt == "ready" else H.CYAN, H.F_MONO))
		body.add_child(sc)
	if not any:
		body.add_child(H.wrap("Sprich mit Leuten in der Akademie – Mira im Schlafsaal, Brann in der Mensa.", 12))
	body.add_child(H.caps("Verborgene Quests", H.GOLD))
	var hidden := [
		["midnight_vault", "Stunde Null", "Hinter den Trümmern im Westen des Archivs flüstert etwas – aber nur, wenn die Uhr die Stunde Null schlägt."],
		["chimera", "Drei Blutlinien", "Das Protokoll will von jeder Blutlinie gekostet haben … mehrmals."],
	]
	for hq in hidden:
		var done: bool = PlayerStats.s.hidden.get(hq[0], false)
		var hc := H.card("CardOn" if done else "CardDim")
		var hv := H.vbox(1)
		hc.add_child(hv)
		hv.add_child(H.lbl(hq[1] if done else "???", 14, H.GOLD if done else H.MUTED, H.F_BOLD))
		hv.add_child(H.wrap("Abgeschlossen." if done else hq[2], 11))
		body.add_child(hc)

# ---------- Ausrüstung ----------

func _item_card(it: Dictionary, buttons: Array, compare := {}) -> PanelContainer:
	var c := H.card("Card")
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var col := Items.color(it)
	var sb := H.box(Color(col.r, col.g, col.b, 0.06), Color(col.r, col.g, col.b, 0.45), 1, 2, Vector2(10, 7))
	c.add_theme_stylebox_override("panel", sb)
	var h := H.hbox(8)
	c.add_child(h)
	var v := H.vbox(0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var head := H.hbox(6)
	head.add_child(H.lbl(String(it.name), 14, col, H.F_BOLD))
	var sub := "%s · %s · Stufe %d" % [Items.SLOTS[it.slot], Items.RARITY[int(it.rarity)].name, int(it.lvl)]
	if it.slot == "weapon":
		sub += " · " + String(Items.WEAPONS[it.type].desc)
	v.add_child(head)
	v.add_child(H.lbl(sub, 10, H.MUTED, H.F_REG))
	var ln := "  ·  ".join(Items.lines(it))
	v.add_child(H.wrap(ln, 11, H.FG))
	if not compare.is_empty():
		var diff := Items.power(it) - Items.power(compare)
		var arrow := "▲ besser" if diff > 0.5 else ("▼ schwächer" if diff < -0.5 else "≈ gleich")
		v.add_child(H.lbl(arrow, 10, Color(0.5, 1.0, 0.6) if diff > 0.5 else (Color(1.0, 0.5, 0.45) if diff < -0.5 else H.MUTED), H.F_SEMI))
	var bv := H.vbox(4)
	bv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bv)
	for b in buttons:
		var btn := H.btn(b[0], b[1], b[2] if b.size() > 2 else "", b[3] if b.size() > 3 else false)
		btn.custom_minimum_size = Vector2(92, 34)
		bv.add_child(btn)
	return c

func _gear() -> void:
	body.add_child(H.caps("Angelegt  ·  Blutsplitter: %d" % int(PlayerStats.s.shards), H.CYAN))
	for slot in ["weapon", "armor", "relic"]:
		var it: Dictionary = PlayerStats.s.equip.get(slot, {})
		if it.is_empty():
			var e := H.card("CardDim")
			e.add_child(H.lbl("%s: leer" % Items.SLOTS[slot], 13, H.MUTED, H.F_SEMI))
			body.add_child(e)
		else:
			body.add_child(_item_card(it, []))
	var bag: Array = PlayerStats.s.bag
	body.add_child(H.caps("Tasche  ·  %d / 30" % bag.size(), H.CYAN))
	if bag.is_empty():
		body.add_child(H.wrap("Noch leer. Gegner lassen Ausrüstung fallen – achte auf Lichtsäulen. Bosse droppen garantiert Seltenes.", 12))
	for i in bag.size():
		var it: Dictionary = bag[i]
		var idx := i
		var eq: Dictionary = PlayerStats.s.equip.get(it.slot, {})
		var cb_eq := func():
			PlayerStats.equip_item(idx)
			if world:
				world.sfx("quest")
			rebuild()
		var cb_sv := func():
			PlayerStats.salvage(idx)
			rebuild()
		body.add_child(_item_card(it, [["Anlegen", cb_eq, "BtnRed"], ["Zerlegen +%d" % Items.value(it), cb_sv]], eq))

func _shop() -> void:
	body.add_child(H.caps("Quartiermeister Brann  ·  Deine Blutsplitter: %d" % int(PlayerStats.s.shards), H.GOLD))
	var items := PlayerStats.shop_items()
	if items.is_empty():
		body.add_child(H.wrap("Ausverkauft. Komm später wieder – Brann bekommt jeden Tag und nach Story-Fortschritt neue Ware.", 12))
	for i in items.size():
		var it: Dictionary = items[i]
		var idx := i
		var p := Items.price(it)
		var eq: Dictionary = PlayerStats.s.equip.get(it.slot, {})
		var cb := func():
			if PlayerStats.buy(idx):
				if world:
					world.sfx("quest")
				rebuild()
		body.add_child(_item_card(it, [["Kaufen ◆%d" % p, cb, "BtnRed", int(PlayerStats.s.shards) < p]], eq))
	body.add_child(H.wrap("Tipp: Gegenstände aus der Tasche zerlegen bringt Blutsplitter.", 11))
