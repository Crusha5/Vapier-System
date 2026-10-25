class_name BodyBuilder
extends RefCounted
## Baut einen durchgehenden, geskinnten Menschen-Körper aus „Lofts“ (Ringen entlang der Knochen):
## Rumpf, Arme, Beine, Kopf, Haare, Mantel/Umhang, Stiefel, Handschuhe, Akzentstreifen.
## Alle Knochen haben eine Ruhe-Rotation von null – Animation = einfache Euler-Drehungen je Knochen.

const BONES := [
	# Name, Elternknochen, Ruhe-Position relativ zum Eltern
	["hips", -1, Vector3(0, 0.95, 0)],
	["spine", 0, Vector3(0, 0.12, 0)],
	["chest", 1, Vector3(0, 0.2, 0)],
	["neck", 2, Vector3(0, 0.26, 0)],
	["head", 3, Vector3(0, 0.09, 0)],
	["upperarm.L", 2, Vector3(-0.2, 0.21, 0)],
	["forearm.L", 5, Vector3(0, -0.28, 0)],
	["hand.L", 6, Vector3(0, -0.25, 0)],
	["upperarm.R", 2, Vector3(0.2, 0.21, 0)],
	["forearm.R", 8, Vector3(0, -0.28, 0)],
	["hand.R", 9, Vector3(0, -0.25, 0)],
	["thigh.L", 0, Vector3(-0.1, -0.04, 0)],
	["shin.L", 11, Vector3(0, -0.42, 0)],
	["foot.L", 12, Vector3(0, -0.41, 0)],
	["thigh.R", 0, Vector3(0.1, -0.04, 0)],
	["shin.R", 14, Vector3(0, -0.42, 0)],
	["foot.R", 15, Vector3(0, -0.41, 0)],
]
const SURFACES := ["skin", "suit", "dark", "accent", "hair", "metal", "cape"]
const N := 12  # Segmente pro Ring

static var _cache := {}

var look: Dictionary
var bk := 1.0
var gpos: Array[Vector3] = []   # globale Ruhe-Positionen
var st := {}                     # Fläche -> SurfaceTool
var cnt := {}                    # Fläche -> Vertexanzahl
var _flip := false
var rigid := false

## Starres Mesh aus Lofts/Primitiven (für Kreaturen): fn erhält den Builder.
static func sculpt(surfs: Array, fn: Callable) -> Dictionary:
	var b := BodyBuilder.new()
	b.rigid = true
	b.look = {}
	for s in surfs:
		var t := SurfaceTool.new()
		t.begin(Mesh.PRIMITIVE_TRIANGLES)
		b.st[s] = t
		b.cnt[s] = 0
	fn.call(b)
	var mesh := ArrayMesh.new()
	var used: Array = []
	for s in surfs:
		if int(b.cnt[s]) == 0:
			continue
		(b.st[s] as SurfaceTool).commit(mesh)
		used.append(s)
	return {"mesh": mesh, "surfaces": used}

## Ring für starre Lofts
static func rr(c: Vector3, rx: float, rz: float, extra := {}) -> Dictionary:
	var r := {"c": c, "rx": rx, "rz": rz, "w": [[0, 1.0]]}
	for k in extra:
		r[k] = extra[k]
	return r

static func bone_index(name: String) -> int:
	for i in BONES.size():
		if BONES[i][0] == name:
			return i
	return -1

static func bone_rest(i: int, bulk: float) -> Vector3:
	var p: Vector3 = BONES[i][2]
	if BONES[i][0].begins_with("upperarm") or BONES[i][0].begins_with("thigh"):
		p.x *= bulk
	return p

## Gibt {mesh, mats} zurück; Mesh ist pro Aussehen zwischengespeichert.
static func build(lk: Dictionary) -> Dictionary:
	var key := str(lk)
	if _cache.has(key):
		return _cache[key]
	var b := BodyBuilder.new()
	b.look = lk
	var res := b._make()
	_cache[key] = res
	return res

func _make() -> Dictionary:
	bk = float(look.get("bulk", 1.0))
	gpos.clear()
	for i in BONES.size():
		var p := bone_rest(i, bk)
		var par: int = BONES[i][1]
		gpos.append(p + (gpos[par] if par >= 0 else Vector3.ZERO))
	for s in SURFACES:
		var t := SurfaceTool.new()
		t.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
		t.begin(Mesh.PRIMITIVE_TRIANGLES)
		st[s] = t
		cnt[s] = 0
	_body()
	var mesh := ArrayMesh.new()
	var used: Array[String] = []
	for s in SURFACES:
		if int(cnt[s]) == 0:
			continue
		(st[s] as SurfaceTool).commit(mesh)
		used.append(s)
	return {"mesh": mesh, "surfaces": used}

# ---------- Grundbausteine ----------

func _vert(surf: String, p: Vector3, n: Vector3, w: Array) -> int:
	var t: SurfaceTool = st[surf]
	if rigid:
		t.set_normal(n.normalized())
		t.add_vertex(p)
		cnt[surf] = int(cnt[surf]) + 1
		return int(cnt[surf]) - 1
	var bones := PackedInt32Array([0, 0, 0, 0])
	var weights := PackedFloat32Array([0, 0, 0, 0])
	var total := 0.0
	for i in min(4, w.size()):
		total += float(w[i][1])
	for i in min(4, w.size()):
		bones[i] = int(w[i][0])
		weights[i] = float(w[i][1]) / maxf(total, 0.0001)
	t.set_normal(n.normalized())
	t.set_bones(bones)
	t.set_weights(weights)
	t.add_vertex(p)
	cnt[surf] = int(cnt[surf]) + 1
	return int(cnt[surf]) - 1

## Dreieck so anlegen, dass es nach „out“ zeigt (Godot: Vorderseite im Uhrzeigersinn)
func _tri(surf: String, a: int, b: int, c: int, pa: Vector3, pb: Vector3, pc: Vector3, out: Vector3) -> void:
	var t: SurfaceTool = st[surf]
	var nrm := (pc - pa).cross(pb - pa)
	if nrm.dot(out) >= 0.0:
		t.add_index(a)
		t.add_index(b)
		t.add_index(c)
	else:
		t.add_index(a)
		t.add_index(c)
		t.add_index(b)

## Ringe: {c: Mitte, rx, rz, w: Gewichte, a0/a1: Winkelbereich (offen), t: Tangente optional}
func loft(surf: String, rings: Array, cap0 := true, cap1 := true, two_sided := false) -> void:
	var n := rings.size()
	if n < 2:
		return
	var open: bool = rings[0].has("a0")
	var segs := N if not open else 9
	var idx: Array = []
	var pts: Array = []
	for i in n:
		var r: Dictionary = rings[i]
		var c: Vector3 = r.c
		var tan: Vector3
		if r.has("t"):
			tan = r.t
		else:
			var pa: Vector3 = rings[max(0, i - 1)].c
			var pb: Vector3 = rings[min(n - 1, i + 1)].c
			tan = (pb - pa).normalized()
		var x := Vector3.RIGHT
		if absf(tan.dot(x)) > 0.9:
			x = Vector3.BACK
		x = (x - tan * tan.dot(x)).normalized()
		var z := x.cross(tan).normalized()
		var row: Array = []
		var prow: Array = []
		var cnt_r := segs if not open else segs + 1
		for j in cnt_r:
			var a: float
			if open:
				a = lerpf(float(r.a0), float(r.a1), float(j) / segs)
			else:
				a = TAU * j / segs
			var rx: float = r.rx
			var rz: float = r.rz
			var p := c + x * cos(a) * rx + z * sin(a) * rz
			var nn := x * cos(a) / rx + z * sin(a) / rz
			row.append(_vert(surf, p, nn, r.w))
			prow.append(p)
		idx.append(row)
		pts.append(prow)
	var cols: int = idx[0].size()
	for i in n - 1:
		var c0: Vector3 = rings[i].c
		for j in (cols if not open else cols - 1):
			var j2 := (j + 1) % cols
			var a: int = idx[i][j]
			var b: int = idx[i][j2]
			var cc: int = idx[i + 1][j]
			var d: int = idx[i + 1][j2]
			var pa: Vector3 = pts[i][j]
			var pb: Vector3 = pts[i][j2]
			var pc: Vector3 = pts[i + 1][j]
			var pd: Vector3 = pts[i + 1][j2]
			var c1: Vector3 = rings[i + 1].c
			var out: Vector3 = ((pa + pb + pc + pd) * 0.25 - (c0 + c1) * 0.5).normalized()
			_tri(surf, a, cc, b, pa, pc, pb, out)
			_tri(surf, b, cc, d, pb, pc, pd, out)
	if two_sided:
		# Rückseite: gleiche Ringe mit umgekehrten Normalen, leicht nach innen versetzt
		var inner: Array = []
		for r in rings:
			var r2: Dictionary = r.duplicate()
			r2.rx = float(r.rx) * 0.97
			r2.rz = float(r.rz) * 0.97
			inner.append(r2)
		_loft_inside(surf, inner)
	if not open:
		if cap0:
			_cap(surf, rings[0], rings[1], idx[0], pts[0])
		if cap1:
			_cap(surf, rings[n - 1], rings[n - 2], idx[n - 1], pts[n - 1])

func _loft_inside(surf: String, rings: Array) -> void:
	var n := rings.size()
	var segs := 9
	var idx: Array = []
	var pts: Array = []
	for i in n:
		var r: Dictionary = rings[i]
		var c: Vector3 = r.c
		var pa: Vector3 = rings[max(0, i - 1)].c
		var pb: Vector3 = rings[min(n - 1, i + 1)].c
		var tan := (pb - pa).normalized()
		var x := (Vector3.RIGHT - tan * tan.dot(Vector3.RIGHT)).normalized()
		var z := x.cross(tan).normalized()
		var row: Array = []
		var prow: Array = []
		for j in segs + 1:
			var a := lerpf(float(r.a0), float(r.a1), float(j) / segs)
			var p := c + x * cos(a) * float(r.rx) + z * sin(a) * float(r.rz)
			var nn := -(x * cos(a) + z * sin(a))
			row.append(_vert(surf, p, nn, r.w))
			prow.append(p)
		idx.append(row)
		pts.append(prow)
	for i in n - 1:
		var c0: Vector3 = rings[i].c
		for j in segs:
			var pa: Vector3 = pts[i][j]
			var pb: Vector3 = pts[i][j + 1]
			var pc: Vector3 = pts[i + 1][j]
			var pd: Vector3 = pts[i + 1][j + 1]
			var c1: Vector3 = rings[i + 1].c
			var inward: Vector3 = -(((pa + pb + pc + pd) * 0.25) - (c0 + c1) * 0.5).normalized()
			_tri(surf, idx[i][j], idx[i + 1][j], idx[i][j + 1], pa, pc, pb, inward)
			_tri(surf, idx[i][j + 1], idx[i + 1][j], idx[i + 1][j + 1], pb, pc, pd, inward)

func _cap(surf: String, r: Dictionary, nb: Dictionary, row: Array, prow: Array) -> void:
	var c: Vector3 = r.c
	var dir := (c - (nb.c as Vector3)).normalized()
	var depth := minf(float(r.rx), float(r.rz)) * 0.55
	var tip := c + dir * depth
	var ti := _vert(surf, tip, dir, r.w)
	for j in row.size():
		var j2 := (j + 1) % row.size()
		var pa: Vector3 = prow[j]
		var pb: Vector3 = prow[j2]
		_tri(surf, row[j], row[j2], ti, pa, pb, tip, ((pa + pb + tip) / 3.0 - c + dir * 0.01).normalized())

## Starres Teil (Primitive) an einem Knochen
func prim(surf: String, m: PrimitiveMesh, xf: Transform3D, w: Array) -> void:
	if m.has_meta("sc"):
		xf.basis = xf.basis * Basis.from_scale(m.get_meta("sc"))
	var arr: Array = m.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := int(cnt[surf])
	var nb := xf.basis.inverse().transposed()
	for i in v.size():
		_vert(surf, xf * v[i], nb * nr[i], w)
	var t: SurfaceTool = st[surf]
	for i in ii:
		t.add_index(base + i)

func _w(name: String) -> Array:
	return [[bone_index(name), 1.0]]

func _w2(a: String, b: String, f: float) -> Array:
	## f = Anteil von b
	return [[bone_index(a), 1.0 - f], [bone_index(b), f]]

func _ring(c: Vector3, rx: float, rz: float, w: Array, extra := {}) -> Dictionary:
	var r := {"c": c, "rx": rx, "rz": rz, "w": w}
	for k in extra:
		r[k] = extra[k]
	return r

## Ringe entlang einer Knochenkette. prof: [[s, rx, rz, zoff], …], s läuft über die Segmente (0..Anzahl)
func chain(surf: String, joints: Array, bones: Array, parent: String, prof: Array, scale_r := 1.0, cap0 := true, cap1 := true) -> void:
	var rings: Array = []
	for pr in prof:
		var s: float = pr[0]
		var k: int = clampi(int(floor(s)), 0, joints.size() - 2)
		var t: float = s - k
		var c: Vector3 = (joints[k] as Vector3).lerp(joints[k + 1], t) + Vector3(0, 0, float(pr[3]) if pr.size() > 3 else 0.0)
		var w: Array
		var prev: String = parent if k == 0 else String(bones[k - 1])
		var cur: String = bones[min(k, bones.size() - 1)]
		if t < 0.3 and prev != "":
			w = _w2(cur, prev, 0.5 * (1.0 - t / 0.3))
		else:
			w = _w(cur)
		rings.append(_ring(c, float(pr[1]) * scale_r * bk, float(pr[2]) * scale_r * bk, w))
	loft(surf, rings, cap0, cap1)

# ---------- Körper ----------

func _g(name: String) -> Vector3:
	return gpos[bone_index(name)]

func _body() -> void:
	var coat: bool = look.get("coat", false)
	var cape: bool = look.get("cape", false)
	var vest: bool = look.get("vest", false)
	var mut: bool = look.get("mutant", false)
	var tf: float = look.get("torso", 1.0)
	# Rumpf
	var torso_j := [Vector3(0, 0.83, 0), _g("spine"), _g("chest"), _g("neck"), _g("neck") + Vector3(0, 0.09, 0)]
	if mut:
		chain("skin", torso_j, ["hips", "spine", "chest", "neck"], "", [
		[0.95, 0.15 * tf, 0.108 * tf], [1.5, 0.165 * tf, 0.125 * tf, 0.02 * (tf - 1.0)],
		[2.0, 0.18 * tf, 0.132 * tf], [2.45, 0.2 * tf, 0.14 * tf, -0.008], [2.8, 0.19 * tf, 0.13 * tf, 0.02 * (tf - 1.0)], [2.95, 0.135, 0.098],
	], 1.0, false, false)
	chain("suit", torso_j, ["hips", "spine", "chest", "neck"], "", [
		[0.0, 0.12, 0.095], [0.3, 0.165, 0.118], [0.8, 0.16, 0.112], [1.0, 0.148, 0.106],
	], 1.0, true, false)
	if not mut:
		chain("suit", torso_j, ["hips", "spine", "chest", "neck"], "", [
			[1.0, 0.148, 0.106], [1.5, 0.152, 0.11], [2.0, 0.17, 0.122], [2.45, 0.195, 0.13, -0.008], [2.8, 0.19, 0.122, -0.004], [2.95, 0.135, 0.098],
		], 1.0, false, false)
	chain("skin", torso_j, ["hips", "spine", "chest", "neck"], "", [[2.85, 0.07, 0.072], [3.2, 0.056, 0.06], [3.9, 0.054, 0.058]], 1.0, false, false)
	if vest:
		chain("dark", torso_j, ["hips", "spine", "chest", "neck"], "", [
			[1.55, 0.158, 0.116], [2.0, 0.178, 0.128], [2.45, 0.204, 0.137, -0.01], [2.78, 0.198, 0.13, -0.006], [2.9, 0.15, 0.108],
		], 1.0, false, false)
	if mut:
		_mutant_extras()
	# Gürtel mit Neon
	chain("accent", torso_j, ["hips", "spine", "chest", "neck"], "", [[0.86, 0.166, 0.117], [0.94, 0.163, 0.115]], 1.03, false, false)
	chain("dark", torso_j, ["hips", "spine", "chest", "neck"], "", [[0.72, 0.17, 0.12], [0.85, 0.168, 0.119]], 1.04, false, false)
	# Kragen (hinten offen nach vorne)
	var cw := _w("chest")
	if mut:
		_limbs(true)
		_head(0.86)
		return
	var nb := _g("neck")
	loft("dark", [
		_ring(nb + Vector3(0, -0.02, 0.005), 0.11 * bk, 0.095, cw, {"a0": -PI * 0.5 + 0.5, "a1": PI * 1.5 - 0.5}),
		_ring(nb + Vector3(0, 0.08, 0.015), 0.095 * bk, 0.085, _w2("chest", "neck", 0.5), {"a0": -PI * 0.5 + 0.55, "a1": PI * 1.5 - 0.55}),
	], false, false, true)
	# Brust-Emblem
	prim("accent", _prism(0.06, 0.08, 0.02), Transform3D(Basis(Vector3.RIGHT, PI), _g("chest") + Vector3(0.08, 0.17, -0.135 * bk)), _w("chest"))
	_limbs(false)
	_head(1.0)
	# Mantel (vorne offen, Schöße folgen den Beinen)
	if coat:
		_skirt(1.0, 0.4, 0.172, 0.27, -PI * 0.5 + 0.75, PI * 1.5 - 0.75, "suit", 0.0)
	if cape:
		_cape()

func _limbs(mut: bool) -> void:
	# Arme
	for side in ["L", "R"]:
		var sx := -1.0 if side == "L" else 1.0
		var j := [_g("upperarm." + side), _g("forearm." + side), _g("hand." + side), _g("hand." + side) + Vector3(0, -0.15, -0.01)]
		var bones := ["upperarm." + side, "forearm." + side, "hand." + side]
		var asc: float = look.get("arm_" + side.to_lower(), 1.0)
		chain("skin" if mut else "suit", j, bones, "chest", [
			[0.0, 0.072, 0.074], [0.25, 0.066, 0.068], [0.85, 0.054, 0.056], [1.0, 0.052, 0.054], [1.3, 0.056, 0.058, 0.004], [1.8, 0.044, 0.046],
		], asc, true, false)
		# Handschuh + Hand
		chain("skin" if mut else "dark", j, bones, "chest", [
			[1.55, 0.053, 0.055], [1.95, 0.047, 0.047], [2.05, 0.044, 0.036], [2.45, 0.048, 0.03, -0.01], [2.9, 0.03, 0.022, -0.012],
		], asc * (1.15 if mut else 1.0), false, true)
		if not mut:
			chain("accent", j, bones, "chest", [[1.42, 0.057, 0.059], [1.48, 0.056, 0.058]], 1.06, false, false)
		# Schulter
		prim("skin" if mut else "suit", _sphere(0.074 * bk * asc, Vector3(1.0, 0.85, 1.0)), Transform3D(Basis(), _g("upperarm." + side) + Vector3(0.01 * sx, 0.01, 0)), _w2("upperarm." + side, "chest", 0.3))
		if look.get("pads", false):
			var pad := BoxMesh.new()
			pad.size = Vector3(0.17, 0.06, 0.2)
			prim("metal", pad, Transform3D(Basis(Vector3.BACK, -0.35 * sx), _g("upperarm." + side) + Vector3(0.03 * sx, 0.07, 0)), _w("upperarm." + side))
		# Beine
		var lj := [_g("thigh." + side), _g("shin." + side), _g("foot." + side)]
		var lb := ["thigh." + side, "shin." + side]
		chain("suit", lj, lb, "hips", [
			[0.0, 0.098, 0.108], [0.15, 0.102, 0.112], [0.55, 0.085, 0.094], [0.92, 0.066, 0.072], [1.0, 0.064, 0.07], [1.3, 0.066, 0.074, 0.012], [1.65, 0.052, 0.056],
		], 1.0, true, false)
		# Stiefel
		if mut:
			var ff := _g("foot." + side)
			loft("skin", [
				_ring(ff + Vector3(0, 0.0, 0.03), 0.06, 0.06, _w("foot." + side), {"t": Vector3.FORWARD}),
				_ring(ff + Vector3(0, -0.04, -0.1), 0.065, 0.035, _w("foot." + side), {"t": Vector3.FORWARD}),
			])
			continue
		chain("dark", lj, lb, "hips", [[1.5, 0.064, 0.07, 0.006], [1.62, 0.066, 0.072, 0.004], [1.9, 0.06, 0.062], [2.0, 0.062, 0.065]], 1.0, false, false)
		chain("accent", lj, lb, "hips", [[1.47, 0.066, 0.072], [1.52, 0.066, 0.072]], 1.05, false, false)
		var f := _g("foot." + side)
		var fw := _w("foot." + side)
		loft("dark", [
			_ring(f + Vector3(0, 0.0, 0.05), 0.058, 0.058, fw, {"t": Vector3.FORWARD}),
			_ring(f + Vector3(0, -0.02, -0.02), 0.064, 0.055, fw, {"t": Vector3.FORWARD}),
			_ring(f + Vector3(0, -0.04, -0.12), 0.06, 0.04, fw, {"t": Vector3.FORWARD}),
			_ring(f + Vector3(0, -0.05, -0.17), 0.045, 0.028, fw, {"t": Vector3.FORWARD}),
		])

func _head(hs: float) -> void:
	# Kopf
	var h := _g("head")
	var hw := _w("head")
	loft("skin", [
		_ring(h + Vector3(0, 0.0, -0.035), 0.06 * hs, 0.06 * hs, hw),
		_ring(h + Vector3(0, 0.035, -0.03), 0.088 * hs, 0.095 * hs, hw),
		_ring(h + Vector3(0, 0.09, -0.012), 0.108 * hs, 0.118 * hs, hw),
		_ring(h + Vector3(0, 0.15, 0.0), 0.116 * hs, 0.124 * hs, hw),
		_ring(h + Vector3(0, 0.22, 0.005), 0.108 * hs, 0.118 * hs, hw),
		_ring(h + Vector3(0, 0.27, 0.01), 0.07 * hs, 0.078 * hs, hw),
	])
	# Nase und Ohren (dezent)
	prim("skin", _prism(0.03, 0.05, 0.03), Transform3D(Basis(Vector3.RIGHT, -0.35), h + Vector3(0, 0.1, -0.128)), hw)
	for sx in [-1.0, 1.0]:
		prim("skin", _sphere(0.028, Vector3(0.5, 1.0, 0.8)), Transform3D(Basis(), h + Vector3(0.112 * sx, 0.13, 0.01)), hw)
	_hair(h, hw)
	if look.get("visor", false):
		var vb := BoxMesh.new()
		vb.size = Vector3(0.25, 0.045, 0.04)
		prim("accent", vb, Transform3D(Basis(), h + Vector3(0, 0.15, -0.12)), hw)

func _mutant_extras() -> void:
	# leuchtende Pusteln auf Rücken, Schultern und dem großen Arm
	var spots := [["chest", Vector3(0.12, 0.12, 0.14), 0.05], ["chest", Vector3(-0.08, 0.2, 0.13), 0.04], ["spine", Vector3(0.05, 0.05, 0.14), 0.045],
		["chest", Vector3(0.0, 0.26, 0.11), 0.035], ["upperarm.R", Vector3(0.08, -0.08, 0.06), 0.05], ["forearm.R", Vector3(0.07, -0.1, 0.05), 0.045],
		["upperarm.R", Vector3(0.02, -0.18, -0.09), 0.035], ["chest", Vector3(-0.16, 0.05, 0.05), 0.03]]
	for sp in spots:
		prim("accent", _sphere(float(sp[2]), Vector3.ONE), Transform3D(Basis(), _g(sp[0]) + (sp[1] as Vector3)), _w(sp[0]))

func _skirt(y0: float, y1: float, r0: float, r1: float, a0: float, a1: float, surf: String, zoff: float) -> void:
	var rings: Array = []
	var steps := 5
	for i in steps + 1:
		var k := float(i) / steps
		var y := lerpf(y0, y1, k)
		var r := lerpf(r0, r1, pow(k, 0.8)) * bk
		# Gewichte: oben Hüfte, unten anteilig das Bein der jeweiligen Seite (Mittelwert über den Ring)
		var w: Array = [[bone_index("hips"), 1.0 - 0.55 * k], [bone_index("thigh.L"), 0.275 * k], [bone_index("thigh.R"), 0.275 * k]]
		rings.append(_ring(Vector3(0, y, 0.01 + zoff + k * 0.03), r, r * 0.78, w, {"a0": a0, "a1": a1, "t": Vector3.DOWN}))
	loft(surf, rings, false, false, true)
	# Saum in Akzentfarbe
	var last: Dictionary = rings[steps].duplicate()
	var hem: Dictionary = last.duplicate()
	hem.c = (last.c as Vector3) + Vector3(0, 0.035, 0)
	loft("accent", [hem, last], false, false, true)

func _cape() -> void:
	var rings: Array = []
	var top := _g("chest") + Vector3(0, 0.22, 0.04)
	var steps := 6
	for i in steps + 1:
		var k := float(i) / steps
		var y := lerpf(top.y, 0.5, k)
		var w: Array
		if k < 0.35:
			w = _w2("chest", "spine", k / 0.35 * 0.5)
		elif k < 0.7:
			w = _w2("spine", "hips", (k - 0.35) / 0.35)
		else:
			w = [[bone_index("hips"), 0.7], [bone_index("thigh.L"), 0.15], [bone_index("thigh.R"), 0.15]]
		var r := lerpf(0.2, 0.26, k) * bk
		rings.append(_ring(Vector3(0, y, 0.05 + k * 0.1), r, r * 0.6, w, {"a0": 0.15, "a1": PI - 0.15, "t": Vector3.DOWN}))
	loft("cape", rings, false, false, true)

func _hair(h: Vector3, hw: Array) -> void:
	var style: String = look.get("hair_style", "spiky")
	# Haarkappe
	prim("hair", _sphere(0.128, Vector3(1.0, 0.82, 1.06)), Transform3D(Basis(), h + Vector3(0, 0.195, 0.012)), hw)
	match style:
		"spiky":
			# Anime-Strähnen: oben/hinten nach hinten-oben, Pony nach vorne-unten
			var spikes := [
				[Vector3(0, 0.29, 0.02), Vector3(-0.9, 0, 0), 0.2, 0.05], [Vector3(-0.06, 0.28, 0.04), Vector3(-1.1, 0, 0.35), 0.18, 0.045],
				[Vector3(0.06, 0.28, 0.04), Vector3(-1.1, 0, -0.35), 0.18, 0.045], [Vector3(0, 0.24, 0.1), Vector3(-1.9, 0, 0), 0.2, 0.05],
				[Vector3(-0.08, 0.22, 0.09), Vector3(-2.0, 0, 0.5), 0.17, 0.045], [Vector3(0.08, 0.22, 0.09), Vector3(-2.0, 0, -0.5), 0.17, 0.045],
				[Vector3(0, 0.15, 0.12), Vector3(-2.6, 0, 0), 0.15, 0.045], [Vector3(-0.11, 0.17, 0.04), Vector3(-2.2, 0, 1.2), 0.13, 0.04],
				[Vector3(0.11, 0.17, 0.04), Vector3(-2.2, 0, -1.2), 0.13, 0.04],
				# Pony
				[Vector3(-0.05, 0.24, -0.1), Vector3(2.5, 0, 0.25), 0.13, 0.035], [Vector3(0.0, 0.25, -0.11), Vector3(2.65, 0, 0.0), 0.15, 0.035],
				[Vector3(0.055, 0.24, -0.1), Vector3(2.5, 0, -0.3), 0.12, 0.035], [Vector3(-0.1, 0.2, -0.07), Vector3(2.7, 0, 0.7), 0.13, 0.03],
				[Vector3(0.1, 0.2, -0.07), Vector3(2.7, 0, -0.7), 0.12, 0.03],
			]
			for sp in spikes:
				_spike(h + (sp[0] as Vector3), sp[1], sp[2], sp[3], hw)
		"slick":
			prim("hair", _sphere(0.122, Vector3(1.04, 0.7, 1.15)), Transform3D(Basis(Vector3.RIGHT, -0.25), h + Vector3(0, 0.235, 0.03)), hw)
			for sx in [-1.0, 0.0, 1.0]:
				_spike(h + Vector3(0.05 * sx, 0.2, 0.12), Vector3(-2.3, 0, -0.4 * sx), 0.2, 0.05, hw)
		"short":
			for sx in [-1.0, 0.0, 1.0]:
				_spike(h + Vector3(0.05 * sx, 0.25, -0.1), Vector3(2.4, 0, -0.3 * sx), 0.09, 0.04, hw)
			_spike(h + Vector3(0, 0.27, 0.05), Vector3(-1.2, 0, 0), 0.1, 0.05, hw)
		"buzz":
			pass
		"long":
			_spike(h + Vector3(0, 0.16, 0.12), Vector3(-2.9, 0, 0), 0.32, 0.09, hw)
			for sx in [-1.0, 1.0]:
				_spike(h + Vector3(0.1 * sx, 0.12, 0.03), Vector3(-3.0, 0, 0.15 * sx), 0.24, 0.05, hw)

func _spike(p: Vector3, rot: Vector3, length: float, r: float, hw: Array) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 5
	c.rings = 1
	var b := Basis.from_euler(rot)
	prim("hair", c, Transform3D(b, p + b * Vector3(0, length * 0.42, 0)), hw)

func _sphere(r: float, sc: Vector3) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	s.set_meta("sc", sc)
	return s

func _prism(w: float, h: float, d: float) -> PrismMesh:
	var p := PrismMesh.new()
	p.size = Vector3(w, h, d)
	return p
