extends Node3D
## Welt-Vorschau: Gelände, Vegetation, Himmel zu verschiedenen Tageszeiten.

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var terrain := Terrain.new()
	add_child(terrain)
	terrain.generate()
	var t1 := Time.get_ticks_msec()
	var veg := Vegetation.new()
	add_child(veg)
	veg.generate(terrain, [[Terrain.VILLAGE, 30.0], [Terrain.BANDITS, 16.0], [Terrain.RUIN, 18.0], [Terrain.TOWER, 12.0]])
	var t2 := Time.get_ticks_msec()
	print("Gelände ", t1 - t0, " ms, Vegetation ", t2 - t1, " ms")
	var dn := DayNight.new()
	add_child(dn)
	var cam := Camera3D.new()
	cam.fov = 60
	cam.far = 400
	add_child(cam)
	dn.follow = cam
	var shots := [
		["w_day_ford", 13.0, Vector3(40, 0, 50), Vector3(70, 0, 30), 3.0],
		["w_day_forest", 15.0, Vector3(-50, 0, 60), Vector3(-80, 0, 110), 2.0],
		["w_dusk_ruin", 19.6, Vector3(-140, 0, -120), Vector3(-170, 0, -160), 6.0],
		["w_night_village", 23.0, Vector3(70, 0, 50), Vector3(98, 0, 28), 4.0],
		["w_night_forest", 0.5, Vector3(-50, 0, 60), Vector3(-80, 0, 110), 2.0],
		["w_day_village", 10.0, Vector3(120, 0, 10), Vector3(98, 0, 28), 3.0],
		["w_overview", 11.0, Vector3(0, 0, 120), Vector3(0, 0, -60), 70.0],
	]
	for s in shots:
		dn.minutes = float(s[1]) * 60.0
		var p: Vector3 = terrain.ground(s[2]) + Vector3(0, float(s[4]), 0)
		var q: Vector3 = terrain.ground(s[3]) + Vector3(0, 2.0, 0)
		cam.global_position = p
		cam.look_at(q)
		for i in 6:
			dn.update(0.016)
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + s[0] + ".png")
	get_tree().quit()
