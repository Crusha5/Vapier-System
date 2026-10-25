extends Node
## Kampf-Nahaufnahme: Klingenspur, Blutspritzer, Lachen, Kombo-Zähler.

var main: Node

func _ready() -> void:
	PlayerStats.reset_game()
	PlayerStats.s.awakened = true
	PlayerStats.s.story = 3
	PlayerStats.s.str = 6
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 20:
		await get_tree().process_frame
	main.player.refresh_awakening()
	main.player.global_position = Vector3(44, 0, 4)
	main._cam_focus = main.player.global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	var foes: Array = []
	for p in [Vector3(45.5, 0, 2.6), Vector3(43.0, 0, 2.4), Vector3(46, 0, 4.6)]:
		var e: Enemy = main.spawn_enemy(["karkosa", "mutant", "cadet"][foes.size()], p, 3)
		e.max_hp = 2000.0
		e.hp = 2000.0
		foes.append(e)
	for i in 10:
		await get_tree().process_frame
	var shot := 0
	for k in 14:
		main.player.attack()
		for f in 9:
			await get_tree().physics_frame
		if k == 12:
			await _snap("combat_swing")
	await get_tree().create_timer(0.08).timeout
	await _snap("combat_after")
	get_tree().quit()

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
