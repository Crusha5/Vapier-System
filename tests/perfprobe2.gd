extends Node
func _m() -> String:
	for i in 6:
		await get_tree().process_frame
	return "draw %d prims %dk objs %d" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)]
func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	m.player.global_position = m.places.spots.village + Vector3(0, 0.3, 8)
	m.rig.yaw = 1.6
	print("TEST all ", await _m())
	m.daynight.sun.shadow_enabled = false
	print("TEST no shadow ", await _m())
	m.veg.visible = false
	print("TEST no veg ", await _m())
	m.places.visible = false
	print("TEST no places ", await _m())
	m.terrain.visible = false
	print("TEST no terrain ", await _m())
	get_tree().quit()
