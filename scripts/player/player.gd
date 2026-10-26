class_name Player
extends CharacterBody3D
## Kael: Bewegung im offenen Gelände (relativ zur Kamera), Schwerkraft, Schwimmen, Kombo-Angriff,
## Schattenschritt, Blutsichel, Treffer. Aussehen folgt der Menschlichkeit.

var world: Node
var rig: CameraRig
var model: Humanoid
var input_dir := Vector2.ZERO
var facing := Vector3(0, 0, -1)
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var dash_speed := 0.0
var combo := 0
var combo_timer := 0.0
var attack_t := 0.0
var pending_hit := -1.0
var pending_combo := 0
var knock := Vector3.ZERO
var flash := 0.0
var hurt_t := 0.0
var lunge := Vector3.ZERO
var dead := false
var busy := false             # Trinken / Zwischensequenz
var swimming := false
var cds := {"dash": 0.0, "skill1": 0.0, "skill2": 0.0, "drink": 0.0}
var cd_max := {"dash": 0.9, "skill1": 4.5, "skill2": 8.0, "drink": 1.0}
var cast_pending := ""
var cast_t := 0.0
var steps_t := 0.0
var trail: BladeTrail
var hit_streak := 0
var streak_t := 0.0
var _heading := NAN
var _last_tier := -1
var viewblade: Node3D
var _vb_swing := 0.0

const GRAVITY := 22.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50)
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.35
	sh.height = 1.75
	cs.shape = sh
	cs.position.y = 0.88
	add_child(cs)
	model = Humanoid.new(Looks.kael())
	add_child(model)
	refresh_weapon()
	PlayerStats.equipment_changed.connect(refresh_weapon)
	PlayerStats.humanity_changed.connect(func(_a, _b): refresh_look())
	refresh_look()

func refresh_weapon() -> void:
	var w := PlayerStats.weapon_def()
	var it: Dictionary = PlayerStats.s.equip.get("weapon", {})
	var col := Color(0.85, 0.1, 0.12)
	if not it.is_empty() and int(it.rarity) >= 3:
		col = Color(1.0, 0.35, 0.15)
	model.add_blade(col, float(w.len), float(w.width))
	if PlayerStats.weapon_type() == "daggers":
		model.add_blade_left(col, float(w.len), float(w.width))
	else:
		model.remove_blade_left()
	if trail == null:
		trail = BladeTrail.new()
		world.add_child(trail)
	trail.color = col
	if rig and rig.first_person:
		model.set_shadow_only(true)
	_build_viewblade(col, float(w.len))

## Blässe, Augen und Adern je nach Menschlichkeit
func refresh_look() -> void:
	var h := PlayerStats.humanity() / 100.0
	var skin := Color(0.88, 0.74, 0.66).lerp(Color(0.72, 0.72, 0.78), 1.0 - h)
	model.set_skin(skin)
	var tier := PlayerStats.tier()
	var eye := Color(0.85, 0.8, 0.75).lerp(Color(1.0, 0.05, 0.1), clampf((1.0 - h) * 1.4, 0.0, 1.0))
	model.set_eye_glow(eye, lerpf(0.4, 4.0, 1.0 - h))
	_last_tier = tier

func set_first_person(v: bool) -> void:
	model.set_shadow_only(v)
	if viewblade:
		viewblade.visible = v

func _build_viewblade(col: Color, length: float) -> void:
	if rig == null:
		return
	if viewblade:
		viewblade.queue_free()
	viewblade = Node3D.new()
	rig.camera.add_child(viewblade)
	var arm := MeshInstance3D.new()
	var am := CapsuleMesh.new()
	am.radius = 0.05
	am.height = 0.45
	arm.mesh = am
	arm.material_override = Toon.mat(Color(0.1, 0.1, 0.12), {"rough": 0.9})
	arm.rotation = Vector3(PI * 0.5, 0, 0)
	arm.position = Vector3(0, 0, 0.18)
	viewblade.add_child(arm)
	var b := MeshInstance3D.new()
	var bm := PrismMesh.new()
	bm.size = Vector3(0.07, length * 0.8, 0.02)
	b.mesh = bm
	b.material_override = Toon.mat(col, {"emit": col, "energy": 2.2})
	b.rotation = Vector3(-PI * 0.5 + 0.15, 0, 0)
	b.position = Vector3(0, 0.02, -length * 0.35)
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	viewblade.add_child(b)
	viewblade.position = Vector3(0.28, -0.24, -0.42)
	viewblade.visible = rig.first_person

func is_invulnerable() -> bool:
	return dash_t > 0.0 or dead

func move_heading() -> float:
	return _heading

func _physics_process(delta: float) -> void:
	for k in cds:
		cds[k] = maxf(0.0, cds[k] - delta)
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 4.0)
		Toon.set_overlay(model, Color(1.0, 0.25, 0.3), flash)
	if dead:
		model.animate(delta, 0.0)
		velocity = Vector3(0, velocity.y - GRAVITY * delta, 0)
		move_and_slide()
		return
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo = 0
	streak_t -= delta
	if streak_t <= 0.0:
		hit_streak = 0
	attack_t -= delta
	hurt_t -= delta
	PlayerStats.invulnerable = dash_t > 0.0
	var locked: bool = world.input_locked() or busy
	var stick := input_dir if not locked else Vector2.ZERO
	var mag := minf(1.0, stick.length())
	var dir := Vector3.ZERO
	if mag > 0.08:
		dir = (rig.right_flat() * stick.x - rig.forward_flat() * stick.y).normalized() * mag
	var run := mag > 0.85
	var spd := PlayerStats.move_speed() * (1.5 if run else 1.0)
	var move := Vector3.ZERO
	# Wasser
	var ground_h: float = world.terrain.height_at(global_position.x, global_position.z)
	swimming = ground_h < -0.95 and global_position.y < -0.6
	if swimming:
		spd *= 0.45
	if dash_t > 0.0:
		dash_t -= delta
		move = dash_dir * dash_speed
		if fmod(dash_t, 0.05) < delta:
			world.afterimage(global_position, model.global_rotation.y)
	else:
		var slow := 0.35 if attack_t > 0.0 else 1.0
		move = dir * spd * slow
		if dir.length() > 0.1 and attack_t <= 0.0:
			facing = dir.normalized()
	if rig.first_person and dash_t <= 0.0:
		facing = rig.forward_flat()
	_heading = atan2(-facing.x, -facing.z) if mag > 0.5 and not rig.first_person else NAN
	if pending_hit >= 0.0:
		pending_hit -= delta
		if pending_hit < 0.0:
			_resolve_melee(pending_combo)
	if cast_pending != "":
		cast_t -= delta
		if cast_t <= 0.0:
			var c := cast_pending
			cast_pending = ""
			_resolve_cast(c)
	move += lunge
	lunge = lunge.move_toward(Vector3.ZERO, delta * 40.0)
	var vy := velocity.y
	if swimming:
		vy = lerpf(vy, (-0.75 - global_position.y) * 4.0, minf(1.0, delta * 6.0))
	elif is_on_floor():
		vy = -1.0
	else:
		vy -= GRAVITY * delta
	velocity = Vector3(move.x + knock.x, vy, move.z + knock.z)
	knock = knock.move_toward(Vector3.ZERO, delta * 25.0)
	move_and_slide()
	# Weltgrenze: der Schleier
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() > 282.0:
		var back := flat.normalized() * 281.0
		global_position.x = back.x
		global_position.z = back.y
		world.veil_touch()
	if global_position.y < ground_h - 3.0:
		global_position.y = ground_h + 0.5
	var target_rot := atan2(-facing.x, -facing.z)
	model.rotation.y = lerp_angle(model.rotation.y, target_rot, clampf(delta * 14.0, 0.0, 1.0))
	var hs := Vector2(velocity.x, velocity.z).length()
	if busy:
		hs = 0.0
	model.animate(delta, 0.0 if dash_t > 0.0 else hs, 0.34 / PlayerStats.attack_speed())
	if trail and model.blade:
		trail.feed(model.blade_base(), model.blade_tip(), model.action == "attack" or cast_pending != "", delta)
	if hs > 2.0 and dash_t <= 0.0 and not swimming:
		steps_t -= delta * hs
		if steps_t <= 0.0:
			steps_t = 3.0
			world.sfx("step")
	if viewblade and viewblade.visible:
		_vb_swing = maxf(0.0, _vb_swing - delta * 5.0)
		var sw := sin(_vb_swing * PI)
		viewblade.rotation = Vector3(-sw * 0.9, sw * 1.2 * (1.0 if combo % 2 == 0 else -1.0), sw * 0.4)
		viewblade.position = Vector3(0.28 - sw * 0.25, -0.24 + sw * 0.08 + sin(Time.get_ticks_msec() * 0.006) * hs * 0.002, -0.42)

# ---------- Aktionen ----------

func nearest_enemy(max_d: float, cone := -0.2) -> Node3D:
	var best: Node3D = null
	var bd := max_d
	var fwd := rig.forward_flat() if rig.first_person else facing
	for e in get_tree().get_nodes_in_group("hostile"):
		var en := e as Node3D
		if not en.has_method("is_alive") or not en.is_alive():
			continue
		var d := en.global_position - global_position
		d.y = 0
		var l := d.length()
		if l > bd:
			continue
		if l > 1.2 and fwd.dot(d / l) < cone:
			continue
		bd = l
		best = en
	return best

func attack() -> void:
	if dead or busy or attack_t > 0.0 or dash_t > 0.0 or world.input_locked() or swimming:
		return
	var aspd := PlayerStats.attack_speed()
	attack_t = 0.36 / aspd
	if combo == 2:
		attack_t = 0.5 / aspd
	var t := nearest_enemy(5.5, -0.1)
	if t:
		var d := t.global_position - global_position
		d.y = 0
		if d.length() > 0.01:
			facing = d.normalized()
		var gap := d.length() - 1.4
		if gap > 0.2:
			lunge = facing * minf(gap, 3.0) * 9.0
	model.play("attack", combo)
	_vb_swing = 1.0
	pending_hit = 0.11 / aspd
	pending_combo = combo
	combo = (combo + 1) % 3
	combo_timer = 0.9
	world.sfx("swing")

func _resolve_melee(c: int) -> void:
	var mults: Array[float] = [1.0, 1.15, 1.7]
	var dmg: float = PlayerStats.melee_damage() * mults[c]
	var w := PlayerStats.weapon_def()
	var reach := (2.4 if c < 2 else 2.8) + float(w.reach)
	var hits := 0
	var fwd := facing
	for e in get_tree().get_nodes_in_group("hittable"):
		var en := e as Node3D
		if not en.has_method("is_alive") or not en.is_alive():
			continue
		var d := en.global_position - global_position
		d.y = 0
		var l := d.length() - 0.4
		if l > reach or absf(en.global_position.y - global_position.y) > 2.2:
			continue
		if c < 2 and l > 0.4 and fwd.dot(d.normalized()) < float(w.arc):
			continue
		var crit := randf() < PlayerStats.crit_chance()
		var amount := dmg * (1.8 if crit else 1.0) * randf_range(0.92, 1.08)
		en.take_hit(amount, global_position, 9.0 if c == 2 else 4.0, crit)
		world.blood_hit(en, global_position, crit or c == 2)
		hits += 1
	if hits > 0:
		world.hitstop(0.05 if c < 2 else 0.09)
		rig.shake = maxf(rig.shake, 0.4 if c < 2 else 0.8)
		world.sfx("hit")
		register_hits(hits)
		var leech := PlayerStats.gear("leech") * hits
		if PlayerStats.has_skill("frenzy"):
			leech += 2.0 * hits
		if leech > 0.0:
			PlayerStats.add_blood(leech)
	world.slash_fx(global_position, facing, c)

func register_hits(n: int) -> void:
	hit_streak += n
	streak_t = 2.6

func dash() -> void:
	if dead or busy or cds.dash > 0.0 or dash_t > 0.0 or world.input_locked():
		return
	var dir := Vector3.ZERO
	if input_dir.length() > 0.2:
		dir = (rig.right_flat() * input_dir.x - rig.forward_flat() * input_dir.y).normalized()
	else:
		dir = -facing if nearest_enemy(4.0) else facing
	dash_dir = dir
	dash_t = 0.22
	dash_speed = (5.6 + PlayerStats.stat("agi") * 0.1) / 0.22
	cds.dash = cd_max.dash * PlayerStats.cooldown_mult()
	attack_t = 0.0
	pending_hit = -1.0
	model.play("dash")
	PlayerStats.invulnerable = true
	world.sfx("dash")
	var perfect := false
	for e in get_tree().get_nodes_in_group("hostile"):
		if e.has_method("time_to_hit"):
			var tt: float = e.time_to_hit(global_position)
			if tt >= 0.0 and tt < 0.38:
				perfect = true
	if perfect:
		PlayerStats.s.perfect_dashes = int(PlayerStats.s.perfect_dashes) + 1
		PlayerStats.daily_progress("perfect_dash")
		world.perfect_dash()

func skill(slot: String) -> void:
	if dead or busy or world.input_locked() or cast_pending != "":
		return
	var id := ""
	for k in PlayerStats.SKILLS:
		if PlayerStats.SKILLS[k].get("slot", "") == slot and PlayerStats.has_skill(k):
			id = k
	if id == "" or cds.get(slot, 0.0) > 0.0:
		return
	var cost: float = {"blood_scythe": 12.0, "radiance": 20.0, "dread": 18.0}.get(id, 0.0)
	if not PlayerStats.spend_blood(cost):
		return
	cds[slot] = cd_max[slot] * PlayerStats.cooldown_mult()
	model.play("cast")
	cast_pending = id
	cast_t = 0.14
	world.sfx("scythe")

func _resolve_cast(id: String) -> void:
	var dmg := PlayerStats.shadow_damage()
	match id:
		"blood_scythe":
			world.scythe_fx(global_position, Color(1.0, 0.1, 0.18))
			rig.shake = 0.6
			for e in get_tree().get_nodes_in_group("hittable"):
				var en := e as Node3D
				if en.has_method("is_alive") and en.is_alive() and en.global_position.distance_to(global_position) < 4.2:
					var crit := randf() < PlayerStats.crit_chance()
					en.take_hit(dmg * 1.1 * (1.8 if crit else 1.0), global_position, 8.0, crit)
					world.blood_hit(en, global_position, true)
		"radiance":
			world.scythe_fx(global_position, Color(1.0, 0.55, 0.4))
			PlayerStats.heal(PlayerStats.max_hp() * 0.25)
			for e in get_tree().get_nodes_in_group("hostile"):
				var en := e as Node3D
				if en.has_method("is_alive") and en.is_alive() and en.global_position.distance_to(global_position) < 6.0:
					en.take_hit(dmg * 0.6, global_position, 14.0, false)
		"dread":
			world.scythe_fx(global_position, Color(0.5, 0.0, 0.1))
			rig.shake = 1.0
			for e in get_tree().get_nodes_in_group("living"):
				var en := e as Node3D
				if en.has_method("frighten") and en.global_position.distance_to(global_position) < 12.0:
					en.frighten(global_position)

func drink() -> void:
	if dead or busy or cds.drink > 0.0:
		return
	var k := PlayerStats.best_vial()
	if k == "":
		PlayerStats.system_message.emit("Keine Blutphiolen.", "blood")
		return
	if PlayerStats.drink_vial(k):
		cds.drink = cd_max.drink
		world.sfx("drink")

func receive_hit(dmg: float, from: Vector3) -> void:
	if is_invulnerable() or busy:
		return
	var dealt := PlayerStats.damage(dmg)
	if dealt < 0.0:
		world.damage_number(global_position + Vector3(0, 2.1, 0), 0, Color(0.6, 0.85, 1.0), false, "AUSGEWICHEN")
		return
	if dealt == 0.0:
		return
	flash = 1.0
	var d := global_position - from
	d.y = 0
	if d.length() > 0.01:
		knock = d.normalized() * 6.0
	if hurt_t <= 0.0:
		model.play("hurt")
		hurt_t = 0.4
	rig.shake = maxf(rig.shake, 1.0)
	world.on_player_hurt(dealt)
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(35)

func die() -> void:
	dead = true
	model.play("dead")

func revive(at: Vector3) -> void:
	dead = false
	busy = false
	model.play("")
	model.rotation.x = 0.0
	model.position = Vector3.ZERO
	global_position = at
	velocity = Vector3.ZERO
	knock = Vector3.ZERO
