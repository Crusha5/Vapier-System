extends "res://tests/opentest.gd"
## Story-Pfad „gut“: Jory-Beweis über Krähe, Truhe, Hanna, Laden, Finale, Chronik.

func _ready() -> void:
	shots = OS.get_environment("SHOT_DIR")
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	var ps := PlayerStats
	ps.s.minutes = 13.0 * 60.0
	m.story.intro()
	await _resolve([0])
	var t: Node3D = m.npcs.get("tamas")
	m.player.global_position = t.global_position + Vector3(2, 0.3, 2)
	await _frames(40)
	await _resolve([3])
	print("TEST tamas=", ps.flag("tamas", ""))
	# Hanna & Jory
	m.player.global_position = m.places.spots.npc_elder + Vector3(1.5, 0.3, 0)
	await _frames(30)
	await _resolve([0])
	m._talk(m.npcs.hanna)
	await _resolve([1])
	m._talk(m.npcs.jory)
	await _resolve([0])
	print("TEST story=", ps.s.story, " investigate=", ps.flag("jory_investigate"))
	# Laden
	m._talk(m.npcs.oswin)
	await _resolve([1])
	await _frames(10)
	await _shot("s1_shop")
	m.toggle_menu()
	await _frames(5)
	# Banditen
	m.player.global_position = m.terrain.ground(m.places.spots.bandits + Vector3(10, 0, 6)) + Vector3(0, 0.3, 0)
	await _frames(40)
	var guard := 0
	while guard < 400:
		guard += 1
		ps.s.hp = ps.max_hp()
		var left := 0
		for e in get_tree().get_nodes_in_group("hostile"):
			if e is Enemy and e.alive and e.global_position.distance_to(m.player.global_position) < 30.0:
				left += 1
				if not e.downed and m.hud.in_dialog() == false:
					e.take_hit(40.0, m.player.global_position, 2.0, false)
		if m.hud.in_dialog():
			await _shot("s2_krahe")
			await _resolve([0, 0])
		if left == 0:
			break
		await _frames(3)
	print("TEST krahe=", ps.flag("krahe", ""), " confessed=", ps.flag("krahe_confessed"), " cult=", ps.flag("cult_lead"))
	m.player.global_position = m.places.spots.bandit_chest + Vector3(1.0, 0.3, 0)
	await _frames(10)
	print("TEST interact=", m.interact_id)
	m._interact()
	await _resolve([])
	print("TEST amulet=", ps.flag("has_amulet"))
	m.player.global_position = m.places.spots.npc_elder + Vector3(1.5, 0.3, 0)
	await _frames(20)
	m._talk(m.npcs.hanna)
	await _resolve([0])
	print("TEST jory=", ps.flag("jory", ""), " story=", ps.s.story, " hum=", ps.humanity())
	await _frames(30)
	await _shot("s3_jory_free")
	# Schrein
	m.player.global_position = m.places.spots.shrine + Vector3(1.5, 0.3, 0)
	await _frames(15)
	print("TEST interact=", m.interact_id)
	m._interact()
	await _resolve([])
	# Finale
	m.player.global_position = m.places.spots.ruin_altar + Vector3(1.8, 0.3, 0)
	await _frames(15)
	print("TEST interact=", m.interact_id)
	m._interact()
	await _resolve([2])
	await _frames(20)
	await _shot("s4_chronicle")
	print("TEST story=", ps.s.story, " choices=", ps.s.choices.size(), " protocol=", ps.s.protocol)
	for c in ps.s.choices:
		print("TEST  - ", c.text)
	m.toggle_menu()
	await _frames(5)
	m.menu.tab = "chronicle"
	m.menu.rebuild()
	await _frames(5)
	await _shot("s5_menu_chronicle")
	print("TEST fertig")
	get_tree().quit()
