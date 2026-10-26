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
	var tabs := [["status", "STATUS" + (" •" if free_attr > 0 else "")], ["gear", "AUSRÜSTUNG"], ["blood", "BLUT"], ["skills", "FÄHIGKEITEN" + (" •" if free_sk > 0 else "")], ["chronicle", "CHRONIK"]]
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

func _buy(idx: int) -> void:
	if PlayerStats.buy(idx):
		if world:
			world.sfx("quest")
		rebuild()
