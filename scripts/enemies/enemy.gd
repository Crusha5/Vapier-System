class_name Enemy
extends CharacterBody3D
## Gegner: Karkosa, Elite-Karkosa, Mutanten, rivalisierende Kadetten, Rivale Drax, Ausbilder, Karkosa-Nest.
## Zustände: idle → chase → windup → attack → recover, dazu stagger, frozen (Eklipse), dead.

const TYPES := {
	"karkosa": {"name": "Karkosa-Späher", "hp": 45.0, "speed": 4.3, "dmg": 9.0, "range": 1.9, "windup": 0.55, "cd": 1.2,
		"xp": 18, "drop": "karkosa", "drop_chance": 0.55, "aggro": 15.0, "kill": "karkosa", "radius": 0.5},
	"karkosa_elite": {"name": "Karkosa-Klinge", "hp": 130.0, "speed": 3.8, "dmg": 16.0, "range": 2.5, "windup": 0.75, "cd": 1.4,
		"xp": 55, "drop": "karkosa", "drop_chance": 1.0, "aggro": 16.0, "kill": "karkosa", "radius": 0.7},
	"mutant": {"name": "Mutant", "hp": 80.0, "speed": 2.7, "dmg": 14.0, "range": 2.2, "windup": 0.8, "cd": 1.5,
		"xp": 28, "drop": "mutant", "drop_chance": 0.65, "aggro": 14.0, "kill": "mutant", "radius": 0.6, "spit": true},
	"cadet": {"name": "Vanguard-Kadett", "hp": 60.0, "speed": 4.6, "dmg": 10.0, "range": 1.9, "windup": 0.45, "cd": 1.1,
		"xp": 30, "drop": "human", "drop_chance": 0.5, "aggro": 13.0, "kill": "cadet", "radius": 0.45},
	"drax": {"name": "Rivale Drax", "hp": 280.0, "speed": 5.0, "dmg": 15.0, "range": 2.2, "windup": 0.5, "cd": 0.9,
		"xp": 160, "drop": "human", "drop_chance": 1.0, "drops": 2, "aggro": 18.0, "kill": "cadet", "radius": 0.5, "boss": true, "charge": true},
	"instructor": {"name": "Ausbilder Varek", "hp": 460.0, "speed": 5.3, "dmg": 22.0, "range": 2.4, "windup": 0.45, "cd": 0.85,
		"xp": 280, "drop": "human", "drop_chance": 1.0, "drops": 3, "aggro": 40.0, "kill": "instructor", "radius": 0.55, "boss": true, "charge": true},
	"nest": {"name": "Karkosa-Nest", "hp": 360.0, "speed": 0.0, "dmg": 0.0, "range": 0.0, "windup": 1.0, "cd": 1.0,
		"xp": 200, "drop": "karkosa", "drop_chance": 1.0, "drops": 3, "aggro": 24.0, "kill": "karkosa", "radius": 1.6, "boss": true},
}

signal died(enemy: Enemy)

var kind := "karkosa"
var cfg: Dictionary
var world: Node
var hp := 1.0
var max_hp := 1.0
var state := "idle"
var state_t := 0.0
var cd := 0.0
var spit_cd := 2.0
var charge_cd := 4.0
var model: Node3D
var agent: NavigationAgent3D
var home := Vector3.ZERO
var wander_target := Vector3.ZERO
var knock := Vector3.ZERO
var flash := 0.0
var telegraph: MeshInstance3D
var repath_t := 0.0
var los_t := 0.0
var has_los := false
var aggro := false
var level_mult := 1.0
var spawn_t := 0.0
var last_hit_t := 99.0
var zone := ""
var _charging := false
var _charge_dir := Vector3.ZERO
var _combo_left := 0
var _attack_kind := "melee"
var _nest_spawn_t := 3.0
var _nest_children: Array = []

func setup(k: String, w: Node, at: Vector3, lvl := 1) -> Enemy:
	kind = k
	world = w
	cfg = TYPES[k]
	level_mult = 1.0 + (lvl - 1) * 0.12
	max_hp = float(cfg.hp) * level_mult
	hp = max_hp
	home = at
	position = at
	wander_target = at
	return self

func is_boss() -> bool:
	return cfg.get("boss", false)

func display_name() -> String:
	return cfg.name

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 4
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = float(cfg.radius)
	sh.height = 1.7 if kind != "nest" else 2.6
	cs.shape = sh
	cs.position.y = sh.height * 0.5
	add_child(cs)
	match kind:
		"karkosa", "karkosa_elite", "mutant":
			model = CreatureModel.new(kind)
		"cadet":
			var h := Humanoid.new({"suit": Color(0.78, 0.8, 0.86), "accent": Color(0.25, 0.55, 1.0), "hair": [Color(0.5, 0.32, 0.18), Color(0.85, 0.7, 0.4), Color(0.1, 0.08, 0.08)][randi() % 3]})
			model = h
			h.ready.connect(func(): h.add_blade(Color(0.3, 0.7, 1.0), 0.7))
		"drax":
			var h := Humanoid.new({"suit": Color(0.9, 0.9, 0.95), "accent": Color(1.0, 0.7, 0.15), "hair": Color(0.95, 0.85, 0.5), "scale": 1.12, "bulk": 1.15, "cape": true})
			model = h
			h.ready.connect(func(): h.add_blade(Color(1.0, 0.75, 0.2), 1.05))
		"instructor":
			var h := Humanoid.new({"suit": Color(0.1, 0.1, 0.12), "accent": Color(1.0, 0.82, 0.3), "hair": Color(0.6, 0.6, 0.62), "scale": 1.22, "bulk": 1.25, "cape": true, "visor": true})
			model = h
			h.ready.connect(func(): h.add_blade(Color(1.0, 0.85, 0.35), 1.2))
		"nest":
			model = _build_nest()
	add_child(model)
	if kind != "nest":
		agent = NavigationAgent3D.new()
		agent.radius = float(cfg.radius)
		agent.height = 1.8
		agent.path_desired_distance = 0.7
		agent.target_desired_distance = 0.5
		agent.path_max_distance = 3.0
		add_child(agent)
	telegraph = Toon.quad_holo(self, Vector2(1, 1), Vector3(0, 0.06, 0), Toon.holo(Toon.RED, 2.2, true, 0.0))
	telegraph.visible = false
	spawn_t = 0.0

func _build_nest() -> Node3D:
	var n := Node3D.new()
	var resin := Toon.amat(Color(0.2, 0.26, 0.2), {"outline": 0.05, "radial": 1.0, "rim": 0.5, "rim_color": Color(0.6, 1.0, 0.3)})
	var sac := Toon.amat(Color(0.45, 0.6, 0.2), {"emit": Color(0.55, 0.9, 0.15), "energy": 0.9, "outline": 0.05, "radial": 1.0})
	Toon.sphere(n, 1.5, Vector3(0, 0.6, 0), resin, Vector3(1.3, 0.7, 1.3), 10)
	var core := Toon.sphere(n, 0.9, Vector3(0, 1.5, 0), sac, Vector3(1.0, 1.25, 1.0), 10)
	core.name = "Core"
	for i in 7:
		var a := TAU * i / 7.0
		Toon.prism(n, Vector3(0.35, 1.8, 0.35), Vector3(cos(a) * 1.5, 1.0, sin(a) * 1.5), resin, Vector3(0, -a, 0.5 * (1 if i % 2 == 0 else -1) + 0.3))
	var l := OmniLight3D.new()
	l.light_color = Color(0.6, 1.0, 0.2)
	l.light_energy = 2.0
	l.omni_range = 7.0
	l.position = Vector3(0, 2.0, 0)
	n.add_child(l)
	return n

func _anim(delta: float, spd: float) -> void:
	if model is Humanoid:
		(model as Humanoid).animate(delta, spd, _action_len())
	elif model is CreatureModel:
		(model as CreatureModel).animate(delta, spd, _action_len())
	elif kind == "nest":
		var core := model.get_node("Core") as Node3D
		var p := 1.0 + sin(Time.get_ticks_msec() * 0.004) * 0.06 + flash * 0.15
		core.scale = Vector3(p, p * 1.25, p)

func _action_len() -> float:
	match state:
		"windup":
			return float(cfg.windup)
		"attack":
			return 0.22
		"stagger":
			return 0.3
	return 0.35

func _play(a: String) -> void:
	if model is Humanoid:
		(model as Humanoid).play(a, randi() % 3)
	elif model is CreatureModel:
		(model as CreatureModel).play(a)

func _set_state(s: String) -> void:
	state = s
	state_t = 0.0

func frozen() -> bool:
	return world != null and world.eclipse_active()

func _physics_process(delta: float) -> void:
	if world == null or world.player == null:
		return
	spawn_t += delta
	last_hit_t += delta
	if flash > 0.0:
		flash = max(0.0, flash - delta * 5.0)
		Toon.set_overlay(model, Color(1, 0.95, 0.95), flash)
	if state == "dead":
		state_t += delta
		_anim(delta, 0.0)
		if state_t > 1.6:
			queue_free()
		return
	if frozen():
		telegraph.visible = false
		Toon.set_overlay(model, Color(0.25, 0.35, 1.0), 0.45)
		return
	elif flash <= 0.0:
		Toon.set_overlay(model, Color(1, 1, 1), 0.0)
	if kind == "nest":
		_nest_logic(delta)
		_anim(delta, 0.0)
		return
	state_t += delta
	cd -= delta
	spit_cd -= delta
	charge_cd -= delta
	var player: Node3D = world.player
	var to_p := player.global_position - global_position
	to_p.y = 0.0
	var dist := to_p.length()
	los_t -= delta
	if los_t <= 0.0:
		los_t = 0.3
		has_los = _check_los(player.global_position)
	if not aggro and dist < float(cfg.aggro) and (has_los or dist < 5.0):
		aggro = true
	if aggro and dist > float(cfg.aggro) * 2.2:
		aggro = false
	var move := Vector3.ZERO
	var spd := float(cfg.speed) * (1.0 + (level_mult - 1.0) * 0.3)
	match state:
		"idle":
			if aggro and not world.player_dead():
				_set_state("chase")
			else:
				if global_position.distance_to(wander_target) < 0.8 or state_t > 6.0:
					wander_target = home + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
					state_t = 0.0
				move = _nav_dir(wander_target, delta) * spd * 0.35
		"chase":
			if not aggro or world.player_dead():
				_set_state("idle")
			elif _charging:
				move = _charge_dir * spd * 3.2
				if state_t > 0.45 or dist < float(cfg.range) * 0.8:
					_charging = false
					_begin_windup("melee")
			elif dist <= float(cfg.range) and cd <= 0.0:
				_begin_windup("melee")
			elif cfg.get("spit", false) and spit_cd <= 0.0 and dist > 4.0 and dist < 10.0 and has_los:
				_begin_windup("spit")
			elif cfg.get("charge", false) and charge_cd <= 0.0 and dist > 4.0 and dist < 9.0 and has_los:
				charge_cd = 5.0
				_charging = true
				_charge_dir = to_p.normalized()
				state_t = 0.0
				_play("dash")
			elif dist > float(cfg.range) * 0.8:
				move = _nav_dir(player.global_position, delta) * spd
			_face(to_p, delta * 10.0)
		"windup":
			_face(to_p, delta * (4.0 if _attack_kind == "melee" else 8.0))
			var wt := float(cfg.windup) * (0.85 if _attack_kind == "spit" else 1.0)
			var k: float = clamp(state_t / wt, 0.0, 1.0)
			telegraph.visible = _attack_kind == "melee"
			var r := float(cfg.range) * 2.0 * (0.4 + 0.6 * k)
			telegraph.scale = Vector3(r, r, 1)
			Toon.set_alpha(telegraph, 0.35 + 0.65 * k)
			if state_t >= wt:
				_do_attack()
		"attack":
			if state_t > 0.25:
				if _combo_left > 0 and dist < float(cfg.range) * 1.5:
					_combo_left -= 1
					_begin_windup("melee", 0.55)
				else:
					_set_state("recover")
		"recover":
			_face(to_p, delta * 3.0)
			if state_t > float(cfg.cd) * 0.5:
				_set_state("chase")
		"stagger":
			if state_t > 0.32:
				_set_state("chase" if aggro else "idle")
	# Abstand zu anderen Gegnern
	for e in get_tree().get_nodes_in_group("enemies"):
		if e == self or not is_instance_valid(e) or (e as Enemy).state == "dead":
			continue
		var d := global_position - (e as Node3D).global_position
		d.y = 0
		var l := d.length()
		var min_d := float(cfg.radius) + float((e as Enemy).cfg.radius) + 0.2
		if l < min_d and l > 0.001:
			move += d / l * (min_d - l) * 6.0
	velocity = move + knock
	velocity.y = 0.0
	knock = knock.move_toward(Vector3.ZERO, delta * 30.0)
	move_and_slide()
	global_position.y = 0.0
	_anim(delta, Vector2(velocity.x, velocity.z).length())

func _begin_windup(kindx: String, mult := 1.0) -> void:
	_attack_kind = kindx
	_set_state("windup")
	state_t = float(cfg.windup) * (1.0 - mult)
	if kindx == "spit":
		_play("spit")
	else:
		_play("windup")
		if _combo_left <= 0 and (kind == "drax" or kind == "instructor"):
			_combo_left = 1 if kind == "drax" else 2

## Für den perfekten Dash: Zeit bis zum Treffer, oder −1
func time_to_hit(player_pos: Vector3) -> float:
	if state != "windup" or _attack_kind != "melee":
		return -1.0
	if global_position.distance_to(player_pos) > float(cfg.range) + 1.6:
		return -1.0
	return float(cfg.windup) - state_t

func _do_attack() -> void:
	telegraph.visible = false
	_set_state("attack")
	cd = float(cfg.cd)
	if _attack_kind == "spit":
		spit_cd = 3.6
		_play("attack")
		world.spawn_spit(global_position + Vector3(0, 1.4, 0) - global_basis.z * 0.6, world.player.global_position + Vector3(0, 0.9, 0), float(cfg.dmg) * 0.6 * level_mult)
		return
	_play("attack")
	if model is Humanoid:
		(model as Humanoid).play("attack", randi() % 3)
	var p: Node3D = world.player
	var to_p := p.global_position - global_position
	to_p.y = 0.0
	var fwd := -global_basis.z
	if to_p.length() <= float(cfg.range) + 0.45 and (to_p.length() < 0.8 or fwd.dot(to_p.normalized()) > 0.25):
		world.player.receive_hit(float(cfg.dmg) * level_mult, global_position)
	world.sfx("swing")

func _face(dir: Vector3, w: float) -> void:
	if dir.length() < 0.01:
		return
	var target := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target, clamp(w, 0.0, 1.0))

func _nav_dir(target: Vector3, delta: float) -> Vector3:
	repath_t -= delta
	if repath_t <= 0.0:
		repath_t = 0.3
		agent.target_position = target
	var next := agent.get_next_path_position()
	var d := next - global_position
	d.y = 0.0
	if d.length() < 0.05 or agent.is_navigation_finished():
		d = target - global_position
		d.y = 0.0
	if d.length() < 0.05:
		return Vector3.ZERO
	var dir := d.normalized()
	if state == "idle" and velocity.length() > 0.1:
		_face(dir, delta * 5.0)
	return dir

func _check_los(target: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.2, 0), target + Vector3(0, 1.2, 0), 1)
	return space.intersect_ray(q).is_empty()

func take_hit(amount: float, from: Vector3, knockback := 4.0, crit := false, color := Color(1, 1, 1)) -> void:
	if state == "dead":
		return
	hp -= amount
	flash = 1.0
	last_hit_t = 0.0
	aggro = true
	world.damage_number(global_position + Vector3(0, 2.0 if kind != "nest" else 3.2, 0), amount, color, crit)
	if kind != "nest":
		var d := global_position - from
		d.y = 0
		var resist := 0.35 if is_boss() else 1.0
		if d.length() > 0.01:
			knock = d.normalized() * knockback * resist
		if (not is_boss() or crit) and state != "windup" or (state == "windup" and knockback > 7.0 and not is_boss()):
			_set_state("stagger")
			telegraph.visible = false
			_charging = false
			_play("hurt")
	if hp <= 0.0:
		_die()

func _die() -> void:
	state = "dead"
	state_t = 0.0
	telegraph.visible = false
	collision_layer = 0
	collision_mask = 0
	if model is Humanoid:
		(model as Humanoid).play("dead")
	elif model is CreatureModel:
		(model as CreatureModel).play("dead")
	else:
		model.visible = false
		world.burst(global_position + Vector3(0, 1.4, 0), Color(0.6, 1.0, 0.2), 3.0)
	var n := int(cfg.get("drops", 1))
	for i in n:
		if randf() < float(cfg.drop_chance):
			var off := Vector3(randf_range(-0.8, 0.8), 0, randf_range(-0.8, 0.8)) if n > 1 else Vector3.ZERO
			world.spawn_capsule(String(cfg.drop), global_position + off)
	PlayerStats.register_kill(String(cfg.kill), int(float(cfg.xp) * level_mult))
	died.emit(self)

# ---------- Nest ----------

func _nest_logic(delta: float) -> void:
	var player: Node3D = world.player
	var dist := player.global_position.distance_to(global_position)
	_nest_children = _nest_children.filter(func(e): return is_instance_valid(e) and (e as Enemy).state != "dead")
	if dist < float(cfg.aggro):
		_nest_spawn_t -= delta
		if _nest_spawn_t <= 0.0 and _nest_children.size() < 5:
			_nest_spawn_t = 4.0
			var k := "karkosa_elite" if randf() < 0.22 else ("mutant" if randf() < 0.2 else "karkosa")
			var a := randf() * TAU
			var e: Enemy = world.spawn_enemy(k, global_position + Vector3(cos(a), 0, sin(a)) * 2.6)
			if e:
				e.aggro = true
				_nest_children.append(e)
				world.burst(e.global_position + Vector3(0, 0.6, 0), Color(0.6, 1.0, 0.2), 1.2)
