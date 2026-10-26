extends "res://tests/opentest.gd"
## Nebenaufgaben und Akt 2 im Schnelldurchlauf.

func _ready() -> void:
	shots = OS.get_environment("SHOT_DIR")
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	var ps := PlayerStats
	ps.s.started = true
	ps.s.story = 3
	ps.set_flag("guard_met")
	ps.s.minutes = 14.0 * 60.0
	await _frames(10)
	# Hallin: Wölfe
	m.player.global_position = m.places.spots.npc_farmer + Vector3(1.5, 0.3, 0)
	await _frames(10)
	m._talk(m.npcs.hallin)
	await _resolve([0])
	print("TEST wolves stage=", m.quests.stage("wolves"))
	for k in 3:
		var e := Enemy.new()
		e.setup("reisser", m, m.player.global_position + Vector3(4 + k, 0, 4), 1)
		m.add_child(e)
		await _frames(2)
		e.die()
	await _frames(5)
	print("TEST wolves stage nach 3 Kills=", m.quests.stage("wolves"))
	m._talk(m.npcs.hallin)
	await _resolve([])
	print("TEST wolves done=", m.quests.is_done("wolves"))
	# Oswin: Schleierstahl
	m._talk(m.npcs.oswin)
	await _resolve([0])
	m.player.global_position = m.places.spots.lander + Vector3(2, 0.3, 0)
	await _frames(15)
	print("TEST interact am Wrack=", m.interact_id)
	m._interact()
	await _resolve([])
	m.player.global_position = m.places.spots.npc_smith + Vector3(1.5, 0.3, 0)
	await _frames(10)
	m._talk(m.npcs.oswin)
	await _resolve([0])
	print("TEST steel done=", m.quests.is_done("steel"))
	await _shot("q1_steel_reward")
	# Greta: Fleisch
	m._talk(m.npcs.greta)
	await _resolve([0])
	for a in get_tree().get_nodes_in_group("animals").slice(0, 3):
		a.die()
	await _frames(5)
	m._talk(m.npcs.greta)
	await _resolve([])
	print("TEST meat done=", m.quests.is_done("meat"), " room=", ps.flag("greta_room"))
	# Pip nachts
	ps.s.day = 2
	ps.s.minutes = 21.0 * 60.0
	await _frames(5)
	m.player.global_position = m.npcs.mara.global_position + Vector3(1.2, 0.3, 0)
	await _frames(5)
	m._talk(m.npcs.mara)
	await _resolve([0])
	print("TEST pip stage=", m.quests.stage("pip"))
	var pip = m.npcs.pip
	m.player.global_position = pip.global_position + Vector3(1.2, 0.3, 0)
	await _frames(20)
	await _shot("q2_pip_found")
	m._talk(pip)
	await _resolve([])
	print("TEST pip folgt=", pip.follow_target != null)
	m.player.global_position = m.places.spots.village + Vector3(3, 0.3, 3)
	pip.global_position = m.places.spots.village + Vector3(5, 0.3, 3)
	await _frames(80)
	print("TEST pip vor Mara: stage=", m.quests.stage("pip"), " dist=", pip.global_position.distance_to(m.places.spots.village), " folgt=", pip.follow_target != null)
	m._talk(m.npcs.mara)
	await _resolve([])
	print("TEST pip done=", m.quests.is_done("pip"))
	# Akt 2
	ps.s.story = 4
	ps.set_story(5)
	await _frames(70)
	m.player.global_position = m.places.spots.shrine + Vector3(1.5, 0.3, 0)
	await _frames(15)
	print("TEST interact Schrein=", m.interact_id)
	m._interact()
	await _resolve([])
	await _frames(70)
	print("TEST story nach Schrein=", ps.s.story)
	for i in 3:
		ps.set_flag("obelisk_%d" % i)
	m.quests.on_obelisk()
	await _resolve([])
	print("TEST story nach Steinen=", ps.s.story)
	ps.s.minutes = 23.0 * 60.0
	m.player.global_position = m.places.spots.shrine + Vector3(20, 0.3, 0)
	await _frames(90)
	print("TEST kult gespawnt=", m.quests._cult.size())
	m.player.global_position = m.places.spots.shrine + Vector3(3, 0.3, 0)
	await _frames(90)
	await _shot("q3_cult")
	await _resolve([1])
	print("TEST story nach Versammlung=", ps.s.story, " kult=", ps.flag("cult", ""))
	m.player.global_position = m.places.spots.tower + Vector3(0, 0.3, 4.2)
	for e in get_tree().get_nodes_in_group("hostile"):
		if e.faction == "wacht":
			e.die()
	await _frames(20)
	print("TEST interact Turm=", m.interact_id)
	m._interact()
	await _resolve([])
	print("TEST story nach Befehl=", ps.s.story, " burn_day=", ps.flag("burn_day", 0))
	m.player.global_position = m.places.spots.npc_elder + Vector3(1.5, 0.3, 0)
	await _frames(10)
	m._talk(m.npcs.hanna)
	await _resolve([0])
	print("TEST gewarnt=", ps.flag("village_warned"))
	ps.s.day = int(ps.flag("burn_day", 1))
	ps.s.minutes = 22.0 * 60.0 + 5.0
	m.player.global_position = m.places.spots.village + Vector3(-10, 0.3, 0)
	await _frames(90)
	print("TEST raid=", m.quests._raid.size())
	await _shot("q4_raid")
	for e in m.quests._raid:
		if is_instance_valid(e):
			e.die()
	await _frames(90)
	await _resolve([])
	print("TEST story ende=", ps.s.story, " fate=", ps.flag("village_fate", ""))
	await _frames(30)
	m.toggle_menu()
	await _frames(5)
	m.menu.tab = "chronicle"
	m.menu.rebuild()
	await _frames(5)
	await _shot("q5_journal")
	print("TEST fertig")
	get_tree().quit()
