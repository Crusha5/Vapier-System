extends Node
## Screenshot des Titelbildschirms (SP_TITLE=1 SHOT_DIR=…)

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	for i in 120:
		await get_tree().process_frame
	main._copy_report()
	print(DisplayServer.clipboard_get().substr(0, 600))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/title.png")
	get_tree().quit()
