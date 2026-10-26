class_name Enemy
extends Actor
## Feinde: Banditen und Wacht-Soldaten (Menschen – gehen bei 0 HP in die Knie und können verhört,
## verschont oder ausgesaugt werden), Reißer (nachtaktive Bestien). Angriffe werden angekündigt.

const TYPES := {
	"bandit": {"name": "Bandit", "hp": 70.0, "speed": 4.4, "dmg": 11.0, "range": 2.0, "windup": 0.5, "cd": 1.1, "xp": 30, "aggro": 16.0, "kind": "human", "faction": "bandit", "shards": 3},
	"bandit_archer": {"name": "Banditenschütze", "hp": 50.0, "speed": 4.0, "dmg": 9.0, "range": 14.0, "windup": 0.9, "cd": 2.2, "xp": 32, "aggro": 22.0, "kind": "human", "faction": "bandit", "ranged": true, "shards": 3},
	"krahe": {"name": "Krähe", "hp": 260.0, "speed": 5.0, "dmg": 17.0, "range": 2.3, "windup": 0.45, "cd": 0.9, "xp": 180, "aggro": 18.0, "kind": "human", "faction": "bandit", "boss": true, "shards": 40},
	"wacht": {"name": "Soldat der Wacht", "hp": 120.0, "speed": 4.6, "dmg": 15.0, "range": 2.2, "windup": 0.5, "cd": 1.0, "xp": 60, "aggro": 20.0, "kind": "human", "faction": "wacht", "shards": 8},
	"reisser": {"name": "Reißer", "hp": 85.0, "speed": 6.2, "dmg": 13.0, "range": 2.0, "windup": 0.42, "cd": 1.0, "xp": 35, "aggro": 20.0, "kind": "beast", "faction": "wild", "shards": 4},
}

var type := "bandit"
var cfg: Dictionary
var state := "idle"
var state_t := 0.0
var cd := 0.0
var aggro := false
var telegraph: MeshInstance3D
var wander_target := Vector3.ZERO
var patrol: Array = []
var night_only := false
var spared := false
var _windup_len := 0.5
var _los_t := 0.0
var _has_los := false

func setup(t: String, w: Node, at: Vector3, lvl := 1, id := "") -> Enemy:
	type = t
	world = w
	cfg = TYPES[t]
	level = lvl
	var mult := 1.0 + (lvl - 1) * 0.15
	max_hp = float(cfg.hp) * mult
	hp = max_hp
	kind = cfg.kind
	faction = cfg.faction
	innocent = faction == "wacht"
	display_name = cfg.name
	npc_id = id
	position = at
	wander_target = at
	radius = 0.5 if kind == "beast" else 0.42
	return self

func _build_model() -> void:
	match type:
		"bandit":
			model = Humanoid.new(Looks.bandit(npc_id.hash() if npc_id != "" else randi()))
		"bandit_archer":
			var l := Looks.bandit_archer(npc_id.hash() if npc_id != "" else randi())
			l.weapon = "equipment.crossbow.default"
			model = Humanoid.new(l)
		"krahe":
			model = Humanoid.new(Looks.krahe())
		"wacht":
			model = Humanoid.new(Looks.wacht(randi()))
		"reisser":
			model = QuadModel.new("reisser")

func _height() -> float:
	return 1.2 if kind == "beast" else 1.75

func _ready() -> void:
	super._ready()
	add_to_group("hittable")
	add_to_group("hostile")
	if model is Humanoid:
		var h := model as Humanoid
		h.always_drawn = true
		if type == "bandit_archer":
			h.add_blade(Color(0.4, 0.3, 0.2), 0.5, 0.04)
		elif type == "wacht":
			h.add_blade(Color(0.5, 0.75, 1.0), 1.0, 0.05)
		else:
			h.add_blade(Color(0.55, 0.55, 0.58), 0.85 if type != "krahe" else 1.1, 0.05)
	telegraph = Toon.quad_holo(self, Vector2(1, 1), Vector3(0, 0.08, 0), Toon.holo(Color(1.0, 0.15, 0.1), 2.0, true, 0.0).duplicate())
	telegraph.visible = false

func is_boss() -> bool:
	return cfg.get("boss", false)

func feedable() -> bool:
	return downed and alive

func feed_info() -> Dictionary:
	return {"id": npc_id, "kind": kind, "innocent": innocent, "name": display_name}

func _go(s: String) -> void:
	state = s
	state_t = 0.0

func time_to_hit(p: Vector3) -> float:
	if state != "windup" or cfg.get("ranged", false):
		return -1.0
	if global_position.distance_to(p) > float(cfg.range) + 1.5:
		return -1.0
	return _windup_len - state_t

func _on_hit(from: Vector3) -> void:
	aggro = true
	if state != "windup" or not is_boss():
		if state == "windup":
			telegraph.visible = false
		_go("stagger")
		if model is Humanoid:
			(model as Humanoid).play("hurt")
		elif model:
			model.play("hurt")

func _on_zero_hp() -> void:
	if kind == "human" and not downed:
		downed = true
		hp = 1.0
		_go("downed")
		telegraph.visible = false
		remove_from_group("hostile")
		(model as Humanoid).play("kneel")
		world.on_enemy_downed(self)
	else:
		die()

func die() -> void:
	var was := alive
	telegraph.visible = false
	super.die()
	if was:
		world.on_enemy_killed(self)

func spare() -> void:
	## Verschont: flieht und taucht nicht wieder auf
	spared = true
	downed = false
	alive = true
	_go("flee")
	(model as Humanoid).play("")
	remove_from_group("hittable")

func _think(delta: float, dist: float) -> void:
	if not alive:
		apply_motion(Vector3.ZERO, delta)
		return
	state_t += delta
	cd -= delta
	var p: Vector3 = world.player.global_position
	var to_p := p - global_position
	to_p.y = 0
	var move := Vector3.ZERO
	if night_only and PlayerStats.night < 0.3 and not aggro:
		visible = false
		return
	visible = true
	_los_t -= delta
	if _los_t <= 0.0:
		_los_t = 0.4
		_has_los = dist < float(cfg.aggro) and can_see(p, float(cfg.aggro), -0.6)
	if not aggro and (_has_los or dist < 4.0) and not world.player.dead:
		aggro = true
		world.on_enemy_alerted(self)
	if aggro and (dist > float(cfg.aggro) * 2.5 or world.player.dead):
		aggro = false
		_go("idle")
	if fear_t > 0.0 and state != "downed":
		move = steer(global_position - to_p.normalized() * 8.0, float(cfg.speed), delta)
		face_dir(move, delta)
		apply_motion(move, delta)
		return
	var spd := float(cfg.speed) * (1.0 + (level - 1) * 0.04)
	match state:
		"idle":
			if aggro:
				_go("chase")
			else:
				if not patrol.is_empty():
					var wp: Vector3 = patrol[0]
					if global_position.distance_to(wp) < 1.0:
						patrol.push_back(patrol.pop_front())
					move = steer(wp, spd * 0.35, delta)
				elif global_position.distance_to(wander_target) < 1.0 or state_t > 8.0:
					wander_target = home + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
					state_t = 0.0
				else:
					move = steer(wander_target, spd * 0.3, delta)
		"chase":
			var rng := float(cfg.range)
			if cfg.get("ranged", false):
				if dist < 6.0:
					move = steer(global_position - to_p.normalized() * 4.0, spd, delta)
				elif dist <= rng and cd <= 0.0 and _has_los:
					_begin_windup()
				elif dist > rng * 0.9:
					move = steer(p, spd, delta)
			else:
				if dist <= rng and cd <= 0.0:
					_begin_windup()
				elif dist > rng * 0.8:
					move = steer(p, spd, delta)
			face_dir(to_p, delta, 10.0)
		"windup":
			face_dir(to_p, delta, 5.0)
			var k := clampf(state_t / _windup_len, 0.0, 1.0)
			if not cfg.get("ranged", false):
				telegraph.visible = true
				var r := float(cfg.range) * 2.0 * (0.4 + 0.6 * k)
				telegraph.scale = Vector3(r, r, 1)
				(telegraph.material_override as ShaderMaterial).set_shader_parameter("alpha", 0.35 + 0.65 * k)
			if state_t >= _windup_len:
				_strike(dist)
		"attack":
			if state_t > 0.3:
				_go("recover")
		"recover":
			face_dir(to_p, delta, 3.0)
			if state_t > float(cfg.cd) * 0.5:
				_go("chase")
		"stagger":
			if state_t > 0.3:
				_go("chase" if aggro else "idle")
		"downed":
			apply_motion(Vector3.ZERO, delta)
			if state_t > 18.0:
				# verblutet
				die()
			return
		"flee":
			move = steer(global_position - to_p.normalized() * 10.0, spd * 1.1, delta)
			if dist > 60.0:
				queue_free()
	# Abstand zum Spieler und zueinander
	if dist < 1.0:
		move -= to_p.normalized() * 2.0
	if move.length() > 0.05 and state != "chase":
		face_dir(move, delta)
	apply_motion(move, delta)

func _begin_windup() -> void:
	_go("windup")
	_windup_len = float(cfg.windup)
	if model is Humanoid:
		(model as Humanoid).play("windup")
	elif model:
		model.play("windup")

func _strike(dist: float) -> void:
	telegraph.visible = false
	_go("attack")
	cd = float(cfg.cd)
	if model is Humanoid:
		(model as Humanoid).play("attack", randi() % 3)
	elif model:
		model.play("attack")
	var dmg := float(cfg.dmg) * (1.0 + (level - 1) * 0.12)
	if cfg.get("ranged", false):
		world.spawn_bolt(global_position + Vector3(0, 1.4, 0), world.player.global_position + Vector3(0, 1.0, 0), dmg)
		return
	var p: Vector3 = world.player.global_position
	var to_p := p - global_position
	to_p.y = 0
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	if dist <= float(cfg.range) + 0.5 and (dist < 0.9 or fwd.dot(to_p.normalized()) > 0.2):
		world.player.receive_hit(dmg, global_position)
	world.sfx("swing")
