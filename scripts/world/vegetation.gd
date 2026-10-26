class_name Vegetation
extends Node3D
## Bäume, Büsche, Gras und Felsen als MultiMesh je 64-m-Chunk, mit Sichtweiten-Abschaltung.
## Stämme bekommen Kollision. Alle Meshes werden prozedural mit Vertexfarben erzeugt
## (Alpha = Biegsamkeit für den Wind im Foliage-Shader).

const FOLIAGE := preload("res://shaders/foliage.gdshader")

var terrain: Terrain
var forest := FastNoiseLite.new()
var meadow := FastNoiseLite.new()
var meshes := {}
var mats := {}
## Ausschlusszonen (Mitte, Radius) – Gebäude, Lager, Ruine
var keep_out: Array = []

func generate(t: Terrain, exclusions: Array) -> void:
	terrain = t
	keep_out = exclusions
	forest.seed = 4242
	forest.frequency = 1.0 / 95.0
	forest.fractal_octaves = 3
	meadow.seed = 99
	meadow.frequency = 1.0 / 40.0
	_make_meshes()
	var chunks := int(Terrain.SIZE / 64.0)
	var shapes := 0
	for cj in chunks:
		for ci in chunks:
			shapes += _chunk(ci, cj)
	print("Vegetation: ", shapes, " Stämme mit Kollision")

func _mat(kind: String) -> ShaderMaterial:
	if mats.has(kind):
		return mats[kind]
	var m := ShaderMaterial.new()
	m.shader = FOLIAGE
	match kind:
		"grass":
			m.set_shader_parameter("wind", 1.6)
			m.set_shader_parameter("translucency", 0.5)
		"rock":
			m.set_shader_parameter("wind", 0.0)
			m.set_shader_parameter("translucency", 0.0)
			m.set_shader_parameter("tint_var", 0.18)
		_:
			m.set_shader_parameter("wind", 0.8)
	mats[kind] = m
	return m

# ---------- Meshes ----------

func _make_meshes() -> void:
	meshes.pine = _pine()
	meshes.oak = _oak()
	meshes.dead = _dead()
	meshes.bush = _bush()
	meshes.grass = _grass()
	meshes.rock = _rock(7)
	meshes.boulder = _rock(13)

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

func _chunk(ci: int, cj: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = ci * 7919 + cj * 104729 + 17
	var x0 := -Terrain.HALF + ci * 64.0
	var z0 := -Terrain.HALF + cj * 64.0
	var lists := {"pine": [], "oak": [], "dead": [], "bush": [], "grass": [], "rock": [], "boulder": []}
	var trunks: Array = []
	var center := Vector2(x0 + 32.0, z0 + 32.0)
	var edge := center.length()
	# Bäume
	var tries := 90
	for i in tries:
		var x := x0 + rng.randf() * 64.0
		var z := z0 + rng.randf() * 64.0
		var y := terrain.height_at(x, z)
		var d := Vector2(x, z).length()
		if y < 0.8 or d > 292.0:
			continue
		var f := forest.get_noise_2d(x, z)
		var dense := f > 0.08
		if not dense and rng.randf() > 0.06:
			continue
		if terrain.road_at(x, z) > 0.05 or terrain.river_dist(x, z) < 7.0 or _blocked(x, z, 4.0):
			continue
		var n := terrain.normal_at(x, z)
		if n.y < 0.78:
			continue
		var kind := "pine"
		var high := y > 15.0 or d > 210.0
		var near_ruin := Vector2(x, z).distance_to(Terrain.RUIN) < 70.0
		var r := rng.randf()
		if near_ruin or d > 250.0:
			kind = "dead" if r < 0.6 else "pine"
		elif high:
			kind = "pine" if r < 0.85 else "dead"
		else:
			kind = "oak" if r < 0.45 else ("pine" if r < 0.92 else "dead")
		var s := rng.randf_range(0.8, 1.35)
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.9, 1.15), s)), Vector3(x, y - 0.1, z))
		lists[kind].append(xf)
		trunks.append([Vector3(x, y, z), 0.3 * s])
		# Büsche unter Bäumen
		if rng.randf() < 0.5:
			var bx := x + rng.randf_range(-3, 3)
			var bz := z + rng.randf_range(-3, 3)
			if terrain.road_at(bx, bz) < 0.1 and not _blocked(bx, bz, 1.0) and terrain.height_at(bx, bz) > 0.6:
				var bs := rng.randf_range(0.7, 1.4)
				lists.bush.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * bs), terrain.ground(Vector3(bx, 0, bz))))
	# Felsen
	for i in 7:
		var x := x0 + rng.randf() * 64.0
		var z := z0 + rng.randf() * 64.0
		if _blocked(x, z, 2.0) or terrain.road_at(x, z) > 0.2:
			continue
		var y := terrain.height_at(x, z)
		if y < -0.5:
			continue
		var big := rng.randf() < 0.25 or Vector2(x, z).length() > 220.0
		var s := rng.randf_range(1.6, 3.4) if big else rng.randf_range(0.3, 0.9)
		var xf := Transform3D(Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled(Vector3(s, s * rng.randf_range(0.6, 1.1), s)), Vector3(x, y - 0.25 * s, z))
		lists["boulder" if big else "rock"].append(xf)
		if big:
			trunks.append([Vector3(x, y, z), 0.8 * s])
	# Gras
	for i in 700:
		var x := x0 + rng.randf() * 64.0
		var z := z0 + rng.randf() * 64.0
		var y := terrain.height_at(x, z)
		if y < 0.5 or terrain.road_at(x, z) > 0.3 or Vector2(x, z).length() > 240.0:
			continue
		if meadow.get_noise_2d(x, z) < -0.25:
			continue
		if _blocked(x, z, -6.0):
			continue
		if terrain.normal_at(x, z).y < 0.82:
			continue
		var s := rng.randf_range(0.7, 1.4)
		lists.grass.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.3), s)), Vector3(x, y - 0.02, z)))
	var ranges := {"pine": 240.0, "oak": 220.0, "dead": 220.0, "bush": 110.0, "grass": 48.0, "rock": 90.0, "boulder": 260.0}
	for kind in lists:
		var arr: Array = lists[kind]
		if arr.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[kind]
		mm.instance_count = arr.size()
		for k in arr.size():
			mm.set_instance_transform(k, arr[k])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _mat("grass" if kind == "grass" else ("rock" if kind == "rock" or kind == "boulder" else "tree"))
		mmi.visibility_range_end = ranges[kind]
		mmi.visibility_range_end_margin = 10.0
		if kind == "grass" or kind == "bush" or kind == "rock":
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
	if not trunks.is_empty():
		var sb := StaticBody3D.new()
		sb.collision_layer = 1
		for tr in trunks:
			var cs := CollisionShape3D.new()
			var cy := CylinderShape3D.new()
			cy.radius = float(tr[1])
			cy.height = 4.0
			cs.shape = cy
			cs.position = (tr[0] as Vector3) + Vector3(0, 2.0, 0)
			sb.add_child(cs)
		add_child(sb)
	return trunks.size()
