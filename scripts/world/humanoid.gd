class_name Humanoid
extends Node3D
## Figur aus den Quaternius-Baukästen (Universal Base Characters + Modular Character Outfits, CC0)
## mit echten Animationen aus der Universal Animation Library 1+2 (CC0).
## Gleiche Schnittstelle wie früher: play(action, n), animate(delta, speed, action_len), add_blade(), …
## look: {body, hair, hair_color, beard, hat, armor, faction, cloth, skin_tone, scale, idle, female}

const ANIMS := preload("res://assets/chars/anims.res")
## Halte-Aktionen enden nicht von selbst
const HOLD := ["windup", "kneel", "sit", "lie", "feed", "cower", "sleep", "talk", "work"]
## Aktion -> [Animation, Modus, Ende-Anteil]; Modi: once, loop, hold (bis zum Ende, dann stehen), scrub (bis Anteil, dann stehen)
const MAP := {
	"attack": ["Sword_Regular_A", "once", 1.0],
	"windup": ["Sword_Heavy_A", "scrub", 0.32],
	"dash": ["Sword_Dash", "once", 1.0],
	"cast": ["Spell_Simple_Shoot", "once", 1.0],
	"hurt": ["Hit_Chest", "once", 1.0],
	"talk": ["Idle_Talking", "loop", 1.0],
	"kneel": ["PickUp_Kneeling", "scrub", 0.42],
	"cower": ["Crying", "loop", 1.0],
	"sit": ["GroundSit_Idle", "loop", 1.0],
	"lie": ["IdleToLay", "hold", 1.0],
	"sleep": ["IdleToLay", "hold", 1.0],
	"feed": ["Zombie_Bite", "scrub", 0.55],
	"dead": ["Death01", "hold", 1.0],
	"spit": ["Hit_Head", "once", 1.0],
	"drink": ["Drink", "once", 1.0],
	"work": ["Farm_Harvest", "loop", 1.0],
}
const COMBO := ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C"]
const SKIN_MATS := ["MI_Superhero_Male", "MI_Regular_Male", "MI_Superhero_Female", "MI_Regular_Female"]
const HAIR_MATS := ["MI_Hair_1", "MI_Hair_2"]

static var _scenes := {}

var look := {}
var rig: Node3D            # importierte Figur (um 180° gedreht: unsere Vorderseite ist −Z)
var skel: Skeleton3D
var anim: AnimationPlayer
var body: MeshInstance3D
var eyes: MeshInstance3D
var hand_r: BoneAttachment3D
var hand_l: BoneAttachment3D
var blade: MeshInstance3D
var blade_l: MeshInstance3D
var meshes: Array[GeometryInstance3D] = []
var skin_mats: Array[StandardMaterial3D] = []
var eye_mat: StandardMaterial3D
var action := ""
var action_t := 0.0
var combo := 0
var move_amt := 0.0
var lean := 0.0
var weapon_pose := true
var bed_height := 0.0
var idle_anim := "Idle"
var _cur := ""
var _prev_action := ""
var _getup := 0.0
var _blade_len := 0.9
var _blade_len_l := 0.6
var _shadow_only := false
var _attachments := {}
var lod := 0               # 0 nah, 1 mittel, 2 fern: Animation seltener auswerten
var _acc := 0.0
var _frame := 0
var combat_t := 0.0        # > 0: Waffe gezogen
var always_drawn := false
var _drawn := true
var _blade_holder: Node3D

func _init(cfg := {}) -> void:
	look = cfg

func _ready() -> void:
	_build()

static func _scene(name: String) -> PackedScene:
	if not _scenes.has(name):
		_scenes[name] = load("res://assets/chars/%s.gltf" % name)
	return _scenes[name]

func _build() -> void:
	var body_name: String = look.get("body", "male.outfit.farmer.lod1")
	var ps := _scene(body_name)
	if ps == null:
		ps = _scene("male.outfit.farmer.lod1")
	rig = ps.instantiate() as Node3D
	rig.rotation.y = PI
	var sc: float = look.get("scale", 1.0)
	rig.scale = Vector3.ONE * sc
	add_child(rig)
	skel = rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	for mi in skel.find_children("*", "MeshInstance3D", true, false):
		meshes.append(mi)
		if mi.name == "Eyes":
			eyes = mi
		elif body == null or mi.name.begins_with("SuperHero"):
			body = mi
	_apply_materials()
	# Haare, Bart, Rüstung, Kopfbedeckung an Knochen hängen
	var hat: String = look.get("hat", "")
	if look.get("hair", "") != "" and hat == "":
		_attach_scene(look.hair, "head.hair", [])
	if look.get("beard", "") != "":
		_attach_scene("facial-hair.beards.default", "head.armor", [look.beard])
	if look.get("armor", "") != "":
		_attach_armor(look.armor)
	if hat != "":
		_attach_scene(hat, "head.armor", [])
	anim = AnimationPlayer.new()
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	rig.add_child(anim)
	anim.add_animation_library("", ANIMS)
	idle_anim = look.get("idle", "Idle")
	_play(idle_anim, 0.0)
	anim.seek(randf() * 2.0, true)
	_frame = randi() % 4

## Materialien je Figur: Haut, Haare, Fraktionsfarbe, Kleidung tönen
func _apply_materials() -> void:
	var tone: Color = look.get("skin_tone", Color(1, 1, 1))
	var hair_c: Color = look.get("hair_color", Color(0.18, 0.1, 0.05))
	var faction: Color = look.get("faction", Color(-1, 0, 0))
	var cloth: Color = look.get("cloth", Color(1, 1, 1))
	var accent: Color = look.get("accent", Color(-1, 0, 0))
	for g in meshes:
		var mi := g as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i) as StandardMaterial3D
			if m == null:
				continue
			var n := m.resource_name
			var nm := m.duplicate() as StandardMaterial3D
			nm.metallic_specular = 0.3
			if n in SKIN_MATS:
				nm.albedo_color = m.albedo_color * tone
				skin_mats.append(nm)
			elif n in HAIR_MATS:
				nm.albedo_color = hair_c
			elif n == "MI_Eyes":
				eye_mat = nm
			elif n == "faction" and faction.r >= 0.0:
				nm.albedo_color = faction
			elif n == "class" and accent.r >= 0.0:
				nm.albedo_color = accent
			else:
				nm.albedo_color = m.albedo_color * cloth
			mi.set_surface_override_material(i, nm)

func _socket(id: String) -> Array:
	var tab: Dictionary = CharData.SOCKETS_FEMALE if look.get("female", false) else CharData.SOCKETS_MALE
	return tab.get(id, [])

func _bone_attach(bone: String) -> BoneAttachment3D:
	if _attachments.has(bone):
		return _attachments[bone]
	var ba := BoneAttachment3D.new()
	ba.bone_name = bone
	skel.add_child(ba)
	_attachments[bone] = ba
	return ba

## Szene an einen Socket hängen; only: nur diese Knoten behalten (leer = alle)
func _attach_scene(name: String, socket: String, only: Array) -> Node3D:
	var ps := _scene(name)
	var s := _socket(socket)
	if ps == null or s.is_empty():
		return null
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(s[2] as Quaternion), s[1])
	_bone_attach(s[0]).add_child(holder)
	var inst := ps.instantiate() as Node3D
	holder.add_child(inst)
	if not only.is_empty():
		for c in inst.get_children():
			if not (c.name in only):
				c.queue_free()
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		if only.is_empty() or mi.name in only:
			meshes.append(mi)
			_tint_attached(mi)
	return inst

func _tint_attached(mi: MeshInstance3D) -> void:
	var hair_c: Color = look.get("hair_color", Color(0.18, 0.1, 0.05))
	var faction: Color = look.get("faction", Color(-1, 0, 0))
	for i in mi.mesh.get_surface_count():
		var m := mi.get_active_material(i) as StandardMaterial3D
		if m == null:
			continue
		var nm := m.duplicate() as StandardMaterial3D
		if m.resource_name in HAIR_MATS:
			nm.albedo_color = hair_c
		elif m.resource_name == "faction" and faction.r >= 0.0:
			nm.albedo_color = faction
		mi.set_surface_override_material(i, nm)

## Rüstungsset: jedes Teil an seinen eigenen Socket
func _attach_armor(name: String) -> void:
	var ps := _scene(name)
	if ps == null:
		return
	var src := ps.instantiate() as Node3D
	for c in src.get_children():
		var sock: String = CharData.PIECES.get(String(c.name), "")
		if sock == "":
			continue
		var s := _socket(sock)
		if s.is_empty():
			continue
		var holder := Node3D.new()
		holder.transform = Transform3D(Basis(s[2] as Quaternion), s[1])
		_bone_attach(s[0]).add_child(holder)
		src.remove_child(c)
		holder.add_child(c)
		for mi in ([c] if c is MeshInstance3D else []) + c.find_children("*", "MeshInstance3D", true, false):
			meshes.append(mi)
			_tint_attached(mi)
	src.free()

# ---------- Waffen ----------

func _weapon_mesh(name: String) -> Mesh:
	var ps := _scene(name)
	if ps == null:
		return null
	var inst := ps.instantiate()
	var mis := inst.find_children("*", "MeshInstance3D", true, false)
	var m: Mesh = (mis[0] as MeshInstance3D).mesh if not mis.is_empty() else null
	var off: Vector3 = (mis[0] as Node3D).position if not mis.is_empty() else Vector3.ZERO
	inst.free()
	if m and off != Vector3.ZERO:
		# Modell-Versatz (Griff im Ursprung) in die Geometrie übernehmen
		var st := SurfaceTool.new()
		var am := ArrayMesh.new()
		for i in m.get_surface_count():
			st.clear()
			st.append_from(m, i, Transform3D(Basis(), off))
			st.commit(am)
			am.surface_set_material(i, m.surface_get_material(i))
		return am
	return m

func _make_weapon(left: bool, color: Color, length: float) -> MeshInstance3D:
	var dagger := length < 0.7
	var mesh_name := "equipment.dagger.blackened.default" if dagger else "equipment.sword.arming.default"
	if look.get("weapon", "") != "":
		mesh_name = look.weapon
	var mi := MeshInstance3D.new()
	mi.mesh = _weapon_mesh(mesh_name)
	var base_len := 0.45 if dagger else 0.9
	var k := clampf(length / base_len, 0.6, 1.6)
	mi.scale = Vector3(1.0, k, 1.0)
	# Blutklinge: rotes Leuchten über dem Stahl
	if color.r > color.g * 2.5 and color.r > 0.6:
		var ov := StandardMaterial3D.new()
		ov.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ov.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ov.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		ov.albedo_color = Color(color.r, color.g, color.b, 0.3)
		mi.material_overlay = ov
		mi.set_meta("base_overlay", ov)
	var sock := "hand_l.weapon" if left else "hand_r.weapon"
	if mesh_name.contains("crossbow"):
		sock = "hand_r.crossbow"
		k = 1.0
		mi.scale = Vector3.ONE
	var s := _socket(sock)
	var holder := Node3D.new()
	holder.transform = Transform3D(Basis(s[2] as Quaternion), s[1])
	_bone_attach(s[0]).add_child(holder)
	holder.add_child(mi)
	meshes.append(mi)
	return mi

func add_blade(color: Color, length := 0.9, _width := 0.05) -> void:
	if skel == null:
		_build_deferred_blade.call_deferred(color, length, false)
		return
	if blade:
		blade.get_parent().queue_free()
	blade = _make_weapon(false, color, length)
	_blade_len = length
	_blade_holder = blade.get_parent() as Node3D
	hand_r = _blade_holder.get_parent() as BoneAttachment3D
	_drawn = true
	_set_drawn(always_drawn or combat_t > 0.0)
	if _shadow_only:
		set_shadow_only(true)

func _build_deferred_blade(color: Color, length: float, left: bool) -> void:
	if left:
		add_blade_left(color, length)
	else:
		add_blade(color, length)

func add_blade_left(color: Color, length := 0.6, _width := 0.04) -> void:
	if skel == null:
		_build_deferred_blade.call_deferred(color, length, true)
		return
	remove_blade_left()
	blade_l = _make_weapon(true, color, length)
	_blade_len_l = length
	hand_l = blade_l.get_parent().get_parent() as BoneAttachment3D

func remove_blade_left() -> void:
	if blade_l:
		blade_l.get_parent().queue_free()
		meshes.erase(blade_l)
		blade_l = null

func set_blade_visible(v: bool) -> void:
	for b in [blade, blade_l]:
		if b:
			b.visible = v

func blade_tip(left := false) -> Vector3:
	var b := blade_l if left else blade
	if b == null:
		return global_position + Vector3(0, 1.2, 0)
	return b.global_transform * Vector3(0, 0.95, 0)

func blade_base(left := false) -> Vector3:
	var b := blade_l if left else blade
	if b == null:
		return global_position + Vector3(0, 1.0, 0)
	return b.global_transform * Vector3(0, 0.2, 0)

## Waffe in der Hand oder an der Hüfte
func _set_drawn(v: bool) -> void:
	if v == _drawn or _blade_holder == null:
		return
	_drawn = v
	var sock := "hand_r.weapon" if v else "hip_l.stowed"
	if look.get("weapon", "").contains("crossbow"):
		sock = "hand_r.crossbow" if v else "back.bow.stowed"
	var s := _socket(sock)
	if s.is_empty():
		return
	_blade_holder.get_parent().remove_child(_blade_holder)
	_bone_attach(s[0]).add_child(_blade_holder)
	_blade_holder.transform = Transform3D(Basis(s[2] as Quaternion), s[1])
	if blade_l:
		blade_l.visible = v
	# Blutschimmer nur mit gezogener Klinge
	if blade and blade.has_meta("base_overlay"):
		blade.material_overlay = blade.get_meta("base_overlay") if v else null

# ---------- Aussehen zur Laufzeit ----------

## Blässe: Hautfarbe relativ zur normalen Haut
func set_skin(c: Color) -> void:
	var base := Color(0.88, 0.74, 0.66)
	var tone: Color = look.get("skin_tone", Color(1, 1, 1))
	var k := Color(c.r / base.r, c.g / base.g, c.b / base.b)
	for m in skin_mats:
		m.albedo_color = Color(tone.r * k.r, tone.g * k.g, tone.b * k.b)

## Ego-Perspektive: Körper wirft nur noch Schatten
func set_shadow_only(v: bool) -> void:
	_shadow_only = v
	for g in meshes:
		if is_instance_valid(g):
			g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if v else GeometryInstance3D.SHADOW_CASTING_SETTING_ON

func set_eye_glow(color: Color, energy: float) -> void:
	if eye_mat == null:
		return
	eye_mat.emission_enabled = energy > 0.5
	eye_mat.emission = color
	eye_mat.emission_energy_multiplier = maxf(0.0, energy - 0.5) * 1.2

# ---------- Animation ----------

func play(a: String, n := 0) -> void:
	if a in ["attack", "windup", "dash", "cast", "hurt"]:
		combat_t = 7.0
		_set_drawn(true)
	if (action == "lie" or action == "sleep") and a == "":
		_getup = 1.4
	_prev_action = action
	action = a
	action_t = 0.0
	combo = n
	if a != "" and MAP.has(a):
		var e: Array = MAP[a]
		var name: String = e[0]
		if a == "attack":
			name = COMBO[n % COMBO.size()]
		elif a == "work":
			name = look.get("work", "Farm_Harvest")
		_play(name, 0.12 if a in ["attack", "hurt", "dash"] else 0.25)
		if e[1] == "scrub":
			anim.pause()
	elif a == "" and _getup > 0.0:
		_play("LayToIdle", 0.1)

func _play(name: String, blend: float) -> void:
	if anim == null or not anim.has_animation(name):
		return
	_cur = name
	anim.play(name, blend)

func animate(delta: float, speed: float, action_len := 0.3) -> void:
	if anim == null:
		return
	# Animation selbst weiterschalten (fern seltener)
	_acc += delta
	_frame += 1
	var step := 1 if lod == 0 else (2 if lod == 1 else 4)
	if _frame % step == 0:
		anim.advance(_acc)
		_acc = 0.0
	if combat_t > 0.0:
		combat_t -= delta
	_set_drawn(always_drawn or combat_t > 0.0)
	move_amt = lerpf(move_amt, clampf(speed / 5.0, 0.0, 1.4), minf(1.0, delta * 10.0))
	position.y = bed_height if action == "sleep" else 0.0
	if action != "" and action != "dead":
		action_t += delta / maxf(action_len, 0.05)
		if action_t >= 1.0 and not HOLD.has(action):
			action = ""
	if action != "" and MAP.has(action):
		var e: Array = MAP[action]
		var a := anim.get_animation(_cur)
		var length := a.length if a else 1.0
		match e[1]:
			"once":
				# Ablauf an die Spiellogik anpassen (z. B. Angriffstempo)
				anim.speed_scale = clampf(length / maxf(action_len * 1.25, 0.05), 0.6, 3.5) if action in ["attack", "dash"] else 1.0
			"scrub":
				var k := clampf(action_t * (4.0 if action == "feed" or action == "kneel" else 1.0), 0.0, 1.0)
				anim.seek(length * float(e[2]) * k, true)
			_:
				anim.speed_scale = 1.0
		return
	# Aufstehen abwarten
	if _getup > 0.0:
		_getup -= delta
		anim.speed_scale = 1.0
		return
	# Fortbewegung
	var target := idle_anim if not (_drawn and blade != null) else "Sword_Idle"
	var sc := 1.0
	if speed > 0.25:
		if speed < 2.4:
			target = "Walk"
			sc = clampf(speed / 1.5, 0.6, 1.5)
		elif speed < 5.2:
			target = "Jog_Fwd"
			sc = clampf(speed / 3.8, 0.7, 1.4)
		else:
			target = "Sprint"
			sc = clampf(speed / 6.5, 0.8, 1.4)
	if target != _cur or anim.is_playing() == false:
		_play(target, 0.22)
	anim.speed_scale = sc
