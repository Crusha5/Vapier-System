extends Node3D
## Posen der neuen Figuren prüfen.
var acts := ["", "talk", "sit", "kneel", "cower", "feed", "lie", "dead", "windup", "attack", "cast", "dash"]
func _ready() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.4, 0.48)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	g.mesh = pm
	add_child(g)
	var hs: Array = []
	for i in acts.size():
		var l: Dictionary = Looks.kael() if i % 2 == 0 else Looks.settler(i * 13)
		var h := Humanoid.new(l)
		h.position = Vector3((i % 6) * 1.6 - 4.0, 0, -int(i / 6) * 2.6)
		add_child(h)
		if i % 2 == 0:
			h.add_blade(Color(0.85, 0.1, 0.12), 0.9)
		var lb := Label3D.new()
		lb.text = acts[i] if acts[i] != "" else "idle"
		lb.font_size = 40
		lb.pixel_size = 0.004
		lb.position = h.position + Vector3(0, 2.1, 0)
		add_child(lb)
		hs.append(h)
	await get_tree().process_frame
	for i in hs.size():
		if acts[i] != "":
			hs[i].play(acts[i], 1)
	for f in 40:
		for i in hs.size():
			hs[i].animate(0.016, 0.0, 0.5 if acts[i] in ["attack", "dash", "cast"] else 0.6)
		await get_tree().process_frame
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 3.2, 6.5)
	cam.look_at(Vector3(0, 0.6, -1.3))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/poses.png")
	get_tree().quit()
