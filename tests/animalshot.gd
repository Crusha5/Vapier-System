extends Node3D
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
	add_child(sun)
	var g := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(30, 30)
	g.mesh = pm
	add_child(g)
	var ref := Humanoid.new(Looks.kael())
	ref.position = Vector3(0, 0, 0)
	add_child(ref)
	var a := QuadModel.new("grazer")
	a.position = Vector3(-2.2, 0, 0)
	a.rotation.y = PI * 0.5
	add_child(a)
	var st := QuadModel.new("stag")
	st.position = Vector3(-4.5, 0, 0)
	st.rotation.y = PI * 0.5
	add_child(st)
	var b := QuadModel.new("reisser")
	b.position = Vector3(2.2, 0, 0)
	b.rotation.y = PI * 0.5
	add_child(b)
	for i in 30:
		a.animate(0.016, 1.2)
		b.animate(0.016, 5.5)
		ref.animate(0.016, 0.0)
		await get_tree().process_frame
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.5, 6)
	cam.look_at(Vector3(0, 0.8, 0))
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/animals.png")
	get_tree().quit()
