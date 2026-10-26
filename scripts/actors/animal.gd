class_name Animal
extends Actor
## Grauläufer: scheue Weidetiere. Grasen, fliehen vor dem Spieler (nachts und geduckt näher heran),
## liegen nachts. Beute für den, der kein Menschenblut will.

var state := "graze"
var state_t := 0.0
var wander_target := Vector3.ZERO
var herd_center := Vector3.ZERO

func setup(w: Node, at: Vector3) -> Animal:
	world = w
	kind = "animal"
	faction = "wild"
	innocent = true
	display_name = "Grauläufer"
	max_hp = 26.0
	hp = max_hp
	position = at
	herd_center = at
	wander_target = at
	radius = 0.45
	return self

func _build_model() -> void:
	model = QuadModel.new("stag" if randf() < 0.25 else "grazer")

func _height() -> float:
	return 1.3

func _ready() -> void:
	super._ready()
	add_to_group("hittable")
	add_to_group("animals")

func die() -> void:
	var was := alive
	super.die()
	if was and world and world.has_method("on_animal_killed"):
		world.on_animal_killed(self)

func feedable() -> bool:
	return (not alive and last_hit_t < 40.0) or (alive and asleep)

func _on_hit(from: Vector3) -> void:
	frighten(from)
	if asleep:
		asleep = false
		(model as QuadModel).play("")

func _think(delta: float, dist: float) -> void:
	if not alive:
		apply_motion(Vector3.ZERO, delta)
		return
	state_t += delta
	var p: Vector3 = world.player.global_position
	var move := Vector3.ZERO
	var night: float = PlayerStats.night
	var notice := lerpf(13.0, 5.0, night)
	var q := model as QuadModel
	if night > 0.7 and fear_t <= 0.0 and dist > notice:
		if not asleep and state_t > 3.0:
			asleep = true
			q.play("lie")
		apply_motion(Vector3.ZERO, delta)
		return
	if asleep and (night < 0.6 or dist < 2.2):
		asleep = false
		q.play("")
		if dist < 2.2:
			frighten(p)
	if dist < notice and fear_t <= 0.0:
		frighten(p)
	if fear_t > 0.0:
		var away := global_position - fear_from
		away.y = 0
		move = steer(global_position + away.normalized() * 8.0, 7.0, delta)
		if q.action == "graze":
			q.play("")
	else:
		if global_position.distance_to(wander_target) < 0.8 or state_t > 10.0:
			state_t = 0.0
			wander_target = herd_center + Vector3(randf_range(-8, 8), 0, randf_range(-8, 8))
			if randf() < 0.6:
				q.play("graze")
		if q.action != "graze":
			move = steer(wander_target, 1.2, delta)
	if move.length() > 0.05:
		face_dir(move, delta)
	apply_motion(move, delta)
