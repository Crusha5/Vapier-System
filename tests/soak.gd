extends Node
## Dauerlauf: Titel → neues Spiel → Erwachen, dann warten und Ressourcen beobachten.

var main: Node
var t := 0.0
var next := 0.0

func _ready() -> void:
	PlayerStats.reset_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)

func _process(delta: float) -> void:
	t += delta / maxf(Engine.time_scale, 0.01)
	if t > 3.0 and main.state == "title":
		main._start_game(true)
	if main.hud.narrating():
		main.hud._advance_narration()
	if t > 8.0 and int(PlayerStats.s.story) == 0 and main.state == "play":
		main.player.global_position = Academy.RELIC_POS + Vector3(0, 0, 2.4)
		await get_tree().process_frame
		main._interact()
	if t > next:
		next += 5.0
		print("t=%d fps=%d obj=%d nodes=%d mem=%.1fMB story=%d enemies=%d" % [t, Engine.get_frames_per_second(), Performance.get_monitor(Performance.OBJECT_COUNT), Performance.get_monitor(Performance.OBJECT_NODE_COUNT), OS.get_static_memory_usage() / 1048576.0, PlayerStats.s.story, get_tree().get_nodes_in_group("enemies").size()])
	if t > 70.0:
		get_tree().quit()
