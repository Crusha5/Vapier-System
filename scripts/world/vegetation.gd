class_name Vegetation
extends Node3D
## Pflanzen und Felsen aus dem Quaternius „Stylized Nature MegaKit“ (CC0) als MultiMesh je 64-m-Chunk.
## Nah: echte Modelle mit Textur (düster eingefärbt, Wind). Fern: einfache prozedurale Ersatz-Bäume.
## Gras in 16-m-Feldern mit kurzer Sichtweite. Stämme und große Felsen bekommen Kollision.

const FOLIAGE := preload("res://shaders/foliage.gdshader")
const CUT := preload("res://shaders/flora_cut.gdshader")
const SOLID := preload("res://shaders/flora_solid.gdshader")

const KITS := {
	"pine": ["Pine_1", "Pine_4"],
	"oak": ["CommonTree_1", "CommonTree_3"],
	"dead": ["DeadTree_1", "DeadTree_3"],
	"birch": ["Birch_1"],
	"giant": ["GiantPine_1"],
	"twisted": ["TwistedTree_1"],
	"bush": ["Bush_Common", "Bush_Large"],
	"fern": ["Fern_1", "Plant_7"],
	"rock": ["Rock_Medium_1", "Rock_Medium_3"],
	"boulder": ["Rock_Big_1", "Rock_Big_2"],
	"grass": ["Grass_Common_Short", "Grass_Wispy_Tall"],
	"flower": ["Flower_3_Group"],
	"shroom": ["Mushroom_Common", "Mushroom_RedCap"],
}
## Ersatz in der Ferne (prozedural, sehr wenige Dreiecke)
const FAR := {"pine": "far_pine", "giant": "far_pine", "oak": "far_oak", "birch": "far_oak", "twisted": "far_oak", "dead": "far_dead"}
const NEAR_RANGE := 105.0
const FAR_RANGE := 270.0

var terrain: Terrain
var forest := FastNoiseLite.new()
var meadow := FastNoiseLite.new()
var meshes := {}       # Variante -> ArrayMesh
var heights := {}      # Variante -> Höhe
var mats := {}
var keep_out: Array = []

func generate(t: Terrain, exclusions: Array) -> void:
	terrain = t
	keep_out = exclusions
	forest.seed = 4242
	forest.frequency = 1.0 / 95.0
	forest.fractal_octaves = 3
	meadow.seed = 99
	meadow.frequency = 1.0 / 40.0
	_load_kits()
	meshes.patch = _patch(false, 11)
	meshes.patch_b = _patch(false, 23)
	meshes.patch_flower = _patch(true, 37)
	meshes.far_pine = _pine()
	meshes.far_oak = _oak()
	meshes.far_dead = _dead()
	var chunks := int(ceil(Terrain.SIZE / 64.0))
	var shapes := 0
	for cj in chunks:
		for ci in chunks:
			shapes += _chunk(ci, cj)
	print("Vegetation: ", shapes, " Kollisionen")

# ---------- Modelle laden ----------

func _load_kits() -> void:
	for kind in KITS:
		for v in KITS[kind]:
			if meshes.has(v):
				continue
			var ps := load("res://assets/nature/%s.gltf" % v) as PackedScene
			if ps == null:
				push_warning("Fehlt: " + v)
				continue
			var root := ps.instantiate()
			var mi := _find_mesh(root)
			if mi == null:
				root.free()
				continue
			var mesh := mi.mesh as ArrayMesh
			for i in mesh.get_surface_count():
				var src := mesh.surface_get_material(i)
				if mi.get_surface_override_material(i):
					src = mi.get_surface_override_material(i)
				mesh.surface_set_material(i, _convert(src, kind, mesh.get_aabb().size.y))
			meshes[v] = mesh
			heights[v] = mesh.get_aabb().size.y
			root.free()

## Grasbüschel-Gruppe: mehrere Halm-Modelle in einem Mesh (ein Draw-Call je 16-m-Feld)
func _patch(flowers: bool, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var by_mat := {}
	for i in 7:
		var v: String = ["Grass_Common_Short", "Grass_Common_Short", "Grass_Wispy_Tall"][rng.randi() % 3]
		if flowers and i < 2:
			v = "Flower_3_Group"
		var src: ArrayMesh = meshes[v]
		var target := (0.75 if v.begins_with("Grass") else 0.45) * rng.randf_range(0.6, 1.2)
		var sc := target / maxf(0.1, float(heights[v]))
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 1.6)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(sc, sc * rng.randf_range(0.85, 1.2), sc)), Vector3(cos(a) * r, -0.05, sin(a) * r))
		for sidx in src.get_surface_count():
			var m := src.surface_get_material(sidx)
			if not by_mat.has(m):
				by_mat[m] = SurfaceTool.new()
			(by_mat[m] as SurfaceTool).append_from(src, sidx, xf)
	var out := ArrayMesh.new()
	for m in by_mat:
		var st: SurfaceTool = by_mat[m]
		st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, m)
	return out

func _find_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _find_mesh(c)
		if r:
			return r
	return null

## Eigenes, mobilfreundliches Material aus dem importierten StandardMaterial3D
func _convert(src: Material, kind: String, h: float) -> ShaderMaterial:
	var sm := src as BaseMaterial3D
	var tex: Texture2D = sm.albedo_texture if sm else null
	var cut := sm != null and sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
	var name := sm.resource_name if sm else ""
	if name.contains("Leaves") or name.contains("Leaf") or name == "Grass" or name == "Flowers":
		cut = true
	var key := "%s|%s|%s" % [name, kind, cut]
	if mats.has(key):
		return mats[key]
	var m := ShaderMaterial.new()
	m.shader = CUT if cut else SOLID
	m.set_shader_parameter("tex", tex)
	if cut:
		var leafy := kind in ["grass", "flower", "fern"]
		m.set_shader_parameter("height_ref", maxf(0.8, h))
		m.set_shader_parameter("wind", 1.8 if leafy else 1.0)
		m.set_shader_parameter("translucency", 0.45 if leafy else 0.3)
		match kind:
			"pine", "giant":
				m.set_shader_parameter("tint", Color(0.62, 0.72, 0.66))
			"oak":
				m.set_shader_parameter("tint", Color(0.56, 0.64, 0.5))
			"bush":
				m.set_shader_parameter("tint", Color(0.7, 0.76, 0.62))
				if name.contains("Twisted"):
					m.set_shader_parameter("hue", 1.9)
			"birch":
				m.set_shader_parameter("tint", Color(0.7, 0.55, 0.45))
			"twisted":
				m.set_shader_parameter("tint", Color(0.72, 0.42, 0.42))
			"grass":
				m.set_shader_parameter("tint", Color(0.52, 0.66, 0.4))
			"fern":
				m.set_shader_parameter("tint", Color(0.66, 0.72, 0.56))
			_:
				m.set_shader_parameter("tint", Color(0.85, 0.8, 0.8))
		m.set_shader_parameter("desat", 0.32)
	else:
		var rocky := kind in ["rock", "boulder"]
		m.set_shader_parameter("tint", Color(0.72, 0.72, 0.76) if rocky else Color(0.78, 0.72, 0.68))
		m.set_shader_parameter("moss", 0.55 if rocky else 0.0)
		m.set_shader_parameter("desat", 0.3)
	mats[key] = m
	return m

func _mat(kind: String) -> ShaderMaterial:
	if mats.has(kind):
		return mats[kind]
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	m.set_shader_parameter("wind", 0.0 if kind == "rock" else 0.6)
	m.set_shader_parameter("tint_var", 0.15)
	mats[kind] = m
	return m

# ---------- Ferne Ersatz-Meshes (prozedural) ----------

func _add_cyl(st: SurfaceTool, base: Vector3, top: Vector3, r0: float, r1: float, segs: int, c0: Color, c1: Color) -> void:
	var axis := (top - base).normalized()
	var x := axis.cross(Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP).normalized()
	if absf(axis.y) > 0.9:
		x = Vector3.RIGHT
	var z := axis.cross(x).normalized()
	x = z.cross(axis).normalized()
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var d0 := x * cos(a0) + z * sin(a0)
		var d1 := x * cos(a1) + z * sin(a1)
		var p00 := base + d0 * r0
		var p01 := base + d1 * r0
		var p10 := top + d0 * r1
		var p11 := top + d1 * r1
		for v in [[p00, d0, c0], [p11, d1, c1], [p10, d0, c1], [p00, d0, c0], [p01, d1, c0], [p11, d1, c1]]:
			st.set_color(v[2])
			st.set_normal(v[1])
			st.add_vertex(v[0])

func _add_cone(st: SurfaceTool, base: Vector3, height: float, r: float, segs: int, c: Color, bend: float, droop := 0.0) -> void:
	var tip := base + Vector3(0, height, 0)
	for i in segs:
		var a0 := TAU * i / segs
		var a1 := TAU * (i + 1) / segs
		var j0 := 1.0 + 0.12 * sin(a0 * 3.0 + base.y)
		var j1 := 1.0 + 0.12 * sin(a1 * 3.0 + base.y)
		var p0 := base + Vector3(cos(a0) * r * j0, -droop, sin(a0) * r * j0)
		var p1 := base + Vector3(cos(a1) * r * j1, -droop, sin(a1) * r * j1)
		var n0 := Vector3(cos(a0), r / height, sin(a0)).normalized()
		var n1 := Vector3(cos(a1), r / height, sin(a1)).normalized()
		var dark := Color(c.r * 0.55, c.g * 0.6, c.b * 0.6, bend * 0.6)
		var light := Color(c.r * 1.15, c.g * 1.1, c.b, bend)
		st.set_color(dark)
		st.set_normal(n0)
		st.add_vertex(p0)
		st.set_color(dark)
		st.set_normal(n1)
		st.add_vertex(p1)
		st.set_color(light)
		st.set_normal(((n0 + n1).normalized() + Vector3.UP * 0.3).normalized())
		st.add_vertex(tip)
		# Unterseite
		st.set_color(Color(c.r * 0.3, c.g * 0.35, c.b * 0.35, bend * 0.6))
		st.set_normal(Vector3.DOWN)
		st.add_vertex(p0)
		st.add_vertex(base + Vector3(0, -droop * 0.5, 0))
		st.add_vertex(p1)

func _add_blob(st: SurfaceTool, center: Vector3, r: Vector3, c: Color, bend: float, seed: int) -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 8
	sm.rings = 5
	var arr: Array = sm.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var jit := []
	for i in v.size():
		jit.append(1.0 + rng.randf_range(-0.16, 0.16))
	for k in ii:
		var p: Vector3 = v[k] * r * float(jit[k])
		var shade := 0.55 + 0.45 * clampf(v[k].y * 0.5 + 0.5, 0.0, 1.0)
		st.set_color(Color(c.r * shade, c.g * shade, c.b * shade, bend))
		st.set_normal(n[k])
		st.add_vertex(center + p)

func _finish(st: SurfaceTool) -> ArrayMesh:
	return st.commit()

func _pine() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.24, 0.17, 0.12, 0.0)
	_add_cyl(st, Vector3.ZERO, Vector3(0, 7.5, 0), 0.28, 0.08, 6, bark, Color(0.2, 0.14, 0.1, 0.4))
	var green := Color(0.1, 0.19, 0.13)
	var tiers := [[1.6, 3.2, 2.3], [3.1, 2.8, 1.9], [4.4, 2.4, 1.5], [5.6, 2.0, 1.05], [6.6, 1.6, 0.6]]
	for t in tiers:
		_add_cone(st, Vector3(0, t[0], 0), t[1], t[2], 9, green, clampf(t[0] / 7.0, 0.2, 1.0), 0.35)
	return _finish(st)

func _oak() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bark := Color(0.22, 0.17, 0.13, 0.0)
	_add_cyl(st, Vector3.ZERO, Vector3(0.1, 3.0, 0), 0.32, 0.2, 7, bark, bark)
	_add_cyl(st, Vector3(0.1, 2.6, 0), Vector3(1.1, 3.9, 0.3), 0.14, 0.07, 5, bark, Color(bark, 0.3))
	_add_cyl(st, Vector3(0.1, 2.8, 0), Vector3(-0.9, 4.0, -0.5), 0.14, 0.07, 5, bark, Color(bark, 0.3))
	var leaf := Color(0.16, 0.24, 0.12)
	_add_blob(st, Vector3(0.1, 4.6, 0), Vector3(2.3, 1.7, 2.2), leaf, 0.8, 1)
	_add_blob(st, Vector3(1.3, 4.1, 0.4), Vector3(1.4, 1.2, 1.4), leaf * 1.08, 0.9, 2)
	_add_blob(st, Vector3(-1.1, 4.2, -0.6), Vector3(1.5, 1.2, 1.3), leaf * 0.95, 0.9, 3)
	_add_blob(st, Vector3(0.0, 5.7, 0.2), Vector3(1.3, 1.0, 1.3), leaf * 1.12, 1.0, 4)
	return _finish(st)

func _dead() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.25, 0.22, 0.2, 0.0)
	var c2 := Color(0.28, 0.25, 0.23, 0.25)
	_add_cyl(st, Vector3.ZERO, Vector3(0.2, 5.2, 0.1), 0.26, 0.06, 6, c, c2)
	var br := [[Vector3(0.1, 2.4, 0), Vector3(1.6, 3.6, 0.4)], [Vector3(0.1, 3.0, 0), Vector3(-1.4, 4.1, -0.6)], [Vector3(0.15, 3.9, 0.05), Vector3(0.8, 5.0, -1.0)],
		[Vector3(1.0, 3.2, 0.25), Vector3(1.8, 4.4, 1.0)], [Vector3(0.18, 4.4, 0.08), Vector3(-0.7, 5.6, 0.6)]]
	for b in br:
		_add_cyl(st, b[0], b[1], 0.09, 0.02, 4, c, c2)
	return _finish(st)

func _bush() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var leaf := Color(0.14, 0.21, 0.11)
	_add_blob(st, Vector3(0, 0.45, 0), Vector3(0.9, 0.6, 0.85), leaf, 0.5, 11)
	_add_blob(st, Vector3(0.5, 0.35, 0.3), Vector3(0.6, 0.45, 0.6), leaf * 1.1, 0.6, 12)
	return _finish(st)

func _grass() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 7:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.35)
		var base := Vector3(cos(a) * r, 0, sin(a) * r)
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.1, 0.3)
		var hgt := rng.randf_range(0.25, 0.5)
		var w := 0.06
		var side := Vector3(-sin(a), 0, cos(a)) * w
		var c0 := Color(0.13, 0.17, 0.08, 0.0)
		var c1 := Color(0.3, 0.33, 0.16, 1.0)
		st.set_color(c0)
		st.set_normal(Vector3.UP)
		st.add_vertex(base - side)
		st.set_color(c1)
		st.add_vertex(base + Vector3(0, hgt, 0) + lean)
		st.set_color(c0)
		st.add_vertex(base + side)
	return _finish(st)

func _rock(seed: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := Color(0.36, 0.35, 0.34, 0.0)
	_add_blob(st, Vector3(0, 0.3, 0), Vector3(1.0, 0.75, 0.85), c, 0.0, seed)
	var m := st.commit()
	# flache Schattierung
	var st2 := SurfaceTool.new()
	st2.create_from(m, 0)
	st2.deindex()
	st2.generate_normals(true)
	return st2.commit()

# ---------- Verteilung ----------

func _blocked(x: float, z: float, margin: float) -> bool:
	for k in keep_out:
		if Vector2(x, z).distance_to(k[0]) < float(k[1]) + margin:
			return true
	return false

func _pick(rng: RandomNumberGenerator, kind: String) -> String:
	var arr: Array = KITS[kind]
	return arr[rng.randi() % arr.size()]

func _xf(rng: RandomNumberGenerator, p: Vector3, s: float, tilt := 0.0) -> Transform3D:
	var b := Basis(Vector3.UP, rng.randf() * TAU)
	if tilt > 0.0:
		b = Basis.from_euler(Vector3(rng.randf_range(-tilt, tilt), rng.randf() * TAU, rng.randf_range(-tilt, tilt)))
	return Transform3D(b.scaled(Vector3(s, s * rng.randf_range(0.9, 1.12), s)), p)

func _chunk(ci: int, cj: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = ci * 7919 + cj * 104729 + 17
	var x0 := -Terrain.HALF + ci * 64.0
	var z0 := -Terrain.HALF + cj * 64.0
	var near := {}     # Variante -> [Transform]
	var far := {}      # Fern-Mesh -> [Transform]
	var cols: Array = []
	var add := func(v: String, xf: Transform3D, kind: String):
		if not near.has(v):
			near[v] = []
		near[v].append(xf)
		if FAR.has(kind):
			var fk: String = FAR[kind]
			if not far.has(fk):
				far[fk] = []
			# Ersatzbaum ungefähr auf die Höhe des Modells skalieren
			var k := float(heights.get(v, 7.0)) / 7.0
			far[fk].append(xf.scaled_local(Vector3(k, k, k)))
	# Bäume
	for i in 85:
		var x := x0 + rng.randf() * 64.0
		var z := z0 + rng.randf() * 64.0
		var y := terrain.height_at(x, z)
		var d := Vector2(x, z).length()
		if y < 0.8 or d > 292.0:
			continue
		var f := forest.get_noise_2d(x, z)
		if f <= 0.08 and rng.randf() > 0.06:
			continue
		if terrain.road_at(x, z) > 0.05 or terrain.river_dist(x, z) < 7.0 or _blocked(x, z, 4.0):
			continue
		if terrain.normal_at(x, z).y < 0.78:
			continue
		var high := y > 15.0 or d > 210.0
		var near_ruin := Vector2(x, z).distance_to(Terrain.RUIN) < 70.0 or Vector2(x, z).distance_to(Terrain.SHRINE) < 40.0
		var r := rng.randf()
		var kind := "pine"
		if near_ruin or d > 250.0:
			kind = "dead" if r < 0.55 else ("twisted" if r < 0.62 else "pine")
		elif high:
			kind = "pine" if r < 0.75 else ("giant" if r < 0.88 else "dead")
		else:
			kind = "oak" if r < 0.42 else ("pine" if r < 0.82 else ("birch" if r < 0.92 else "dead"))
		var s := rng.randf_range(0.85, 1.3)
		if kind == "twisted":
			s *= 0.55
		var v := _pick(rng, kind)
		add.call(v, _xf(rng, Vector3(x, y - 0.15, z), s), kind)
		cols.append([Vector3(x, y, z), (0.45 if kind == "twisted" else 0.32) * s, 4.0])
		# Unterholz
		if rng.randf() < 0.55:
			var bx := x + rng.randf_range(-3.5, 3.5)
			var bz := z + rng.randf_range(-3.5, 3.5)
			if terrain.road_at(bx, bz) < 0.1 and not _blocked(bx, bz, 1.0) and terrain.height_at(bx, bz) > 0.6:
				var under := "bush" if rng.randf() < 0.55 else ("fern" if rng.randf() < 0.8 else "shroom")
				var uv := _pick(rng, under)
				var target: float = {"bush": 1.3, "fern": 0.9, "shroom": 0.3}[under] * rng.randf_range(0.7, 1.3)
				var us := target / maxf(0.1, float(heights.get(uv, 1.0)))
				add.call(uv, _xf(rng, terrain.ground(Vector3(bx, 0, bz)) - Vector3(0, 0.05, 0), us), under)
	# Felsen
	for i in 8:
		var x := x0 + rng.randf() * 64.0
		var z := z0 + rng.randf() * 64.0
		if _blocked(x, z, 2.0) or terrain.road_at(x, z) > 0.2:
			continue
		var y := terrain.height_at(x, z)
		if y < -0.5:
			continue
		var big := rng.randf() < 0.22 or Vector2(x, z).length() > 225.0
		var kind := "boulder" if big else "rock"
		var s := rng.randf_range(0.7, 1.6) if big else rng.randf_range(0.4, 1.0)
		add.call(_pick(rng, kind), _xf(rng, Vector3(x, y - 0.3 * s, z), s, 0.25), kind)
		if big:
			cols.append([Vector3(x, y, z), 1.9 * s, 3.5 * s])
	_emit(near, far, Vector3(x0 + 32.0, 0, z0 + 32.0))
	# Gras, Blumen in 16-m-Feldern (Büschel-Gruppen)
	for sj in 4:
		for si in 4:
			var gx := x0 + si * 16.0
			var gz := z0 + sj * 16.0
			var patches := {"patch": [], "patch_b": [], "patch_flower": []}
			for i in 30:
				var x := gx + rng.randf() * 16.0
				var z := gz + rng.randf() * 16.0
				var y := terrain.height_at(x, z)
				if y < 0.5 or terrain.road_at(x, z) > 0.3 or Vector2(x, z).length() > 240.0:
					continue
				if meadow.get_noise_2d(x, z) < -0.2 or _blocked(x, z, -6.0) or terrain.normal_at(x, z).y < 0.82:
					continue
				var r := rng.randf()
				var k := "patch" if r < 0.55 else ("patch_b" if r < 0.97 else "patch_flower")
				patches[k].append(_xf(rng, Vector3(x, y, z), rng.randf_range(0.8, 1.2)))
			for k in patches:
				if not (patches[k] as Array).is_empty():
					_mmi(meshes[k], patches[k], 0.0, 36.0, false)
	if not cols.is_empty():
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		for c in cols:
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = float(c[1])
			cy.height = float(c[2])
			cs.shape = cy
			cs.position = (c[0] as Vector3) + Vector3(0, float(c[2]) * 0.5, 0)
			sb.add_child(cs)
		add_child(sb)
	return cols.size()

func _emit(near: Dictionary, far: Dictionary, _center: Vector3) -> void:
	for v: String in near:
		var small: bool = not (v.begins_with("Pine") or v.begins_with("Common") or v.begins_with("Dead") or v.begins_with("Birch") or v.begins_with("Giant") or v.begins_with("Twisted") or v.begins_with("Rock_Big"))
		_mmi(meshes[v], near[v], 0.0, 60.0 if small else NEAR_RANGE, not small)
	for fk in far:
		var mmi := _mmi(meshes[fk], far[fk], NEAR_RANGE, FAR_RANGE, false)
		mmi.material_override = _mat("tree")

func _mmi(mesh: Mesh, arr: Array, r0: float, r1: float, shadows: bool) -> MultiMeshInstance3D:
	# Knoten in die Mitte der Instanzen setzen: die Sichtweite misst vom Knoten aus
	var center := Vector3.ZERO
	for xf: Transform3D in arr:
		center += xf.origin
	center /= maxf(1.0, arr.size())
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = arr.size()
	for k in arr.size():
		var xf: Transform3D = arr[k]
		xf.origin -= center
		mm.set_instance_transform(k, xf)
	var mmi := MultiMeshInstance3D.new()
	mmi.position = center
	mmi.multimesh = mm
	mmi.visibility_range_begin = r0
	mmi.visibility_range_end = r1
	mmi.visibility_range_end_margin = 8.0
	mmi.visibility_range_begin_margin = 8.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	return mmi
