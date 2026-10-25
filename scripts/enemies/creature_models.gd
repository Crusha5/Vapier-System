class_name CreatureModel
extends Node3D
## Karkosa (insektoid) aus glatten, gerippten Lofts mit prozeduraler Animation.
## Blickrichtung −Z. kind: "karkosa", "karkosa_elite", "brood" (Brutmutter, Boss)

var kind := "karkosa"
var body: Node3D
var head: Node3D
var abdomen: Node3D
var legs: Array = []      # [pivot, knee, seite, phase_offset]
var scythes: Array = []   # Pivots der Sichelarme
var phase := 0.0
var move_amt := 0.0
var action := ""
var action_t := 0.0
var _t := 0.0

const PALETTE := {
	"karkosa": {"chitin": Color(0.12, 0.28, 0.27), "plate": Color(0.2, 0.42, 0.38), "glow": Color(0.75, 1.0, 0.2), "bone": Color(0.86, 0.84, 0.72), "scale": 1.0, "belly": 1.0},
	"karkosa_elite": {"chitin": Color(0.22, 0.06, 0.08), "plate": Color(0.42, 0.1, 0.12), "glow": Color(1.0, 0.55, 0.1), "bone": Color(0.95, 0.88, 0.75), "scale": 1.35, "belly": 1.0},
	"brood": {"chitin": Color(0.2, 0.06, 0.22), "plate": Color(0.38, 0.12, 0.36), "glow": Color(1.0, 0.25, 0.75), "bone": Color(0.9, 0.82, 0.86), "scale": 2.3, "belly": 1.55},
}

static var _meshes := {}

func _init(k := "karkosa") -> void:
	kind = k if PALETTE.has(k) else "karkosa"

func _ready() -> void:
	_build()

func _mats() -> Dictionary:
	var p: Dictionary = PALETTE[kind]
	var rim := {"rim": 0.5, "rim_color": Color(0.35, 1.0, 0.85) if kind == "karkosa" else (p.glow as Color)}
	return {
		"chitin": Toon.amat(p.chitin, {"outline": 0.026, "spec": 0.6, "rim": rim.rim, "rim_color": rim.rim_color}),
		"plate": Toon.amat(p.plate, {"outline": 0.026, "spec": 0.9, "rim": rim.rim, "rim_color": rim.rim_color}),
		"glow": Toon.amat(p.glow, {"emit": p.glow, "energy": 2.6, "outline": 0.01}),
		"bone": Toon.amat(p.bone, {"outline": 0.02, "spec": 0.7, "rim": 0.2}),
	}

func _mi(parent: Node3D, part: String, mats: Dictionary, pos := Vector3.ZERO) -> MeshInstance3D:
	var key := kind + "|" + part
	if not _meshes.has(key):
		_meshes[key] = BodyBuilder.sculpt(["chitin", "plate", "glow", "bone"], Callable(self, "_part_" + part.split(":")[0]).bind(part))
	var res: Dictionary = _meshes[key]
	var mi := MeshInstance3D.new()
	mi.mesh = res.mesh
	var surfs: Array = res.surfaces
	for i in surfs.size():
		mi.set_surface_override_material(i, mats[surfs[i]])
	mi.position = pos
	parent.add_child(mi)
	return mi

func _p(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build() -> void:
	var pal: Dictionary = PALETTE[kind]
	scale = Vector3.ONE * float(pal.scale)
	var mats := _mats()
	body = _p(self, Vector3(0, 0.72, 0))
	_mi(body, "thorax", mats)
	abdomen = _p(body, Vector3(0, 0.0, 0.15))
	_mi(abdomen, "abdomen", mats)
	head = _p(body, Vector3(0, 0.06, -0.44))
	_mi(head, "head", mats)
	for sx in [-1.0, 1.0]:
		var sp := _p(body, Vector3(0.22 * sx, 0.1, -0.36))
		_mi(sp, "scythe:%d" % int(sx), mats)
		scythes.append(sp)
	var i := 0
	for sx in [-1.0, 1.0]:
		for zz in [-0.18, 0.08]:
			var lp := _p(body, Vector3(0.2 * sx, -0.02, zz))
			_mi(lp, "femur:%d" % int(sx), mats)
			var kn := _p(lp, Vector3(0.46 * sx, 0.24, 0))
			_mi(kn, "tibia:%d" % int(sx), mats)
			lp.rotation.y = (0.35 if zz < 0 else -0.35) * sx
			legs.append([lp, kn, sx, (0.0 if (i % 2 == 0) else PI)])
			i += 1

# ---------- Teile ----------

func _part_thorax(b: BodyBuilder, _p2: String) -> void:
	var f := Vector3.BACK
	b.loft("chitin", [
		BodyBuilder.rr(Vector3(0, 0.02, -0.44), 0.11, 0.1, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.04, -0.32), 0.19, 0.16, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.05, -0.2), 0.2, 0.17, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.06, -0.08), 0.25, 0.2, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.05, 0.06), 0.23, 0.19, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.03, 0.2), 0.15, 0.14, {"t": f}),
	])
	# Rückenplatten + Stacheln
	for z in [-0.3, -0.12, 0.05]:
		b.loft("plate", [
			BodyBuilder.rr(Vector3(0, 0.07, z - 0.05), 0.2, 0.18, {"t": f, "a0": -PI * 0.5 - 1.1, "a1": -PI * 0.5 + 1.1}),
			BodyBuilder.rr(Vector3(0, 0.08, z + 0.05), 0.24, 0.2, {"t": f, "a0": -PI * 0.5 - 1.1, "a1": -PI * 0.5 + 1.1}),
		], false, false, true)
		_cone(b, "bone", Vector3(0, 0.27, z), Vector3(-0.5, 0, 0), 0.18 if kind != "brood" else 0.3, 0.035)

func _part_abdomen(b: BodyBuilder, _p2: String) -> void:
	var k: float = PALETTE[kind].belly
	var f := Vector3.BACK
	var prof := [[0.0, 0.15, 0.0], [0.14, 0.27, 0.05], [0.26, 0.25, 0.06], [0.4, 0.33, 0.08], [0.52, 0.3, 0.09], [0.66, 0.34, 0.1], [0.78, 0.29, 0.09], [0.9, 0.23, 0.07], [1.0, 0.11, 0.04]]
	var rings: Array = []
	for pr in prof:
		rings.append(BodyBuilder.rr(Vector3(0, float(pr[2]) * k, float(pr[0]) * k), float(pr[1]) * k, float(pr[1]) * 0.82 * k, {"t": f}))
	b.loft("plate", rings)
	# leuchtende Streifen in den Furchen
	for z in [0.26, 0.52, 0.78]:
		var r: float = 0.26 * k if z < 0.3 else (0.31 * k if z < 0.6 else 0.3 * k)
		b.loft("glow", [
			BodyBuilder.rr(Vector3(0, 0.07 * k, (z - 0.015) * k), r * 1.02, r * 0.84, {"t": f, "a0": -PI * 0.5 - 1.2, "a1": -PI * 0.5 + 1.2}),
			BodyBuilder.rr(Vector3(0, 0.07 * k, (z + 0.015) * k), r * 1.02, r * 0.84, {"t": f, "a0": -PI * 0.5 - 1.2, "a1": -PI * 0.5 + 1.2}),
		], false, false, true)
	if kind == "brood":
		# Eiersäcke an den Seiten
		for sx in [-1.0, 1.0]:
			for z in [0.35, 0.6]:
				b.prim("glow", _sph(0.12, Vector3(1, 0.8, 1.2)), Transform3D(Basis(), Vector3(0.36 * sx * k, 0.0, z * k)), [[0, 1.0]])

func _part_head(b: BodyBuilder, _p2: String) -> void:
	var f := Vector3.FORWARD
	b.loft("chitin", [
		BodyBuilder.rr(Vector3(0, 0.0, 0.06), 0.09, 0.08, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.02, -0.04), 0.14, 0.11, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.02, -0.16), 0.13, 0.1, {"t": f}),
		BodyBuilder.rr(Vector3(0, -0.01, -0.27), 0.08, 0.06, {"t": f}),
		BodyBuilder.rr(Vector3(0, -0.03, -0.33), 0.04, 0.035, {"t": f}),
	])
	# Kamm
	b.loft("plate", [
		BodyBuilder.rr(Vector3(0, 0.08, 0.04), 0.03, 0.06, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.12, -0.08), 0.025, 0.07, {"t": f}),
		BodyBuilder.rr(Vector3(0, 0.07, -0.2), 0.015, 0.03, {"t": f}),
	])
	for sx in [-1.0, 1.0]:
		b.prim("glow", _sph(0.042, Vector3(1.0, 0.8, 1.2)), Transform3D(Basis(), Vector3(0.085 * sx, 0.06, -0.15)), [[0, 1.0]])
		b.prim("glow", _sph(0.026, Vector3.ONE), Transform3D(Basis(), Vector3(0.115 * sx, 0.05, -0.07)), [[0, 1.0]])
		# Mandibeln: gebogene Hörner nach vorne-innen
		_cone(b, "bone", Vector3(0.07 * sx, -0.06, -0.27), Vector3(1.75, 0, -0.5 * sx), 0.2, 0.03)
		# Fühler
		_cone(b, "plate", Vector3(0.05 * sx, 0.1, -0.12), Vector3(-0.6, 0, -0.5 * sx), 0.32, 0.012)

func _part_scythe(b: BodyBuilder, part: String) -> void:
	var sx := float(part.split(":")[1])
	var e := Vector3(0.1 * sx, 0.06, -0.48)
	b.loft("chitin", [
		BodyBuilder.rr(Vector3.ZERO, 0.055, 0.055),
		BodyBuilder.rr(e * 0.5 + Vector3(0, 0.02, 0), 0.05, 0.05),
		BodyBuilder.rr(e, 0.04, 0.04),
	])
	b.prim("plate", _sph(0.06, Vector3.ONE), Transform3D(Basis(), e), [[0, 1.0]])
	# Sichelklinge: flacher, gebogener Loft
	var rings: Array = []
	var n := 9
	for i in n + 1:
		var u := float(i) / n
		var p := e + Vector3(0.02 * sx * u, 0.06 - 0.82 * u, -0.28 * sin(PI * u * 0.9))
		var nxt := e + Vector3(0.02 * sx * (u + 0.01), 0.06 - 0.82 * (u + 0.01), -0.28 * sin(PI * (u + 0.01) * 0.9))
		var w := lerpf(0.085, 0.008, pow(u, 1.2))
		rings.append(BodyBuilder.rr(p, 0.014, w, {"t": (nxt - p).normalized()}))
	b.loft("bone", rings)

func _part_femur(b: BodyBuilder, part: String) -> void:
	var sx := float(part.split(":")[1])
	var kn := Vector3(0.46 * sx, 0.24, 0)
	b.loft("chitin", [
		BodyBuilder.rr(Vector3.ZERO, 0.06, 0.06),
		BodyBuilder.rr(kn * 0.35 + Vector3(0, 0.03, 0), 0.055, 0.06),
		BodyBuilder.rr(kn * 0.8, 0.045, 0.048),
		BodyBuilder.rr(kn, 0.04, 0.04),
	])
	b.prim("plate", _sph(0.055, Vector3.ONE), Transform3D(Basis(), kn), [[0, 1.0]])

func _part_tibia(b: BodyBuilder, part: String) -> void:
	var sx := float(part.split(":")[1])
	var tip := Vector3(0.2 * sx, -0.95, 0)
	b.loft("chitin", [
		BodyBuilder.rr(Vector3.ZERO, 0.042, 0.042),
		BodyBuilder.rr(tip * 0.3 + Vector3(0.03 * sx, 0, 0), 0.036, 0.036),
		BodyBuilder.rr(tip * 0.75, 0.022, 0.022),
		BodyBuilder.rr(tip, 0.006, 0.006),
	])
	_cone(b, "bone", tip * 0.35 + Vector3(0.03 * sx, 0, 0), Vector3(0, 0, -1.9 * sx), 0.1, 0.018)

func _cone(b: BodyBuilder, surf: String, p: Vector3, rot: Vector3, length: float, r: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 6
	c.rings = 1
	var bs := Basis.from_euler(rot)
	b.prim(surf, c, Transform3D(bs, p + bs * Vector3(0, length * 0.45, 0)), [[0, 1.0]])

func _sph(r: float, sc: Vector3) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	s.set_meta("sc", sc)
	return s

# ---------- Animation ----------

func play(a: String) -> void:
	action = a
	action_t = 0.0

func animate(delta: float, speed: float, action_len := 0.4) -> void:
	_t += delta
	move_amt = lerpf(move_amt, clampf(speed / 4.0, 0.0, 1.5), minf(1.0, delta * 8.0))
	phase += delta * (5.0 + speed * 2.2)
	if action != "" and action != "dead":
		action_t += delta / maxf(action_len, 0.05)
		if action_t >= 1.0 and action != "windup":
			action = ""
	var m := move_amt
	body.position.y = 0.72 + sin(phase * 2.0) * 0.03 * m + sin(_t * 2.0) * 0.015
	body.rotation = Vector3(0, sin(phase) * 0.06 * m, sin(phase) * 0.04 * m)
	head.rotation = Vector3(sin(_t * 3.1) * 0.08, sin(_t * 1.7) * 0.2, 0)
	abdomen.rotation = Vector3(sin(_t * 1.3) * 0.05 - 0.05 * m, -sin(phase) * 0.08 * m, 0)
	for l in legs:
		var lp: Node3D = l[0]
		var kn: Node3D = l[1]
		var sx: float = l[2]
		var ph: float = phase + float(l[3])
		lp.rotation.x = 0.0
		lp.rotation.z = maxf(0.0, cos(ph)) * 0.35 * m * sx
		lp.rotation.y = lerpf(lp.rotation.y, (sin(ph) * 0.45 * m) * sx + (0.35 if lp.position.z < 0 else -0.35) * sx, 0.5)
		kn.rotation = Vector3(0, 0, -maxf(0.0, cos(ph)) * 0.25 * m * sx)
	var t: float = clampf(action_t, 0.0, 1.0)
	for i in scythes.size():
		var sp: Node3D = scythes[i]
		var sx := -1.0 if i == 0 else 1.0
		var pose := Vector3(0.55 + sin(_t * 2.0 + i) * 0.08, 0.0, 0.0)
		match action:
			"windup":
				var w := minf(t * 1.5, 1.0)
				pose = Vector3(1.5 * w, -0.35 * sx * w, 0)
				body.rotation.x = 0.28 * w
				head.rotation.x = -0.3 * w
			"attack":
				var k: float = 1.0 - pow(1.0 - t, 3.0)
				pose = Vector3(lerpf(1.5, -1.0, k), lerpf(-0.35, 0.45, k) * sx, 0)
				body.rotation.x = lerpf(0.28, -0.22, k)
			"hurt":
				body.rotation.x = 0.3 * sin(t * PI)
				pose.x += 0.6 * sin(t * PI)
			"spit":
				head.rotation.x = -0.5 * sin(t * PI)
		sp.rotation = pose
	if action == "dead":
		action_t = minf(1.0, action_t + delta * 2.0)
		body.rotation.z = lerpf(0.0, 2.6, action_t)
		body.position.y = lerpf(body.position.y, 0.35, action_t)
		for l in legs:
			(l[1] as Node3D).rotation.z = lerpf(0.0, 1.2 * float(l[2]), action_t)
