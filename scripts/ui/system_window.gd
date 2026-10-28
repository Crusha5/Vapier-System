class_name SystemWindow
extends Control
## Zentrales Hologramm-Fenster: Status, Ausrüstung, Blut, Fähigkeiten (zwei Pfade), Chronik.

signal closed

const H := preload("res://scripts/ui/holo_ui.gd")
const ATTRS := [
	["str", "STR", "Stärke", "Physischer Nahkampfschaden"],
	["agi", "AGI", "Beweglichkeit", "Angriffs-/Bewegungstempo, Ausweichen, Krit"],
	["end", "END", "Ausdauer", "Max. HP, Rüstung, langsamerer Blutverbrauch"],
	["shd", "SHD", "Schatten-Kraft", "Blutkräfte, Abklingzeiten, Fähigkeiten"],
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
	shop_open = t == "shop"
	if t != "":
		tab = t
	elif tab == "shop":
		tab = "status"
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
	var tabs := [["status", "STATUS" + (" •" if free_attr > 0 else "")], ["gear", "AUSRÜSTUNG"], ["blood", "BLUT"], ["skills", "KRÄFTE" + (" •" if free_sk > 0 else "")], ["chronicle", "AUFGABEN"], ["world", "WELT"]]
	if shop_open:
		tabs.insert(0, ["shop", "HANDEL"])
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
		"gear":
			_gear()
		"blood":
			_blood()
		"skills":
			_skills()
		"chronicle":
			_chronicle()
		"shop":
			_shop()
		"world":
			_world()

func _kv(k: String, v: String, vc := H.FG) -> HBoxContainer:
	var h := H.hbox(6)
	var kl := H.lbl(k, 12, H.MUTED, H.F_REG)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(kl)
	h.add_child(H.lbl(v, 12, vc, H.F_MONO))
	return h

# ---------- Status ----------

func _status() -> void:
	var s := PlayerStats.s
	body.add_child(brightness_row(rebuild))
	body.add_child(quality_row(rebuild))
	var head := H.hbox(14)
	body.add_child(head)
	var l := H.vbox(2)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	l.add_child(H.caps("Wirt der Ersten Nacht", H.RED))
	l.add_child(H.lbl("Kael", 20, H.FG, H.F_BOLD))
	l.add_child(H.lbl("Stufe %d  ·  %s" % [int(s.level), PlayerStats.tier_name()], 13, H.MUTED, H.F_SEMI))
	var xpb := H.Bar.new(200, 5)
	xpb.set_value(float(s.xp) / PlayerStats.xp_to_next(), H.CYAN)
	l.add_child(xpb)
	l.add_child(H.lbl("EXP %d / %d" % [int(s.xp), PlayerStats.xp_to_next()], 11, H.MUTED, H.F_MONO))
	var r := H.vbox(2)
	r.custom_minimum_size = Vector2(250, 0)
	head.add_child(r)
	r.add_child(_kv("HP", "%d / %d" % [int(s.hp), int(PlayerStats.max_hp())]))
	r.add_child(_kv("Blut", "%d / %d" % [int(s.blood), int(PlayerStats.max_blood())], H.RED))
	r.add_child(_kv("Hunger", "%.2f / s" % PlayerStats.blood_drain(), H.RED))
	r.add_child(_kv("Menschlichkeit", "%d · %s" % [int(PlayerStats.humanity()), PlayerStats.tier_name()], Color(0.95, 0.85, 0.65)))
	r.add_child(_kv("Sonnenschaden", "%.1f HP/s" % PlayerStats.sun_dps(), Color(1.0, 0.6, 0.25)))
	var hc := H.card("CardOn")
	body.add_child(hc)
	hc.add_child(H.wrap(PlayerStats.TIERS[PlayerStats.tier()][2] + "  Je weniger Menschlichkeit, desto stärker bist du nachts – und desto schneller kommt der Hunger und desto mehr brennt die Sonne.", 11, H.FG))
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
		h.add_child(H.lbl(str(int(s[key])), 22, H.FG, H.F_BOLD))
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
	for kv in [["Nahkampf", "%d" % int(PlayerStats.melee_damage())], ["Blutkraft", "%d" % int(PlayerStats.shadow_damage())],
		["Rüstung", "%d %%" % int(PlayerStats.armor() * 100)], ["Ausweichen", "%d %%" % int(PlayerStats.dodge_chance() * 100)],
		["Krit", "%d %%" % int(PlayerStats.crit_chance() * 100)], ["Tempo", "%.1f m/s" % PlayerStats.move_speed()]]:
		dg.add_child(_kv(kv[0], kv[1]))

# ---------- Blut ----------

func _blood() -> void:
	body.add_child(H.caps("Blutphiolen", H.RED))
	for k in ["animal", "beast", "human"]:
		var bt: Dictionary = PlayerStats.BLOOD_TYPES[k]
		var n := int(PlayerStats.s.inventory[k])
		var c := H.card("Card" if n > 0 else "CardDim")
		var h := H.hbox(12)
		c.add_child(h)
		var sw := ColorRect.new()
		sw.color = bt.color
		sw.custom_minimum_size = Vector2(8, 40)
		h.add_child(sw)
		var col := H.vbox(1)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(col)
		col.add_child(H.lbl("%s   ×%d" % [bt.name, n], 15, H.FG, H.F_BOLD))
		col.add_child(H.wrap(bt.desc, 11))
		var cb := func():
			if PlayerStats.drink_vial(k) and world:
				world.sfx("drink")
		var b := H.btn("Trinken", cb, "BtnRed", n <= 0)
		b.custom_minimum_size = Vector2(96, 40)
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		body.add_child(c)
	body.add_child(H.wrap("Direkt trinken ist mächtiger: Nähere dich einem Wesen und wähle „Trinken“. Nippen lässt es leben – es erinnert sich vielleicht an dein Gesicht. Aussaugen tötet.", 12))

# ---------- Fähigkeiten ----------

func _skills() -> void:
	body.add_child(H.caps("Freie Punkte: %d  ·  Menschlichkeit %d" % [int(PlayerStats.s.skill_points), int(PlayerStats.humanity())], H.CYAN))
	for path in [["neutral", "Erbe der Ersten Nacht", H.CYAN], ["guardian", "Pfad des Beschützers – braucht Menschlichkeit", Color(0.95, 0.85, 0.6)], ["beast", "Pfad der Bestie – braucht den Hunger", H.RED]]:
		body.add_child(H.caps(path[1], path[2]))
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 6)
		grid.add_theme_constant_override("v_separation", 6)
		body.add_child(grid)
		for id in PlayerStats.SKILLS:
			var sk: Dictionary = PlayerStats.SKILLS[id]
			if sk.path != path[0]:
				continue
			var st := PlayerStats.skill_state(id)
			var c := H.card("CardOn" if st == "owned" else ("Card" if st == "ready" else "CardDim"))
			c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var h := H.hbox(8)
			c.add_child(h)
			var v := H.vbox(1)
			v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(v)
			v.add_child(H.lbl(sk.name, 14, path[2] if st == "owned" else H.FG, H.F_BOLD))
			v.add_child(H.wrap(sk.desc, 10))
			if st != "owned":
				var req := []
				for k in sk.req:
					match k:
						"humanity_min":
							req.append("Menschlichkeit ≥ %d" % int(sk.req[k]))
						"humanity_max":
							req.append("Menschlichkeit ≤ %d" % int(sk.req[k]))
						_:
							req.append("%s %d" % [String(k).to_upper(), int(sk.req[k])])
				if sk.get("grant", false):
					v.add_child(H.lbl("Wird vom System verliehen", 10, H.MUTED, H.F_MONO))
				else:
					v.add_child(H.lbl(("Braucht: " + ", ".join(req) if req.size() > 0 else "Frei") + "  ·  %d SP" % int(sk.cost), 10, H.GOLD if st == "ready" else H.MUTED, H.F_MONO))
			if st == "ready":
				var b := H.btn("Lernen", func(): PlayerStats.learn_skill(id))
				b.custom_minimum_size = Vector2(76, 38)
				b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				h.add_child(b)
			elif st == "owned":
				h.add_child(H.lbl("✓", 18, path[2], H.F_BOLD))
			grid.add_child(c)

# ---------- Chronik ----------

func _chronicle() -> void:
	body.add_child(H.caps("Ziel", H.CYAN))
	var c := H.card("CardOn")
	var v := H.vbox(2)
	c.add_child(v)
	v.add_child(H.lbl(PlayerStats.story_title(), 15, H.FG, H.F_BOLD))
	v.add_child(H.wrap(PlayerStats.story_text(), 12))
	body.add_child(c)
	# Nebenaufgaben
	if world and world.get("quests") != null:
		var js: Array = world.quests.journal()
		body.add_child(H.caps("Nebenaufgaben", H.CYAN))
		if js.is_empty():
			body.add_child(H.wrap("Noch keine. Sprich mit den Leuten in Asch-Furt – viele brauchen Hilfe.", 12))
		for j in js:
			var active: bool = j.state == "aktiv"
			var jc := H.card("CardOn" if active else "CardDim")
			var jv := H.vbox(2)
			jc.add_child(jv)
			var head := H.hbox(8)
			var tl := H.lbl(j.title, 14, H.FG if active else H.MUTED, H.F_BOLD)
			tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(tl)
			head.add_child(H.lbl(String(j.state).to_upper(), 10, H.CYAN if active else (H.GOLD if j.state == "erledigt" else H.RED), H.F_MONO))
			jv.add_child(head)
			jv.add_child(H.lbl("von " + String(j.giver), 10, H.MUTED, H.F_SEMI))
			if active:
				jv.add_child(H.wrap(j.text, 12))
			body.add_child(jc)
	body.add_child(H.caps("Tägliche Aufgaben des Protokolls (Echtzeit)", H.CYAN))
	if PlayerStats.s.daily.has("quests"):
		for q in PlayerStats.s.daily.quests:
			var qc := H.card("Card" if not q.done else "CardDim")
			var h := H.hbox(10)
			qc.add_child(h)
			var t := H.lbl(PlayerStats.daily_text(q), 13, H.FG if not q.done else H.MUTED, H.F_SEMI)
			t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(t)
			h.add_child(H.lbl("%d/%d" % [int(q.progress), int(q.goal)] if not q.done else "✓", 12, H.CYAN, H.F_MONO))
			body.add_child(qc)
	body.add_child(H.caps("Deine Entscheidungen – unumkehrbar", H.RED))
	var ch: Array = PlayerStats.s.choices
	if ch.is_empty():
		body.add_child(H.wrap("Noch nichts. Aber Veyra merkt sich alles.", 12))
	for e in ch:
		var cc := H.card("CardDim")
		cc.add_child(H.wrap("Tag %d  ·  %s" % [int(e.day), e.text], 12, H.FG))
		body.add_child(cc)
	var dead: Array = PlayerStats.s.dead
	if not dead.is_empty():
		body.add_child(H.caps("Tote durch deine Hand oder dein Zutun: %d" % dead.size(), Color(1.0, 0.45, 0.4)))

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
	head.add_child(H.lbl(Items.title(it), 14, col, H.F_BOLD))
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

func _valuables() -> void:
	var s := PlayerStats.s
	var c := H.card("CardDim")
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 18)
	c.add_child(g)
	for t in 4:
		g.add_child(_kv(PlayerStats.crystal_name(t), "%d" % int(s.crystals[t]), Items.RARITY[t].color))
	g.add_child(_kv("Dietriche", "%d" % int(s.picks)))
	g.add_child(_kv("Schatzkarten", "%d" % (s.maps as Array).size(), Color(1.0, 0.45, 0.35)))
	body.add_child(c)

func _gear() -> void:
	body.add_child(H.caps("Wertsachen", H.GOLD))
	_valuables()
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
	body.add_child(H.caps("Schmied Oswin  ·  Deine Blutsplitter: %d" % int(PlayerStats.s.shards), H.GOLD))
	var items := PlayerStats.shop_items()
	if items.is_empty():
		body.add_child(H.wrap("Ausverkauft. Oswin schmiedet jeden Tag Neues.", 12))
	for i in items.size():
		var it: Dictionary = items[i]
		var p := Items.price(it)
		var eq: Dictionary = PlayerStats.s.equip.get(it.slot, {})
		body.add_child(_item_card(it, [["Kaufen ◆%d" % p, _buy.bind(i), "BtnRed", int(PlayerStats.s.shards) < p]], eq))
	body.add_child(H.wrap("Tipp: Gegenstände aus der Tasche zerlegen bringt Blutsplitter.", 11))
	# Schmieden mit Bestienkristallen
	body.add_child(H.caps("Schmieden  ·  Bestienkristalle machen deine Ausrüstung stärker", H.GOLD))
	_valuables()
	for slot in ["weapon", "armor", "relic"]:
		var it: Dictionary = PlayerStats.s.equip.get(slot, {})
		if it.is_empty():
			continue
		var cc := H.card("Card")
		var h := H.hbox(8)
		cc.add_child(h)
		var v := H.vbox(1)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(v)
		v.add_child(H.lbl(Items.title(it), 14, Items.color(it), H.F_BOLD))
		if Items.plus(it) >= 10:
			v.add_child(H.lbl("Höchste Stufe erreicht", 10, H.GOLD, H.F_MONO))
		else:
			var cost := PlayerStats.upgrade_cost(it)
			v.add_child(H.lbl("→ +%d   ◆%d  ·  %d× %s" % [int(cost.next), int(cost.shards), int(cost.count), PlayerStats.crystal_name(int(cost.tier))], 11, H.FG, H.F_MONO))
			v.add_child(H.lbl("Je Stufe: +12 % Grundwerte und mehr Kernkraft", 10, H.MUTED, H.F_REG))
			var sl: String = slot
			var b := H.btn("Schmieden", func():
				if PlayerStats.upgrade(sl) and world:
					world.sfx("level")
				rebuild(), "BtnRed", not PlayerStats.can_upgrade(slot))
			b.custom_minimum_size = Vector2(104, 38)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			h.add_child(b)
		body.add_child(cc)
	var rc := H.card("CardDim")
	var rh := H.hbox(6)
	rc.add_child(rh)
	var rl := H.lbl("Veredeln: 3 Kristalle → 1 der nächsten Stufe (◆10)", 11, H.MUTED, H.F_SEMI)
	rl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(rl)
	for t in 3:
		var tt := t
		var rb := H.btn(PlayerStats.CRYSTALS[t], func():
			PlayerStats.refine(tt)
			rebuild(), "", int(PlayerStats.s.crystals[t]) < 3 or int(PlayerStats.s.shards) < 10)
		rb.custom_minimum_size = Vector2(0, 32)
		rh.add_child(rb)
	body.add_child(rc)
	var pc := H.card("CardDim")
	var ph := H.hbox(6)
	pc.add_child(ph)
	var pl := H.lbl("Dietrich – öffnet verschlossene Truhen  (du hast %d)" % int(PlayerStats.s.picks), 12, H.FG, H.F_SEMI)
	pl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ph.add_child(pl)
	var pb := H.btn("Kaufen ◆20", func():
		PlayerStats.buy_pick()
		rebuild(), "BtnRed", int(PlayerStats.s.shards) < 20)
	pb.custom_minimum_size = Vector2(110, 34)
	ph.add_child(pb)
	body.add_child(pc)

func _buy(idx: int) -> void:
	if PlayerStats.buy(idx):
		if world:
			world.sfx("quest")
		rebuild()

# ---------- Welt: Karte, Schnellreise, Sammlung, Titel, Login-Serie ----------

func _world() -> void:
	var s := PlayerStats.s
	if world == null or world.get("treasure") == null:
		return
	var tr: Treasure = world.treasure
	var zones: Array = world.ZONES
	var found_z := 0
	for zn in zones:
		if (s.discovered as Array).has(zn[0]):
			found_z += 1
	var opened := tr.opened_count()
	var total := zones.size() + tr.objs.size() + PlayerStats.PAGE_COUNT + tr.altars.size() + PlayerStats.DIG_COUNT
	var found := found_z + opened + (s.pages as Array).size() + (s.altars as Array).size() + (s.dug as Array).size()
	var pct := int(floor(100.0 * found / maxf(1.0, total)))
	var top := H.hbox(10)
	var tl := H.lbl("VEYRA ERKUNDET: %d %%" % pct, 15, H.GOLD, H.F_BOLD)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tl)
	var bar := H.Bar.new(220, 6)
	bar.set_value(pct / 100.0, H.GOLD)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(bar)
	body.add_child(top)
	var mv := MapView.new()
	mv.world = world
	mv.custom_minimum_size = Vector2(0, 250)
	body.add_child(mv)
	# Schnellreise
	body.add_child(H.caps("Schattenreise zu entdeckten Orten", H.CYAN))
	var fg := GridContainer.new()
	fg.columns = 3
	fg.add_theme_constant_override("h_separation", 6)
	fg.add_theme_constant_override("v_separation", 6)
	body.add_child(fg)
	var any := false
	for zid in world.TRAVEL:
		if not (s.discovered as Array).has(zid):
			continue
		any = true
		var nm := ""
		for zn in zones:
			if zn[0] == zid:
				nm = zn[1]
		var id: String = zid
		var b := H.btn(nm, func(): world.travel_to(id))
		b.custom_minimum_size = Vector2(0, 34)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = true
		fg.add_child(b)
	if not any:
		body.add_child(H.wrap("Entdecke Orte, um zwischen ihnen durch die Schatten zu reisen.", 11))
	# Sammlung
	body.add_child(H.caps("Sammlung", H.CYAN))
	var cc := H.card("CardDim")
	var cg := GridContainer.new()
	cg.columns = 2
	cg.add_theme_constant_override("h_separation", 24)
	cc.add_child(cg)
	cg.add_child(_kv("Orte entdeckt", "%d / %d" % [found_z, zones.size()]))
	cg.add_child(_kv("Truhen & Gräber geöffnet", "%d / %d" % [opened, tr.objs.size()]))
	cg.add_child(_kv("Logbuchseiten", "%d / %d" % [(s.pages as Array).size(), PlayerStats.PAGE_COUNT], Color(0.5, 0.85, 1.0)))
	cg.add_child(_kv("Blutaltäre", "%d / %d" % [(s.altars as Array).size(), tr.altars.size()], H.RED))
	cg.add_child(_kv("Vergrabene Schätze", "%d / %d" % [(s.dug as Array).size(), PlayerStats.DIG_COUNT], Color(1.0, 0.45, 0.35)))
	cg.add_child(_kv("Elite-Gegner besiegt", "%d" % PlayerStats.count("elites"), Color(1.0, 0.75, 0.3)))
	body.add_child(cc)
	body.add_child(H.wrap("Tipp: Mit Blutsinn leuchten Schätze durch Wände, der Kompass zeigt den nächsten – und blutgebundene Truhen werden überhaupt erst sichtbar.", 11))
	# Login-Serie
	var st: Dictionary = s.streak
	var cnt := int(st.get("count", 0))
	body.add_child(H.caps("Login-Serie: %d Tag(e) in Folge" % cnt, H.GOLD))
	var sh := H.hbox(4)
	body.add_child(sh)
	for d in 7:
		var done := cnt > 0 and d < ((cnt - 1) % 7) + 1
		var dc := H.card("CardOn" if done else "CardDim")
		dc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var dv := H.vbox(0)
		dc.add_child(dv)
		dv.add_child(H.lbl("TAG %d" % (d + 1), 10, H.GOLD if done else H.MUTED, H.F_BOLD))
		dv.add_child(H.wrap(PlayerStats.STREAK_REWARDS[d], 9, H.FG if done else H.MUTED))
		sh.add_child(dc)
	# Titel
	body.add_child(H.caps("Titel  ·  jeder gibt einen dauerhaften Bonus", H.GOLD))
	var tg := GridContainer.new()
	tg.columns = 2
	tg.add_theme_constant_override("h_separation", 6)
	tg.add_theme_constant_override("v_separation", 6)
	body.add_child(tg)
	for id in PlayerStats.TITLES:
		var t: Dictionary = PlayerStats.TITLES[id]
		var own := (s.titles as Array).has(id)
		var c := H.card("CardOn" if own else "CardDim")
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v := H.vbox(1)
		c.add_child(v)
		var hh := H.hbox(6)
		var nl := H.lbl(t.name, 13, H.GOLD if own else H.FG, H.F_BOLD)
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hh.add_child(nl)
		hh.add_child(H.lbl("✓" if own else "%d/%d" % [mini(PlayerStats.title_progress(id), int(t.goal)), int(t.goal)], 11, H.GOLD if own else H.CYAN, H.F_MONO))
		v.add_child(hh)
		v.add_child(H.lbl(t.desc, 10, H.MUTED, H.F_REG))
		v.add_child(H.lbl(t.btext, 10, Color(0.5, 1.0, 0.6) if own else H.MUTED, H.F_SEMI))
		tg.add_child(c)

## Kleine Weltkarte: Gelände, entdeckte Orte, Spieler, Schatzkarten
class MapView extends Control:
	const HU := preload("res://scripts/ui/holo_ui.gd")
	const R := 215.0
	static var tex: Texture2D
	var world: Node

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if tex == null:
			var t: Terrain = world.terrain
			var n := 150
			var img := Image.create(n, n, false, Image.FORMAT_RGB8)
			for j in n:
				for i in n:
					var x := -R + (i + 0.5) / n * 2.0 * R
					var z := -R + (j + 0.5) / n * 2.0 * R
					var h := t.height_at(x, z)
					var c: Color
					if h < 0.05:
						c = Color(0.1, 0.2, 0.3)
					elif t.road_at(x, z) > 0.45:
						c = Color(0.42, 0.36, 0.26)
					else:
						var k := clampf((h - 2.0) / 30.0, 0.0, 1.0)
						c = Color(0.16, 0.22, 0.14).lerp(Color(0.45, 0.45, 0.47), k)
						c = c.lightened(clampf(t.normal_at(x, z).x * 0.6, -0.2, 0.2))
					img.set_pixel(i, j, c)
			tex = ImageTexture.create_from_image(img)

	func _process(_d: float) -> void:
		queue_redraw()

	func _to_map(p: Vector3, r: Rect2) -> Vector2:
		return r.position + Vector2((p.x + R) / (2.0 * R), (p.z + R) / (2.0 * R)) * r.size

	func _draw() -> void:
		var side := minf(size.x, size.y)
		var r := Rect2(Vector2((size.x - side) * 0.5, 0), Vector2(side, side))
		draw_texture_rect(tex, r, false, Color(0.8, 0.8, 0.85))
		draw_rect(r, Color(HU.CYAN, 0.4), false, 1.0)
		var s := PlayerStats.s
		for zn in world.ZONES:
			var c: Vector2 = zn[2]
			var mp := _to_map(Vector3(c.x, 0, c.y), r)
			if (s.discovered as Array).has(zn[0]):
				var col := HU.GOLD if world.TRAVEL.has(zn[0]) else (HU.RED if String(zn[0]).begins_with("altar") or String(zn[0]).begins_with("den") else HU.CYAN)
				draw_circle(mp, 3.5, col)
				draw_string(HU.F_SEMI, mp + Vector2(5, 4), String(zn[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(HU.FG, 0.85))
			else:
				draw_string(HU.F_BOLD, mp + Vector2(-3, 4), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(HU.MUTED, 0.5))
		for m in world.treasure.marks():
			var mp2 := _to_map(m[0], r)
			draw_line(mp2 + Vector2(-4, -4), mp2 + Vector2(4, 4), Color(1.0, 0.3, 0.2), 2.0)
			draw_line(mp2 + Vector2(-4, 4), mp2 + Vector2(4, -4), Color(1.0, 0.3, 0.2), 2.0)
		var pp: Vector3 = world.player.global_position
		var pm := _to_map(pp, r)
		var yaw: float = world.rig.yaw
		var f := Vector2(-sin(yaw), -cos(yaw))
		var rt := Vector2(-f.y, f.x)
		draw_colored_polygon(PackedVector2Array([pm + f * 8.0, pm - f * 4.0 + rt * 4.5, pm - f * 4.0 - rt * 4.5]), Color(1.0, 0.2, 0.3))

## Helligkeit (Gerätestand, bleibt auch bei neuem Spiel erhalten)
static func brightness_row(after: Callable) -> HBoxContainer:
	var h := H.hbox(8)
	var l := H.lbl("HELLIGKEIT", 12, H.MUTED, H.F_SEMI)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var minus := H.btn("  −  ", func():
		PlayerStats.set_brightness(PlayerStats.brightness - 0.15)
		after.call())
	h.add_child(minus)
	var v := H.lbl("%d %%" % int(round(PlayerStats.brightness * 100.0)), 13, H.FG, H.F_BOLD)
	v.custom_minimum_size = Vector2(56, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(v)
	var plus := H.btn("  +  ", func():
		PlayerStats.set_brightness(PlayerStats.brightness + 0.15)
		after.call())
	h.add_child(plus)
	return h

## Grafikstufe
static func quality_row(after: Callable) -> HBoxContainer:
	var h := H.hbox(6)
	var l := H.lbl("GRAFIK", 12, H.MUTED, H.F_SEMI)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	for q in 3:
		var b := H.btn(PlayerStats.QUALITY_NAMES[q], func():
			PlayerStats.set_quality(q)
			after.call(), "TabOn" if PlayerStats.quality == q else "Tab")
		b.custom_minimum_size = Vector2(74, 30)
		h.add_child(b)
	return h
