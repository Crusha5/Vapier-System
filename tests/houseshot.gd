extends Node3D
## Vorschau: ein Haus aus dem Baukasten von vier Seiten.
func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.5, 0.6, 0.7)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	ground.mesh = pm
	add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var h1 := Node3D.new()
	add_child(h1)
	VillageKit.house(h1, 6, 6, "plaster", rng)
	var h2 := Node3D.new()
	h2.position = Vector3(12, 0, 0)
	add_child(h2)
	VillageKit.house(h2, 8, 6, "brick", rng)
	var cam := Camera3D.new()
	add_child(cam)
	var i := 0
	for a in [PI, 0.0, PI * 0.5, PI * 1.25]:
		cam.position = Vector3(6 + sin(a) * 16, 6, cos(a) * 16)
		cam.look_at(Vector3(6, 2, 0))
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/house_%d.png" % i)
		i += 1
	get_tree().quit()
