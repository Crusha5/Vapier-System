class_name Places
extends Node3D
## Orte von Veyra: Ruine der Alten (Start), Dorf Asch-Furt, Banditenlager, Wachturm,
## Schrein des Kults, Landerwrack und Obelisken. Gibt benannte Punkte für Story und NPCs zurück.

var terrain: Terrain
var spots := {}          # Name -> Vector3 (auf dem Boden)
var fires: Array = []    # [OmniLight3D, Basisenergie]
var glyphs: Array = []   # Leuchtende Glyphen-Materialien der Alten
var _t := 0.0
var cage_door: Node3D
var altar_core: MeshInstance3D

# Materialien
var m_wood: Material
var m_wood_dark: Material
var m_plank: Material
var m_roof: Material
var m_stone: Material
var m_stone_old: Material
var m_metal: Material
var m_cloth: Material
var m_cloth_red: Material
var m_glyph: Material
var m_fire: Material
var m_lamp: Material

func build(t: Terrain) -> void:
	terrain = t
	m_wood = Toon.tri("res://assets/village/wood_planks.png", Color(0.62, 0.55, 0.5), 0.55, 0.5)
	m_wood_dark = Toon.tri("res://assets/village/wood_dark.png", Color(0.6, 0.55, 0.52), 0.55, 0.5)
	m_plank = Toon.tri("res://assets/village/wood_planks.png", Color(0.75, 0.68, 0.6), 0.6, 0.4)
	m_roof = Toon.tri("res://assets/village/T_RoundTiles_BaseColor.png", Color(0.55, 0.45, 0.42), 0.5, 0.6)
	m_stone = Toon.tri("res://assets/village/T_UnevenBrick_BaseColor.png", Color(0.75, 0.74, 0.74), 0.45, 0.5, 0.35)
	m_stone_old = Toon.tri("res://assets/village/T_Brick_BaseColor.png", Color(0.42, 0.42, 0.5), 0.38, 0.8, 0.5)
	m_metal = Toon.mat(Color(0.35, 0.36, 0.38), {"metal": 0.6, "rough": 0.45, "grime": 0.6})
	m_cloth = Toon.mat(Color(0.48, 0.42, 0.32), {"grime": 0.6, "rough": 1.0})
	m_cloth_red = Toon.mat(Color(0.45, 0.08, 0.08), {"grime": 0.4, "rough": 1.0})
	m_glyph = Toon.mat(Color(0.9, 0.1, 0.15), {"emit": Color(1.0, 0.1, 0.15), "energy": 2.2})
	m_fire = Toon.mat(Color(1.0, 0.55, 0.2), {"emit": Color(1.0, 0.5, 0.15), "energy": 3.5})
	m_lamp = Toon.mat(Color(1.0, 0.8, 0.5), {"emit": Color(1.0, 0.75, 0.4), "energy": 3.0})
	_ruin()
	_village()
	_bandits()
	_tower()
	_shrine()
	_lander(Vector2(150, -175))
	for p in [Vector2(-110, -40), Vector2(30, -190), Vector2(-150, 30), Vector2(180, 90), Vector2(-40, 220)]:
		_obelisk(p)
	altar_core.set_meta("keep", true)
	cage_door.set_meta("keep", true)
	var n := Batcher.merge(self)
	print("Orte: ", n, " Meshes zusammengefasst")

func exclusions() -> Array:
	return [[Terrain.VILLAGE, 32.0], [Terrain.BANDITS, 17.0], [Terrain.RUIN, 20.0], [Terrain.TOWER, 12.0], [Terrain.SHRINE, 7.0], [Vector2(150, -175), 10.0]]

# ---------- Bausteine ----------

func gp(x: float, z: float, up := 0.0) -> Vector3:
	return Vector3(x, terrain.height_at(x, z) + up, z)

func _box(size: Vector3, pos: Vector3, mt: Material, rot := Vector3.ZERO, solid := true) -> MeshInstance3D:
	var mi := Toon.box(self, size, pos, mt, rot)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		sb.rotation = rot
		add_child(sb)
	return mi

func _cyl(r0: float, r1: float, hgt: float, pos: Vector3, mt: Material, segs := 8, rot := Vector3.ZERO, solid := false) -> MeshInstance3D:
	var mi := Toon.cyl(self, r0, r1, hgt, pos, mt, segs, rot)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := CylinderShape3D.new()
		sh.radius = maxf(r0, r1)
		sh.height = hgt
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		sb.rotation = rot
		add_child(sb)
	return mi

func _light(pos: Vector3, c: Color, energy: float, rng: float, flicker := true) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.3
	add_child(l)
	if flicker:
		fires.append([l, energy])
	return l

func _house(c: Vector2, rot: float, w := 6.0, d := 5.0, _tall := 2.8) -> Dictionary:
	# Maße auf das 2-m-Raster des Baukastens runden
	var wi := 8 if w > 6.8 else 6
	var di := 8 if d > 7.0 else 6
	var base := gp(c.x, c.y)
	var b := Basis(Vector3.UP, rot)
	var root := Node3D.new()
	root.position = base
	root.rotation.y = rot
	add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x * 31.0 + c.y * 17.0)
	# Fundament aus Stein (verdeckt Gelände-Unebenheiten)
	var fund := Toon.box(root, Vector3(wi + 0.5, 0.9, di + 0.5), Vector3(0, -0.42, 0), m_stone)
	fund.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var door_x := VillageKit.house(root, wi, di, "plaster" if rng.randf() < 0.6 else "brick", rng)
	var hw := wi * 0.5
	var hd := di * 0.5
	# Innen: Bett, Tisch, Truhe
	var bed_local := Vector3(-hw + 0.9, 0.35, hd - 1.4)
	Toon.box(root, Vector3(1.0, 0.35, 2.0), bed_local, m_wood_dark)
	Toon.box(root, Vector3(0.9, 0.12, 1.9), bed_local + Vector3(0, 0.22, 0), m_cloth)
	Toon.box(root, Vector3(1.2, 0.08, 0.8), Vector3(hw - 1.2, 1.0, hd - 1.1), m_plank)
	Toon.box(root, Vector3(0.1, 0.9, 0.1), Vector3(hw - 1.2, 0.55, hd - 1.1), m_wood_dark)
	Toon.box(root, Vector3(0.9, 0.5, 0.5), Vector3(hw - 0.8, 0.3, -hd + 0.8), m_wood)
	var inner := OmniLight3D.new()
	inner.position = Vector3(0, 2.2, 0.3)
	inner.light_color = Color(1.0, 0.6, 0.35)
	inner.light_energy = 0.8
	inner.omni_range = 5.5
	root.add_child(inner)
	# Kollision: Wände mit Türlücke
	var door := 1.3
	var lw := door_x - door * 0.5 + hw       # Länge links der Tür
	var rw := hw - (door_x + door * 0.5)     # rechts der Tür
	var tall := 3.2
	var boxes := [[Vector3(wi, tall, 0.4), Vector3(0, tall * 0.5, hd - 0.1)], [Vector3(0.4, tall, di), Vector3(-hw + 0.1, tall * 0.5, 0)], [Vector3(0.4, tall, di), Vector3(hw - 0.1, tall * 0.5, 0)],
		[Vector3(lw, tall, 0.4), Vector3(-hw + lw * 0.5, tall * 0.5, -hd + 0.1)], [Vector3(rw, tall, 0.4), Vector3(hw - rw * 0.5, tall * 0.5, -hd + 0.1)]]
	for cs in boxes:
		if (cs[0] as Vector3).x < 0.05:
			continue
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = cs[0]
		col.shape = sh
		sb.add_child(col)
		sb.position = base + b * (cs[1] as Vector3)
		sb.rotation.y = rot
		add_child(sb)
	var info := {
		"door_out": base + b * Vector3(door_x, 0, -hd - 1.2),
		"door_in": base + b * Vector3(door_x, 0, -hd + 1.0),
		"bed": base + b * (bed_local + Vector3(0, -0.35, 0)),
		"bed_rot": rot,
		"center": base,
		"rect": [base, rot, float(wi), float(di)],
	}
	if not spots.has("houses"):
		spots.houses = []
	spots.houses.append(info)
	return info

func _palisade(center: Vector2, radius: float, gaps: Array) -> void:
	var n := int(TAU * radius / 0.62)
	for i in n:
		var a := TAU * i / n
		var skip := false
		for g in gaps:
			if absf(wrapf(a - float(g[0]), -PI, PI)) < float(g[1]):
				skip = true
		if skip:
			continue
		var x := center.x + cos(a) * radius
		var z := center.y + sin(a) * radius
		var hgt := 3.0 + sin(i * 2.7) * 0.35
		var p := gp(x, z)
		Toon.cyl(self, 0.2, 0.26, hgt, p + Vector3(0, hgt * 0.5 - 0.2, 0), m_wood_dark, 6)
		var tip := Toon.cyl(self, 0.0, 0.2, 0.5, p + Vector3(0, hgt + 0.05, 0), m_wood_dark, 6)
		tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Kollision in Segmenten
	var segs := 36
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var am := (a0 + a1) * 0.5
		var skip := false
		for g in gaps:
			if absf(wrapf(am - float(g[0]), -PI, PI)) < float(g[1]) + 0.04:
				skip = true
		if skip:
			continue
		var pm := Vector2(center.x + cos(am) * radius, center.y + sin(am) * radius)
		var len := TAU * radius / segs + 0.4
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = Vector3(len, 4.0, 0.6)
		cs.shape = sh
		sb.add_child(cs)
		sb.position = gp(pm.x, pm.y, 1.5)
		sb.rotation.y = -am + PI * 0.5
		add_child(sb)

func _campfire(p: Vector3, big := false) -> void:
	var s := 1.4 if big else 1.0
	for i in 8:
		var a := TAU * i / 8.0
		Toon.sphere(self, 0.18 * s, p + Vector3(cos(a) * 0.6 * s, 0.05, sin(a) * 0.6 * s), m_stone, Vector3(1, 0.7, 1), 6)
	for i in 4:
		Toon.cyl(self, 0.06 * s, 0.06 * s, 0.9 * s, p + Vector3(0, 0.15, 0), m_wood_dark, 5, Vector3(PI * 0.5, i * PI * 0.25, 0))
	var f := Toon.cyl(self, 0.0, 0.32 * s, 0.7 * s, p + Vector3(0, 0.45 * s, 0), m_fire, 7)
	f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var embers := CPUParticles3D.new()
	var em := SphereMesh.new()
	em.radius = 0.03
	em.height = 0.06
	em.radial_segments = 4
	em.rings = 2
	embers.mesh = em
	embers.material_override = m_fire
	embers.amount = 14
	embers.lifetime = 1.6
	embers.direction = Vector3.UP
	embers.spread = 20.0
	embers.initial_velocity_min = 0.6
	embers.initial_velocity_max = 1.6
	embers.gravity = Vector3(0, 0.2, 0)
	embers.position = p + Vector3(0, 0.5, 0)
	add_child(embers)
	_light(p + Vector3(0, 1.2, 0), Color(1.0, 0.55, 0.25), 2.2 * s, 9.0 * s)

func _lantern(p: Vector3) -> void:
	Toon.cyl(self, 0.07, 0.09, 2.6, p + Vector3(0, 1.3, 0), m_wood_dark, 6)
	var l := _prop("lantern", p + Vector3(0, 2.0, 0.08), 0.0, 0.5)
	var glow := Toon.box(self, Vector3(0.12, 0.16, 0.12), p + Vector3(0.0, 2.35, 0.38), m_lamp)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light(p + Vector3(0.0, 2.3, 0.4), Color(1.0, 0.7, 0.4), 1.3, 8.0)

func _crate(p: Vector3, s := 1.0, rot := 0.0) -> void:
	VillageKit.piece(self, "Prop_Crate", p, rot, 0.8 * s)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(0.86, 0.85, 0.86) * s
	cs.shape = sh
	sb.add_child(cs)
	sb.position = p + Vector3(0, 0.42 * s, 0)
	sb.rotation.y = rot
	add_child(sb)

func _wagon(p: Vector3, rot: float) -> void:
	VillageKit.piece(self, "Prop_Wagon", p, rot)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(1.9, 1.4, 3.0)
	cs.shape = sh
	cs.position = Vector3(0, 0.7, -1.1)
	sb.add_child(cs)
	sb.position = p
	sb.rotation.y = rot
	add_child(sb)

func _fence(a: Vector3, b: Vector3) -> void:
	var dir := b - a
	var n := int(ceil(Vector2(dir.x, dir.z).length() / 2.05))
	for i in n:
		var t := (i + 0.5) / n
		var p := a.lerp(b, t)
		p = gp(p.x, p.z)
		VillageKit.piece(self, "Prop_WoodenFence_Single", p, -atan2(dir.z, dir.x))

func _barrel(p: Vector3) -> void:
	_prop("barrel-tall" if randf() < 0.5 else "keg", p, randf() * TAU, 0.85)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 0.45
	sh.height = 1.1
	cs.shape = sh
	sb.add_child(cs)
	sb.position = p + Vector3(0, 0.55, 0)
	add_child(sb)

## Requisit aus dem Greyhaven-Starter (Quaternius-Modelle, CC0)
func _prop(name: String, p: Vector3, rot_y := 0.0, s := 1.0) -> Node3D:
	var ps := load("res://assets/props/%s.lod1.gltf" % name) as PackedScene
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = p
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * s
	add_child(n)
	return n

func _tent(p: Vector3, rot: float, mt: Material) -> void:
	var tent := PrismMesh.new()
	tent.size = Vector3(3.0, 2.0, 3.6)
	var mi := Toon.mesh(self, tent, mt, p + Vector3(0, 1.0, 0), Vector3(0, rot, 0))
	mi.name = "Tent"
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(2.4, 1.6, 3.6)
	cs.shape = sh
	sb.add_child(cs)
	sb.position = p + Vector3(0, 0.8, 0)
	sb.rotation.y = rot
	add_child(sb)

# ---------- Ruine der Alten ----------

func _ruin() -> void:
	var c := Terrain.RUIN
	var base := gp(c.x, c.y)
	spots.ruin_altar = base + Vector3(0, 0, 0)
	spots.ruin_wake = gp(c.x + 2.5, c.y + 3.0)
	spots.ruin_exit = gp(c.x + 12.0, c.y + 18.0)
	spots.wounded = gp(c.x + 14.0, c.y + 22.0)
	# Bodenplatten-Kreis
	var disc := CylinderMesh.new()
	disc.top_radius = 11.0
	disc.bottom_radius = 11.3
	disc.height = 0.4
	disc.radial_segments = 24
	disc.rings = 1
	Toon.mesh(self, disc, m_stone_old, base + Vector3(0, 0.05, 0))
	# Stehende Bögen der Alten im Kreis
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		var p := base + Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
		var broken := i % 3 == 1
		var hgt := 6.5 if not broken else 3.0 + (i % 2)
		var pil := _box(Vector3(1.0, hgt, 1.2), p + Vector3(0, hgt * 0.5, 0), m_stone_old, Vector3(0, -a, 0.04 * (i % 2)))
		var gl := Toon.box(self, Vector3(0.08, hgt * 0.7, 0.3), p + Vector3(0, hgt * 0.45, 0) - Vector3(cos(a), 0, sin(a)) * 0.52, m_glyph, Vector3(0, -a, 0))
		gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not broken and i % 2 == 0:
			# Querbalken zum nächsten Pfeiler
			var a2 := a + TAU / 8.0
			var p2 := base + Vector3(cos(a2) * 9.0, 0, sin(a2) * 9.0)
			var mid := (p + p2) * 0.5 + Vector3(0, 6.6, 0)
			Toon.box(self, Vector3(p.distance_to(p2) + 1.0, 0.8, 1.0), mid, m_stone_old, Vector3(0, -atan2(p2.z - p.z, p2.x - p.x), 0))
		else:
			for k in 3:
				_box(Vector3(0.7, 0.5, 0.6), p + Vector3(randf_range(-1.6, 1.6), 0.25, randf_range(-1.6, 1.6)), m_stone_old, Vector3(randf(), randf() * TAU, 0), false)
	# Altar mit dem Herz der Ersten Nacht
	_box(Vector3(2.4, 1.0, 1.6), base + Vector3(0, 0.5, 0), m_stone_old)
	var heart := SphereMesh.new()
	heart.radius = 0.35
	heart.height = 0.8
	heart.radial_segments = 10
	heart.rings = 6
	altar_core = Toon.mesh(self, heart, Toon.mat(Color(0.35, 0.02, 0.05), {"emit": Color(0.9, 0.05, 0.1), "energy": 1.6, "rough": 0.3}), base + Vector3(0, 1.45, 0), Vector3.ZERO, false)
	for i in 5:
		var a := TAU * i / 5.0
		var spike := Toon.cyl(self, 0.0, 0.08, 0.9, base + Vector3(cos(a) * 0.45, 1.4, sin(a) * 0.45), m_stone_old, 5, Vector3(0, 0, 0.6).rotated(Vector3.UP, -a))
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var al := _light(base + Vector3(0, 2.0, 0), Color(1.0, 0.15, 0.2), 2.4, 12.0, false)
	al.set_meta("pulse", true)
	fires.append([al, 2.4])
	# Glyphen-Rinnen im Boden
	for i in 4:
		var a := TAU * i / 4.0 + PI * 0.25
		var g := Toon.box(self, Vector3(8.0, 0.05, 0.14), base + Vector3(cos(a) * 4.8, 0.27, sin(a) * 4.8), m_glyph, Vector3(0, -a, 0))
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Felsbrocken und Ranken: die Natur holt sich die Ruine zurück
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		var a := TAU * i / 9.0 + rng.randf() * 0.4
		var r := rng.randf_range(13.0, 19.0)
		var q := gp(c.x + cos(a) * r, c.y + sin(a) * r)
		_rock(q - Vector3(0, 0.4, 0), rng.randf_range(0.5, 1.1), rng.randf() * TAU, i % 2 == 0)
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		if i % 3 == 1:
			continue
		var p := base + Vector3(cos(a) * 9.0, 0, sin(a) * 9.0)
		var out := Vector3(cos(a), 0, sin(a))
		VillageKit.piece(self, ["Prop_Vine1", "Prop_Vine2", "Prop_Vine4"][i % 3], p + out * 0.62 + Vector3(0, rng.randf_range(3.0, 5.5), 0), -a + PI * 0.5)

func _rock(p: Vector3, s: float, rot: float, big: bool) -> void:
	var ps := load("res://assets/nature/%s.gltf" % ("Rock_Big_1" if big else "Rock_Medium_3")) as PackedScene
	var n := ps.instantiate() as Node3D
	n.position = p
	n.rotation.y = rot
	n.scale = Vector3.ONE * s
	add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = Toon.tri("res://assets/nature/Rocks_Diffuse.png", Color(0.62, 0.62, 0.66), 0.35, 0.5, 0.6)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = (2.2 if big else 1.3) * s
	sh.height = (4.0 if big else 2.0) * s
	cs.shape = sh
	sb.add_child(cs)
	sb.position = p + Vector3(0, sh.height * 0.5, 0)
	add_child(sb)

# ---------- Asch-Furt ----------

func _village() -> void:
	var c := Terrain.VILLAGE
	var houses := [
		[Vector2(-14, -12), 0.9, 6.0, 5.0], [Vector2(-2, -19), 0.0, 6.5, 5.0], [Vector2(14, -15), -0.6, 6.0, 5.0],
		[Vector2(19, 2), -PI * 0.5, 7.5, 6.0], [Vector2(12, 17), PI - 0.5, 6.0, 5.0], [Vector2(-6, 19), PI, 6.0, 5.0], [Vector2(-19, 8), PI * 0.5 + 0.3, 6.0, 5.0],
	]
	for hs in houses:
		var pos: Vector2 = c + hs[0]
		# Häuser schauen zur Dorfmitte
		var face := atan2(-(hs[0] as Vector2).x, -(hs[0] as Vector2).y)
		_house(pos, face + PI, hs[2], hs[3], 3.0 if hs[2] > 7.0 else 2.7)
	_palisade(c, 31.0, [[PI, 0.16], [-0.35, 0.14]])
	spots.village = gp(c.x, c.y)
	spots.village_gate_w = gp(c.x - 31.0, c.y)
	spots.village_gate_e = gp(c.x + cos(-0.35) * 31.0, c.y + sin(-0.35) * 31.0)
	spots.elder_house = gp(c.x + 19 - 4.5, c.y + 2)
	spots.tavern = gp(c.x - 2, c.y - 19 + 4.0)
	# Brunnen in der Mitte
	var w := gp(c.x, c.y)
	_cyl(1.2, 1.3, 0.9, w + Vector3(0, 0.45, 0), m_stone, 12, Vector3.ZERO, true)
	Toon.cyl(self, 1.05, 1.05, 0.1, w + Vector3(0, 0.85, 0), Toon.mat(Color(0.05, 0.08, 0.1), {"rough": 0.1}), 12)
	for sx in [-1.0, 1.0]:
		Toon.box(self, Vector3(0.18, 2.0, 0.18), w + Vector3(sx * 1.0, 1.4, 0), m_wood_dark)
	Toon.box(self, Vector3(2.4, 0.18, 0.18), w + Vector3(0, 2.4, 0), m_wood_dark)
	spots.well = w
	# Lagerfeuer
	var fire_p := gp(c.x + 6, c.y + 6)
	_campfire(fire_p, true)
	spots.fire = fire_p
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		_prop("bench", gp(fire_p.x + cos(a) * 2.6, fire_p.z + sin(a) * 2.6), -a + PI * 0.5, 0.75)
	# Käfig mit dem Gefangenen (nahe dem Westtor)
	var cg := gp(c.x - 20, c.y - 6)
	spots.cage = cg
	for i in 10:
		var a := TAU * i / 10.0
		if i == 0:
			continue
		_cyl(0.05, 0.05, 2.4, cg + Vector3(cos(a) * 1.1, 1.2, sin(a) * 1.1), m_metal, 5, Vector3.ZERO, true)
	Toon.cyl(self, 1.25, 1.25, 0.15, cg + Vector3(0, 2.45, 0), m_metal, 10)
	Toon.cyl(self, 1.2, 1.2, 0.12, cg + Vector3(0, 0.06, 0), m_wood_dark, 10)
	cage_door = Node3D.new()
	cage_door.position = cg + Vector3(1.1, 0, 0)
	add_child(cage_door)
	for k in 2:
		var bar := Toon.cyl(cage_door, 0.05, 0.05, 2.4, Vector3(0, 1.2, (k - 0.5) * 0.5), m_metal, 5)
		bar.name = "Bar%d" % k
	var door_body := StaticBody3D.new()
	door_body.name = "Body"
	var dcs := CollisionShape3D.new()
	var dsh := BoxShape3D.new()
	dsh.size = Vector3(0.2, 2.4, 0.9)
	dcs.shape = dsh
	dcs.position = Vector3(0, 1.2, 0)
	door_body.add_child(dcs)
	cage_door.add_child(door_body)
	# Marktstand
	var st := gp(c.x - 8, c.y + 4)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Toon.box(self, Vector3(0.14, 2.2, 0.14), st + Vector3(sx * 1.3, 1.1, sz * 0.8), m_wood_dark)
	Toon.box(self, Vector3(3.0, 0.12, 2.0), st + Vector3(0, 2.25, 0), m_cloth_red, Vector3(0.12, 0, 0))
	_box(Vector3(2.6, 0.9, 1.0), st + Vector3(0, 0.45, 0.3), m_plank)
	spots.market = st + Vector3(0, 0, -1.4)
	_prop("cart", gp(c.x - 12, c.y + 6), 0.5, 0.6)
	_prop("crate-low", gp(c.x - 9.5, c.y + 6.5), 0.2, 0.7)
	for p in [Vector2(-4, 10), Vector2(9, -6), Vector2(-24, 2), Vector2(4, 25)]:
		_lantern(gp(c.x + p.x, c.y + p.y))
	for p in [Vector2(16, 10), Vector2(17, 11.2), Vector2(-12, -6), Vector2(8, -22)]:
		_crate(gp(c.x + p.x, c.y + p.y), randf_range(0.8, 1.1), randf())
	for p in [Vector2(15.4, 12.4), Vector2(-11, -7.5), Vector2(-10.2, -6.5)]:
		_barrel(gp(c.x + p.x, c.y + p.y))
	_wagon(gp(c.x + 6, c.y - 9), 0.7)
	_wagon(gp(c.x + 36, c.y - 22), -0.3)
	# Zäune an den Feldern
	_fence(gp(c.x + 38, c.y - 20), gp(c.x + 54, c.y - 20))
	_fence(gp(c.x + 38, c.y + 16), gp(c.x + 54, c.y + 16))
	# Felder vor dem Dorf
	var field_m := Toon.mat(Color(0.32, 0.27, 0.15), {"grime": 0.9})
	for k in 3:
		var fp := gp(c.x + 46, c.y - 14 + k * 12)
		var fm := Toon.box(self, Vector3(14, 0.15, 9), fp + Vector3(0, 0.04, 0), field_m, Vector3(0, 0.1, 0))
		fm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# NPC-Plätze
	spots.npc_elder = gp(c.x + 12.5, c.y + 3)
	spots.npc_innkeeper = gp(c.x - 1, c.y - 14)
	spots.npc_smith = gp(c.x - 8, c.y + 2.2)
	spots.npc_guard = gp(c.x - 27, c.y + 2)
	spots.npc_child = gp(c.x + 3, c.y + 9)
	spots.npc_farmer = gp(c.x + 44, c.y - 2)
	spots.npc_widow = gp(c.x - 4, c.y + 14)

# ---------- Banditenlager ----------

func _bandits() -> void:
	var c := Terrain.BANDITS
	spots.bandits = gp(c.x, c.y)
	_campfire(gp(c.x, c.y), true)
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		_tent(gp(c.x + cos(a) * 9.0, c.y + sin(a) * 9.0), -a + PI * 0.5, m_cloth)
	_palisade(c, 16.0, [[-PI * 0.5 + 0.45, 0.28], [PI * 0.6, 0.5], [0.3, 0.6]])
	for p in [Vector2(4, -3), Vector2(4.8, -2.2), Vector2(-5, 4)]:
		_crate(gp(c.x + p.x, c.y + p.y), 1.0, randf())
	_barrel(gp(c.x - 4.2, c.y + 5.0))
	# Galgen
	var gal := gp(c.x - 6, c.y - 7)
	for sx in [-1.0, 1.0]:
		Toon.box(self, Vector3(0.22, 3.4, 0.22), gal + Vector3(sx * 1.2, 1.7, 0), m_wood_dark)
	Toon.box(self, Vector3(2.8, 0.22, 0.22), gal + Vector3(0, 3.35, 0), m_wood_dark)
	spots.bandit_chest = gp(c.x + 3, c.y + 6)
	_prop("chest", spots.bandit_chest, 0.4, 0.55)
	_prop("crate-long", gp(c.x + 5, c.y + 7), 1.2, 0.7)
	_prop("tub", gp(c.x - 3, c.y + 4), 0.0, 0.5)
	_barrel(gp(c.x + 6.5, c.y + 5.2))

# ---------- Wachturm ----------

func _tower() -> void:
	var c := Terrain.TOWER
	var p := gp(c.x, c.y)
	spots.tower = p
	# Runder Wachturm aus Bruchstein mit Ziegelhaube
	var tw := Toon.cyl(self, 2.7, 3.0, 10.0, p + Vector3(0, 4.9, 0), m_stone, 20)
	tw.name = "Tower"
	Toon.cyl(self, 3.05, 3.05, 0.4, p + Vector3(0, 9.9, 0), m_wood_dark, 20)
	var roof := VillageKit.piece(self, "Roof_Tower_RoundTiles", p + Vector3(0, 10.0, 0), 0.0, 1.08)
	VillageKit.piece(self, "Door_1_Round", p + Vector3(-0.53, 0.0, 2.95), 0.0)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		VillageKit.piece(self, "Window_Thin_Round1", p + Vector3(sin(a) * 2.78, 4.0 + (k % 2) * 2.4, cos(a) * 2.78), a)
	var tsb := StaticBody3D.new()
	var tcs := CollisionShape3D.new()
	var tsh := CylinderShape3D.new()
	tsh.radius = 2.9
	tsh.height = 10.0
	tcs.shape = tsh
	tsb.add_child(tcs)
	tsb.position = p + Vector3(0, 5.0, 0)
	add_child(tsb)
	# Banner der Wacht
	Toon.cyl(self, 0.06, 0.06, 3.0, p + Vector3(0, 18.6, 0), m_metal, 6)
	Toon.box(self, Vector3(1.6, 1.1, 0.05), p + Vector3(0.82, 19.4, 0), Toon.mat(Color(0.12, 0.2, 0.42), {"emit": Color(0.1, 0.2, 0.5), "energy": 0.3}))
	var beacon := Toon.sphere(self, 0.3, p + Vector3(0, 20.2, 0), Toon.mat(Color(0.5, 0.8, 1.0), {"emit": Color(0.4, 0.75, 1.0), "energy": 3.0}), Vector3.ONE, 8)
	beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light(p + Vector3(0, 8.0, 3.6), Color(0.5, 0.75, 1.0), 2.0, 14.0, false)
	_lantern(gp(c.x + 3.2, c.y + 3.6))
	for k in 2:
		_tent(gp(c.x - 8 + k * 5.0, c.y + 8), 0.3 * k, Toon.mat(Color(0.2, 0.26, 0.36), {"grime": 0.4}))
	_campfire(gp(c.x - 3, c.y + 5))
	spots.tower_guard = gp(c.x - 4, c.y + 3)

# ---------- Schrein des Kults (versteckt) ----------

func _shrine() -> void:
	var c := Terrain.SHRINE
	var p := gp(c.x, c.y)
	spots.shrine = p
	_box(Vector3(1.4, 4.2, 1.4), p + Vector3(0, 2.1, 0), m_stone_old)
	for i in 3:
		var g := Toon.box(self, Vector3(1.45, 0.08, 1.45), p + Vector3(0, 1.2 + i * 1.1, 0), m_glyph)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 6:
		var a := TAU * i / 6.0
		var q := p + Vector3(cos(a) * 2.4, 0, sin(a) * 2.4)
		Toon.cyl(self, 0.05, 0.06, 0.3, q + Vector3(0, 0.15, 0), Toon.mat(Color(0.85, 0.8, 0.7)), 6)
		var fl := Toon.sphere(self, 0.04, q + Vector3(0, 0.36, 0), m_fire, Vector3(1, 1.6, 1), 5)
		fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Opferschale
	_cyl(0.6, 0.35, 0.5, p + Vector3(0, 0.25, -1.6), m_stone_old, 10, Vector3.ZERO, true)
	Toon.cyl(self, 0.5, 0.5, 0.05, p + Vector3(0, 0.49, -1.6), Toon.mat(Color(0.35, 0.0, 0.03), {"emit": Color(0.5, 0.0, 0.05), "energy": 0.8, "rough": 0.15}), 10)
	_light(p + Vector3(0, 1.0, -1.6), Color(1.0, 0.25, 0.25), 1.3, 7.0)

# ---------- Landerwrack ----------

func _lander(c: Vector2) -> void:
	var p := gp(c.x, c.y)
	spots.lander = p
	var hull := Toon.mat(Color(0.5, 0.52, 0.55), {"metal": 0.5, "rough": 0.5, "grime": 0.9})
	_box(Vector3(5.0, 2.6, 9.0), p + Vector3(0, 1.0, 0), hull, Vector3(0.12, 0.6, 0.2))
	_box(Vector3(9.0, 0.3, 2.4), p + Vector3(-0.6, 1.4, 0.8), hull, Vector3(0.1, 0.6, -0.35))
	var cockpit := Toon.box(self, Vector3(3.0, 1.2, 1.6), p + Vector3(1.6, 1.8, -3.6), Toon.mat(Color(0.2, 0.35, 0.45), {"rough": 0.15, "metal": 0.3, "emit": Color(0.1, 0.3, 0.4), "energy": 0.3}), Vector3(0.12, 0.6, 0.2))
	cockpit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for k in 6:
		_box(Vector3(randf_range(0.5, 1.4), 0.15, randf_range(0.5, 1.2)), p + Vector3(randf_range(-6, 6), 0.08, randf_range(-6, 6)), hull, Vector3(randf() * 0.4, randf() * TAU, randf() * 0.4), false)
	var spark := _light(p + Vector3(0.5, 2.2, 0.0), Color(0.4, 0.8, 1.0), 1.2, 6.0)
	spark.set_meta("spark", true)

func _obelisk(c: Vector2) -> void:
	var p := gp(c.x, c.y)
	_box(Vector3(1.1, 5.0, 1.1), p + Vector3(0, 2.3, 0), m_stone_old, Vector3(0.05, randf() * TAU, 0.04))
	var g := Toon.box(self, Vector3(0.1, 3.0, 1.12), p + Vector3(0, 2.6, 0), m_glyph, Vector3(0, randf() * TAU, 0))
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not spots.has("obelisks"):
		spots.obelisks = []
	spots.obelisks.append(p)

# ---------- Laufzeit ----------

func tick(delta: float, night: float) -> void:
	VillageKit.set_night(night)
	_t += delta
	for f in fires:
		var l: OmniLight3D = f[0]
		var e: float = f[1]
		if l.has_meta("pulse"):
			l.light_energy = e * (0.8 + 0.35 * sin(_t * 2.2) + 0.15 * maxf(0.0, sin(_t * 5.0)))
		elif l.has_meta("spark"):
			l.light_energy = e * (1.0 if fmod(_t, 3.1) < 0.12 or fmod(_t + 0.4, 5.3) < 0.08 else 0.05)
		else:
			l.light_energy = e * (0.85 + 0.12 * sin(_t * 11.0 + l.position.x) + 0.08 * sin(_t * 23.0 + l.position.z)) * lerpf(0.55, 1.0, night)
	if altar_core:
		var s := 1.0 + sin(_t * 2.2) * 0.08
		altar_core.scale = Vector3(s, s * 1.1, s)
