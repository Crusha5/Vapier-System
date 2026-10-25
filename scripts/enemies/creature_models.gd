class_name CreatureModel
extends Node3D
## Prozedurale Modelle + Animation für Karkosa (insektoid) und Mutanten.
## Blickrichtung −Z. kind: "karkosa", "karkosa_elite", "mutant"

var kind := "karkosa"
var body: Node3D
var head: Node3D
var legs: Array = []      # [pivot, knee, seite, phase_offset]
var scythes: Array = []   # Pivots der Sichelarme
var big_arm: Node3D
var phase := 0.0
var move_amt := 0.0
var action := ""
var action_t := 0.0
var _t := 0.0

func _init(k := "karkosa") -> void:
	kind = k

func _ready() -> void:
	if kind == "mutant":
		_build_mutant()
	else:
		_build_karkosa(kind == "karkosa_elite")

func _m(c: Color, extra := {}) -> Material:
	var o := {"outline": 0.03, "radial": 1.0, "rim": 0.45, "rim_color": Color(0.3, 1.0, 0.8)}
	for k in extra:
		o[k] = extra[k]
	return Toon.amat(c, o)

func _p(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build_karkosa(elite: bool) -> void:
	var sc := 1.35 if elite else 1.0
	scale = Vector3.ONE * sc
	var chitin := _m(Toon.CHITIN if not elite else Color(0.32, 0.12, 0.14))
	var plate := _m((Toon.CHITIN if not elite else Color(0.32, 0.12, 0.14)).lightened(0.18), {"spec": 0.5})
	var glow_c := Color(0.75, 1.0, 0.2) if not elite else Color(1.0, 0.55, 0.1)
	var glow := Toon.amat(glow_c, {"emit": glow_c, "energy": 2.4})
	var bone := _m(Color(0.82, 0.8, 0.68))
	body = _p(self, Vector3(0, 0.72, 0))
	Toon.sphere(body, 0.36, Vector3.ZERO, chitin, Vector3(1.0, 0.8, 1.45), 10)
	Toon.sphere(body, 0.4, Vector3(0, 0.08, 0.62), plate, Vector3(1.0, 0.85, 1.4), 10)
	for i in 3:
		Toon.box(body, Vector3(0.5 - i * 0.08, 0.03, 0.05), Vector3(0, 0.36 - i * 0.02, 0.45 + i * 0.22), glow)
	for i in 4:
		Toon.prism(body, Vector3(0.12, 0.24, 0.12), Vector3(0, 0.3 + (0.04 if i % 2 == 0 else 0.0), -0.25 + i * 0.25), plate, Vector3(-0.4, 0, 0))
	head = _p(body, Vector3(0, 0.08, -0.55))
	Toon.sphere(head, 0.2, Vector3.ZERO, plate, Vector3(1.1, 0.85, 1.3), 8)
	for sx in [-1.0, 1.0]:
		var e := Toon.sphere(head, 0.045, Vector3(0.09 * sx, 0.07, -0.17), glow, Vector3.ONE, 6)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Toon.sphere(head, 0.03, Vector3(0.14 * sx, 0.1, -0.1), glow, Vector3.ONE, 6)
		Toon.prism(head, Vector3(0.06, 0.24, 0.05), Vector3(0.08 * sx, -0.08, -0.25), bone, Vector3(-1.9, 0, 0.35 * sx))
	# Sichelarme vorne
	for sx in [-1.0, 1.0]:
		var sp := _p(body, Vector3(0.26 * sx, 0.12, -0.4))
		Toon.box(sp, Vector3(0.08, 0.08, 0.55), Vector3(0, 0, -0.25), chitin, Vector3(0, 0.25 * sx, 0))
		var tip := _p(sp, Vector3(0.12 * sx, 0, -0.5))
		Toon.prism(tip, Vector3(0.06, 0.7, 0.14), Vector3(0, -0.3, 0), bone, Vector3(0.0, 0, 0))
		scythes.append(sp)
	# Laufbeine (2 Paar pro Seite)
	var i := 0
	for sx in [-1.0, 1.0]:
		for zz in [-0.05, 0.45]:
			var lp := _p(body, Vector3(0.3 * sx, 0.0, zz))
			Toon.box(lp, Vector3(0.5, 0.07, 0.07), Vector3(0.24 * sx, 0.12, 0), chitin, Vector3(0, 0, 0.45 * sx))
			var kn := _p(lp, Vector3(0.46 * sx, 0.24, 0))
			Toon.box(kn, Vector3(0.06, 0.95, 0.06), Vector3(0.1 * sx, -0.42, 0), chitin, Vector3(0, 0, 0.22 * sx))
			legs.append([lp, kn, sx, (0.0 if (i % 2 == 0) else PI)])
			i += 1

func _build_mutant() -> void:
	var flesh := _m(Color(0.42, 0.36, 0.44), {"rim_color": Color(0.8, 0.4, 1.0)})
	var dark := _m(Color(0.22, 0.18, 0.26), {"rim_color": Color(0.8, 0.4, 1.0)})
	var glow_c := Color(0.75, 0.35, 1.0)
	var glow := Toon.amat(glow_c, {"emit": glow_c, "energy": 2.2})
	body = _p(self, Vector3(0, 1.0, 0))
	Toon.sphere(body, 0.5, Vector3(0, 0.1, 0.05), flesh, Vector3(1.15, 0.95, 0.9), 10)
	Toon.sphere(body, 0.36, Vector3(0, -0.3, 0.05), dark, Vector3(1.0, 0.8, 0.9), 8)
	for p in [Vector3(0.3, 0.35, 0.2), Vector3(-0.25, 0.25, 0.3), Vector3(0.1, 0.5, 0.25), Vector3(0.38, 0.0, -0.1), Vector3(-0.42, 0.1, -0.05)]:
		Toon.sphere(body, 0.09, p, glow, Vector3.ONE, 6)
	head = _p(body, Vector3(0, 0.35, -0.42))
	Toon.sphere(head, 0.2, Vector3.ZERO, flesh, Vector3(1.0, 0.9, 1.0), 8)
	for sx in [-1.0, 1.0]:
		Toon.sphere(head, 0.045, Vector3(0.08 * sx, 0.04, -0.17), glow, Vector3.ONE, 6)
	Toon.box(head, Vector3(0.22, 0.05, 0.05), Vector3(0, -0.09, -0.18), _m(Color(0.1, 0.02, 0.05)))
	# riesiger rechter Arm, dünner linker
	big_arm = _p(body, Vector3(0.55, 0.25, -0.05))
	Toon.sphere(big_arm, 0.22, Vector3(0, 0, 0), flesh, Vector3.ONE, 8)
	Toon.box(big_arm, Vector3(0.26, 0.6, 0.26), Vector3(0.05, -0.36, -0.02), flesh, Vector3(0, 0, 0.15))
	Toon.sphere(big_arm, 0.24, Vector3(0.12, -0.75, -0.04), dark, Vector3(1.0, 1.0, 1.1), 8)
	Toon.sphere(big_arm, 0.07, Vector3(0.0, -0.3, -0.16), glow, Vector3.ONE, 6)
	var la := _p(body, Vector3(-0.5, 0.2, -0.05))
	Toon.box(la, Vector3(0.12, 0.65, 0.12), Vector3(0, -0.3, 0), flesh, Vector3(0, 0, -0.2))
	scythes.append(la)
	var i := 0
	for sx in [-1.0, 1.0]:
		var lp := _p(body, Vector3(0.22 * sx, -0.45, 0.05))
		Toon.box(lp, Vector3(0.2, 0.36, 0.2), Vector3(0, -0.16, 0), dark)
		var kn := _p(lp, Vector3(0, -0.32, 0))
		Toon.box(kn, Vector3(0.16, 0.3, 0.18), Vector3(0, -0.12, -0.03), dark)
		Toon.box(kn, Vector3(0.22, 0.08, 0.3), Vector3(0, -0.25, -0.06), dark)
		legs.append([lp, kn, sx, (0.0 if i == 0 else PI)])
		i += 1

func play(a: String) -> void:
	action = a
	action_t = 0.0

func animate(delta: float, speed: float, action_len := 0.4) -> void:
	_t += delta
	move_amt = lerp(move_amt, clamp(speed / 4.0, 0.0, 1.5), min(1.0, delta * 8.0))
	phase += delta * (5.0 + speed * 2.2)
	if action != "" and action != "dead":
		action_t += delta / max(action_len, 0.05)
		if action_t >= 1.0 and action != "windup":
			action = ""
	var m := move_amt
	if kind == "mutant":
		_anim_mutant(m)
	else:
		_anim_karkosa(m)
	if action == "dead":
		action_t = min(1.0, action_t + delta * 2.0)
		body.rotation.z = lerp(0.0, 2.6, action_t)
		body.position.y = lerp(body.position.y, 0.35, action_t)

func _anim_karkosa(m: float) -> void:
	body.position.y = 0.72 + sin(phase * 2.0) * 0.03 * m + sin(_t * 2.0) * 0.015
	body.rotation = Vector3(0, sin(phase) * 0.06 * m, sin(phase) * 0.04 * m)
	head.rotation = Vector3(sin(_t * 3.1) * 0.08, sin(_t * 1.7) * 0.2, 0)
	for l in legs:
		var lp: Node3D = l[0]
		var kn: Node3D = l[1]
		var sx: float = l[2]
		var ph: float = phase + float(l[3])
		lp.rotation = Vector3(0, sin(ph) * 0.45 * m * sx, max(0.0, cos(ph)) * 0.35 * m * sx)
		kn.rotation = Vector3(0, 0, -max(0.0, cos(ph)) * 0.25 * m * sx)
	var t: float = clamp(action_t, 0.0, 1.0)
	for i in scythes.size():
		var sp: Node3D = scythes[i]
		var sx := -1.0 if i == 0 else 1.0
		var idle := Vector3(0.6 + sin(_t * 2.0 + i) * 0.08, 0.0, 0.0)
		match action:
			"windup":
				idle = Vector3(1.4 * min(t * 1.5, 1.0), -0.3 * sx, 0)
				body.rotation.x = 0.25 * min(t * 1.5, 1.0)
			"attack":
				var k: float = 1.0 - pow(1.0 - t, 3.0)
				idle = Vector3(lerp(1.4, -0.9, k), lerp(-0.3, 0.4, k) * sx, 0)
				body.rotation.x = lerp(0.25, -0.2, k)
			"hurt":
				body.rotation.x = 0.3 * sin(t * PI)
		sp.rotation = idle

func _anim_mutant(m: float) -> void:
	body.position.y = 1.0 + abs(sin(phase)) * 0.06 * m + sin(_t * 1.6) * 0.02
	body.rotation = Vector3(0.15, sin(phase) * 0.15 * m, sin(phase) * 0.1 * m)
	head.rotation = Vector3(0, sin(_t * 1.3) * 0.25, sin(_t * 0.9) * 0.1)
	for l in legs:
		var lp: Node3D = l[0]
		var kn: Node3D = l[1]
		var ph: float = phase + float(l[3])
		lp.rotation = Vector3(sin(ph) * 0.6 * m, 0, 0)
		kn.rotation = Vector3(-max(0.0, -cos(ph)) * 0.8 * m, 0, 0)
	var t: float = clamp(action_t, 0.0, 1.0)
	var arm := Vector3(sin(phase) * 0.4 * m, 0, 0.1)
	match action:
		"windup":
			arm = Vector3(-2.4 * min(t * 1.4, 1.0), 0, 0.3)
			body.rotation.x = -0.2
		"attack":
			var k: float = 1.0 - pow(1.0 - t, 3.0)
			arm = Vector3(lerp(-2.4, 0.4, k), 0, 0.1)
			body.rotation.x = lerp(-0.2, 0.45, k)
		"spit":
			var k2 := sin(t * PI)
			head.rotation.x = -0.6 * k2
			body.rotation.x = -0.3 * k2
		"hurt":
			body.rotation.x = -0.3 * sin(t * PI)
	big_arm.rotation = arm
	(scythes[0] as Node3D).rotation = Vector3(-sin(phase) * 0.5 * m, 0, -0.2)
