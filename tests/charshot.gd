extends Node3D
## Figuren-Schaufenster: Spieler, Kadett, Drax, Varek (+ Karkosa, Mutant) in Ruhe, Lauf- und Angriffspose.

var figs: Array = []
var cam: Camera3D

func _ready() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.31, 0.4)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.7
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.light_color = Color(0.78, 0.82, 1.0)
	sun.shadow_enabled = true
	add_child(sun)
	var l := OmniLight3D.new()
	l.position = Vector3(-3, 2.5, 2)
	l.light_color = Color(1.0, 0.25, 0.3)
	l.omni_range = 8
	l.light_energy = 1.5
	add_child(l)
	var l2 := OmniLight3D.new()
	l2.position = Vector3(3, 2.5, 2)
	l2.light_color = Color(0.3, 0.85, 1.0)
	l2.omni_range = 8
	l2.light_energy = 1.5
	add_child(l2)
	Toon.box(self, Vector3(20, 0.2, 20), Vector3(0, -0.1, 0), Toon.mat(Color(0.27, 0.27, 0.3), {"tiles": 0.5}))
	var looks := [Looks.player(), Looks.cadet(0), Looks.cadet(3), Looks.drax(), Looks.instructor()]
	for i in looks.size():
		var h := Humanoid.new(looks[i])
		h.position = Vector3(-3.2 + i * 1.6, 0, 0)
		h.rotation.y = PI
		add_child(h)
		h.add_blade([Toon.RED, Color(0.3, 0.7, 1.0), Color(0.3, 0.7, 1.0), Color(1.0, 0.75, 0.2), Color(1.0, 0.85, 0.35)][i], [0.95, 0.7, 0.7, 1.05, 1.2][i])
		if i == 0:
			h.set_eye_glow(Color(1.0, 0.1, 0.15), 3.0)
		figs.append(h)
	var mu := Humanoid.new(Looks.mutant())
	mu.lean = 0.55
	mu.weapon_pose = false
	mu.position = Vector3(3.0, 0, -2.4)
	mu.rotation.y = PI * 0.85
	add_child(mu)
	figs.append(mu)
	for k in ["karkosa", "karkosa_elite"]:
		var c := CreatureModel.new(k)
		c.position = Vector3(-2.5 + ["karkosa", "karkosa_elite"].find(k) * 2.6, 0, -2.6)
		c.rotation.y = PI * 0.85
		add_child(c)
		figs.append(c)
	cam = Camera3D.new()
	cam.fov = 40
	add_child(cam)
	cam.position = Vector3(0, 1.6, 6.2)
	cam.look_at(Vector3(0, 0.9, -0.6))
	await _run("idle", 0.0, "", 40)
	await _snap("char_idle")
	cam.position = Vector3(-2.4, 1.5, 2.2)
	cam.look_at(Vector3(-2.4, 1.1, 0))
	await _snap("char_player_close")
	cam.position = Vector3(0, 1.6, 6.2)
	cam.look_at(Vector3(0, 0.9, -0.6))
	await _run("run", 5.0, "", 23)
	await _snap("char_run")
	for f in figs:
		if f is Humanoid:
			f.play("attack", 0)
		else:
			f.play("windup")
	await _run("atk", 0.0, "", 7)
	await _snap("char_attack")
	# Spielperspektive
	cam.position = Vector3(0, 10.4 * 0.55, 7.3 * 0.55)
	cam.look_at(Vector3(0, 0.6, -0.5))
	cam.fov = 46
	await _run("run2", 5.0, "", 10)
	await _snap("char_gamecam")
	get_tree().quit()

func _run(_n: String, speed: float, _a: String, frames: int) -> void:
	for i in frames:
		for f in figs:
			f.animate(1.0 / 30.0, speed)
		await get_tree().process_frame

func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
