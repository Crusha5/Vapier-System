extends "res://tests/opentest.gd"
## Schnelle Bildprüfung: Lagerfeuer, Zelte, Tiere, Reißer.
func _ready() -> void:
	shots = OS.get_environment("SHOT_DIR")
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	PlayerStats.s.started = true
	PlayerStats.s.minutes = 22.5 * 60.0
	var c: Vector3 = m.places.spots.bandits
	m.player.global_position = m.terrain.ground(c + Vector3(8, 0, 8)) + Vector3(0, 0.3, 0)
	m.rig.yaw = atan2(8.0, 8.0)
	for e in get_tree().get_nodes_in_group("hostile"):
		e.set_physics_process(false)
	await _frames(25)
	await _shot("v1_camp_night")
	# Tiere
	PlayerStats.s.minutes = 15.0 * 60.0
	var a: Node3D = get_tree().get_nodes_in_group("animals")[0]
	m.player.global_position = a.global_position + Vector3(4, 0.3, 4)
	m.rig.yaw = atan2(4.0, 4.0)
	var w := Enemy.new()
	w.setup("reisser", m, a.global_position + Vector3(-2, 0.3, 2), 2)
	m.add_child(w)
	w.set_physics_process(false)
	await _frames(25)
	await _shot("v2_animals")
	get_tree().quit()
