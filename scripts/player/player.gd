class_name Player
extends CharacterBody3D
## Kadett-Subjekt 0: Bewegung, Kombo-Angriff, Schatten-Dash, Blut-Skills, Treffer.

var world: Node
var model: Humanoid
var input_dir := Vector2.ZERO   # vom Touch-Joystick (x rechts, y unten)
var facing := Vector3(0, 0, -1)
var dash_t := 0.0
var dash_dir := Vector3.ZERO
var dash_speed := 0.0
var combo := 0
var combo_timer := 0.0
var attack_t := 0.0       # Sperre bis zur nächsten Aktion
var pending_hit := -1.0   # Zeit bis zum Treffermoment
var pending_combo := 0
var knock := Vector3.ZERO
var flash := 0.0
var hurt_t := 0.0
var lunge := Vector3.ZERO
var dead := false
var cds := {"dash": 0.0, "skill1": 0.0, "skill2": 0.0, "skill3": 0.0, "drink": 0.0}
var cd_max := {"dash": 0.9, "skill1": 4.5, "skill2": 6.0, "skill3": 45.0, "drink": 1.0}
var cast_pending := ""
var cast_t := 0.0
var trail_t := 0.0
var steps_t := 0.0

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.38
	sh.height = 1.7
	cs.shape = sh
	cs.position.y = 0.85
	add_child(cs)
	model = Humanoid.new({"suit": Color(0.1, 0.1, 0.14), "accent": Toon.RED, "hair": Color(0.06, 0.05, 0.08),
		"skin": Color(0.82, 0.7, 0.66), "eyes": Color(0.85, 0.9, 1.0), "glow": 0.0, "cape": true})
	add_child(model)
	model.add_blade(Toon.RED, 0.95)
	refresh_awakening()

func refresh_awakening() -> void:
	var awake: bool = PlayerStats.s.awakened
	model.blade.visible = awake
	if awake:
		model.set_eye_glow(Color(1.0, 0.1, 0.15), 3.0)
	else:
		model.set_eye_glow(Color(0.85, 0.9, 1.0), 0.0)

func is_invulnerable() -> bool:
	return dash_t > 0.0 or dead

func _physics_process(delta: float) -> void:
	for k in cds:
		cds[k] = max(0.0, cds[k] - delta)
	if dead:
		model.animate(delta, 0.0)
		return
	if flash > 0.0:
		flash = max(0.0, flash - delta * 4.0)
		Toon.set_overlay(model, Color(1.0, 0.25, 0.3), flash)
	combo_timer -= delta
	if combo_timer <= 0.0:
		combo = 0
	attack_t -= delta
	hurt_t -= delta
	PlayerStats.invulnerable = dash_t > 0.0
	var dir := Vector3(input_dir.x, 0, input_dir.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	var locked: bool = world.input_locked()
	if locked:
		dir = Vector3.ZERO
	var spd := PlayerStats.move_speed()
	var move := Vector3.ZERO
	if dash_t > 0.0:
		dash_t -= delta
		move = dash_dir * dash_speed
		trail_t -= delta
		if trail_t <= 0.0:
			trail_t = 0.045
			world.afterimage(global_position, rotation.y)
		if dash_t <= 0.0:
			PlayerStats.invulnerable = false
	else:
		var slow := 0.35 if attack_t > 0.0 else 1.0
		move = dir * spd * slow
		if dir.length() > 0.1 and attack_t <= 0.0:
			facing = dir.normalized()
	# Treffermoment der Kombo
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
	velocity = move + knock
	velocity.y = 0.0
	knock = knock.move_toward(Vector3.ZERO, delta * 25.0)
	move_and_slide()
	global_position.y = 0.0
	var target_rot := atan2(-facing.x, -facing.z)
	rotation.y = lerp_angle(rotation.y, target_rot, clamp(delta * 16.0, 0.0, 1.0))
	var hs := Vector2(velocity.x, velocity.z).length()
	model.animate(delta, 0.0 if dash_t > 0.0 else hs, 0.34 / PlayerStats.attack_speed())
	if hs > 2.0 and dash_t <= 0.0:
		steps_t -= delta * hs
		if steps_t <= 0.0:
			steps_t = 3.2
			world.sfx("step")

# ---------- Aktionen ----------

func _nearest_enemy(max_d: float) -> Enemy:
	var best: Enemy = null
	var bd := max_d
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en.state == "dead":
			continue
		var d := en.global_position.distance_to(global_position) - float(en.cfg.radius)
		if d < bd:
			bd = d
			best = en
	return best

func attack() -> void:
	if dead or attack_t > 0.0 or dash_t > 0.0 or world.input_locked():
		return
	var aspd := PlayerStats.attack_speed()
	attack_t = 0.36 / aspd
	if combo == 2:
		attack_t = 0.5 / aspd
	var t := _nearest_enemy(5.5)
	if t:
		var d := t.global_position - global_position
		d.y = 0
		if d.length() > 0.01:
			facing = d.normalized()
			rotation.y = atan2(-facing.x, -facing.z)
		var gap := d.length() - float(t.cfg.radius) - 1.0
		if gap > 0.2:
			lunge = facing * min(gap, 3.0) * 9.0
	elif input_dir.length() > 0.2:
		lunge = facing * 3.0
	model.play("attack", combo)
	pending_hit = 0.11 / aspd
	pending_combo = combo
	combo = (combo + 1) % 3
	combo_timer = 0.9
	world.sfx("swing")

func _resolve_melee(c: int) -> void:
	var mults: Array[float] = [1.0, 1.15, 1.7]
	var dmg: float = PlayerStats.melee_damage() * mults[c]
	if world.eclipse_active():
		dmg *= 1.5
	var reach := 2.5 if c < 2 else 2.9
	var hits := 0
	for e in get_tree().get_nodes_in_group("enemies"):
		var en := e as Enemy
		if en.state == "dead":
			continue
		var d := en.global_position - global_position
		d.y = 0
		var l := d.length() - float(en.cfg.radius)
		if l > reach:
			continue
		if c < 2 and l > 0.4 and facing.dot(d.normalized()) < 0.15:
			continue
		var crit := randf() < PlayerStats.crit_chance()
		var amount := dmg * (1.8 if crit else 1.0) * randf_range(0.92, 1.08)
		en.take_hit(amount, global_position, 9.0 if c == 2 else 4.0, crit, Color(1.0, 0.85, 0.3) if crit else Color(1, 1, 1))
		hits += 1
	if hits > 0:
		world.hitstop(0.05 if c < 2 else 0.09)
		world.shake(0.15 if c < 2 else 0.35)
		world.sfx("hit")
		world.slash_fx(global_position, facing, c)
		if PlayerStats.has_skill("crimson_feast"):
			PlayerStats.add_blood(1.5 * hits)
	else:
		world.slash_fx(global_position, facing, c)

func dash() -> void:
	if dead or cds.dash > 0.0 or dash_t > 0.0 or world.input_locked():
		return
	var dir := Vector3(input_dir.x, 0, input_dir.y)
	if dir.length() < 0.2:
		dir = facing
	dir = dir.normalized()
	facing = dir
	dash_dir = dir
	dash_t = 0.2
	dash_speed = (5.2 + PlayerStats.stat("agi") * 0.1) / 0.2
	cds.dash = cd_max.dash * PlayerStats.cooldown_mult()
	attack_t = 0.0
	pending_hit = -1.0
	model.play("dash")
	PlayerStats.invulnerable = true
	world.sfx("dash")
	if PlayerStats.has_skill("shadow_echo"):
		world.shadow_echo(global_position)
	# Perfekter Dash: ein Angriff stand unmittelbar bevor
	var perfect := false
	for e in get_tree().get_nodes_in_group("enemies"):
		var t := (e as Enemy).time_to_hit(global_position)
		if t >= 0.0 and t < 0.38:
			perfect = true
	if world.spit_incoming(global_position):
		perfect = true
	if perfect:
		PlayerStats.s.perfect_dashes = int(PlayerStats.s.perfect_dashes) + 1
		PlayerStats.daily_progress("perfect_dash")
		world.perfect_dash()

func skill(slot: String) -> void:
	if dead or world.input_locked() or cast_pending != "":
		return
	var id := ""
	for k in PlayerStats.SKILLS:
		if PlayerStats.SKILLS[k].slot == slot and PlayerStats.has_skill(k):
			id = k
	if id == "" or cds[slot] > 0.0:
		return
	var cost: float = {"blood_scythe": 12.0, "blood_lance": 18.0, "eclipse": 35.0}.get(id, 0.0)
	if not PlayerStats.spend_blood(cost):
		return
	cds[slot] = cd_max[slot] * (PlayerStats.cooldown_mult() if slot != "skill3" else 1.0)
	PlayerStats.daily_progress("skill_use")
	match id:
		"blood_scythe":
			model.play("cast")
			cast_pending = id
			cast_t = 0.12
			world.sfx("scythe")
		"blood_lance":
			var t := _nearest_enemy(12.0)
			if t:
				var d := t.global_position - global_position
				d.y = 0
				facing = d.normalized()
				rotation.y = atan2(-facing.x, -facing.z)
			model.play("attack", 2)
			cast_pending = id
			cast_t = 0.1
			world.sfx("lance")
		"eclipse":
			model.play("cast")
			world.start_eclipse(4.0)

func _resolve_cast(id: String) -> void:
	var dmg := PlayerStats.shadow_damage()
	if world.eclipse_active():
		dmg *= 1.5
	match id:
		"blood_scythe":
			world.scythe_fx(global_position)
			world.shake(0.3)
			for e in get_tree().get_nodes_in_group("enemies"):
				var en := e as Enemy
				if en.state == "dead":
					continue
				if en.global_position.distance_to(global_position) - float(en.cfg.radius) < 3.7:
					var crit := randf() < PlayerStats.crit_chance()
					en.take_hit(dmg * 1.1 * (1.8 if crit else 1.0), global_position, 8.0, crit, Toon.RED.lightened(0.3))
		"blood_lance":
			world.lance_fx(global_position, facing)
			world.shake(0.25)
			for e in get_tree().get_nodes_in_group("enemies"):
				var en := e as Enemy
				if en.state == "dead":
					continue
				var d := en.global_position - global_position
				d.y = 0
				var along := d.dot(facing)
				var side := (d - facing * along).length()
				if along > -0.5 and along < 11.5 and side < 1.2 + float(en.cfg.radius):
					var crit := randf() < PlayerStats.crit_chance()
					en.take_hit(dmg * 2.0 * (1.8 if crit else 1.0), global_position, 6.0, crit, Toon.RED.lightened(0.3))

func drink() -> void:
	if dead or cds.drink > 0.0:
		return
	var k := PlayerStats.best_capsule()
	if k == "":
		PlayerStats.system_message.emit("Keine Blut-Essenzen im Inventar.", "blood")
		return
	if PlayerStats.drink(k):
		cds.drink = cd_max.drink
		world.sfx("drink")
		world.burst(global_position + Vector3(0, 1.2, 0), PlayerStats.BLOOD_TYPES[k].color, 0.8)

func receive_hit(dmg: float, from: Vector3) -> void:
	if is_invulnerable():
		return
	var dealt := PlayerStats.damage(dmg)
	if dealt < 0.0:
		world.damage_number(global_position + Vector3(0, 2.1, 0), 0, Toon.CYAN, false, "AUSGEWICHEN")
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
	world.damage_number(global_position + Vector3(0, 2.1, 0), dealt, Color(1.0, 0.3, 0.3), false)
	world.shake(0.4)
	world.sfx("hurt")
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(40)

func die() -> void:
	dead = true
	model.play("dead")

func revive(at: Vector3) -> void:
	dead = false
	model.action = ""
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
	global_position = at
	knock = Vector3.ZERO
