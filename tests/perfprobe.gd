extends Node
## Misst Draw-Calls und Dreiecke an typischen Orten.
func _ready() -> void:
	var m = load("res://scenes/main.tscn").instantiate()
	add_child(m)
	while m.state == "loading":
		await get_tree().process_frame
	for n in [m.terrain, m.places, m.veg]:
		var c := {}
		for ch in n.get_children():
			c[ch.get_class()] = c.get(ch.get_class(), 0) + 1
		print("TEST ", n.name, " ", c)
	var spots := {"ruin": m.places.spots.ruin_wake, "village": m.places.spots.village + Vector3(0, 0, 8), "forest": m.terrain.ground(Vector3(-60, 0, 80)), "field": m.terrain.ground(Vector3(40, 0, 50))}
	for k in spots:
		m.player.global_position = spots[k] + Vector3(0, 0.3, 0)
		for yaw in [0.0, 1.6, 3.2, 4.8]:
			m.rig.yaw = yaw
			for i in 8:
				await get_tree().process_frame
			var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			var pr := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			var ob := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			print("TEST %s yaw %.1f: draw %d, prims %dk, objs %d" % [k, yaw, dc, pr / 1000, ob])
	print("TEST vram MB ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576)
	get_tree().quit()
