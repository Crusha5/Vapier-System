class_name HumanNpc
extends Actor
## Dorfbewohner und Story-Figuren: Tagesablauf (Arbeit, Feuer am Abend, Schlaf im eigenen Bett),
## Gespräche, Angst, Flucht. Wer angegriffen wird, geht in die Knie (überwältigt) statt sofort zu sterben.

var look: Dictionary
var work_spot := Vector3.ZERO
var fire_spot := Vector3.ZERO
var bed_path: Array = []     # Wegpunkte bis ins Bett
var bed_rot := 0.0
var role := "villager"        # villager, guard, elder, prisoner, wounded, child
var state := "work"
var state_t := 0.0
var path: Array = []
var talking := false
var wander_target := Vector3.ZERO
var night_owl := false        # bleibt nachts am Feuer
var marker: Label3D
var _attack_t := 0.0
var _windup := false
var sees_player_t := 0.0
var hostile := false

func setup(id: String, name: String, lk: Dictionary, w: Node, at: Vector3, r := "villager") -> HumanNpc:
	npc_id = id
	display_name = name
	look = lk
	world = w
	role = r
	kind = "human"
	faction = "village"
	innocent = true
	max_hp = 60.0 if r != "guard" else 120.0
	hp = max_hp
	position = at
	work_spot = at
	wander_target = at
	return self

func _build_model() -> void:
	var h := Humanoid.new(look)
	h.weapon_pose = role == "guard"
	model = h

func _ready() -> void:
	super._ready()
	add_to_group("hittable")
	add_to_group("npcs")
	if role == "guard":
		(model as Humanoid).add_blade(Color(0.6, 0.62, 0.66), 0.85, 0.05)
		(model as Humanoid).blade.material_override = Toon.mat(Color(0.55, 0.57, 0.6), {"metal": 0.8, "rough": 0.3})
	marker = Label3D.new()
	marker.font = HoloUI.F_BOLD
	marker.font_size = 96
	marker.pixel_size = 0.006
	marker.modulate = Color(1.0, 0.8, 0.35)
	marker.outline_size = 18
	marker.outline_modulate = Color(0, 0, 0, 0.8)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.position = Vector3(0, _height() + 0.55, 0)
	marker.visible = false
	add_child(marker)
	match role:
		"prisoner":
			(model as Humanoid).play("sit")
			state = "fixed"
		"wounded":
			(model as Humanoid).play("lie")
			state = "fixed"

func _height() -> float:
	return 1.75 * float(look.get("scale", 1.0))

func set_marker(v: bool, text := "!") -> void:
	marker.visible = v and alive
	marker.text = text

func feedable() -> bool:
	if not alive:
		return false
	return true

## Weiß das Opfer, wer es gebissen hat?
func aware_of(p: Vector3) -> bool:
	if asleep or downed or role == "wounded":
		return false
	var d := p - global_position
	d.y = 0
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	return d.length() < 1.0 or fwd.dot(d.normalized()) > -0.4

func _on_hit(from: Vector3) -> void:
	if alive and not downed:
		world.on_villager_attacked(self)
		if role == "guard" or hostile:
			hostile = true
			add_to_group("hostile")
		elif role != "prisoner":
			frighten(from)

func _on_zero_hp() -> void:
	if downed:
		die()
		return
	downed = true
	hp = 1.0
	state = "downed"
	state_t = 0.0
	(model as Humanoid).play("cower" if role != "guard" else "kneel")
	asleep = false

func die() -> void:
	var was := alive
	super.die()
	if was:
		set_marker(false)
		world.on_villager_killed(self)

func revive_from_downed() -> void:
	downed = false
	hp = max_hp * 0.3
	state = "flee"
	fear_t = 10.0
	(model as Humanoid).play("")

func wake_up() -> void:
	if asleep:
		asleep = false
		(model as Humanoid).bed_height = 0.0
		(model as Humanoid).play("")
		state = "work"

func _think(delta: float, dist: float) -> void:
	if not alive:
		_anim_speed = 0.0
		apply_motion(Vector3.ZERO, delta)
		return
	state_t += delta
	var p: Vector3 = world.player.global_position
	var move := Vector3.ZERO
	var hostile_village: bool = PlayerStats.flag("village_hostile")
	if role == "guard" and hostile_village and dist < 25.0 and not downed:
		hostile = true
		if not is_in_group("hostile"):
			add_to_group("hostile")
	if talking:
		face_dir(p - global_position, delta, 6.0)
		if (model as Humanoid).action != "talk" and state != "fixed":
			(model as Humanoid).play("talk")
		apply_motion(Vector3.ZERO, delta)
		return
	elif (model as Humanoid).action == "talk":
		(model as Humanoid).play("" if state != "fixed" else ("sit" if role == "prisoner" else "lie"))
	match state:
		"fixed", "dead":
			apply_motion(Vector3.ZERO, delta)
			return
		"downed":
			apply_motion(Vector3.ZERO, delta)
			if state_t > 16.0:
				revive_from_downed()
			return
	if hostile and role == "guard":
		_guard_fight(delta, p, dist)
		return
	# Angst: weglaufen oder kauern
	if fear_t > 0.0 or (hostile_village and dist < 9.0 and role != "guard"):
		if asleep:
			wake_up()
		var away := global_position - (fear_from if fear_t > 0.0 else p)
		away.y = 0
		if role == "child" or dist < 2.5:
			if (model as Humanoid).action != "cower":
				(model as Humanoid).play("cower")
			apply_motion(Vector3.ZERO, delta)
			face_dir(p - global_position, delta)
			return
		if (model as Humanoid).action == "cower":
			(model as Humanoid).play("")
		move = steer(global_position + away.normalized() * 6.0, 5.2, delta)
		face_dir(move, delta)
		apply_motion(move, delta)
		return
	if (model as Humanoid).action == "cower":
		(model as Humanoid).play("")
	# Tagesablauf
	var h := PlayerStats.clock_hour()
	var want := "work"
	if h >= 22 or h < 6:
		want = "fire" if night_owl else "sleep"
	elif h >= 19:
		want = "fire"
	if role == "guard":
		want = "work"
	if want != state and not (state == "sleeping" and want == "sleep"):
		state = want
		state_t = 0.0
		if state == "sleep":
			path = bed_path.duplicate()
		if asleep and want != "sleep":
			wake_up()
	match state:
		"work":
			if global_position.distance_to(wander_target) < 0.8 or state_t > 9.0:
				state_t = 0.0
				wander_target = work_spot + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)) if role != "guard" else work_spot
			if global_position.distance_to(wander_target) > 0.8:
				move = steer(wander_target, 1.4, delta)
		"fire":
			var spot := fire_spot + (global_position - fire_spot).normalized() * 2.6 if fire_spot != Vector3.ZERO else work_spot
			if global_position.distance_to(spot) > 1.0:
				move = steer(spot, 1.6, delta)
				if (model as Humanoid).action == "sit":
					(model as Humanoid).play("")
			elif (model as Humanoid).action != "sit":
				(model as Humanoid).play("sit")
				heading = atan2(-(fire_spot - global_position).x, -(fire_spot - global_position).z)
		"sleep":
			if path.is_empty():
				if not asleep:
					asleep = true
					state = "sleeping"
					if bed_path.size() > 0:
						heading = bed_rot
						global_position = bed_path[-1]
						(model as Humanoid).bed_height = 0.42
					(model as Humanoid).play("sleep")
			else:
				var wp: Vector3 = path[0]
				if global_position.distance_to(wp) < 0.6:
					path.pop_front()
				else:
					move = steer(wp, 1.5, delta)
		"sleeping":
			pass
	# Feststecken auflösen
	if move.length() > 0.1:
		if global_position.distance_to(_last_pos) < delta * 0.3:
			stuck_t += delta
			if stuck_t > 2.0:
				stuck_t = 0.0
				if not path.is_empty():
					global_position = path[0]
				else:
					wander_target = global_position
		else:
			stuck_t = 0.0
	_last_pos = global_position
	if move.length() > 0.05:
		face_dir(move, delta)
	apply_motion(move, delta)

func _guard_fight(delta: float, p: Vector3, dist: float) -> void:
	var to_p := p - global_position
	to_p.y = 0
	face_dir(to_p, delta, 10.0)
	_attack_t -= delta
	var move := Vector3.ZERO
	if _windup:
		if _attack_t <= 0.0:
			_windup = false
			_attack_t = 1.1
			(model as Humanoid).play("attack", randi() % 3)
			if dist < 2.4:
				world.player.receive_hit(14.0 + level * 2.0, global_position)
	elif dist > 1.8:
		move = steer(p, 4.6, delta)
	elif _attack_t <= 0.0:
		_windup = true
		_attack_t = 0.55
		(model as Humanoid).play("windup")
	apply_motion(move, delta)

func time_to_hit(pp: Vector3) -> float:
	if _windup and global_position.distance_to(pp) < 3.2:
		return _attack_t
	return -1.0
