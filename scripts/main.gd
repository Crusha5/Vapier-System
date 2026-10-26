extends Node3D
## Sanguine Protocol – offene Welt Veyra. Baut die Welt, setzt Figuren, verbindet Eingabe, Story,
## Trinken (mit Zeugen), Sonne, Blutsinn, Tod/Wiedererwachen und Effekte.

const H := preload("res://scripts/ui/holo_ui.gd")
const SPLAT := preload("res://shaders/splat.gdshader")
const SENSE := preload("res://shaders/sense.gdshader")

var terrain: Terrain
var places: Places
var veg: Vegetation
var daynight: DayNight
var player: Player
var rig: CameraRig
var hud: Hud
var menu: SystemWindow
var audio: Sfx
var story: Story
var title: Control
var loading: Label
var sense_rect: ColorRect
var state := "loading"     # loading, title, play, talk, dead
var npcs := {}             # id -> HumanNpc
var fx: Array = []
var loot: Array = []
var decals: Array = []
var bolts: Array = []
var heartbeats: Array = []
var sense_on := false
var _sense_amt := 0.0
var interact_id := ""
var interact_target: Node3D
var _slow_until := 0
var _slow_scale := 1.0
var _hitstop_until := 0
var _talk_focus: Variant = null
var _prev_fp := false
var _forced_fp := false
var _model_hidden := false
var death_t := -1.0
var last_zone := ""
var _zone_t := 0.0
var _beast_t := 5.0
var _director_t := 0.0
var _arc_mesh: ArrayMesh
var _ring_mesh: ArrayMesh
var _ribbon_red: ShaderMaterial
var autotest := false
var _new_armed := false
var _last_day := 0

const ZONES := [
	["ruin", "Ruinen der Alten", Vector2(-170, -160), 26.0],
	["village", "Asch-Furt", Vector2(98, 28), 34.0],
	["bandits", "Krähes Lager", Vector2(-96, 138), 22.0],
	["tower", "Wachturm der Wacht", Vector2(212, -92), 24.0],
	["shrine", "Schrein der Ersten Nacht", Vector2(-205, 95), 12.0],
	["lander", "Landerwrack „Hoffnung“", Vector2(150, -175), 14.0],
	["ford", "Die Furt", Vector2(66, 36), 12.0],
	["lake", "Spiegelsee", Vector2(150, 175), 45.0],
]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	autotest = get_parent() != get_tree().root and OS.get_environment("SP_TITLE") != "1"
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui)
	var sense_layer := CanvasLayer.new()
	sense_layer.layer = 4
	add_child(sense_layer)
	sense_rect = ColorRect.new()
	sense_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sense_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	sm.shader = SENSE
	sense_rect.material = sm
	sense_rect.visible = false
	sense_layer.add_child(sense_rect)
	loading = H.lbl("VEYRA WIRD GEFORMT …", 18, H.RED, H.F_BOLD)
	loading.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	loading.grow_horizontal = Control.GROW_DIRECTION_BOTH
	var bg := ColorRect.new()
	bg.color = Color(0.01, 0.01, 0.02)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.name = "LoadBG"
	ui.add_child(bg)
	ui.add_child(loading)
	hud = Hud.new()
	hud.world = self
	hud.title_mode = true
	ui.add_child(hud)
	menu = SystemWindow.new()
	menu.world = self
	menu.visible = false
	ui.add_child(menu)
	menu.closed.connect(toggle_menu)
	hud.menu_pressed.connect(toggle_menu)
	hud.interact_pressed.connect(_interact)
	hud.view_pressed.connect(toggle_view)
	hud.sense_pressed.connect(toggle_sense)
	audio = Sfx.new()
	add_child(audio)
	await get_tree().process_frame
	await get_tree().process_frame
	_build_world()
	bg.queue_free()
	loading.queue_free()
	if autotest:
		state = "play"
		hud.title_mode = false
	else:
		_build_title()

func _build_world() -> void:
	var t0 := Time.get_ticks_msec()
	terrain = Terrain.new()
	add_child(terrain)
	terrain.generate()
	places = Places.new()
	add_child(places)
	places.build(terrain)
	veg = Vegetation.new()
	add_child(veg)
	veg.generate(terrain, places.exclusions())
	daynight = DayNight.new()
	add_child(daynight)
	rig = CameraRig.new()
	add_child(rig)
	player = Player.new()
	player.world = self
	player.rig = rig
	add_child(player)
	rig.target = player
	daynight.follow = player
	player.refresh_weapon()
	story = Story.new()
	story.w = self
	add_child(story)
	_build_fx_assets()
	_spawn_world()
	_place_player()
	PlayerStats.player_died.connect(_on_player_died)
	PlayerStats.leveled_up.connect(func(l):
		burst(player.global_position + Vector3(0, 1, 0), H.GOLD, 2.0)
		hud.show_banner("STUFE %d" % l))
	_last_day = int(PlayerStats.s.day)
	print("Welt fertig in ", Time.get_ticks_msec() - t0, " ms")

func _place_player() -> void:
	var p: Array = PlayerStats.s.get("pos", [])
	if PlayerStats.s.started and p.size() == 3:
		player.global_position = Vector3(p[0], p[1] + 0.3, p[2])
	else:
		player.global_position = places.spots.ruin_wake + Vector3(0, 0.2, 0)
		rig.yaw = PI * 0.8
	rig.global_position = player.global_position + Vector3(0, 1.5, 0)
	rig.set_first_person(PlayerStats.s.get("camera_fp", false))
	player.set_first_person(rig.first_person)

# ---------- Figuren ----------

func _spawn_npc(id: String, name: String, look: Dictionary, at: Vector3, role := "villager", house := -1) -> HumanNpc:
	if PlayerStats.is_dead(id):
		return null
	var n := HumanNpc.new()
	n.setup(id, name, look, self, at + Vector3(0, 0.2, 0), role)
	n.fire_spot = places.spots.fire
	if house >= 0 and house < places.spots.houses.size():
		var hs: Dictionary = places.spots.houses[house]
		n.bed_path = [hs.door_out, hs.door_in, hs.bed]
		n.bed_rot = hs.bed_rot
	add_child(n)
	npcs[id] = n
	return n

func _spawn_world() -> void:
	var sp: Dictionary = places.spots
	_spawn_npc("hanna", "Hanna", Looks.hanna(), sp.npc_elder, "elder", 3)
	var lenz := _spawn_npc("lenz", "Lenz", Looks.village_guard(), sp.npc_guard, "guard")
	if lenz:
		lenz.night_owl = true
	_spawn_npc("greta", "Greta", Looks.innkeeper(), sp.npc_innkeeper, "villager", 1)
	if npcs.has("greta"):
		npcs.greta.night_owl = true
	_spawn_npc("oswin", "Oswin", Looks.smith(), sp.npc_smith, "villager", 6)
	_spawn_npc("pip", "Pip", Looks.child(), sp.npc_child, "child", 5)
	_spawn_npc("mara", "Mara", Looks.widow(), sp.npc_widow, "villager", 4)
	_spawn_npc("hallin", "Bauer Hallin", Looks.settler(5), sp.npc_farmer, "villager", 2)
	_spawn_npc("ilse", "Ilse", Looks.settler(9), sp.village + Vector3(-10, 0, 8), "villager", 0)
	_spawn_npc("bo", "Bo", Looks.settler(14), sp.village + Vector3(10, 0, -8), "villager", 2)
	# Jory im Käfig
	var jf: String = PlayerStats.flag("jory", "")
	if jf == "" or jf == "caged":
		var j := _spawn_npc("jory", "Jory", Looks.jory(), sp.cage, "prisoner")
		if j:
			j.heading = PI * 0.5
	elif jf == "proven":
		_spawn_npc("jory", "Jory", Looks.jory(), sp.village + Vector3(-6, 0, -4), "villager", 0)
	if jf in ["proven", "freed"] and places.cage_door:
		places.cage_door.rotation.y = 1.8
	# Tamas
	var tf: String = PlayerStats.flag("tamas", "")
	if tf == "":
		_spawn_npc("tamas", "Tamas", Looks.tamas(), sp.wounded, "wounded")
	elif tf in ["helped", "sipped"]:
		_spawn_npc("tamas", "Tamas", Looks.tamas(), sp.village + Vector3(4, 0, -6), "villager", 4)
		PlayerStats.set_flag("tamas_arrived")
	elif tf in ["drained", "left"]:
		# Die Leiche liegt am Weg
		var body := _spawn_npc("tamas_body", "Tamas", Looks.tamas(), sp.wounded, "wounded")
		if body:
			body.alive = false
			body.state = "dead"
			(body.model as Humanoid).play("dead")
	# Banditenlager
	var bc: Vector3 = sp.bandits
	var bpos := [Vector3(5, 0, 2), Vector3(-4, 0, 5), Vector3(-5, 0, -3), Vector3(3, 0, -6), Vector3(8, 0, -4)]
	for i in bpos.size():
		var id := "bandit_%d" % i
		if PlayerStats.is_dead(id):
			continue
		var e := Enemy.new()
		e.setup("bandit_archer" if i == 4 else "bandit", self, terrain.ground(bc + bpos[i]) + Vector3(0, 0.3, 0), 2 + (i % 2), id)
		add_child(e)
	if PlayerStats.flag("krahe", "") == "" and not PlayerStats.is_dead("krahe"):
		var k := Enemy.new()
		k.setup("krahe", self, terrain.ground(bc + Vector3(0, 0, -2)) + Vector3(0, 0.3, 0), 4, "krahe")
		add_child(k)
	# Hinterhalt an der Weggabelung (nachts)
	for i in 2:
		var id := "ambush_%d" % i
		if PlayerStats.is_dead(id):
			continue
		var e := Enemy.new()
		e.setup("bandit", self, terrain.ground(Vector3(-40 + i * 3, 0, 52 + i * 2)) + Vector3(0, 0.3, 0), 2, id)
		e.night_only = true
		add_child(e)
	# Wacht am Turm
	for i in 3:
		var id := "tower_%d" % i
		if PlayerStats.is_dead(id):
			continue
		var e := Enemy.new()
		e.setup("wacht", self, terrain.ground(sp.tower + Vector3(-5 + i * 3, 0, 7)) + Vector3(0, 0.3, 0), 5, id)
		add_child(e)
	# Grauläufer-Herden
	for hc in [Vector2(-120, -100), Vector2(-20, -120), Vector2(140, 60), Vector2(30, 160), Vector2(-150, 60)]:
		for k in 4:
			var a := Animal.new()
			a.setup(self, terrain.ground(Vector3(hc.x + randf_range(-6, 6), 0, hc.y + randf_range(-6, 6))) + Vector3(0, 0.3, 0))
			add_child(a)
	# Reißer-Rudel (nachts)
	for pc in [Vector2(-60, 110), Vector2(-150, -40), Vector2(80, -110), Vector2(160, 120)]:
		for k in 2:
			var e := Enemy.new()
			e.setup("reisser", self, terrain.ground(Vector3(pc.x + k * 2.0, 0, pc.y)) + Vector3(0, 0.3, 0), 2 + k)
			e.night_only = true
			add_child(e)

# ---------- Titel ----------

func _build_title() -> void:
	state = "title"
	hud.title_mode = true
	title = Control.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.theme = H.make_theme()
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.get_parent().add_child(title)
	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.02, 0.5)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_child(bg)
	var box := H.hbox(28)
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	title.add_child(box)
	var icon := TextureRect.new()
	icon.texture = load("res://icon.png")
	icon.custom_minimum_size = Vector2(170, 170)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(icon)
	var v := H.vbox(5)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_child(v)
	v.add_child(H.caps("Kolonie Veyra · hinter dem Schleier", H.CYAN, 12))
	var t1 := H.lbl("SANGUINE", 36, H.FG, H.F_BOLD)
	t1.add_theme_color_override("font_outline_color", Color(0.4, 0.0, 0.05))
	t1.add_theme_constant_override("outline_size", 8)
	v.add_child(t1)
	v.add_child(H.lbl("PROTOCOL", 36, H.RED, H.F_BOLD))
	v.add_child(H.lbl("Akt 1 · Die Erste Nacht", 14, H.MUTED, H.F_SEMI))
	if PlayerStats.s.started:
		var b1 := H.btn("Fortsetzen  ·  Tag %d · %s" % [int(PlayerStats.s.day), PlayerStats.tier_name()], func(): _start(false), "BtnRed")
		b1.custom_minimum_size = Vector2(280, 44)
		v.add_child(b1)
	var b2 := H.btn("Neues Spiel", func(): _confirm_new(), "" if PlayerStats.s.started else "BtnRed")
	b2.custom_minimum_size = Vector2(280, 42)
	v.add_child(b2)
	var note := H.wrap("Ein einziger Spielstand. Jede Entscheidung wird sofort gespeichert – es gibt kein Zurück.", 10, Color(H.MUTED, 0.8))
	note.custom_minimum_size = Vector2(280, 0)
	v.add_child(note)
	v.add_child(H.lbl("v0.3.0 · Open-World-Prototyp", 9, Color(H.MUTED, 0.6), H.F_MONO))

func _confirm_new() -> void:
	if PlayerStats.s.started and not _new_armed:
		_new_armed = true
		PlayerStats.system_message.emit("Alles, was du getan hast, geht verloren. Zum Bestätigen erneut tippen.", "warn")
		return
	PlayerStats.delete_save()
	PlayerStats.reset_game()
	get_tree().reload_current_scene()

func _start(fresh: bool) -> void:
	if title:
		title.queue_free()
		title = null
	hud.title_mode = false
	state = "play"
	audio.start_ambient()
	if not PlayerStats.s.started:
		player.model.play("lie")
		story.intro()
	else:
		hud.show_zone("Veyra · Tag %d" % int(PlayerStats.s.day))

func awaken_fx() -> void:
	audio.play("awaken", 0.0, 0.0)
	rig.shake = 1.2
	hud.red_flash = 1.0
	burst(places.spots.ruin_altar + Vector3(0, 1.5, 0), Color(1.0, 0.1, 0.15), 2.5)
	player.model.play("")
	player.refresh_look()

# ---------- Welt-Schnittstelle ----------

func input_locked() -> bool:
	return state != "play" or hud.in_dialog()

func menu_open() -> bool:
	return menu.visible

func active_boss() -> Actor:
	for e in get_tree().get_nodes_in_group("hostile"):
		if e is Enemy and (e as Enemy).is_boss() and (e as Enemy).aggro and (e as Enemy).alive:
			return e
	return null

func sfx(name: String) -> void:
	var vol := {"step": -16.0, "swing": -6.0, "tick": -8.0, "hit": -3.0}.get(name, -4.0) as float
	audio.play(name, vol)

func hitstop(t: float) -> void:
	_hitstop_until = Time.get_ticks_msec() + int(t * 1000.0)

func perfect_dash() -> void:
	_slow_until = Time.get_ticks_msec() + 600
	_slow_scale = 0.3
	hud.perfect_t = 0.9
	audio.play("perfect", -2.0, 0.0)

func veil_touch() -> void:
	if Time.get_ticks_msec() % 4000 < 40:
		PlayerStats.system_message.emit("Der Schleier brennt auf deiner Haut. Weiter geht es nicht.", "warn")
	PlayerStats.damage(0.3, true)

func on_player_hurt(dealt: float) -> void:
	damage_number(player.global_position + Vector3(0, 2.1, 0), dealt, Color(1.0, 0.3, 0.3), false)
	sfx("hurt")
	hud.red_flash = maxf(hud.red_flash, 0.35)

func begin_talk(focus: Variant) -> void:
	if state == "play":
		state = "talk"
	_talk_focus = focus
	player.input_dir = Vector2.ZERO
	if focus is HumanNpc:
		(focus as HumanNpc).talking = true

func end_talk() -> void:
	if _talk_focus is HumanNpc and is_instance_valid(_talk_focus):
		(_talk_focus as HumanNpc).talking = false
	_talk_focus = null
	if state == "talk":
		state = "play"

func toggle_view() -> void:
	rig.set_first_person(not rig.first_person)
	player.set_first_person(rig.first_person)
	PlayerStats.s.camera_fp = rig.first_person
	_forced_fp = false
	sfx("tick")

func toggle_sense() -> void:
	sense_on = not sense_on
	sfx("perfect" if sense_on else "tick")

func toggle_menu() -> void:
	if state == "title" or state == "loading":
		return
	if menu.visible:
		menu.visible = false
		get_tree().paused = false
		PlayerStats.save_game()
	else:
		if hud.in_dialog() or state != "play":
			return
		hud.release_all()
		menu.open()
		get_tree().paused = true
	sfx("tick")

func open_shop() -> void:
	hud.release_all()
	menu.open("shop")
	get_tree().paused = true

func sleep_until(hour: int) -> void:
	state = "talk"
	hud.fade_t = 0.0
	await get_tree().create_timer(0.5, true, false, true).timeout
	var target := float(hour * 60)
	var now := float(PlayerStats.s.minutes)
	var passed := fmod(target - now + 24.0 * 60.0, 24.0 * 60.0)
	if target <= now:
		PlayerStats.s.day = int(PlayerStats.s.day) + 1
	PlayerStats.s.minutes = target
	PlayerStats.heal(9999.0)
	PlayerStats.s.blood = maxf(0.0, float(PlayerStats.s.blood) - PlayerStats.blood_drain() * passed * 0.25)
	_check_events()
	PlayerStats.save_game()
	await get_tree().create_timer(0.5, true, false, true).timeout
	state = "play"
	PlayerStats.system_message.emit("Du hast geschlafen. %s." % PlayerStats.clock_text(), "sys")

func show_chronicle() -> void:
	var lines: Array = []
	for c in PlayerStats.s.choices:
		lines.append(c.text)
	hud.show_chronicle(lines)
	state = "talk"
	await get_tree().create_timer(4.0 + lines.size() * 0.6, true, false, true).timeout
	hud.chronicle_t = -1.0
	state = "play"

# ---------- Trinken ----------

func witnesses(at: Vector3, exclude: Node = null) -> Array:
	var out: Array = []
	for id in npcs:
		var n: HumanNpc = npcs[id]
		if n == exclude or not is_instance_valid(n) or not n.alive or n.asleep or n.downed:
			continue
		if n.global_position.distance_to(at) < 15.0 and n.can_see(at, 15.0, -0.35):
			out.append(n)
	return out

func _feed_prompt(a: Actor) -> void:
	var name := a.display_name
	var lines: Array = []
	var choices: Array = []
	var info := a.feed_info()
	if a is Animal:
		perform_feed(a, "drain", false)
		return
	var wit := witnesses(player.global_position, a)
	var warn := "" if wit.is_empty() else "  %d Zeuge(n) sehen dich!" % wit.size()
	if a is HumanNpc:
		var hn := a as HumanNpc
		if hn.asleep:
			lines.append({"who": "", "text": "%s schläft. Der Herzschlag ist langsam und warm.%s" % [name, warn]})
		elif hn.role == "prisoner":
			lines.append({"who": "", "text": "%s weicht an die Gitter zurück. Er kann nirgendwohin.%s" % [name, warn]})
		elif hn.downed:
			lines.append({"who": "", "text": "%s liegt am Boden und fleht.%s" % [name, warn]})
		else:
			lines.append({"who": "", "text": "%s bemerkt dich. Wenn du jetzt trinkst, wird %s dein Gesicht kennen.%s" % [name, name, warn]})
		choices = ["Nippen – %s überlebt" % name, "[Aussaugen] %s stirbt" % name, "Lass es"]
	else:
		lines.append({"who": "", "text": "%s kniet blutend vor dir.%s" % [name, warn]})
		choices = ["Nippen und laufen lassen", "[Aussaugen]", "Hinrichten", "Lass es"]
	lines.append({"who": "DIE ERSTE NACHT", "text": ["Trink.", "Nimm, was dir zusteht.", "Wer wird es je erfahren?", "Du zitterst. Warum?"][randi() % 4]})
	begin_talk(a if a is HumanNpc else null)
	hud.dialog(lines, choices, func(i):
		end_talk()
		var c: String = choices[i] if i >= 0 else ""
		if c.begins_with("Nippen"):
			perform_feed(a, "sip", false)
		elif c.begins_with("[Aussaugen]"):
			perform_feed(a, "drain", false)
		elif c == "Hinrichten":
			a.die()
			PlayerStats.record_choice("Du hast %s hingerichtet." % name) if a is Enemy and (a as Enemy).is_boss() else null)

func perform_feed(a: Actor, mode: String, scripted: bool) -> void:
	var info := a.feed_info()
	var wit: Array = [] if scripted else witnesses(player.global_position, a)
	state = "talk"
	player.busy = true
	var to := a.global_position - player.global_position
	to.y = 0
	if to.length() > 0.01:
		player.facing = to.normalized()
	player.model.play("feed")
	if a is HumanNpc:
		var hn := a as HumanNpc
		if not hn.asleep and hn.role != "wounded":
			(hn.model as Humanoid).play("kneel")
	audio.play("drink", 0.0, 0.0)
	hud.red_flash = 0.6
	for k in 3:
		await get_tree().create_timer(0.5, true, false, true).timeout
		blood_hit(a, player.global_position, false)
	var gained := PlayerStats.feed(info, mode)
	PlayerStats.system_message.emit("+%d Blut" % int(gained), "blood")
	player.model.play("")
	player.busy = false
	state = "play"
	var aware := a is HumanNpc and (a as HumanNpc).aware_of(player.global_position) and not scripted
	if mode == "drain":
		if a is Animal:
			if a.alive:
				a.die()
			a.set_meta("fed", true)
		else:
			a.die()
			if a is HumanNpc and not scripted and a.npc_id != "jory":
				PlayerStats.record_choice("Du hast %s ausgesaugt." % a.display_name)
	else:
		if a is HumanNpc:
			var hn := a as HumanNpc
			if aware:
				PlayerStats.set_flag("saw_" + hn.npc_id)
				PlayerStats.system_message.emit("%s hat dein Gesicht gesehen." % hn.display_name, "choice")
				hn.frighten(player.global_position)
			elif hn.asleep:
				(hn.model as Humanoid).play("sleep")
				PlayerStats.system_message.emit("%s träumt schlecht – mehr nicht." % hn.display_name, "mini")
		elif a is Enemy:
			(a as Enemy).spare()
	if a.npc_id == "jory":
		story.jory_fed(mode)
	if not wit.is_empty() and a.kind == "human" and (a.faction == "village"):
		_village_alarm("Asch-Furt hat gesehen, was du bist.")

func _village_alarm(text: String) -> void:
	if PlayerStats.flag("village_hostile"):
		return
	PlayerStats.set_flag("village_hostile")
	PlayerStats.record_choice("Asch-Furt hat dich als Blutgeborenen erkannt. Das Dorf ist dir verschlossen.")
	PlayerStats.system_message.emit(text, "warn")
	hud.show_banner("ENTDECKT")
	for id in npcs:
		var n: HumanNpc = npcs[id]
		if is_instance_valid(n) and n.alive:
			n.wake_up()
			n.frighten(player.global_position)

func on_villager_attacked(n: HumanNpc) -> void:
	if not witnesses(player.global_position, n).is_empty() or n.role == "guard":
		_village_alarm("Du hast einen Bewohner von Asch-Furt angegriffen.")

func on_villager_killed(n: HumanNpc) -> void:
	if n.npc_id == "tamas" or n.npc_id == "tamas_body":
		return
	PlayerStats.set_flag("murders", int(PlayerStats.flag("murders", 0)) + 1)
	if n.npc_id == "jory" and PlayerStats.flag("jory", "") == "":
		story.jory_fed("drain")

func on_enemy_downed(e: Enemy) -> void:
	if e.npc_id == "krahe":
		story.krahe_downed(e)

func on_enemy_alerted(e: Enemy) -> void:
	if e.faction == "wacht" and not PlayerStats.flag("wacht_recognized"):
		PlayerStats.set_flag("wacht_recognized")
		story.say([{"who": "Soldat der Wacht", "text": "Halt! … Kael? Du bist tot! Varek hat dich selbst …"},
			{"who": "Soldat der Wacht", "text": "Deserteur! Zu den Waffen!"}], [], Callable())
		PlayerStats.record_choice("Die Wacht hat dich gesehen. Varek wird erfahren, dass du lebst.")

func on_enemy_killed(e: Enemy) -> void:
	var lvl := e.level
	var sh: int = int(e.cfg.get("shards", 2)) + randi() % 3
	PlayerStats.add_shards(sh)
	PlayerStats.register_kill("beast" if e.kind == "beast" else ("wacht" if e.faction == "wacht" else "bandit"), int(e.cfg.xp) + lvl * 4, e.npc_id, e.innocent)
	splat(e.global_position, Color(0.5, 0.02, 0.05) if e.kind == "human" else Color(0.35, 0.1, 0.4), randf_range(1.2, 1.8))
	if e.is_boss():
		_slow_until = Time.get_ticks_msec() + 1200
		_slow_scale = 0.25
		hud.show_banner("%s BESIEGT" % e.display_name.to_upper())
		spawn_loot(Items.random_drop(lvl + 1, 0.15, 2), e.global_position)
	elif randf() < (0.25 if e.kind == "human" else 0.1):
		spawn_loot(Items.random_drop(lvl), e.global_position)
	if e.kind == "beast" and randf() < 0.5:
		PlayerStats.pick_vial("beast")

# ---------- Interaktion ----------

func _set_interact(id: String, text: String, target: Node3D = null, warn := "") -> void:
	interact_id = id
	interact_target = target
	hud.interact_text = text
	hud.interact_warn = warn

func _update_interact() -> void:
	_set_interact("", "")
	if state != "play" or player.dead or player.busy:
		return
	var pp := player.global_position
	var fwd := rig.forward_flat() if rig.first_person else player.facing
	# Trinken / Reden – nächstes Wesen vor dir
	var best: Actor = null
	var bd := 2.4
	for e in get_tree().get_nodes_in_group("living"):
		var a := e as Actor
		if a == null or a._far:
			continue
		var d := a.global_position - pp
		d.y = 0
		var l := d.length()
		if l < bd and (l < 0.9 or fwd.dot(d / l) > 0.2):
			if a.feedable() or (a is HumanNpc and a.alive):
				best = a
				bd = l
	if best:
		if best is HumanNpc:
			var hn := best as HumanNpc
			var can_talk := not hn.asleep and not hn.downed and hn.alive and hn.fear_t <= 0.0
			if hn.role == "wounded" and hn.npc_id == "tamas" and PlayerStats.flag("tamas", "") == "":
				_set_interact("tamas", "VERWUNDETEN ANSPRECHEN", hn)
				return
			if can_talk and hn.role != "wounded":
				var wit := witnesses(pp, hn)
				_set_interact("talk", "MIT %s SPRECHEN" % hn.display_name.to_upper(), hn)
				if not hn.aware_of(pp) or hn.role == "prisoner":
					_set_interact("feed", "TRINKEN", hn, ("%d ZEUGE(N)" % wit.size()) if not wit.is_empty() else "")
					if hn.role == "prisoner":
						_set_interact("talk_or_feed", "MIT JORY SPRECHEN", hn)
				return
			if hn.feedable() and PlayerStats.s.started:
				var wit2 := witnesses(pp, hn)
				_set_interact("feed", "TRINKEN", hn, ("%d ZEUGE(N)" % wit2.size()) if not wit2.is_empty() else ("SCHLÄFT" if hn.asleep else ""))
				return
		elif best.feedable():
			_set_interact("feed", "TRINKEN" if best is Animal else "ÜBERWÄLTIGT", best)
			return
	var sp: Dictionary = places.spots
	if int(PlayerStats.s.story) == 3 and not PlayerStats.flag("jory_resolved") and npcs.has("jory") and is_instance_valid(npcs.jory) and npcs.jory.alive:
		if pp.distance_to(sp.cage + Vector3(1.4, 0, 0)) < 1.6:
			_set_interact("cage", "KÄFIG ÖFFNEN", null, "Lenz sieht zu!" if _guard_watching() else "")
			return
	if pp.distance_to(sp.bandit_chest) < 1.8 and not PlayerStats.flag("chest_open"):
		_set_interact("chest", "TRUHE ÖFFNEN")
		return
	if int(PlayerStats.s.story) == 4 and pp.distance_to(sp.ruin_altar) < 3.0:
		_set_interact("finale", "DAS HERZ BERÜHREN")
		return
	if pp.distance_to(sp.shrine) < 3.0 and not PlayerStats.flag("shrine_read"):
		_set_interact("shrine", "SCHREIN UNTERSUCHEN")
		return
	if pp.distance_to(sp.lander) < 6.0 and not PlayerStats.flag("lander_read"):
		_set_interact("lander", "WRACK DURCHSUCHEN")
		return
	if sp.has("obelisks"):
		for i in (sp.obelisks as Array).size():
			if pp.distance_to(sp.obelisks[i]) < 2.4 and not PlayerStats.flag("obelisk_%d" % i):
				_set_interact("obelisk:%d" % i, "GLYPHEN BERÜHREN")
				return

func _guard_watching() -> bool:
	if not npcs.has("lenz") or not is_instance_valid(npcs.lenz):
		return false
	var l: HumanNpc = npcs.lenz
	return l.alive and not l.asleep and l.can_see(player.global_position, 16.0, -0.4)

func _interact() -> void:
	match interact_id:
		"talk", "talk_or_feed":
			_talk(interact_target as HumanNpc)
		"tamas":
			story.tamas_encounter(interact_target as HumanNpc)
		"feed":
			_feed_prompt(interact_target as Actor)
		"cage":
			try_free_jory()
		"chest":
			PlayerStats.set_flag("chest_open")
			PlayerStats.set_flag("has_amulet")
			PlayerStats.add_shards(45)
			spawn_loot(Items.random_drop(int(PlayerStats.s.level) + 1, 0.1, 1), places.spots.bandit_chest + Vector3(1.2, 0, 0))
			story.say([{"who": "", "text": "Unter gestohlenem Saatgut liegt ein Silberamulett. Eingraviert: „Für Edrik, in Liebe“."}])
			PlayerStats.system_message.emit("Edriks Amulett erhalten.", "reward")
		"finale":
			story.finale()
		"shrine":
			PlayerStats.set_flag("shrine_read")
			PlayerStats.add_xp(80)
			story.say([{"who": "", "text": "In der Opferschale schwimmt frisches Blut. Daneben ein Zeichen: zwei verschlungene Schlangen – rot und schwarz."},
				{"who": "DIE ERSTE NACHT", "text": "Meine Kinder. Sie warten seit Jahrhunderten auf jemanden wie dich. Sie werden dich finden."},
				{"who": "SYSTEM", "text": "Fraktion entdeckt: Der Kult der Ersten Nacht."}])
		"lander":
			PlayerStats.set_flag("lander_read")
			PlayerStats.add_xp(60)
			spawn_loot(Items.random_drop(int(PlayerStats.s.level), 0.1, 1), places.spots.lander + Vector3(2, 0, 2))
			story.say([{"who": "", "text": "Ein Logbuch, halb verbrannt: „Tag 1 nach dem Schleier. Wir versuchen, durchzubrechen. Die Instrumente zeigen … etwas Lebendiges. Es atmet.“"}])
		_:
			if interact_id.begins_with("obelisk:"):
				var i := int(interact_id.substr(8))
				PlayerStats.set_flag("obelisk_%d" % i)
				PlayerStats.add_xp(50)
				var lore := [
					"Die Alten nannten diese Welt nicht Veyra. Sie nannten sie „Wiege“. Und was sie wiegte, schlief.",
					"Fünf Steine. Fünf Wächter. Einer nach dem anderen fiel. Der Schlaf wurde leichter.",
					"Wer von der Ersten Nacht trinkt, bekommt ihre Kraft. Wer zu viel trinkt, wird sie.",
					"Der Schleier ist kein Sturm. Er ist eine Haut. Und darunter wächst etwas.",
					"Die Alten haben die Wiege nicht verlassen. Sie sind noch hier. In jedem Stein. In jedem Tropfen.",
				]
				story.say([{"who": "", "text": "Die Glyphen glühen auf, als du sie berührst."}, {"who": "DIE ERSTE NACHT", "text": lore[i % lore.size()]}])
				hud.red_flash = 0.4

func _talk(n: HumanNpc) -> void:
	if n == null or not is_instance_valid(n):
		return
	match n.npc_id:
		"hanna":
			story.hanna(n)
		"lenz":
			if not PlayerStats.flag("guard_met"):
				story.guard_greet(n)
			else:
				story.generic(n)
		"jory":
			story.jory(n)
		"tamas":
			story.say([{"who": "Tamas", "text": "Danke noch mal, Fremder." if PlayerStats.flag("tamas", "") == "helped" else "Bleib weg von mir! Ich weiß, was du bist!"}], [], Callable(), n)
		"mara":
			story.mara(n)
		"greta":
			story.innkeeper(n)
		"oswin":
			story.smith(n)
		"pip":
			story.child(n)
		_:
			story.generic(n)

func try_free_jory() -> void:
	if _guard_watching():
		PlayerStats.system_message.emit("Lenz sieht dich. Nicht jetzt – warte auf die Nacht oder lenk ihn ab.", "warn")
		return
	if PlayerStats.night < 0.5:
		PlayerStats.system_message.emit("Am helllichten Tag? Zu viele Augen. Komm nachts wieder.", "warn")
		return
	var wit := witnesses(player.global_position, npcs.get("jory"))
	free_jory_npc(true)
	story.jory_freed_secretly()
	if not wit.is_empty():
		_village_alarm("Man hat gesehen, wie du Jory befreit hast.")

func free_jory_npc(flee: bool) -> void:
	if places.cage_door:
		var tw := create_tween()
		tw.tween_property(places.cage_door, "rotation:y", 1.8, 0.6)
		var body := places.cage_door.get_node_or_null("Body")
		if body:
			body.queue_free()
	if npcs.has("jory") and is_instance_valid(npcs.jory):
		var j: HumanNpc = npcs.jory
		j.role = "villager"
		j.state = "work"
		(j.model as Humanoid).play("")
		if flee:
			j.work_spot = terrain.ground(Vector3(-60, 0, 100))
			j.frighten(player.global_position)
			j.fear_t = 30.0
			j.set_meta("leaving", true)
		else:
			j.work_spot = places.spots.village + Vector3(-6, 0, -4)

# ---------- Ablauf ----------

func _process(delta: float) -> void:
	if state == "loading":
		return
	var now := Time.get_ticks_msec()
	var ts := 1.0
	if now < _slow_until:
		ts = _slow_scale
	if death_t >= 0.0:
		ts = minf(ts, 0.4)
	if now < _hitstop_until:
		ts = 0.06
	Engine.time_scale = ts
	var rd := delta / maxf(ts, 0.01)
	PlayerStats.paused_world = state != "play" or player.dead
	daynight.minutes = float(PlayerStats.s.minutes)
	daynight.update(delta)
	PlayerStats.night = daynight.night
	places.tick(delta, daynight.night)
	if state == "title":
		# Kamerafahrt über die Ruine
		var a := Time.get_ticks_msec() * 0.00005
		rig.cutscene = true
		rig.cut_from = places.spots.ruin_altar + Vector3(sin(a) * 16.0, 7.0, cos(a) * 16.0)
		rig.cut_at = places.spots.ruin_altar + Vector3(0, 2.0, 0)
		return
	rig.cutscene = false
	player.input_dir = hud.move_input() if not input_locked() else Vector2.ZERO
	var look := hud.take_look()
	if look != Vector2.ZERO and not input_locked():
		rig.look(look)
	_update_indoor()
	_update_sun(delta)
	_update_sense(delta, rd)
	_update_interact()
	_update_zone(delta)
	_update_compass()
	_update_loot(delta)
	_update_bolts(delta)
	_update_fx(delta, rd)
	_update_decals(delta)
	_director_t -= delta
	if _director_t <= 0.0:
		_director_t = 1.0
		_director()
	if PlayerStats.s.started and Engine.get_frames_drawn() % 30 == 0:
		var p := player.global_position
		PlayerStats.s.pos = [p.x, p.y, p.z]
	if death_t >= 0.0:
		death_t += rd
		if death_t > 3.4:
			_respawn()

func _update_indoor() -> void:
	var inside := false
	var pp := player.global_position
	for hs in places.spots.get("houses", []):
		var r: Array = hs.rect
		var local := (pp - (r[0] as Vector3)).rotated(Vector3.UP, -float(r[1]))
		if absf(local.x) < float(r[2]) * 0.5 and absf(local.z) < float(r[3]) * 0.5:
			inside = true
	if inside and not rig.first_person:
		_forced_fp = true
		rig.set_first_person(true)
		player.set_first_person(true)
	elif not inside and _forced_fp:
		_forced_fp = false
		rig.set_first_person(false)
		player.set_first_person(false)
	player.set_meta("indoor", inside)
	# Kamera klebt an einer Wand: Figur ausblenden statt durch den Kopf zu schauen
	var hide := rig.first_person or (rig.arm.get_hit_length() < 1.1 and not rig.cutscene)
	if hide != _model_hidden:
		_model_hidden = hide
		player.model.set_shadow_only(hide)

func _update_sun(delta: float) -> void:
	var exposure := 0.0
	if daynight.daylight > 0.05 and not player.get_meta("indoor", false) and PlayerStats.s.started and state == "play":
		var sun_dir := -daynight.sun.global_transform.basis.z
		var from := player.global_position + Vector3(0, 1.6, 0)
		var q := PhysicsRayQueryParameters3D.create(from, from - sun_dir * 60.0, 1)
		q.exclude = [player.get_rid()]
		var shaded := not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
		# Baumkronen spenden Schatten (Stämme sind Kollision, Kronen nicht): Wald-Rauschen als Näherung
		var p := player.global_position
		if veg.forest.get_noise_2d(p.x, p.z) > 0.12:
			shaded = true
		exposure = 0.0 if shaded else daynight.daylight
	PlayerStats.in_sun = exposure
	hud.sun_burn = lerpf(hud.sun_burn, exposure * clampf(PlayerStats.sun_dps() / 4.0, 0.15, 1.0), minf(1.0, delta * 3.0))
	if exposure > 0.3 and PlayerStats.sun_dps() > 2.0 and Engine.get_frames_drawn() % 50 == 0:
		burst(player.global_position + Vector3(0, 1.2, 0), Color(1.0, 0.55, 0.2), 0.4)

func _update_sense(delta: float, rd: float) -> void:
	_sense_amt = move_toward(_sense_amt, 1.0 if sense_on else 0.0, rd * 3.0)
	sense_rect.visible = _sense_amt > 0.01
	if sense_rect.visible:
		(sense_rect.material as ShaderMaterial).set_shader_parameter("amount", _sense_amt)
	# Herzschläge als leuchtende Punkte (durch Wände sichtbar)
	if _sense_amt > 0.01:
		var need: Array = []
		for e in get_tree().get_nodes_in_group("living"):
			var a := e as Actor
			if a.alive and a.global_position.distance_to(player.global_position) < 45.0:
				need.append(a)
		while heartbeats.size() < need.size():
			var s := Sprite3D.new()
			var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			for y in 32:
				for x in 32:
					var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
					img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 2))
			s.texture = ImageTexture.create_from_image(img)
			s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			s.no_depth_test = true
			s.shaded = false
			s.pixel_size = 0.05
			s.render_priority = 5
			add_child(s)
			heartbeats.append(s)
		for i in heartbeats.size():
			var s: Sprite3D = heartbeats[i]
			if i < need.size():
				var a: Actor = need[i]
				s.visible = true
				s.global_position = a.global_position + Vector3(0, a._height() * 0.7, 0)
				var beat := 1.0 + 0.35 * maxf(0.0, sin(Time.get_ticks_msec() * 0.008 + i))
				var col := Color(1.0, 0.15, 0.2)
				if a.kind == "animal":
					col = Color(1.0, 0.55, 0.3)
				elif a.kind == "beast":
					col = Color(0.75, 0.3, 1.0)
				elif a is HumanNpc and (a as HumanNpc).asleep:
					col = Color(1.0, 0.85, 0.5)
				s.modulate = Color(col, _sense_amt * 0.9)
				s.scale = Vector3.ONE * beat * (0.8 if a.kind == "animal" else 1.0)
			else:
				s.visible = false
	else:
		for s in heartbeats:
			s.visible = false

func _update_zone(delta: float) -> void:
	_zone_t -= delta
	if _zone_t > 0.0:
		return
	_zone_t = 0.5
	var p := Vector2(player.global_position.x, player.global_position.z)
	var z := ""
	for zn in ZONES:
		if p.distance_to(zn[2]) < float(zn[3]):
			z = zn[0]
			if z != last_zone:
				hud.show_zone(zn[1])
				if PlayerStats.s.started:
					PlayerStats.discover(z, zn[1])
			break
	last_zone = z
	# Story-Auslöser
	var st := int(PlayerStats.s.story)
	if st == 1 and npcs.has("tamas") and is_instance_valid(npcs.tamas) and PlayerStats.flag("tamas", "") == "" and not PlayerStats.flag("tamas_met"):
		if player.global_position.distance_to(npcs.tamas.global_position) < 7.0 and state == "play":
			story.tamas_encounter(npcs.tamas)
	if z == "village" and npcs.has("lenz") and is_instance_valid(npcs.lenz) and not PlayerStats.flag("guard_met") and state == "play" and npcs.lenz.alive:
		if player.global_position.distance_to(npcs.lenz.global_position) < 9.0:
			story.guard_greet(npcs.lenz)

func _update_compass() -> void:
	var marks: Array = []
	var st := int(PlayerStats.s.story)
	var sp: Dictionary = places.spots
	match st:
		1:
			if npcs.has("tamas") and is_instance_valid(npcs.tamas) and PlayerStats.flag("tamas", "") == "":
				marks.append([npcs.tamas.global_position, Color(1.0, 0.8, 0.35), "!"])
		2:
			marks.append([sp.village, Color(1.0, 0.8, 0.35), "ASCH-FURT"])
		3:
			if PlayerStats.flag("has_amulet"):
				marks.append([sp.npc_elder, Color(1.0, 0.8, 0.35), "HANNA"])
			elif PlayerStats.flag("jory_investigate"):
				marks.append([sp.bandits, Color(1.0, 0.4, 0.3), "KRÄHE"])
			else:
				marks.append([sp.cage, Color(1.0, 0.8, 0.35), "JORY"])
		4:
			marks.append([sp.ruin_altar, Color(1.0, 0.2, 0.3), "RUINE"])
	if PlayerStats.flag("cult_lead") and not PlayerStats.flag("shrine_read"):
		marks.append([sp.shrine, Color(0.9, 0.2, 0.3), "SCHREIN"])
	hud.compass_marks = marks

func _director() -> void:
	if not PlayerStats.s.started:
		return
	_check_events()
	# Tamas läuft ins Dorf
	if npcs.has("tamas") and is_instance_valid(npcs.tamas) and npcs.tamas.alive and PlayerStats.flag("tamas", "") in ["helped", "sipped"]:
		if npcs.tamas.global_position.distance_to(places.spots.village) < 30.0 and not PlayerStats.flag("tamas_arrived"):
			PlayerStats.set_flag("tamas_arrived")
	# Jory verlässt die Gegend
	if npcs.has("jory") and is_instance_valid(npcs.jory) and npcs.jory.has_meta("leaving"):
		if npcs.jory.global_position.distance_to(player.global_position) > 70.0:
			npcs.jory.queue_free()
			npcs.erase("jory")

func _check_events() -> void:
	var day := int(PlayerStats.s.day)
	var hour := PlayerStats.clock_hour()
	# Hinrichtung bei Sonnenaufgang
	var dl: Variant = PlayerStats.flag("jory_deadline", -1)
	if int(dl) > 0 and not PlayerStats.flag("jory_resolved") and (day > int(dl) or (day == int(dl) and hour >= 6)):
		if npcs.has("jory") and is_instance_valid(npcs.jory):
			npcs.jory.queue_free()
			npcs.erase("jory")
		story.jory_hanged()
	# Tamas stirbt ohne Hilfe
	if PlayerStats.flag("tamas", "") == "left" and not PlayerStats.is_dead("tamas") and day > _last_day:
		PlayerStats.mark_dead("tamas")
	if day > _last_day:
		_last_day = day
		if PlayerStats.flag("tamas", "") in ["drained", "left"]:
			PlayerStats.set_flag("tamas_found")

# ---------- Tod ----------

func _on_player_died() -> void:
	if player.dead:
		return
	player.die()
	death_t = 0.0
	hud.death_t = 0.0
	state = "dead"
	audio.play("boom", 0.0, 0.0)
	if menu.visible:
		toggle_menu()

func _respawn() -> void:
	death_t = -1.0
	hud.death_t = -1.0
	var s := PlayerStats.s
	s.xp = int(int(s.xp) * 0.8)
	s.hp = PlayerStats.max_hp()
	s.blood = maxf(float(s.blood), 30.0)
	PlayerStats.change_humanity(-1.0, "Die Erste Nacht holt dich zurück")
	player.revive(places.spots.ruin_wake + Vector3(0, 0.3, 0))
	rig.global_position = player.global_position + Vector3(0, 1.5, 0)
	state = "play"
	PlayerStats.system_message.emit("−20 % EXP der aktuellen Stufe.", "sys")
	PlayerStats.save_game()

# ---------- Effekte ----------

func damage_number(pos: Vector3, amount: float, color: Color, crit: bool, text := "") -> void:
	var l := Label3D.new()
	l.text = text if text != "" else str(int(round(amount)))
	if crit and text == "":
		l.text += "!"
	l.font = H.F_BOLD
	l.font_size = 60 if crit else 44
	l.pixel_size = 0.005
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.2, 0.2))
	add_child(l)
	fx.append({"n": l, "t": 0.0, "life": 0.75, "kind": "num", "v": Vector3(0, 2.4, 0)})

func burst(pos: Vector3, color: Color, size := 1.0) -> void:
	var p := CPUParticles3D.new()
	var m := BoxMesh.new()
	m.size = Vector3.ONE * 0.07 * size
	p.mesh = m
	p.material_override = Toon.mat(color, {"emit": color, "energy": 2.5})
	p.amount = int(10 + 6 * size)
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 1.5 * size
	p.initial_velocity_max = 4.5 * size
	p.gravity = Vector3(0, -9.0, 0)
	p.position = pos
	p.emitting = true
	add_child(p)
	fx.append({"n": p, "t": 0.0, "life": 1.0, "kind": "free"})

func blood_hit(a: Node3D, from: Vector3, big: bool) -> void:
	if not is_instance_valid(a):
		return
	var col := Color(0.55, 0.02, 0.05)
	if a is Actor:
		var ac := a as Actor
		if ac.kind == "beast":
			col = Color(0.35, 0.08, 0.4)
		elif ac.kind == "animal":
			col = Color(0.5, 0.05, 0.04)
	var dir := a.global_position - from
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var p := CPUParticles3D.new()
	var m := SphereMesh.new()
	m.radius = 0.04
	m.height = 0.08
	m.radial_segments = 4
	m.rings = 2
	p.mesh = m
	p.material_override = Toon.mat(col, {"rough": 0.3})
	p.amount = 14 if big else 7
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = (dir + Vector3(0, 0.6, 0)).normalized()
	p.spread = 35.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 6.5 if big else 4.0
	p.gravity = Vector3(0, -16.0, 0)
	p.position = a.global_position + Vector3(0, 1.1, 0)
	p.emitting = true
	add_child(p)
	fx.append({"n": p, "t": 0.0, "life": 0.9, "kind": "free"})
	if big or randf() < 0.3:
		splat(a.global_position + dir * randf_range(0.5, 1.2), col, randf_range(0.6, 1.2))

func splat(pos: Vector3, col: Color, size: float) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = SPLAT
	mat.set_shader_parameter("color", Color(col.r, col.g, col.b, 0.85))
	mat.set_shader_parameter("seed", randf() * 100.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var n := terrain.normal_at(pos.x, pos.z)
	mi.basis = Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.RIGHT, -PI * 0.5) * Basis(Vector3.FORWARD, randf() * TAU)
	mi.position = terrain.ground(pos) + n * (0.04 + decals.size() * 0.0005)
	add_child(mi)
	decals.append({"n": mi, "m": mat, "t": 0.0})
	if decals.size() > 40:
		var old: Dictionary = decals.pop_front()
		(old.n as Node).queue_free()

func _update_decals(delta: float) -> void:
	for d in decals:
		d.t += delta
		if float(d.t) > 30.0:
			(d.m as ShaderMaterial).set_shader_parameter("alpha", clampf(1.0 - (float(d.t) - 30.0) / 8.0, 0.0, 1.0))
	while decals.size() > 0 and float(decals[0].t) > 38.0:
		var old: Dictionary = decals.pop_front()
		(old.n as Node).queue_free()

func afterimage(pos: Vector3, rot_y: float) -> void:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = 0.3
	c.height = 1.75
	c.radial_segments = 8
	c.rings = 2
	mi.mesh = c
	mi.material_override = Toon.holo(Color(0.75, 0.05, 0.2), 1.0, false, 0.5).duplicate()
	mi.position = pos + Vector3(0, 0.9, 0)
	mi.rotation.y = rot_y
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	fx.append({"n": mi, "t": 0.0, "life": 0.28, "kind": "fade"})

func _build_fx_assets() -> void:
	_arc_mesh = _make_arc(1.0, 2.4, -1.25, 1.25, 18)
	_ring_mesh = _make_arc(1.2, 2.2, 0.0, TAU, 40)
	_ribbon_red = Toon.holo(Color(1.0, 0.12, 0.2), 2.2, false, 0.0).duplicate()
	_ribbon_red.set_shader_parameter("ribbon", 1.0)

func _make_arc(r0: float, r1: float, a0: float, a1: float, segs: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segs:
		var fa := float(i) / segs
		var fb := float(i + 1) / segs
		var aa := lerpf(a0, a1, fa)
		var ab := lerpf(a0, a1, fb)
		var pa0 := Vector3(sin(aa) * r0, 0, -cos(aa) * r0)
		var pa1 := Vector3(sin(aa) * r1, 0, -cos(aa) * r1)
		var pb0 := Vector3(sin(ab) * r0, 0, -cos(ab) * r0)
		var pb1 := Vector3(sin(ab) * r1, 0, -cos(ab) * r1)
		for q in [[pa0, Vector2(fa, 0)], [pa1, Vector2(fa, 1)], [pb1, Vector2(fb, 1)], [pa0, Vector2(fa, 0)], [pb1, Vector2(fb, 1)], [pb0, Vector2(fb, 0)]]:
			st.set_uv(q[1])
			st.add_vertex(q[0])
	return st.commit()

func slash_fx(pos: Vector3, dir: Vector3, combo: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh if combo == 2 else _arc_mesh
	mi.material_override = _ribbon_red.duplicate()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 1.0 if combo < 2 else 0.3, 0)
	mi.rotation.y = atan2(-dir.x, -dir.z)
	if combo == 1:
		mi.scale = Vector3(-1, 1, 1)
	add_child(mi)
	fx.append({"n": mi, "t": 0.0, "life": 0.18, "kind": "fade"})

func scythe_fx(pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _ring_mesh
	var m := Toon.holo(col, 2.4, false, 0.0).duplicate()
	m.set_shader_parameter("ribbon", 1.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.8, 0)
	mi.scale = Vector3.ONE * 0.4
	add_child(mi)
	fx.append({"n": mi, "t": 0.0, "life": 0.38, "kind": "grow", "to": 1.9, "spin": 14.0})
	burst(pos + Vector3(0, 0.8, 0), col, 1.4)

func spawn_bolt(from: Vector3, to: Vector3, dmg: float) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.04, 0.04, 0.7)
	mi.mesh = b
	mi.material_override = Toon.mat(Color(0.4, 0.3, 0.2))
	mi.position = from
	add_child(mi)
	mi.look_at(to)
	bolts.append({"n": mi, "v": (to - from).normalized() * 26.0, "t": 0.0, "dmg": dmg})
	sfx("swing")

func _update_bolts(delta: float) -> void:
	var keep: Array = []
	var space := get_world_3d().direct_space_state
	for b in bolts:
		var n: Node3D = b.n
		b.t += delta
		var from := n.global_position
		var to: Vector3 = from + b.v * delta
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))
		if (player.global_position + Vector3(0, 1.0, 0)).distance_to(to) < 0.7 and not player.is_invulnerable():
			player.receive_hit(float(b.dmg), from)
			n.queue_free()
			continue
		if not hit.is_empty() or float(b.t) > 1.5:
			n.queue_free()
			continue
		n.global_position = to
		keep.append(b)
	bolts = keep

func spawn_loot(it: Dictionary, pos: Vector3) -> void:
	var n := Node3D.new()
	var col := Items.color(it)
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.1
	cm.height = 3.0 + int(it.rarity) * 0.8
	cm.radial_segments = 8
	cm.rings = 1
	beam.mesh = cm
	beam.material_override = Toon.holo(col, 0.6 + int(it.rarity) * 0.25, false, 0.4)
	beam.position.y = cm.height * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(beam)
	var icon := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(0.12, 0.7, 0.05)
	icon.mesh = pm
	icon.material_override = Toon.mat(col, {"emit": col, "energy": 1.4})
	icon.position.y = 0.75
	icon.name = "Icon"
	n.add_child(icon)
	n.position = terrain.ground(pos + Vector3(randf_range(-0.5, 0.5), 0, randf_range(-0.5, 0.5)))
	add_child(n)
	loot.append({"n": n, "item": it, "t": 0.0})

func _update_loot(delta: float) -> void:
	var keep: Array = []
	for d in loot:
		var n: Node3D = d.n
		d.t += delta
		var icon := n.get_node("Icon") as Node3D
		icon.rotation.y += delta * 2.5
		if float(d.t) > 0.5 and not player.dead and n.global_position.distance_to(player.global_position) < 1.4:
			if PlayerStats.add_item(d.item):
				burst(n.global_position + Vector3(0, 0.8, 0), Items.color(d.item), 0.9)
				sfx("tick")
				n.queue_free()
				continue
			d.t = -3.0
		keep.append(d)
	loot = keep

func _update_fx(delta: float, rd: float) -> void:
	var keep: Array = []
	for f in fx:
		f.t += rd if f.kind == "num" else delta
		var k: float = f.t / f.life
		var n = f.n
		match f.kind:
			"num":
				(n as Node3D).position += (f.v as Vector3) * rd * (1.0 - k)
				(n as Label3D).modulate.a = clampf(1.6 - k * 1.6, 0.0, 1.0)
			"fade":
				Toon.set_alpha(n, 1.0 - k)
			"grow":
				var s: float = lerpf(0.4, float(f.to), 1.0 - pow(1.0 - k, 3.0))
				(n as Node3D).scale = Vector3(s, 1, s)
				(n as Node3D).rotation.y += float(f.spin) * delta
				Toon.set_alpha(n, 1.0 - k * k)
		if k >= 1.0:
			if n != null and is_instance_valid(n):
				(n as Node).queue_free()
			continue
		keep.append(f)
	fx = keep
