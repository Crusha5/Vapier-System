extends Node3D
## Galerie aller Figuren-Varianten mit Animation.
var names_all := ["male.lod1", "male.skin.light.lod1", "male.outfit.class.rogue.lod1", "male.outfit.class.ranger.lod1", "male.outfit.class.warden.lod1", "male.outfit.class.necromancer.lod1",
	"male.outfit.class.arcanist.lod1", "male.outfit.class.cleric.lod1", "male.outfit.class.druid.lod1", "male.outfit.farmer.lod1", "male.outfit.innkeeper.lod1", "male.outfit.knight.lod1",
	"male.outfit.monk.lod1", "male.outfit.redbrand.lod1", "male.outfit.soldier.lod1", "female.lod1", "female.outfit.tanner.lod1", "female.skin.light.lod1"]
var names: Array = []
func _ready() -> void:
	names = names_all if OS.get_environment("SEL") == "" else Array(OS.get_environment("SEL").split(","))
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.35, 0.4, 0.48)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.55, 0.6)
	var we := WorldEnvironment.new()
	we.environment = e
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.7, 0.5, 0)
	add_child(sun)
	var lib := load("res://assets/chars/anims.res") as AnimationLibrary
	var anim: String = OS.get_environment("ANIM") if OS.get_environment("ANIM") != "" else "Idle"
	for i in names.size():
		var ps := load("res://assets/chars/%s.gltf" % names[i]) as PackedScene
		if ps == null:
			print("TEST fehlt ", names[i])
			continue
		var c := ps.instantiate() as Node3D
		c.position = Vector3((i % 6) * 1.1 - 2.75, 0, -int(i / 6) * 2.2)
		add_child(c)
		var ap := AnimationPlayer.new()
		c.add_child(ap)
		ap.add_animation_library("", lib)
		ap.play(anim)
		ap.seek(0.4 + i * 0.1, true)
		var l := Label3D.new()
		l.text = names[i].replace("male.outfit.", "").replace(".lod1", "")
		l.font_size = 28
		l.pixel_size = 0.004
		l.position = c.position + Vector3(0, 2.05, 0)
		add_child(l)
	var cam := Camera3D.new()
	add_child(cam)
	if names.size() <= 6:
		cam.position = Vector3(0, 1.3, 3.6)
		cam.look_at(Vector3(0, 1.0, 0))
	else:
		cam.position = Vector3(0, 2.6, 5.8)
		cam.look_at(Vector3(0, 0.6, -2.2))
	for i in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OS.get_environment("SHOT_DIR") + "/gallery_%s.png" % anim)
	get_tree().quit()
