extends Node
## Bilder der neuen Orte und Menüs (v0.7)
var m: Node
var shots := ""

func _ready() -> void:
	shots = OS.get_environment("SHOT_DIR")
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	var ps := PlayerStats
	ps.s.started = true
	ps.s.minutes = 12.0 * 60.0
	ps.s.humanity = 90.0
	for z in ["mill", "hut", "barrow", "morrow", "village", "ruin", "den1", "altar2"]:
		ps.discover(z, z)
	ps.s.crystals = [5, 3, 1, 0]
	ps.s.shards = 600
	var sp: Dictionary = m.places.spots
	var views := [["s_mill", sp.mill + Vector3(14, 0, -6), -1.0], ["s_hut", sp.hut + Vector3(-4, 0, -11), 2.8], ["s_barrow", sp.barrow + Vector3(2, 0, 20), 0.0],
		["s_morrow", sp.morrow + Vector3(-4, 0, -20), PI], ["s_den", sp.dens[1] + Vector3(0, 0, 10), 0.0]]
	for v in views:
		m.player.global_position = m.terrain.ground(v[1]) + Vector3(0, 0.4, 0)
		m.rig.yaw = v[2]
		await _frames(45)
		await _shot(v[0])
	# Blutgebundene Truhe mit Blutsinn
	for o in m.treasure.objs:
		if o.kind == "versteckt":
			m.player.global_position = (o.pos as Vector3) + Vector3(0, 0.4, 3.0).rotated(Vector3.UP, float(o.rot))
			m.rig.yaw = float(o.rot)
			m.toggle_sense()
			await _frames(40)
			await _shot("s_hidden")
			m.toggle_sense()
			break
	m.toggle_menu()
	m.menu.tab = "world"
	m.menu.rebuild()
	await _frames(10)
	await _shot("s_world_tab")
	m.menu.scroll.scroll_vertical = 600
	await _frames(5)
	await _shot("s_world_tab2")
	m.menu.open("shop")
	await _frames(5)
	m.menu.scroll.scroll_vertical = 500
	await _frames(5)
	await _shot("s_shop")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _shot(name: String) -> void:
	if shots == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(shots + "/" + name + ".png")
