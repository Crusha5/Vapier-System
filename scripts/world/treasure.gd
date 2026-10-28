class_name Treasure
extends Node3D
## Schätze von Veyra: Kisten (füllen sich nach zwei Tagen neu), verschlossene Truhen (Dietrich oder
## STR 7), Gräber der Alten (oft bewacht), blutgebundene Truhen (nur mit Blutsinn sichtbar),
## Logbuchseiten der „Hoffnung“, Blutaltäre und vergrabene Schätze aus Schatzkarten.

const KINDS := {
	"kiste": {"name": "Kiste", "verb": "KISTE ÖFFNEN", "scale": 0.62, "spark": Color(1.0, 0.85, 0.5)},
	"truhe": {"name": "Verschlossene Truhe", "verb": "TRUHE", "scale": 0.8, "spark": Color(0.45, 0.75, 1.0)},
	"grab": {"name": "Grab der Alten", "verb": "GRAB ÖFFNEN", "scale": 1.0, "spark": Color(0.85, 0.5, 1.0)},
	"versteckt": {"name": "Blutgebundene Truhe", "verb": "BLUTSIEGEL BRECHEN", "scale": 0.72, "spark": Color(1.0, 0.25, 0.35)},
}
const REFILL_DAYS := 2

const PAGES := [
	"Logbuch der „Hoffnung“, Tag 3: Der Schleier lässt kein Signal durch. Kapitän Morrow sagt, wir bauen eine Siedlung. Niemand widerspricht. Niemand glaubt ihm.",
	"Tag 19: Das Wasserrad dreht sich. Brot! Die Kinder lachen wieder. Nachts hören wir etwas im Wald, das wie ein Herz schlägt.",
	"Tag 41: Jäger Brann ist nicht zurückgekehrt. Wir fanden seine Hütte leer, die Felle zerrissen. Keine Spuren. Nur Blut, das nicht gerinnt.",
	"Tag 77: Unter den Hügeln im Westen liegen Gräber. Keine menschlichen. Die Inschriften leuchten, wenn man blutet.",
	"Tag 102: Morrow lässt die Station befestigen. Er sagt, die Alten hätten den Schleier gewoben – um etwas EINzusperren, nicht uns AUS.",
	"Tag 130: Die Wacht wurde gegründet. Gute Leute. Aber Varek ist jung und hasst alles, was er nicht versteht.",
	"Tag 166: Ich habe den nördlichsten Stein berührt. Er hat mit mir gesprochen. Mit der Stimme meiner toten Mutter. Ich gehe nicht mehr hin.",
	"Letzter Eintrag: Die Reißer kommen jede Nacht näher. Die Alphas führen sie. Wer das liest: Das Herz in der Ruine schläft nicht. Es WARTET. Auf einen Wirt.",
]

var w: Node
var terrain: Terrain
var objs: Array = []     # {id, kind, pos, rot, node, sk, bone, rest, lid, spark, col}
var pages: Array = []    # {i, pos, node}
var digs: Array = []     # Vector3
var dig_nodes := {}
var altars: Array = []
var _t := 0.0
var _slow := 0.0
var _dot: Texture2D
var m_stone_old: Material
var m_glyph: Material

# ---------- Planung (vor der Vegetation, damit keine Bäume in Truhen wachsen) ----------

func plan(t: Terrain, sp: Dictionary, keep_out: Array) -> void:
	terrain = t
	var g := func(v: Vector3) -> Vector3: return Vector3(v.x, t.height_at(v.x, v.z), v.z)
	var rb: Vector3 = sp.ruin_altar
	var fixed := [
		["f_camp", "kiste", sp.bandits + Vector3(-6.5, 0, 2.5), 1.2],
		["f_tower", "truhe", sp.tower + Vector3(4.3, 0, -1.2), -1.4],
		["f_lander", "versteckt", sp.lander + Vector3(5.5, 0, -3.5), 0.6],
		["f_ruin_g1", "grab", rb + Vector3(-23.0, 0, 7.0), 1.3],
		["f_ruin_g2", "grab", rb + Vector3(9.0, 0, -23.0), -0.3],
		["f_ruin_h", "versteckt", rb + Vector3(3.2, 0, -3.4), 2.2],
		["f_shrine", "grab", sp.shrine + Vector3(4.0, 0, 2.5), 0.5],
		["f_mill", "truhe", sp.mill_chest, PI * 0.5],
		["f_mill2", "kiste", sp.mill_front + Vector3(1.0, 0, -2.4), 0.4],
		["f_hut", "truhe", sp.hut_chest, 0.5 + PI * 0.5],
		["f_hut2", "kiste", sp.hut_front + Vector3(-1.5, 0, -2.0), 2.0],
		["f_bar0", "grab", sp.barrow_graves[0], 0.0],
		["f_bar1", "grab", sp.barrow_graves[1], 0.0],
		["f_bar2", "grab", sp.barrow_graves[2], 0.0],
		["f_bar_h", "versteckt", sp.barrow + Vector3(0.5, 0, 7.0), 2.8],
		["f_mor0", "truhe", sp.morrow_rooms[0], 0.2],
		["f_mor1", "truhe", sp.morrow_rooms[2], 0.1 + PI],
		["f_mor2", "kiste", sp.morrow_rooms[1], -0.3],
		["f_mor_h", "versteckt", sp.morrow_console + Vector3(-2.2, 0, 0.8), 1.0],
		["f_obel", "versteckt", sp.obelisks[4] + Vector3(3.0, 0, 2.0), 0.3],
	]
	for i in (sp.dens as Array).size():
		fixed.append(["f_den%d" % i, "kiste", (sp.dens[i] as Vector3) + Vector3(2.2, 0, 1.2), 2.6])
	for f in fixed:
		objs.append({"id": f[0], "kind": f[1], "pos": g.call(f[2]), "rot": float(f[3])})
	# Verstreute Schätze in der Wildnis (fester Zufall – überall gleich)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var n := 0
	var tries := 0
	while n < 22 and tries < 6000:
		tries += 1
		var p := Vector2(rng.randf_range(-195, 195), rng.randf_range(-195, 195))
		if not _free_spot(p, keep_out, 16.0):
			continue
		var r := rng.randf()
		var kind := "kiste" if r < 0.55 else ("truhe" if r < 0.8 else ("grab" if r < 0.9 else "versteckt"))
		objs.append({"id": "r%d" % n, "kind": kind, "pos": Vector3(p.x, t.height_at(p.x, p.y), p.y), "rot": rng.randf() * TAU})
		n += 1
	# Grabstellen für Schatzkarten
	rng.seed = 999
	tries = 0
	while digs.size() < PlayerStats.DIG_COUNT and tries < 6000:
		tries += 1
		var q := Vector2(rng.randf_range(-190, 190), rng.randf_range(-190, 190))
		if not _free_spot(q, keep_out, 30.0):
			continue
		digs.append(Vector3(q.x, t.height_at(q.x, q.y), q.y))
	pages = []
	for i in (sp.pages as Array).size():
		pages.append({"i": i, "pos": sp.pages[i]})
	altars = sp.altars

func _free_spot(p: Vector2, keep_out: Array, min_d: float) -> bool:
	if p.length() > 195.0:
		return false
	if terrain.river_dist(p.x, p.y) < 9.0 or terrain.height_at(p.x, p.y) < 1.3:
		return false
	if terrain.normal_at(p.x, p.y).y < 0.88 or terrain.road_at(p.x, p.y) > 0.15:
		return false
	for ex in keep_out:
		if p.distance_to(ex[0]) < float(ex[1]) + 4.0:
			return false
	for o in objs:
		var op: Vector3 = o.pos
		if p.distance_to(Vector2(op.x, op.z)) < min_d:
			return false
	for d in digs:
		if p.distance_to(Vector2((d as Vector3).x, (d as Vector3).z)) < min_d:
			return false
	return true

func exclusions() -> Array:
	var ex: Array = []
	for o in objs:
		var p: Vector3 = o.pos
		ex.append([Vector2(p.x, p.z), 2.2])
	for d in digs:
		ex.append([Vector2((d as Vector3).x, (d as Vector3).z), 1.5])
	return ex

# ---------- Aufbau ----------

func build(world: Node) -> void:
	w = world
	m_stone_old = Toon.tri("res://assets/village/T_Brick_BaseColor.png", Color(0.42, 0.42, 0.5), 0.38, 0.8, 0.5)
	m_glyph = Toon.mat(Color(0.9, 0.1, 0.15), {"emit": Color(1.0, 0.1, 0.15), "energy": 2.2})
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2.2))
	_dot = ImageTexture.create_from_image(img)
	for o in objs:
		_make(o)
	for pg in pages:
		if not (PlayerStats.s.pages as Array).has(int(pg.i)):
			_make_page(pg)
	_refresh_digs()

func _spark(parent: Node3D, col: Color, y: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.texture = _dot
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.pixel_size = 0.03
	s.modulate = col
	s.position.y = y
	s.render_priority = 4
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(s)
	return s

func _make(o: Dictionary) -> void:
	var root := Node3D.new()
	root.position = o.pos
	root.rotation.y = o.rot
	add_child(root)
	o.node = root
	var k: Dictionary = KINDS[o.kind]
	var sc: float = k.scale
	if o.kind == "grab":
		var base := Toon.box(root, Vector3(1.1, 0.4, 2.1), Vector3(0, 0.15, 0), m_stone_old)
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var lid := Node3D.new()
		lid.position = Vector3(0, 0.35, 0)
		root.add_child(lid)
		Toon.box(lid, Vector3(1.25, 0.18, 2.25), Vector3(0, 0.09, 0), m_stone_old)
		var gl := Toon.box(lid, Vector3(0.12, 0.03, 1.6), Vector3(0, 0.19, 0), m_glyph)
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Toon.box(root, Vector3(0.95, 1.25, 0.26), Vector3(0, 0.55, -1.3), m_stone_old, Vector3(-0.08, 0, 0.04))
		var g2 := Toon.box(root, Vector3(0.5, 0.06, 0.28), Vector3(0, 0.85, -1.3), m_glyph, Vector3(-0.08, 0, 0.04))
		g2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for sx in [-0.75, 0.75]:
			Toon.cyl(root, 0.05, 0.06, 0.25, Vector3(sx, 0.12, 1.15), Toon.mat(Color(0.85, 0.8, 0.7)), 6)
			var fl := Toon.sphere(root, 0.035, Vector3(sx, 0.3, 1.15), Toon.mat(Color(1.0, 0.55, 0.2), {"emit": Color(1.0, 0.5, 0.15), "energy": 3.5}), Vector3(1, 1.6, 1), 5)
			fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		o.lid = lid
		Toon.collider(root, Vector3(1.2, 0.7, 2.6), Vector3(0, 0.35, -0.2))
		o.spark = _spark(root, k.spark, 1.2)
	else:
		var ps := load("res://assets/props/chest.lod1.gltf") as PackedScene
		var n := ps.instantiate() as Node3D
		n.scale = Vector3.ONE * sc
		root.add_child(n)
		var sks := n.find_children("*", "Skeleton3D", true, false)
		if not sks.is_empty():
			var sk := sks[0] as Skeleton3D
			o.sk = sk
			o.bone = sk.find_bone("Chest_Top")
			o.rest = sk.get_bone_pose_rotation(int(o.bone)) if int(o.bone) >= 0 else Quaternion.IDENTITY
		if o.kind == "truhe":
			var gold := Toon.mat(Color(0.8, 0.62, 0.25), {"metal": 0.8, "rough": 0.35})
			Toon.box(root, Vector3(0.14, 0.18, 0.06), Vector3(0, 0.36 * sc / 0.8, 0.36 * sc / 0.8), gold)
			for sx in [-0.3, 0.3]:
				Toon.box(root, Vector3(0.05, 0.5, 0.6), Vector3(sx * sc / 0.8, 0.25 * sc / 0.8, 0.0), Toon.mat(Color(0.25, 0.25, 0.27), {"metal": 0.7, "rough": 0.4}))
		if o.kind == "versteckt":
			# Blutsiegel: rot leuchtender Kreis unter der Truhe, Siegel-Glyphe auf dem Deckel
			var ring := Toon.quad_holo(root, Vector2(1.8, 1.8), Vector3(0, 0.06, 0), Toon.holo(Color(1.0, 0.15, 0.25), 1.8, true, 0.0))
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var seal := Toon.box(root, Vector3(0.36, 0.03, 0.36), Vector3(0, 0.66 * sc / 0.72, 0.05), m_glyph, Vector3(0, PI * 0.25, 0))
			seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			seal.name = "Seal"
		Toon.collider(root, Vector3(0.95, 0.75, 0.65) * sc, Vector3(0, 0.37 * sc, 0))
		o.spark = _spark(root, k.spark, 1.1 * sc + 0.35)
	for gi in root.find_children("*", "GeometryInstance3D", true, false):
		if gi is Sprite3D:
			continue
		(gi as GeometryInstance3D).visibility_range_end = 80.0
	if not available(o):
		_set_open(o, true)

func _make_page(pg: Dictionary) -> void:
	var n := Node3D.new()
	n.position = pg.pos + Vector3(0, 0.9, 0)
	add_child(n)
	var paper := Toon.box(n, Vector3(0.3, 0.015, 0.4), Vector3.ZERO, Toon.mat(Color(0.95, 0.9, 0.75), {"emit": Color(0.55, 0.8, 1.0), "energy": 0.7}), Vector3(0.6, 0, 0.2))
	paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	paper.name = "Paper"
	var ring := Toon.quad_holo(n, Vector2(0.9, 0.9), Vector3(0, -0.85, 0), Toon.holo(Color(0.35, 0.8, 1.0), 1.2, true, 0.0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pg.spark = _spark(n, Color(0.5, 0.85, 1.0), 0.35)
	pg.node = n

func _refresh_digs() -> void:
	var maps: Array = PlayerStats.s.maps
	for i in digs.size():
		var want := maps.has(i) and not (PlayerStats.s.dug as Array).has(i)
		if want and not dig_nodes.has(i):
			var n := Node3D.new()
			n.position = digs[i]
			add_child(n)
			var red := Toon.mat(Color(0.6, 0.05, 0.05), {"emit": Color(0.9, 0.08, 0.08), "energy": 1.6})
			for a in [PI * 0.25, -PI * 0.25]:
				var b := Toon.box(n, Vector3(1.6, 0.04, 0.22), Vector3(0, 0.06, 0), red, Vector3(0, a, 0))
				b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Toon.sphere(n, 0.5, Vector3(0, -0.15, 0), Toon.mat(Color(0.3, 0.22, 0.15), {"rough": 1.0}), Vector3(1.4, 0.5, 1.4), 8)
			_spark(n, Color(1.0, 0.3, 0.2), 1.0)
			dig_nodes[i] = n
		elif not want and dig_nodes.has(i):
			(dig_nodes[i] as Node).queue_free()
			dig_nodes.erase(i)

# ---------- Zustand ----------

func available(o: Dictionary) -> bool:
	var st := PlayerStats.chest_state(String(o.id))
	if st < 0:
		return true
	return o.kind == "kiste" and int(PlayerStats.s.day) - st >= REFILL_DAYS

func _set_open(o: Dictionary, open: bool, animate := false) -> void:
	o.is_open = open
	if o.has("spark") and o.spark:
		(o.spark as Sprite3D).visible = not open
	if o.kind == "grab":
		var lid: Node3D = o.lid
		var to_pos := Vector3(0.75, 0.25, 0.15) if open else Vector3(0, 0.35, 0)
		var to_rot := Vector3(0, 0.25, -0.45) if open else Vector3.ZERO
		if animate:
			var tw := create_tween().set_parallel(true)
			tw.tween_property(lid, "position", to_pos, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(lid, "rotation", to_rot, 0.7)
		else:
			lid.position = to_pos
			lid.rotation = to_rot
		return
	var seal := (o.node as Node3D).get_node_or_null("Seal")
	if seal:
		seal.visible = not open
	if not o.has("sk") or int(o.bone) < 0:
		return
	var sk: Skeleton3D = o.sk
	var bone: int = o.bone
	var rest: Quaternion = o.rest
	var target := -1.9 if open else 0.0
	if animate:
		var tw2 := create_tween()
		tw2.tween_method(func(a: float): sk.set_bone_pose_rotation(bone, rest * Quaternion(Vector3.RIGHT, a)), 0.0, target, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		sk.set_bone_pose_rotation(bone, rest * Quaternion(Vector3.RIGHT, target))

func opened_count() -> int:
	var n := 0
	for o in objs:
		if PlayerStats.chest_state(String(o.id)) >= 0:
			n += 1
	return n

# ---------- Laufzeit ----------

func tick(delta: float, sense: float) -> void:
	if w == null:
		return
	_t += delta
	var pp: Vector3 = w.player.global_position
	var pulse := 1.0 + 0.3 * sin(_t * 4.0)
	for o in objs:
		var sp: Sprite3D = o.get("spark")
		var d := pp.distance_to(o.pos)
		var hidden: bool = o.kind == "versteckt"
		var open: bool = o.get("is_open", false)
		if hidden:
			(o.node as Node3D).visible = (sense > 0.3 or open) and d < 80.0
		if sp == null:
			continue
		if open:
			sp.visible = false
			continue
		var seen := (d < 30.0 and not hidden) or (sense > 0.3 and d < 70.0)
		sp.visible = seen
		if seen:
			sp.no_depth_test = sense > 0.3
			sp.scale = Vector3.ONE * pulse * (1.6 if sense > 0.3 else 1.0)
	for pg in pages:
		if pg.has("node") and is_instance_valid(pg.node):
			var n: Node3D = pg.node
			if pp.distance_to(n.position) < 45.0:
				n.get_node("Paper").rotation.y += delta * 1.2
				n.position.y = (pg.pos as Vector3).y + 0.9 + sin(_t * 2.0 + float(pg.i)) * 0.08
				(pg.spark as Sprite3D).no_depth_test = sense > 0.3
	# Kisten füllen sich nach ein paar Tagen neu
	_slow -= delta
	if _slow <= 0.0:
		_slow = 2.0
		for o in objs:
			if o.kind == "kiste" and o.get("is_open", false) and available(o) and pp.distance_to(o.pos) > 25.0:
				_set_open(o, false)

## Interaktion am Boden-Punkt pp: [id, Text, Warnung] oder []
func interaction(pp: Vector3, sense: bool) -> Array:
	var best := -1
	var bd := 9.0
	for i in objs.size():
		var o: Dictionary = objs[i]
		var reach := 2.3 if o.kind == "grab" else 1.8
		var d := pp.distance_to(o.pos)
		if d < reach and d < bd and available(o):
			if o.kind == "versteckt" and not sense:
				continue
			best = i
			bd = d
	if best >= 0:
		var o: Dictionary = objs[best]
		match String(o.kind):
			"truhe":
				if int(PlayerStats.s.picks) > 0:
					return ["tr:%d" % best, "TRUHE AUFSCHLIESSEN", "1 von %d Dietrichen" % int(PlayerStats.s.picks)]
				if PlayerStats.stat("str") >= 7:
					return ["tr:%d" % best, "TRUHE AUFBRECHEN", "STR %d" % PlayerStats.stat("str")]
				return ["trl:%d" % best, "VERSCHLOSSEN", "Dietrich oder STR 7 nötig"]
			"grab":
				return ["tr:%d" % best, "GRAB ÖFFNEN", "Die Alten ruhen nicht immer"]
			_:
				return ["tr:%d" % best, KINDS[o.kind].verb, ""]
	for pg in pages:
		if pg.has("node") and is_instance_valid(pg.node) and pp.distance_to(pg.pos) < 1.8:
			return ["pg:%d" % int(pg.i), "LOGBUCHSEITE LESEN", "%d / %d gefunden" % [(PlayerStats.s.pages as Array).size(), PlayerStats.PAGE_COUNT]]
	for i in altars.size():
		if pp.distance_to(altars[i]) < 2.6 and not (PlayerStats.s.altars as Array).has(i):
			return ["al:%d" % i, "BLUTOPFER DARBRINGEN", "kostet 25 Blut"]
	for i in dig_nodes:
		if pp.distance_to(digs[i]) < 2.4:
			return ["dg:%d" % int(i), "SCHATZ AUSGRABEN", ""]
	return []

func interact(id: String) -> void:
	var parts := id.split(":")
	var i := int(parts[1])
	match parts[0]:
		"tr":
			_open(i)
		"trl":
			PlayerStats.system_message.emit("Verschlossen. Du brauchst einen Dietrich (Oswin, Truhen) oder STR 7.", "warn")
		"pg":
			_read_page(i)
		"al":
			_altar(i)
		"dg":
			_dig(i)

func _open(i: int) -> void:
	var o: Dictionary = objs[i]
	if not available(o):
		return
	var how := ""
	if o.kind == "truhe":
		if int(PlayerStats.s.picks) > 0:
			PlayerStats.s.picks = int(PlayerStats.s.picks) - 1
			how = "Der Dietrich knackt im Schloss."
		else:
			how = "Du reißt den Deckel mit bloßer Kraft auf."
	PlayerStats.s.chests[String(o.id)] = int(PlayerStats.s.day)
	PlayerStats.bump("chests")
	if o.kind == "grab":
		PlayerStats.bump("graves")
	_set_open(o, true, true)
	w.sfx("quest")
	var pos: Vector3 = o.pos
	w.burst(pos + Vector3(0, 0.7, 0), KINDS[o.kind].spark, 1.6)
	if how != "":
		PlayerStats.system_message.emit(how, "mini")
	await get_tree().create_timer(0.35).timeout
	var fwd := Vector3(0, 0, 1.4).rotated(Vector3.UP, float(o.rot))
	give(String(o.kind), pos + fwd)
	if o.kind == "grab" and (String(o.id) == "f_bar2" or randf() < 0.45):
		await get_tree().create_timer(0.6).timeout
		PlayerStats.system_message.emit("Etwas erhebt sich aus dem Grab!", "warn")
		w.spawn_elite("ghoul", pos + Vector3(0, 0, -2.5).rotated(Vector3.UP, float(o.rot)))
	PlayerStats.save_game()

## Beute ausschütten. Gibt eine Zusammenfassung als Systemmeldung aus.
func give(kind: String, pos: Vector3) -> void:
	var s := PlayerStats.s
	var lvl := int(s.level)
	var luck := PlayerStats.luck()
	var jackpot := randf() < 0.05 + luck
	var parts: Array = []
	var shards := 0
	var top := 0
	for r in (2 if jackpot else 1):
		match kind:
			"kiste":
				shards += randi_range(8, 16) + lvl * 2
				if randf() < 0.35:
					var v: String = ["animal", "beast", "animal"][randi() % 3]
					s.inventory[v] = int(s.inventory.get(v, 0)) + 1
					parts.append(PlayerStats.BLOOD_TYPES[v].name)
				if randf() < 0.3:
					PlayerStats.add_crystal(0, 1, true)
					parts.append(PlayerStats.crystal_name(0))
				if randf() < 0.2:
					PlayerStats.add_picks(1)
					parts.append("Dietrich")
				if randf() < 0.22 + luck:
					w.spawn_loot(Items.random_drop(lvl, luck), pos)
			"truhe":
				shards += randi_range(25, 45) + lvl * 4
				var c := 1 + randi() % 2
				PlayerStats.add_crystal(0, c, true)
				parts.append("%d× %s" % [c, PlayerStats.crystal_name(0)])
				if randf() < 0.35:
					PlayerStats.add_crystal(1, 1, true)
					parts.append(PlayerStats.crystal_name(1))
					top = maxi(top, 1)
				if randf() < 0.2:
					s.inventory.human = int(s.inventory.get("human", 0)) + 1
					parts.append("Menschenblut")
				w.spawn_loot(Items.random_drop(lvl + 1, luck + 0.1, 1), pos)
				if randf() < 0.25 and PlayerStats.add_map():
					w.treasure_maps_changed()
			"grab":
				shards += randi_range(40, 70) + lvl * 5
				var c2 := 1 + randi() % 2
				PlayerStats.add_crystal(1, c2, true)
				parts.append("%d× %s" % [c2, PlayerStats.crystal_name(1)])
				top = maxi(top, 1)
				if randf() < 0.25:
					PlayerStats.add_crystal(2, 1, true)
					parts.append(PlayerStats.crystal_name(2))
					top = 2
				w.spawn_loot(Items.random_drop(lvl + 1, luck + 0.2, 1), pos)
				if randf() < 0.4:
					w.spawn_loot(Items.random_drop(lvl, luck), pos + Vector3(0.8, 0, 0))
				if randf() < 0.3 and PlayerStats.add_map():
					w.treasure_maps_changed()
			"versteckt":
				shards += randi_range(60, 100) + lvl * 6
				PlayerStats.add_crystal(2, 1, true)
				parts.append(PlayerStats.crystal_name(2))
				top = 2
				w.spawn_loot(Items.random_drop(lvl + 2, luck + 0.25, 2), pos)
				if randf() < 0.5:
					PlayerStats.add_picks(2)
					parts.append("2 Dietriche")
			"dig":
				shards += randi_range(80, 140) + lvl * 6
				PlayerStats.add_crystal(1, 2, true)
				parts.append("2× %s" % PlayerStats.crystal_name(1))
				top = maxi(top, 1)
				if randf() < 0.35:
					PlayerStats.add_crystal(2, 1, true)
					parts.append(PlayerStats.crystal_name(2))
					top = 2
				w.spawn_loot(Items.random_drop(lvl + 1, luck + 0.3, 2 if randf() < 0.45 else 1), pos)
	PlayerStats.add_shards(shards)
	parts.push_front("+%d Blutsplitter" % shards)
	if jackpot:
		w.hud.show_banner("GLÜCKSTREFFER – DOPPELTE BEUTE")
		w.burst(pos + Vector3(0, 1.0, 0), Color(1.0, 0.8, 0.3), 2.4)
	PlayerStats.system_message.emit("  ·  ".join(parts), "loot%d" % top)
	PlayerStats.stats_changed.emit()

func _read_page(i: int) -> void:
	var s := PlayerStats.s
	if (s.pages as Array).has(i):
		return
	(s.pages as Array).append(i)
	for pg in pages:
		if int(pg.i) == i and pg.has("node") and is_instance_valid(pg.node):
			w.burst((pg.node as Node3D).position, Color(0.5, 0.85, 1.0), 1.0)
			(pg.node as Node).queue_free()
	PlayerStats.add_xp(40)
	PlayerStats.add_shards(10)
	var n := (s.pages as Array).size()
	var lines := [{"who": "LOGBUCHSEITE %d / %d" % [n, PlayerStats.PAGE_COUNT], "text": PAGES[i % PAGES.size()]}]
	PlayerStats.check_titles()
	if n >= PlayerStats.PAGE_COUNT and not PlayerStats.flag("pages_reward"):
		PlayerStats.set_flag("pages_reward")
		var it := Items.make("relic", int(s.level) + 2, 3)
		it.name = "Siegel der Hoffnung"
		w.spawn_loot(it, w.player.global_position + w.player.facing * 1.5)
		lines.append({"who": "SYSTEM", "text": "Logbuch vollständig. Belohnung: Legendäres Relikt „Siegel der Hoffnung“."})
	w.story.say(lines)
	PlayerStats.save_game()

func _altar(i: int) -> void:
	var s := PlayerStats.s
	if (s.altars as Array).has(i):
		return
	if not PlayerStats.spend_blood(25.0):
		return
	(s.altars as Array).append(i)
	s.attr_points = int(s.attr_points) + 1
	var p: Vector3 = altars[i]
	w.burst(p + Vector3(0, 1.4, 0), Color(1.0, 0.1, 0.15), 2.2)
	w.hud.red_flash = 0.7
	w.sfx("level")
	PlayerStats.check_titles()
	PlayerStats.system_message.emit("Blutaltar: +1 Attributpunkt (dauerhaft)", "reward")
	var lore := ["Blut für Blut. Die Alten nehmen – und geben zurück.", "Du spürst, wie etwas Altes in deine Adern sickert.", "Drei Altäre. Drei Opfer. Die Wiege erinnert sich an dich."]
	w.story.say([{"who": "DIE ERSTE NACHT", "text": lore[i % lore.size()]}, {"who": "SYSTEM", "text": "Blutaltäre geopfert: %d / %d" % [(s.altars as Array).size(), altars.size()]}])
	PlayerStats.save_game()

func _dig(i: int) -> void:
	var s := PlayerStats.s
	if (s.dug as Array).has(i):
		return
	(s.maps as Array).erase(i)
	(s.dug as Array).append(i)
	PlayerStats.bump("digs")
	w.player.model.play("kneel")
	w.sfx("hit")
	var p: Vector3 = digs[i]
	for k in 3:
		w.burst(p + Vector3(randf_range(-0.4, 0.4), 0.3, randf_range(-0.4, 0.4)), Color(0.4, 0.3, 0.2), 1.0)
	await get_tree().create_timer(0.6).timeout
	_refresh_digs()
	give("dig", p + Vector3(1.0, 0, 0))
	w.hud.show_banner("VERGRABENER SCHATZ")
	PlayerStats.save_game()

func marks() -> Array:
	var out: Array = []
	for i in dig_nodes:
		out.append([digs[i], Color(1.0, 0.3, 0.2), "SCHATZ"])
	return out

## Kompass-Hinweis bei aktivem Blutsinn: nächster ungeöffneter Schatz
func nearest_hint(pp: Vector3) -> Array:
	var best: Dictionary = {}
	var bd := 120.0
	for o in objs:
		if available(o):
			var d := pp.distance_to(o.pos)
			if d < bd:
				bd = d
				best = o
	if best.is_empty():
		return []
	return [best.pos, KINDS[best.kind].spark, "SCHATZ"]
