class_name Terrain
extends Node3D
## Prozedurales Gelände von Veyra: Höhenfeld (2-m-Raster), Chunks mit Vertexfarben,
## Fluss mit Furt, See, Wege, Berge am Schleier. Kollision über HeightMapShape3D.

const SIZE := 640.0          # Weltbreite in Metern (−320 … +320)
const CELL := 2.0            # Rasterabstand
const N := 321               # Stützpunkte je Achse
const CHUNK := 32            # Zellen je Chunk (64 m)
const WATER_Y := 0.0
const HALF := SIZE * 0.5

## Wichtige Orte
const RUIN := Vector2(-170, -160)
const VILLAGE := Vector2(98, 28)
const FORD := Vector2(66, 36)
const BANDITS := Vector2(-96, 138)
const TOWER := Vector2(212, -92)
const LAKE := Vector2(150, 175)
const SHRINE := Vector2(-205, 95)

const RIVER := [Vector2(-34, -262), Vector2(-28, -230), Vector2(8, -140), Vector2(30, -50), Vector2(52, 10), Vector2(66, 36),
	Vector2(92, 82), Vector2(120, 128), Vector2(150, 175)]
const ROADS := [
	[Vector2(-170, -160), Vector2(-150, -128), Vector2(-104, -84), Vector2(-52, -40), Vector2(-4, -6), Vector2(40, 26), Vector2(66, 36), Vector2(98, 28)],
	[Vector2(-4, -6), Vector2(-34, 46), Vector2(-62, 96), Vector2(-96, 138)],
	[Vector2(98, 28), Vector2(140, -10), Vector2(180, -60), Vector2(212, -92)],
	[Vector2(-62, 96), Vector2(-140, 100), Vector2(-205, 95)],
]
## Eingeebnete Flächen: Mitte, Radius, Übergang
const FLATS := [[VILLAGE, 34.0, 18.0], [BANDITS, 20.0, 12.0], [RUIN, 22.0, 14.0], [TOWER, 16.0, 10.0], [SHRINE, 10.0, 8.0]]

var h := PackedFloat32Array()
var road_mask := PackedFloat32Array()
var noise := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var mat: ShaderMaterial
var water: MeshInstance3D

func generate() -> void:
	noise.seed = 1337
	noise.frequency = 1.0 / 170.0
	noise.fractal_octaves = 5
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail.seed = 77
	detail.frequency = 1.0 / 23.0
	h.resize(N * N)
	road_mask.resize(N * N)
	var flat_targets := []
	for f in FLATS:
		flat_targets.append(_base((f[0] as Vector2).x, (f[0] as Vector2).y) + (6.0 if f[0] == RUIN else 0.0))
	for j in N:
		var z := -HALF + j * CELL
		for i in N:
			var x := -HALF + i * CELL
			var y := _base(x, z)
			if absf(x - RUIN.x) < 90 and absf(z - RUIN.y) < 90:
				var dr := Vector2(x, z).distance_to(RUIN)
				y += 9.0 * exp(-dr * dr / (2.0 * 40.0 * 40.0))
			for k in FLATS.size():
				var f: Array = FLATS[k]
				var d := Vector2(x, z).distance_to(f[0])
				if d < float(f[1]) + float(f[2]):
					var t := smoothstep(float(f[1]) + float(f[2]), float(f[1]), d)
					y = lerpf(y, float(flat_targets[k]), t)
			# Wege: leicht eingeebnet
			var rd := _dist_polys(Vector2(x, z), ROADS)
			var rm := smoothstep(4.5, 1.5, rd)
			road_mask[j * N + i] = rm
			# Fluss
			var dv := _dist_poly(Vector2(x, z), RIVER)
			if dv < 20.0:
				var depth := -1.8
				var ford := Vector2(x, z).distance_to(FORD)
				if ford < 14.0:
					depth = lerpf(-0.45, -1.8, ford / 14.0)
				var bank := smoothstep(16.0, 5.0, dv)
				y = lerpf(y, minf(y, depth), bank)
				road_mask[j * N + i] *= (1.0 - bank) if ford > 10.0 else 1.0
			# See
			var dl := Vector2(x, z).distance_to(LAKE)
			if dl < 70.0:
				y = lerpf(y, -3.2, smoothstep(68.0, 30.0, dl))
			h[j * N + i] = y
	_build_mesh()
	_build_collision()
	_build_water()

func _base(x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z)
	var y := 7.5 + n * 9.0 + detail.get_noise_2d(x, z) * 0.6
	var d := Vector2(x, z).length()
	var edge := smoothstep(205.0, 300.0, d)
	y += edge * (34.0 + noise.get_noise_2d(x * 2.3, z * 2.3) * 14.0)
	# Hügel für den Wachturm
	var dt := Vector2(x, z).distance_to(TOWER)
	y += 8.0 * exp(-dt * dt / (2.0 * 35.0 * 35.0))
	return maxf(y, 1.4)

func _dist_poly(p: Vector2, pts: Array) -> float:
	var best := 1e9
	for k in pts.size() - 1:
		best = minf(best, _seg_dist(p, pts[k], pts[k + 1]))
	return best

func _dist_polys(p: Vector2, polys: Array) -> float:
	var best := 1e9
	for poly in polys:
		best = minf(best, _dist_poly(p, poly))
	return best

static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

# ---------- Abfragen ----------

func height_at(x: float, z: float) -> float:
	var fx := clampf((x + HALF) / CELL, 0.0, N - 1.001)
	var fz := clampf((z + HALF) / CELL, 0.0, N - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var a := h[j * N + i]
	var b := h[j * N + i + 1]
	var c := h[(j + 1) * N + i]
	var d := h[(j + 1) * N + i + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

func normal_at(x: float, z: float) -> Vector3:
	var e := 1.0
	return Vector3(height_at(x - e, z) - height_at(x + e, z), 2.0 * e, height_at(x, z - e) - height_at(x, z + e)).normalized()

func road_at(x: float, z: float) -> float:
	var i := clampi(int(round((x + HALF) / CELL)), 0, N - 1)
	var j := clampi(int(round((z + HALF) / CELL)), 0, N - 1)
	return road_mask[j * N + i]

func river_dist(x: float, z: float) -> float:
	return minf(_dist_poly(Vector2(x, z), RIVER), Vector2(x, z).distance_to(LAKE) - 45.0)

func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, height_at(p.x, p.z), p.z)

# ---------- Mesh ----------

func _color(i: int, j: int, n: Vector3) -> Color:
	var y := h[j * N + i]
	var x := -HALF + i * CELL
	var z := -HALF + j * CELL
	var dn := detail.get_noise_2d(x * 0.7, z * 0.7)
	var grass := Color(0.2, 0.25, 0.13).lerp(Color(0.3, 0.29, 0.15), clampf(dn * 0.8 + 0.4, 0.0, 1.0))
	var c := grass
	var slope := 1.0 - n.y
	var rock := Color(0.3, 0.29, 0.28).lerp(Color(0.38, 0.34, 0.3), clampf(dn + 0.5, 0.0, 1.0))
	c = c.lerp(rock, smoothstep(0.18, 0.35, slope))
	var mud := Color(0.22, 0.18, 0.14)
	c = c.lerp(mud, smoothstep(1.6, 0.4, y))
	var rm := road_mask[j * N + i]
	c = c.lerp(Color(0.33, 0.26, 0.19), rm * 0.9)
	# Asche und roter Fels nahe dem Schleier
	var d := Vector2(x, z).length()
	c = c.lerp(Color(0.3, 0.2, 0.19), smoothstep(230.0, 290.0, d))
	# Ruinenboden: grauer Stein
	c = c.lerp(Color(0.3, 0.3, 0.31), smoothstep(26.0, 14.0, Vector2(x, z).distance_to(RUIN)) * 0.6)
	return c

## Gewichte für die Texturen: x = Fels (Hang), y = Weg/Erde
func _weights(i: int, j: int, n: Vector3) -> Vector2:
	var y := h[j * N + i]
	var x := -HALF + i * CELL
	var z := -HALF + j * CELL
	var rockw := smoothstep(0.16, 0.32, 1.0 - n.y)
	var dirt := maxf(road_mask[j * N + i] * 0.95, smoothstep(1.6, 0.4, y) * 0.8)
	dirt = maxf(dirt, smoothstep(26.0, 14.0, Vector2(x, z).distance_to(RUIN)) * 0.5)
	return Vector2(rockw, dirt)

func _build_mesh() -> void:
	var nrm := PackedVector3Array()
	nrm.resize(N * N)
	for j in N:
		for i in N:
			var l := h[j * N + maxi(i - 1, 0)]
			var r := h[j * N + mini(i + 1, N - 1)]
			var u := h[maxi(j - 1, 0) * N + i]
			var dd := h[mini(j + 1, N - 1) * N + i]
			nrm[j * N + i] = Vector3(l - r, 2.0 * CELL, u - dd).normalized()
	mat = ShaderMaterial.new()
	mat.shader = preload("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("grass_tex", load("res://assets/terrain/ground_grass.png"))
	mat.set_shader_parameter("dirt_tex", load("res://assets/terrain/ground_dirt.png"))
	mat.set_shader_parameter("rock_tex", load("res://assets/terrain/ground_rock.png"))
	var chunks := (N - 1) / CHUNK
	for cj in chunks:
		for ci in chunks:
			var verts := PackedVector3Array()
			var norms := PackedVector3Array()
			var cols := PackedColorArray()
			var wts := PackedVector2Array()
			var idx := PackedInt32Array()
			var w := CHUNK + 1
			for j in w:
				for i in w:
					var gi := ci * CHUNK + i
					var gj := cj * CHUNK + j
					verts.append(Vector3(-HALF + gi * CELL, h[gj * N + gi], -HALF + gj * CELL))
					var nn := nrm[gj * N + gi]
					norms.append(nn)
					cols.append(_color(gi, gj, nn))
					wts.append(_weights(gi, gj, nn))
			for j in CHUNK:
				for i in CHUNK:
					var a := j * w + i
					var b := a + 1
					var c := a + w
					var d := c + 1
					idx.append_array([a, b, c, b, d, c])
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_COLOR] = cols
			arr[Mesh.ARRAY_TEX_UV] = wts
			arr[Mesh.ARRAY_INDEX] = idx
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var mi := MeshInstance3D.new()
			mi.mesh = am
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)

func _build_collision() -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var shape := HeightMapShape3D.new()
	shape.map_width = N
	shape.map_depth = N
	shape.map_data = h
	cs.shape = shape
	cs.scale = Vector3(CELL, 1.0, CELL)
	sb.add_child(cs)
	add_child(sb)

func _build_water() -> void:
	water = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(SIZE, SIZE)
	pm.subdivide_width = 0
	pm.subdivide_depth = 0
	water.mesh = pm
	var wm := ShaderMaterial.new()
	wm.shader = preload("res://shaders/water.gdshader")
	water.material_override = wm
	water.position.y = WATER_Y
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
