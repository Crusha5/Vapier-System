class_name Humanoid
extends Node3D
## Mensch mit durchgehendem, geskinntem Körper (BodyBuilder) und Skelett.
## Prozedurale Animation über Knochen-Rotationen. Blickrichtung ist −Z.

var look := {}
var skel: Skeleton3D
var body: MeshInstance3D
var eyes: MeshInstance3D
var hand_r: BoneAttachment3D
var hand_l: BoneAttachment3D
var blade: MeshInstance3D
var blade_l: MeshInstance3D
var bi := {}

var phase := 0.0
var move_amt := 0.0
## Aktionen: "", "attack", "dash", "hurt", "cast", "windup", "dead", "talk"
var action := ""
var action_t := 0.0
var combo := 0
var _breath := 0.0
var _idle_t := 0.0
var lean := 0.0          # Dauerhaftes Vorbeugen (z. B. Mutant)
var weapon_pose := true  # Klinge vor dem Körper halten

func _init(cfg := {}) -> void:
	look = {
		"skin": Color(0.9, 0.74, 0.66), "suit": Color(0.14, 0.15, 0.2), "accent": Toon.RED,
		"hair": Color(0.08, 0.07, 0.09), "eyes": Color(0.9, 0.95, 1.0), "glow": 0.0,
		"scale": 1.0, "bulk": 1.0, "coat": false, "cape": false, "vest": false, "pads": false, "visor": false,
		"hair_style": "short",
	}
	for k in cfg:
		look[k] = cfg[k]
	if not look.has("suit2"):
		look["suit2"] = (look.suit as Color).darkened(0.45)
	if not look.has("cape_color"):
		look["cape_color"] = (look.accent as Color).darkened(0.55)
	if not look.has("metal"):
		look["metal"] = Color(0.55, 0.57, 0.63)

func _ready() -> void:
	_build()

func _rim(c: Color) -> float:
	return 0.38 * (1.0 - clampf(c.get_luminance() * 1.1, 0.0, 0.85))

func _surf_mat(s: String) -> Material:
	var base := {"outline": 0.022, "rim": _rim(look.suit)}
	match s:
		"skin":
			return Toon.amat(look.skin, {"outline": 0.02, "rim": 0.12, "rim_color": Color(1.0, 0.6, 0.6)})
		"suit":
			return Toon.amat(look.suit, base)
		"dark":
			return Toon.amat(look.suit2, {"outline": 0.022, "rim": _rim(look.suit2), "spec": 0.4})
		"accent":
			return Toon.amat(look.accent, {"emit": look.accent, "energy": 1.4, "outline": 0.012})
		"hair":
			return Toon.amat(look.hair, {"outline": 0.024, "rim": 0.5, "spec": 0.5})
		"metal":
			return Toon.amat(look.metal, {"outline": 0.022, "spec": 0.9, "rim": 0.3})
		"cape":
			return Toon.amat(look.cape_color, {"outline": 0.022, "rim": _rim(look.cape_color)})
	return Toon.amat(Color.MAGENTA)

func _build() -> void:
	scale = Vector3.ONE * float(look.scale)
	var bk: float = look.bulk
	skel = Skeleton3D.new()
	add_child(skel)
	for i in BodyBuilder.BONES.size():
		var b: Array = BodyBuilder.BONES[i]
		skel.add_bone(b[0])
		bi[b[0]] = i
		if int(b[1]) >= 0:
			skel.set_bone_parent(i, int(b[1]))
		skel.set_bone_rest(i, Transform3D(Basis(), BodyBuilder.bone_rest(i, bk)))
	skel.reset_bone_poses()
	var res := BodyBuilder.build(look)
	body = MeshInstance3D.new()
	body.mesh = res.mesh
	var surfs: Array = res.surfaces
	for i in surfs.size():
		body.set_surface_override_material(i, _surf_mat(surfs[i]))
	skel.add_child(body)
	body.skin = skel.create_skin_from_rest_transforms()
	body.skeleton = NodePath("..")
	# Augen (leuchtend, eigenes Material zum Umschalten)
	var head_att := BoneAttachment3D.new()
	head_att.bone_name = "head"
	skel.add_child(head_att)
	eyes = MeshInstance3D.new()
	var em := ArrayMesh.new()
	var stt := SurfaceTool.new()
	stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx in [-1.0, 1.0]:
		# schräg gestellte Anime-Augen als flache Rauten
		var c := Vector3(0.044 * sx, 0.142, -0.122)
		var pts := [c + Vector3(-0.022 * sx, 0.006, 0), c + Vector3(0.02 * sx, 0.012, -0.002), c + Vector3(0.019 * sx, -0.008, 0), c + Vector3(-0.018 * sx, -0.006, 0.002)]
		for tri in [[0, 1, 2], [0, 2, 3]]:
			var a: Vector3 = pts[tri[0]]
			var b2: Vector3 = pts[tri[1]]
			var c2: Vector3 = pts[tri[2]]
			if ((c2 - a).cross(b2 - a)).z > 0.0:
				var tmp := b2
				b2 = c2
				c2 = tmp
			for v in [a, b2, c2]:
				stt.set_normal(Vector3.FORWARD)
				stt.add_vertex(v)
	stt.commit(em)
	eyes.mesh = em
	eyes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	head_att.add_child(eyes)
	set_eye_glow(look.eyes, look.glow)
	hand_r = BoneAttachment3D.new()
	hand_r.bone_name = "hand.R"
	skel.add_child(hand_r)
	hand_l = BoneAttachment3D.new()
	hand_l.bone_name = "hand.L"
	skel.add_child(hand_l)

## Blut-/Energieklinge an der rechten (oder linken) Hand
func add_blade(color: Color, length := 0.9, width := 0.05) -> void:
	if blade:
		(blade.get_meta("hilt") as Node).queue_free()
		blade.queue_free()
	blade = _make_blade(hand_r, color, length, width)

func add_blade_left(color: Color, length := 0.6, width := 0.04) -> void:
	remove_blade_left()
	blade_l = _make_blade(hand_l, color, length, width)

func remove_blade_left() -> void:
	if blade_l:
		(blade_l.get_meta("hilt") as Node).queue_free()
		blade_l.queue_free()
		blade_l = null

func _make_blade(hand: Node3D, color: Color, length: float, width: float) -> MeshInstance3D:
	var b := MeshInstance3D.new()
	var bm := PrismMesh.new()
	bm.size = Vector3(width * 1.6, length, 0.03)
	b.mesh = bm
	b.material_override = Toon.amat(color, {"emit": color, "energy": 2.4, "outline": 0.016})
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Klinge zeigt in Handrichtung nach vorne
	b.rotation = Vector3(-PI * 0.5, 0, 0)
	b.position = Vector3(0, -0.08, -length * 0.5 + 0.02)
	hand.add_child(b)
	var hilt := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.12, 0.03, 0.04)
	hilt.mesh = hb
	hilt.material_override = Toon.amat(Color(0.12, 0.12, 0.15), {"outline": 0.012, "spec": 0.8})
	hilt.position = Vector3(0, -0.08, 0.02)
	hand.add_child(hilt)
	b.set_meta("hilt", hilt)
	return b

func set_blade_visible(v: bool) -> void:
	for b in [blade, blade_l]:
		if b:
			b.visible = v
			(b.get_meta("hilt") as Node3D).visible = v

func blade_tip(left := false) -> Vector3:
	var b := blade_l if left else blade
	if b == null:
		return global_position + Vector3(0, 1.2, 0)
	return b.global_transform * Vector3(0, 0.5 * (b.mesh as PrismMesh).size.y, 0)

func blade_base(left := false) -> Vector3:
	var b := blade_l if left else blade
	if b == null:
		return global_position + Vector3(0, 1.0, 0)
	return b.global_transform * Vector3(0, -0.3 * (b.mesh as PrismMesh).size.y, 0)

func set_eye_glow(color: Color, energy: float) -> void:
	eyes.material_override = Toon.amat(color, {"emit": color, "energy": energy})

func play(a: String, n := 0) -> void:
	action = a
	action_t = 0.0
	combo = n

func _r(name: String, e: Vector3) -> void:
	skel.set_bone_pose_rotation(bi[name], Quaternion.from_euler(e))

func animate(delta: float, speed: float, action_len := 0.3) -> void:
	if skel == null:
		return
	move_amt = lerpf(move_amt, clampf(speed / 5.0, 0.0, 1.4), minf(1.0, delta * 10.0))
	phase += delta * (4.0 + speed * 1.6)
	_breath += delta * 2.0
	_idle_t += delta
	if action != "" and action != "dead":
		action_t += delta / maxf(action_len, 0.05)
		if action_t >= 1.0 and action != "windup":
			action = ""
	var s := sin(phase)
	var c := cos(phase)
	var m := move_amt
	var idle := 1.0 - clampf(m * 2.0, 0.0, 1.0)
	var breath := sin(_breath)
	# --- Grundhaltung / Laufen ---
	var hip_y := absf(c) * 0.055 * m + breath * 0.004 - 0.02 * idle
	var hips := Vector3(lean * 0.3, s * 0.14 * m, 0)
	var spine := Vector3(-0.1 * m - lean * 0.5, -s * 0.1 * m, 0)
	var chest := Vector3(-0.06 * m + breath * 0.015 * idle - lean * 0.4, -s * 0.12 * m + sin(_idle_t * 0.7) * 0.04 * idle, 0)
	var neck := Vector3(0.05 * m + lean * 0.5, 0, 0)
	var head := Vector3(0.04 * m + lean * 0.4, s * 0.06 * m + sin(_idle_t * 0.5) * 0.08 * idle, 0)
	var thigh_l := Vector3(s * 0.8 * m - 0.03 * idle, 0, 0.04 * idle)
	var thigh_r := Vector3(-s * 0.8 * m - 0.03 * idle, 0, -0.04 * idle)
	var shin_l := Vector3(-maxf(0.0, -c) * 1.25 * m - 0.06 - 0.05 * idle, 0, 0)
	var shin_r := Vector3(-maxf(0.0, c) * 1.25 * m - 0.06 - 0.05 * idle, 0, 0)
	var foot_l := Vector3(maxf(0.0, -c) * 0.4 * m + s * 0.15 * m, 0, 0)
	var foot_r := Vector3(maxf(0.0, c) * 0.4 * m - s * 0.15 * m, 0, 0)
	var arm_l := Vector3(-s * 0.7 * m + 0.05, 0, -0.12 - 0.03 * breath * idle)
	var arm_r := Vector3(s * 0.7 * m + 0.05, 0, 0.12 + 0.03 * breath * idle)
	var fore_l := Vector3(0.25 + 0.8 * m, 0, 0)
	var fore_r := Vector3(0.25 + 0.8 * m, 0, 0)
	var hand_l := Vector3(-1.3, 0, 0) if (blade_l != null and blade_l.visible) else Vector3.ZERO
	var armed := blade != null and blade.visible
	# Klinge liegt senkrecht zum Unterarm – Handgelenk abknicken, damit sie nach vorne zeigt
	var hand_rr := Vector3(-1.3, 0, 0) if armed else Vector3.ZERO
	if weapon_pose and armed:
		# Kampfhaltung im Stand: Klinge locker nach vorne-unten
		arm_r = arm_r.lerp(Vector3(0.3, 0.0, 0.16), idle)
		fore_r = fore_r.lerp(Vector3(0.6, 0, 0), idle)
	var t: float = clampf(action_t, 0.0, 1.0)
	match action:
		"attack":
			var k := _swing(t)
			match combo % 3:
				0:  # Rückhand-Schnitt von links nach rechts
					chest.y = lerpf(0.7, -0.75, k)
					spine.y = lerpf(0.35, -0.35, k)
					arm_r = Vector3(1.4, lerpf(1.2, -1.0, k), lerpf(0.9, 0.3, k))
					fore_r = Vector3(lerpf(1.3, 0.15, k), 0, 0)
				1:  # Vorhand zurück
					chest.y = lerpf(-0.7, 0.8, k)
					spine.y = lerpf(-0.3, 0.4, k)
					arm_r = Vector3(1.45, lerpf(-1.0, 1.1, k), lerpf(0.2, 0.6, k))
					fore_r = Vector3(lerpf(0.2, 1.1, k), 0, 0)
				2:  # Abwärtshieb mit Sprung
					hip_y += sin(t * PI) * 0.22
					spine.x = lerpf(0.25, -0.35, k)
					chest.x = lerpf(0.3, -0.35, k)
					arm_r = Vector3(lerpf(2.9, 0.5, k), 0, 0.12)
					arm_l = Vector3(lerpf(2.6, 0.4, k), 0, -0.12)
					fore_r = Vector3(lerpf(0.6, 0.1, k), 0, 0)
					fore_l = Vector3(lerpf(0.6, 0.6, k), 0, 0)
			arm_l.x = maxf(arm_l.x, 0.4)
			fore_l.x = maxf(fore_l.x, 1.1)
			thigh_l = Vector3(-0.55, 0, 0.05)
			thigh_r = Vector3(0.35, 0, -0.05)
			shin_l = Vector3(-0.35, 0, 0)
			shin_r = Vector3(-0.55, 0, 0)
			hip_y -= 0.05
		"windup":
			var w: float = minf(t, 1.0)
			spine = Vector3(0.2 * w, 0.35 * w, 0)
			chest = Vector3(0.15 * w, 0.4 * w, 0)
			arm_r = Vector3(2.4 * w, -0.4 * w, 0.4)
			fore_r = Vector3(0.9 * w, 0, 0)
			thigh_l = Vector3(-0.3 * w, 0, 0)
			shin_l = Vector3(-0.3 * w, 0, 0)
			hip_y -= 0.06 * w
		"dash":
			spine.x = -0.45
			chest.x = -0.3
			arm_l = Vector3(-1.0, 0, -0.35)
			arm_r = Vector3(-1.0, 0, 0.35)
			fore_l = Vector3(0.2, 0, 0)
			fore_r = Vector3(0.2, 0, 0)
			thigh_l = Vector3(-0.9, 0, 0)
			shin_l = Vector3(-0.6, 0, 0)
			thigh_r = Vector3(0.5, 0, 0)
			shin_r = Vector3(-1.4, 0, 0)
			hip_y -= 0.12
		"cast":
			var cc := sin(t * PI)
			chest.y = sin(t * TAU) * 0.6
			arm_l = Vector3(0.8 * cc, 0, -1.4 * cc)
			arm_r = Vector3(0.8 * cc, 0, 1.4 * cc)
			fore_l = Vector3(0.4, 0, 0)
			fore_r = Vector3(0.4, 0, 0)
			hip_y -= cc * 0.12
			thigh_l = Vector3(-0.3 * cc, 0, 0.15 * cc)
			thigh_r = Vector3(-0.3 * cc, 0, -0.15 * cc)
			shin_l = Vector3(-0.6 * cc, 0, 0)
			shin_r = Vector3(-0.6 * cc, 0, 0)
		"hurt":
			var hh := sin(t * PI)
			spine.x = 0.25 * hh
			chest.x = 0.25 * hh
			head.x = 0.35 * hh
			arm_l.z = -0.7 * hh
			arm_r.z = 0.7 * hh
		"spit":
			var sp := sin(t * PI)
			head.x -= 0.6 * sp
			neck.x -= 0.3 * sp
			chest.x += 0.25 * sp
		"talk":
			var tk := sin(_idle_t * 3.0)
			arm_r = Vector3(0.6 + 0.2 * tk, -0.3, 0.25)
			fore_r = Vector3(1.2, 0, 0)
			head.x += sin(_idle_t * 5.0) * 0.04
		"dead":
			var d: float = minf(1.0, action_t + delta * 2.5)
			action_t = d
			rotation.x = lerpf(0.0, PI * 0.5, d)
			position.y = lerpf(0.0, 0.18, d)
			arm_l = Vector3(0, 0, -1.2 * d)
			arm_r = Vector3(0, 0, 1.2 * d)
	skel.set_bone_pose_position(bi.hips, BodyBuilder.bone_rest(0, 1.0) + Vector3(0, hip_y, 0))
	_r("hips", hips)
	_r("spine", spine)
	_r("chest", chest)
	_r("neck", neck)
	_r("head", head)
	_r("upperarm.L", arm_l)
	_r("upperarm.R", arm_r)
	_r("forearm.L", fore_l)
	_r("forearm.R", fore_r)
	_r("hand.L", hand_l)
	_r("hand.R", hand_rr)
	_r("thigh.L", thigh_l)
	_r("thigh.R", thigh_r)
	_r("shin.L", shin_l)
	_r("shin.R", shin_r)
	_r("foot.L", foot_l)
	_r("foot.R", foot_r)

func _swing(t: float) -> float:
	# schnelle Mitte, ruhige Enden
	if t < 0.25:
		return t * 0.4
	if t < 0.55:
		return 0.1 + (t - 0.25) / 0.3 * 0.85
	return 0.95 + (t - 0.55) * 0.11
