class_name Actor
extends CharacterBody3D
## Basis für alle Lebewesen in Veyra: Gesundheit, Treffer, Schwerkraft im Gelände, einfache Steuerung
## mit Hindernis-Ausweichen, Sichtprüfung, Schlafmodus weit weg vom Spieler.

signal died(actor: Actor)

var world: Node
var model: Node3D
var npc_id := ""
var display_name := "?"
var kind := "human"          # human, beast, animal
var faction := "neutral"     # village, bandit, wacht, wild, cult
var innocent := true
var hp := 50.0
var max_hp := 50.0
var alive := true
var downed := false
var asleep := false
var fear_t := 0.0
var fear_from := Vector3.ZERO
var flash := 0.0
var knock := Vector3.ZERO
var home := Vector3.ZERO
var radius := 0.45
var last_hit_t := 99.0
var _avoid := Vector3.ZERO
var _avoid_t := 0.0
var _far := false
var _anim_speed := 0.0
var heading := 0.0
var level := 1
var stuck_t := 0.0
var _last_pos := Vector3.ZERO

const GRAVITY := 22.0

func _ready() -> void:
	add_to_group("living")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(55)
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = radius
	sh.height = _height()
	cs.shape = sh
	cs.position.y = sh.height * 0.5
	add_child(cs)
	_build_model()
	if model:
		add_child(model)
	home = global_position
	_last_pos = global_position
	_apply_vis_range.call_deferred(self)

## Ferne Figuren nicht zeichnen (spart auf dem Handy viele Draw-Calls)
func _apply_vis_range(n: Node) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		g.visibility_range_end = 75.0
		g.visibility_range_end_margin = 5.0
	for c in n.get_children():
		_apply_vis_range(c)

func _height() -> float:
	return 1.75

func _build_model() -> void:
	pass

func is_alive() -> bool:
	return alive

func feedable() -> bool:
	return false

func feed_info() -> Dictionary:
	return {"id": npc_id, "kind": kind, "innocent": innocent, "name": display_name}

## Kann dieses Wesen den Spieler sehen? (Entfernung, Blickwinkel, Sichtlinie)
func can_see(p: Vector3, max_d := 16.0, fov_dot := -0.2) -> bool:
	if not alive or asleep or downed:
		return false
	var d := p - global_position
	d.y = 0
	var l := d.length()
	if l > max_d:
		return false
	var night: float = PlayerStats.night
	if night > 0.6 and l > max_d * 0.55:
		return false
	var fwd := Vector3(-sin(heading), 0, -cos(heading))
	if l > 2.0 and fwd.dot(d / l) < fov_dot:
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.5, 0), p + Vector3(0, 1.4, 0), 1)
	return space.intersect_ray(q).is_empty()

func take_hit(amount: float, from: Vector3, knockback := 4.0, crit := false) -> void:
	if not alive:
		return
	hp -= amount
	flash = 1.0
	last_hit_t = 0.0
	world.damage_number(global_position + Vector3(0, _height() + 0.3, 0), amount, Color(1.0, 0.85, 0.3) if crit else Color(1, 1, 1), crit)
	var d := global_position - from
	d.y = 0
	if d.length() > 0.01:
		knock = d.normalized() * knockback
	_on_hit(from)
	if hp <= 0.0:
		hp = 0.0
		_on_zero_hp()

func _on_hit(_from: Vector3) -> void:
	pass

func _on_zero_hp() -> void:
	die()

func die() -> void:
	if not alive:
		return
	alive = false
	downed = false
	remove_from_group("hostile")
	remove_from_group("hittable")
	collision_layer = 0
	if model is Humanoid:
		(model as Humanoid).play("dead")
	elif model and model.has_method("play"):
		model.play("dead")
	if npc_id != "":
		PlayerStats.mark_dead(npc_id)
	died.emit(self)

func frighten(from: Vector3) -> void:
	fear_t = 6.0
	fear_from = from

## Bewegung Richtung Ziel mit einfachem Ausweichen. Gibt die horizontale Geschwindigkeit zurück.
func steer(target: Vector3, speed: float, delta: float) -> Vector3:
	var d := target - global_position
	d.y = 0
	if d.length() < 0.3:
		return Vector3.ZERO
	var dir := d.normalized()
	_avoid_t -= delta
	if _avoid_t <= 0.0:
		_avoid_t = 0.25
		_avoid = Vector3.ZERO
		var space := get_world_3d().direct_space_state
		var from := global_position + Vector3(0, 0.8, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * 2.2, 1)
		q.exclude = [get_rid()]
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and absf((hit.normal as Vector3).y) < 0.6:
			var side := dir.cross(Vector3.UP)
			# Seite wählen, die frei ist
			var ql := PhysicsRayQueryParameters3D.create(from, from + (dir + side).normalized() * 2.2, 1)
			ql.exclude = [get_rid()]
			_avoid = side if space.intersect_ray(ql).is_empty() else -side
	if _avoid != Vector3.ZERO:
		dir = (dir + _avoid * 1.4).normalized()
	return dir * speed

func face_dir(dir: Vector3, delta: float, rate := 8.0) -> void:
	if dir.length() < 0.01:
		return
	heading = lerp_angle(heading, atan2(-dir.x, -dir.z), clampf(delta * rate, 0.0, 1.0))

func apply_motion(horizontal: Vector3, delta: float) -> void:
	var vy := velocity.y
	if is_on_floor():
		vy = -1.0
	else:
		vy -= GRAVITY * delta
	velocity = Vector3(horizontal.x + knock.x, vy, horizontal.z + knock.z)
	knock = knock.move_toward(Vector3.ZERO, delta * 25.0)
	move_and_slide()
	# nicht durch den Boden fallen
	var gh: float = world.terrain.height_at(global_position.x, global_position.z)
	if global_position.y < gh - 2.0:
		global_position.y = gh + 0.3
	# Wasser meiden: zurück
	if gh < -0.9 and kind != "beast":
		global_position -= horizontal.normalized() * 0.15 if horizontal.length() > 0.01 else Vector3.ZERO
	_anim_speed = Vector2(velocity.x, velocity.z).length()

func _physics_process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var dist: float = global_position.distance_to(world.player.global_position)
	_far = dist > 110.0
	if _far and alive:
		return
	last_hit_t += delta
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 5.0)
		Toon.set_overlay(model, Color(1, 0.95, 0.95), flash)
	if fear_t > 0.0:
		fear_t -= delta
	_think(delta, dist)
	if model:
		model.rotation.y = heading
		if dist < 60.0:
			_animate(delta)

func _think(_delta: float, _dist: float) -> void:
	pass

func _animate(delta: float) -> void:
	if model is Humanoid:
		(model as Humanoid).animate(delta, _anim_speed)
	elif model and model.has_method("animate"):
		model.animate(delta, _anim_speed)
