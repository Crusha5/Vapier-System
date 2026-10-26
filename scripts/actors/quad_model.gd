class_name QuadModel
extends Node3D
## Vierbeiner von Veyra aus glatten Lofts: „grazer“ (Grauläufer, scheues Weidetier) und
## „reisser“ (Reißer, nachtaktive Bestie mit Knochenkamm). Prozedurale Lauf- und Angriffsanimation.

var kind := "grazer"
var body: Node3D
var neck: Node3D
var head: Node3D
var tail: Node3D
var legs: Array = []   # [hüfte, knie, vorn?, seite, phase]
var phase := 0.0
var move_amt := 0.0
var action := ""
var action_t := 0.0
var _t := 0.0

static var _meshes := {}

const PAL := {
	"grazer": {"fur": Color(0.42, 0.38, 0.33), "belly": Color(0.62, 0.58, 0.5), "dark": Color(0.2, 0.17, 0.15), "eye": Color(0.1, 0.1, 0.1), "glow": 0.0, "scale": 1.0},
	"reisser": {"fur": Color(0.16, 0.14, 0.15), "belly": Color(0.3, 0.24, 0.22), "dark": Color(0.08, 0.07, 0.07), "eye": Color(1.0, 0.25, 0.1), "glow": 3.0, "scale": 1.15},
}

func _init(k := "grazer") -> void:
	kind = k

func _ready() -> void:
	var pal: Dictionary = PAL[kind]
	scale = Vector3.ONE * float(pal.scale)
	var mats := {
		"fur": Toon.mat(pal.fur, {"rough": 1.0, "outline": 0.02, "grime": 0.5}),
		"belly": Toon.mat(pal.belly, {"rough": 1.0, "outline": 0.02}),
		"dark": Toon.mat(pal.dark, {"rough": 0.6, "outline": 0.02}),
		"eye": Toon.mat(pal.eye, {"emit": pal.eye, "energy": pal.glow} if float(pal.glow) > 0.0 else {"rough": 0.2}),
	}
	var hip_y := 0.95 if kind == "grazer" else 0.8
	body = _p(self, Vector3(0, hip_y, 0))
	_mi(body, "body", mats)
	neck = _p(body, Vector3(0, 0.12, -0.55))
	_mi(neck, "neck", mats)
	head = _p(neck, Vector3(0, 0.45, -0.25) if kind == "grazer" else Vector3(0, 0.12, -0.32))
	_mi(head, "head", mats)
	tail = _p(body, Vector3(0, 0.1, 0.6))
	_mi(tail, "tail", mats)
	var i := 0
	for front in [true, false]:
		for sx in [-1.0, 1.0]:
			var hp := _p(body, Vector3(0.18 * sx, -0.05, -0.42 if front else 0.42))
			_mi(hp, "upper", mats)
			var kn := _p(hp, Vector3(0, -0.42 if kind == "grazer" else -0.36, 0))
			_mi(kn, "lower", mats)
			legs.append([hp, kn, front, sx, 0.0 if (i == 0 or i == 3) else PI])
			i += 1

func _p(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _mi(parent: Node3D, part: String, mats: Dictionary) -> void:
	var key := kind + part
	if not _meshes.has(key):
		_meshes[key] = BodyBuilder.sculpt(["fur", "belly", "dark", "eye"], Callable(self, "_part").bind(part))
	var res: Dictionary = _meshes[key]
	var mi := MeshInstance3D.new()
	mi.mesh = res.mesh
	var surfs: Array = res.surfaces
	for k in surfs.size():
		mi.set_surface_override_material(k, mats[surfs[k]])
	parent.add_child(mi)

func _part(b: BodyBuilder, part: String) -> void:
	var g := kind == "grazer"
	var R := BodyBuilder.rr
	match part:
		"body":
			var f := Vector3.BACK
			if g:
				b.loft("fur", [R.call(Vector3(0, 0.05, -0.68), 0.12, 0.14, {"t": f}), R.call(Vector3(0, 0.08, -0.5), 0.22, 0.26, {"t": f}),
					R.call(Vector3(0, 0.04, -0.1), 0.24, 0.28, {"t": f}), R.call(Vector3(0, 0.05, 0.3), 0.23, 0.27, {"t": f}), R.call(Vector3(0, 0.07, 0.62), 0.12, 0.14, {"t": f})])
				b.loft("belly", [R.call(Vector3(0, -0.1, -0.4), 0.17, 0.12, {"t": f}), R.call(Vector3(0, -0.12, 0.0), 0.2, 0.14, {"t": f}), R.call(Vector3(0, -0.1, 0.35), 0.16, 0.11, {"t": f})])
			else:
				b.loft("fur", [R.call(Vector3(0, 0.1, -0.7), 0.16, 0.18, {"t": f}), R.call(Vector3(0, 0.14, -0.45), 0.28, 0.32, {"t": f}),
					R.call(Vector3(0, 0.06, -0.05), 0.24, 0.27, {"t": f}), R.call(Vector3(0, 0.0, 0.3), 0.19, 0.22, {"t": f}), R.call(Vector3(0, 0.02, 0.6), 0.1, 0.12, {"t": f})])
				# Knochenkamm auf dem Rücken
				for k in 6:
					var z := -0.55 + k * 0.2
					_cone(b, "belly", Vector3(0, 0.38 - k * 0.025, z), Vector3(-0.5, 0, 0), 0.32 - k * 0.03, 0.05)
		"neck":
			if g:
				b.loft("fur", [R.call(Vector3(0, -0.02, 0.05), 0.12, 0.14), R.call(Vector3(0, 0.25, -0.12), 0.09, 0.1), R.call(Vector3(0, 0.46, -0.24), 0.08, 0.09)])
			else:
				b.loft("fur", [R.call(Vector3(0, 0.0, 0.08), 0.18, 0.2), R.call(Vector3(0, 0.08, -0.16), 0.14, 0.15), R.call(Vector3(0, 0.12, -0.32), 0.12, 0.13)])
		"head":
			var f := Vector3.FORWARD
			if g:
				b.loft("fur", [R.call(Vector3(0, 0.02, 0.08), 0.08, 0.09, {"t": f}), R.call(Vector3(0, 0.02, -0.06), 0.09, 0.1, {"t": f}), R.call(Vector3(0, -0.03, -0.22), 0.05, 0.06, {"t": f}), R.call(Vector3(0, -0.05, -0.3), 0.03, 0.035, {"t": f})])
				for sx in [-1.0, 1.0]:
					b.prim("eye", _sph(0.022), Transform3D(Basis(), Vector3(0.075 * sx, 0.05, -0.06)), [[0, 1.0]])
					_cone(b, "fur", Vector3(0.06 * sx, 0.1, 0.04), Vector3(-0.4, 0, -0.9 * sx), 0.14, 0.03)
					# kleines Geweih
					_cone(b, "dark", Vector3(0.04 * sx, 0.11, -0.01), Vector3(-0.3, 0, -0.35 * sx), 0.28, 0.018)
			else:
				b.loft("fur", [R.call(Vector3(0, 0.02, 0.1), 0.12, 0.13, {"t": f}), R.call(Vector3(0, 0.03, -0.06), 0.13, 0.14, {"t": f}), R.call(Vector3(0, -0.02, -0.26), 0.08, 0.09, {"t": f}), R.call(Vector3(0, -0.04, -0.38), 0.05, 0.06, {"t": f})])
				b.loft("dark", [R.call(Vector3(0, -0.09, -0.08), 0.09, 0.05, {"t": f}), R.call(Vector3(0, -0.1, -0.34), 0.05, 0.03, {"t": f})])
				for sx in [-1.0, 1.0]:
					b.prim("eye", _sph(0.028), Transform3D(Basis(), Vector3(0.08 * sx, 0.06, -0.14)), [[0, 1.0]])
					_cone(b, "belly", Vector3(0.03 * sx, -0.08, -0.34), Vector3(PI, 0, 0), 0.08, 0.015)
					_cone(b, "fur", Vector3(0.08 * sx, 0.12, 0.02), Vector3(-0.9, 0, -0.5 * sx), 0.16, 0.04)
		"tail":
			if g:
				b.loft("fur", [R.call(Vector3.ZERO, 0.05, 0.05), R.call(Vector3(0, -0.05, 0.12), 0.04, 0.03), R.call(Vector3(0, -0.12, 0.18), 0.01, 0.01)])
			else:
				b.loft("fur", [R.call(Vector3.ZERO, 0.07, 0.07), R.call(Vector3(0, 0.02, 0.3), 0.05, 0.05), R.call(Vector3(0, -0.05, 0.6), 0.02, 0.02)])
		"upper":
			var l := 0.42 if g else 0.36
			b.loft("fur", [R.call(Vector3(0, 0.05, 0), 0.08 if g else 0.11, 0.1 if g else 0.13), R.call(Vector3(0, -l * 0.5, 0.02), 0.06 if g else 0.08, 0.07 if g else 0.09), R.call(Vector3(0, -l, 0), 0.04 if g else 0.06, 0.04 if g else 0.06)])
		"lower":
			var l := 0.48 if g else 0.42
			b.loft("fur" if not g else "belly", [R.call(Vector3.ZERO, 0.035 if g else 0.055, 0.035 if g else 0.055), R.call(Vector3(0, -l * 0.8, 0.02), 0.025 if g else 0.045, 0.025 if g else 0.045)])
			b.loft("dark", [R.call(Vector3(0, -l * 0.8, 0.02), 0.03 if g else 0.05, 0.035 if g else 0.06), R.call(Vector3(0, -l, -0.03), 0.035 if g else 0.06, 0.04 if g else 0.07)])

func _cone(b: BodyBuilder, surf: String, p: Vector3, rot: Vector3, length: float, r: float) -> void:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = length
	c.radial_segments = 5
	c.rings = 1
	var bs := Basis.from_euler(rot)
	b.prim(surf, c, Transform3D(bs, p + bs * Vector3(0, length * 0.45, 0)), [[0, 1.0]])

func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 6
	s.rings = 4
	return s

func play(a: String) -> void:
	action = a
	action_t = 0.0
	if a == "":
		body.rotation.z = 0.0

func animate(delta: float, speed: float) -> void:
	_t += delta
	move_amt = lerpf(move_amt, clampf(speed / 4.5, 0.0, 1.6), minf(1.0, delta * 8.0))
	phase += delta * (3.0 + speed * 2.6)
	var m := move_amt
	if action != "" and action != "dead" and action != "graze" and action != "lie":
		action_t += delta / 0.45
		if action_t >= 1.0 and action != "windup":
			action = ""
	var gallop := m > 1.0
	body.position.y = (0.95 if kind == "grazer" else 0.8) + absf(sin(phase)) * 0.06 * m
	body.rotation = Vector3(sin(phase * (2.0 if gallop else 1.0)) * 0.05 * m, 0, sin(phase) * 0.03 * m)
	neck.rotation = Vector3(sin(phase * 2.0) * 0.06 * m, 0, 0)
	head.rotation = Vector3(0, sin(_t * 0.7) * 0.25 * (1.0 - m), 0)
	tail.rotation = Vector3(-0.3 + sin(_t * 3.0) * 0.1, sin(_t * 2.0) * 0.4, 0)
	for l in legs:
		var hp: Node3D = l[0]
		var kn: Node3D = l[1]
		var ph: float = phase + float(l[4]) + (0.0 if l[2] else (PI * 0.5 if gallop else 0.0))
		var sw := sin(ph) * 0.65 * m
		hp.rotation.x = sw if l[2] else -sw
		kn.rotation.x = (maxf(0.0, -cos(ph)) * 0.9 * m) * (-1.0 if l[2] else 1.0)
	var t := clampf(action_t, 0.0, 1.0)
	match action:
		"graze":
			neck.rotation.x = lerpf(neck.rotation.x, 1.1, minf(1.0, _t))
			head.rotation.x = 0.3 + sin(_t * 4.0) * 0.08
		"alert":
			neck.rotation.x = -0.3
		"windup":
			body.rotation.x = 0.18 * minf(t * 2.0, 1.0)
			neck.rotation.x = 0.35 * minf(t * 2.0, 1.0)
		"attack":
			var k := 1.0 - pow(1.0 - t, 3.0)
			body.rotation.x = lerpf(0.18, -0.25, k)
			neck.rotation.x = lerpf(0.35, -0.4, k)
			head.rotation.x = -0.4 * sin(t * PI)
		"hurt":
			body.rotation.z = 0.25 * sin(t * PI)
		"dead", "lie":
			action_t = minf(1.0, action_t + delta * 2.0)
			body.rotation.z = lerpf(0.0, PI * 0.5, action_t)
			body.position.y = lerpf(body.position.y, 0.35, action_t)
