class_name Humanoid
extends Node3D
## Low-Poly-Mensch mit prozeduraler Animation (Kadetten, Spieler, Ausbilder).
## Blickrichtung ist −Z.

var look := {}
var hips: Node3D
var torso: Node3D
var head: Node3D
var arm_l: Node3D
var arm_r: Node3D
var fore_l: Node3D
var fore_r: Node3D
var leg_l: Node3D
var leg_r: Node3D
var knee_l: Node3D
var knee_r: Node3D
var hand_r: Node3D
var eyes: Array[MeshInstance3D] = []
var blade: MeshInstance3D

var phase := 0.0
var move_amt := 0.0
## Aktionen: "", "attack", "dash", "hurt", "cast", "windup", "dead"
var action := ""
var action_t := 0.0
var combo := 0
var _breath := 0.0

func _init(cfg := {}) -> void:
	look = {
		"skin": Color(0.86, 0.68, 0.58), "suit": Color(0.14, 0.15, 0.2), "accent": Toon.RED,
		"hair": Color(0.08, 0.07, 0.09), "eyes": Color(0.9, 0.95, 1.0), "glow": 0.0,
		"scale": 1.0, "bulk": 1.0, "cape": false, "visor": false,
	}
	for k in cfg:
		look[k] = cfg[k]

func _ready() -> void:
	_build()

func _m(c: Color, extra := {}) -> Material:
	var o := {"outline": 0.03, "radial": 1.0, "rim": 0.45}
	for k in extra:
		o[k] = extra[k]
	return Toon.amat(c, o)

func _part(parent: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n

func _build() -> void:
	var sc: float = look.scale
	var bk: float = look.bulk
	scale = Vector3.ONE * sc
	var suit := _m(look.suit)
	var skin := _m(look.skin)
	var acc := _m(look.accent, {"emit": look.accent, "energy": 0.6})
	var dark := _m(look.suit.darkened(0.45))
	hips = _part(self, Vector3(0, 0.95, 0))
	Toon.box(hips, Vector3(0.42 * bk, 0.2, 0.24), Vector3(0, 0, 0), dark)
	torso = _part(hips, Vector3(0, 0.1, 0))
	Toon.box(torso, Vector3(0.5 * bk, 0.56, 0.28 * bk), Vector3(0, 0.3, 0), suit)
	# Brustpanzer + Akzentstreifen
	Toon.box(torso, Vector3(0.38 * bk, 0.22, 0.06), Vector3(0, 0.42, -0.15 * bk), dark)
	Toon.box(torso, Vector3(0.06, 0.4, 0.02), Vector3(0.1, 0.3, -0.155 * bk), acc)
	Toon.box(torso, Vector3(0.52 * bk, 0.05, 0.3 * bk), Vector3(0, 0.08, 0), acc)
	if look.cape:
		Toon.box(torso, Vector3(0.5 * bk, 0.9, 0.04), Vector3(0, 0.05, 0.17 * bk), _m(look.accent.darkened(0.5)), Vector3(0.12, 0, 0))
	head = _part(torso, Vector3(0, 0.66, 0))
	Toon.box(head, Vector3(0.1, 0.1, 0.1), Vector3(0, -0.04, 0), skin)
	Toon.box(head, Vector3(0.24, 0.27, 0.25), Vector3(0, 0.13, 0), skin)
	Toon.box(head, Vector3(0.27, 0.1, 0.28), Vector3(0, 0.28, 0.01), _m(look.hair))
	Toon.box(head, Vector3(0.27, 0.16, 0.08), Vector3(0, 0.2, 0.12), _m(look.hair))
	if look.visor:
		Toon.box(head, Vector3(0.26, 0.06, 0.04), Vector3(0, 0.15, -0.13), _m(look.accent, {"emit": look.accent, "energy": 2.0}))
	var eye_m := Toon.amat(look.eyes, {"emit": look.eyes, "energy": look.glow})
	for sx in [-1.0, 1.0]:
		var e := Toon.box(head, Vector3(0.05, 0.035, 0.02), Vector3(0.055 * sx, 0.15, -0.126), eye_m)
		e.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		eyes.append(e)
	# Arme
	arm_l = _part(torso, Vector3(-0.31 * bk, 0.52, 0))
	arm_r = _part(torso, Vector3(0.31 * bk, 0.52, 0))
	for a in [arm_l, arm_r]:
		Toon.box(a, Vector3(0.17 * bk, 0.14, 0.2), Vector3(0, 0.02, 0), dark)
		Toon.box(a, Vector3(0.12 * bk, 0.32, 0.13 * bk), Vector3(0, -0.16, 0), suit)
	fore_l = _part(arm_l, Vector3(0, -0.32, 0))
	fore_r = _part(arm_r, Vector3(0, -0.32, 0))
	for f in [fore_l, fore_r]:
		Toon.box(f, Vector3(0.11 * bk, 0.28, 0.12 * bk), Vector3(0, -0.14, 0), suit)
		Toon.box(f, Vector3(0.12 * bk, 0.06, 0.13 * bk), Vector3(0, -0.22, 0), acc)
		Toon.box(f, Vector3(0.09, 0.1, 0.1), Vector3(0, -0.33, 0), skin)
	hand_r = _part(fore_r, Vector3(0, -0.34, 0))
	# Beine
	leg_l = _part(hips, Vector3(-0.12 * bk, -0.06, 0))
	leg_r = _part(hips, Vector3(0.12 * bk, -0.06, 0))
	for l in [leg_l, leg_r]:
		Toon.box(l, Vector3(0.16 * bk, 0.44, 0.17 * bk), Vector3(0, -0.21, 0), suit)
	knee_l = _part(leg_l, Vector3(0, -0.43, 0))
	knee_r = _part(leg_r, Vector3(0, -0.43, 0))
	for k in [knee_l, knee_r]:
		Toon.box(k, Vector3(0.14 * bk, 0.4, 0.15 * bk), Vector3(0, -0.2, 0), suit)
		Toon.box(k, Vector3(0.15 * bk, 0.12, 0.26), Vector3(0, -0.41, -0.04), dark)

## Blut-/Energieklinge an der rechten Hand (Spieler, Drax, Ausbilder)
func add_blade(color: Color, length := 0.9) -> void:
	blade = Toon.box(hand_r, Vector3(0.05, 0.08, length), Vector3(0, -0.02, -length * 0.5 + 0.05),
		Toon.amat(color, {"emit": color, "energy": 2.2, "outline": 0.02, "radial": 1.0}))
	blade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func set_eye_glow(color: Color, energy: float) -> void:
	var m := Toon.amat(color, {"emit": color, "energy": energy})
	for e in eyes:
		e.material_override = m

func play(a: String, n := 0) -> void:
	action = a
	action_t = 0.0
	combo = n

func animate(delta: float, speed: float, action_len := 0.3) -> void:
	move_amt = lerp(move_amt, clamp(speed / 5.0, 0.0, 1.4), min(1.0, delta * 10.0))
	phase += delta * (4.0 + speed * 1.6)
	_breath += delta * 2.0
	if action != "" and action != "dead":
		action_t += delta / max(action_len, 0.05)
		if action_t >= 1.0 and action != "windup":
			action = ""
	var s := sin(phase)
	var m := move_amt
	# Grundhaltung: Laufen
	hips.position.y = 0.95 + abs(cos(phase)) * 0.06 * m + sin(_breath) * 0.006
	hips.rotation = Vector3(0, s * 0.12 * m, 0)
	torso.rotation = Vector3(-0.12 * m, -s * 0.18 * m, 0)
	head.rotation = Vector3(0.06 * m, s * 0.08 * m, 0)
	leg_l.rotation = Vector3(s * 0.75 * m, 0, 0)
	leg_r.rotation = Vector3(-s * 0.75 * m, 0, 0)
	knee_l.rotation = Vector3(-max(0.0, -cos(phase)) * 1.1 * m - 0.05, 0, 0)
	knee_r.rotation = Vector3(-max(0.0, cos(phase)) * 1.1 * m - 0.05, 0, 0)
	arm_l.rotation = Vector3(-s * 0.7 * m, 0, -0.12)
	arm_r.rotation = Vector3(s * 0.7 * m, 0, 0.12)
	fore_l.rotation = Vector3(-0.35 - 0.5 * m, 0, 0)
	fore_r.rotation = Vector3(-0.35 - 0.5 * m, 0, 0)
	var t: float = clamp(action_t, 0.0, 1.0)
	match action:
		"attack":
			var k := _swing(t)
			match combo % 3:
				0:  # Rückhand-Schnitt von links nach rechts
					torso.rotation.y = lerp(0.9, -0.9, k)
					arm_r.rotation = Vector3(-1.4, lerp(1.2, -1.0, k), 0.6)
					fore_r.rotation = Vector3(-0.3, 0, 0)
				1:  # Vorhand zurück
					torso.rotation.y = lerp(-0.8, 0.9, k)
					arm_r.rotation = Vector3(-1.5, lerp(-1.1, 1.1, k), 0.3)
					fore_r.rotation = Vector3(-0.2, 0, 0)
				2:  # Abwärtshieb mit Sprung
					hips.position.y += sin(t * PI) * 0.25
					torso.rotation.x = lerp(-0.5, 0.45, k)
					arm_r.rotation = Vector3(lerp(-2.8, -0.6, k), 0, 0.1)
					arm_l.rotation = Vector3(lerp(-2.6, -0.4, k), 0, -0.1)
					fore_r.rotation = Vector3(-0.1, 0, 0)
			arm_l.rotation.x = min(arm_l.rotation.x, -0.5)
			leg_l.rotation.x = -0.45
			leg_r.rotation.x = 0.35
		"windup":
			var w: float = min(t, 1.0)
			torso.rotation = Vector3(-0.35 * w, 0.7 * w, 0)
			arm_r.rotation = Vector3(-2.2 * w, 0.6 * w, 0.4)
			fore_r.rotation = Vector3(-0.8 * w, 0, 0)
		"dash":
			torso.rotation.x = -0.6
			arm_l.rotation = Vector3(0.9, 0, -0.3)
			arm_r.rotation = Vector3(0.9, 0, 0.3)
			leg_l.rotation.x = -0.7
			leg_r.rotation.x = 0.6
			knee_r.rotation.x = -1.2
		"cast":
			var c := sin(t * PI)
			torso.rotation.y = t * TAU * 0.0 + sin(t * TAU) * 0.6
			arm_l.rotation = Vector3(-1.5 * c, 0, -1.2 * c)
			arm_r.rotation = Vector3(-1.5 * c, 0, 1.2 * c)
			hips.position.y -= c * 0.1
		"hurt":
			var hh := sin(t * PI)
			torso.rotation.x = 0.4 * hh
			head.rotation.x = 0.3 * hh
			arm_l.rotation.z = -0.6 * hh
			arm_r.rotation.z = 0.6 * hh
		"dead":
			var d: float = min(1.0, action_t + delta * 2.5)
			action_t = d
			rotation.x = lerp(0.0, PI * 0.5, d)
			position.y = lerp(0.0, 0.18, d)

func _swing(t: float) -> float:
	# schnelle Mitte, ruhige Enden
	if t < 0.25:
		return t * 0.4
	if t < 0.55:
		return 0.1 + (t - 0.25) / 0.3 * 0.85
	return 0.95 + (t - 0.55) * 0.11
