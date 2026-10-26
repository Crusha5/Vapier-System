extends Node
## Titel: „Neues Spiel“ ohne Spielstand startet sofort; nach Neustart mit Meta direkt ins Intro.
func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	await _f(10)
	_find_btn(m.title, "Neues Spiel").pressed.emit()
	await _f(30)
	print("TEST ohne Stand: state=", m.state, " in_dialog=", m.hud.in_dialog())
	m.queue_free()
	await _f(2)
	Engine.set_meta("sp_autostart", true)
	m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	await _f(30)
	print("TEST nach Reset: state=", m.state, " title=", m.title, " in_dialog=", m.hud.in_dialog())
	get_tree().quit()

func _f(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _find_btn(n: Node, t: String) -> Button:
	if n is Button and (n as Button).text.begins_with(t):
		return n
	for c in n.get_children():
		var r := _find_btn(c, t)
		if r:
			return r
	return null
