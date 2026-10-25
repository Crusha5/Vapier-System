extends Node
## Automatischer Durchlauf von Kapitel 1 mit Prüfungen und Screenshots.
## Start: godot --path . res://tests/autotest.tscn   (SHOT_DIR=/pfad für Screenshots, SP_FRESH=1)

var main: Node
var errors := 0

func shot(name: String) -> void:
	var dir := OS.get_environment("SHOT_DIR")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		await get_tree().process_frame
	if dir != "" and DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		img.save_png(dir + "/" + name + ".png")
	print("SHOT ", name, " story=", PlayerStats.s.story, " lvl=", PlayerStats.s.level, " hp=", int(PlayerStats.s.hp), " blood=", int(PlayerStats.s.blood))

func wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func check(cond: bool, what: String) -> void:
	if not cond:
		errors += 1
		print("FAIL ", what)
	else:
		print("OK   ", what)

func skip_narration() -> void:
	var guard := 0
	while main.hud.narrating() and guard < 60:
		main.hud._advance_narration()
		guard += 1
	await wait(2)

func place(p: Vector3, face := Vector3(0, 0, -1)) -> void:
	main.player.global_position = p
	main.player.facing = face.normalized()
	main._cam_focus = p
	await wait(8)

## Kampf-Bot: läuft zum nächsten Gegner, schlägt zu, weicht Telegraphs aus
func fight(max_frames: int, cond: Callable) -> int:
	var f := 0
	while f < max_frames and not cond.call():
		var p: Player = main.player
		var t := p._nearest_enemy(40.0)
		if t:
			var d := t.global_position - p.global_position
			d.y = 0
			if t.state == "windup" and t.time_to_hit(p.global_position) >= 0.0 and t.time_to_hit(p.global_position) < 0.3:
				p.input_dir = Vector2(-d.x, -d.z).normalized()
				p.dash()
			elif d.length() > 2.0 + float(t.cfg.radius):
				p.input_dir = Vector2(d.x, d.z).normalized()
			else:
				p.input_dir = Vector2.ZERO
				if f % 40 == 0 and float(PlayerStats.s.blood) > 30:
					p.skill("skill1")
				p.attack()
		if float(PlayerStats.s.blood) < 25 and PlayerStats.capsule_count() > 0:
			p.drink()
		main.hud.stick = p.input_dir
		await get_tree().physics_frame
		f += 1
	main.hud.stick = Vector2.ZERO
	return f

func _ready() -> void:
	PlayerStats.reset_game()
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(40)
	# --- Titelbildschirm (eigene Instanz ohne Autotest-Kennung nicht nötig): Start direkt ---
	main._start_game(true)
	await wait(5)
	await shot("00_intro_narration")
	check(main.hud.narrating(), "Intro-Erzählung läuft")
	await skip_narration()
	check(main.state == "play", "nach Intro spielbar")
	await wait(30)
	await shot("01_archive_start")
	# --- Erwachen ---
	await place(Academy.RELIC_POS + Vector3(0, 0, 2.4))
	await wait(5)
	check(main.interact_id == "awaken", "Relikt kann berührt werden")
	main._interact()
	await wait(20)
	await shot("02_awakening")
	await skip_narration()
	check(PlayerStats.s.awakened, "Sanguine-Protokoll erwacht")
	check(int(PlayerStats.s.story) == 1, "Story-Schritt 1")
	await wait(90)
	await shot("03_karkosa_breach")
	# Spieler etwas stärken, damit der Bot verlässlich durchkommt
	PlayerStats.s.str = 8
	PlayerStats.s.end = 8
	PlayerStats.heal(999)
	var b0 := float(PlayerStats.s.blood)
	var frames := await fight(4000, func(): return int(PlayerStats.s.story) >= 2)
	print("Welle besiegt nach ", frames, " Frames, Kills=", PlayerStats.s.kills)
	check(int(PlayerStats.s.story) == 2, "Karkosa-Welle besiegt → Rangordnung")
	check(float(PlayerStats.s.blood) < b0 + 40.0, "Blut-Anzeige verbraucht sich")
	await shot("04_after_wave")
	check(main.capsules.size() > 0 or PlayerStats.capsule_count() > 0 or int(PlayerStats.s.drunk.karkosa) > 0, "Blut-Essenzen fallen")
	# --- Korridor ---
	await place(Vector3(24, 0, 0), Vector3(1, 0, 0))
	await wait(30)
	await shot("05_corridor")
	# --- Trainingshalle: Drax ---
	await place(Vector3(37, 0, 0), Vector3(1, 0, 0))
	await wait(20)
	check(main.hud.narrating(), "Drax spricht beim Betreten der Halle")
	await shot("06_drax_taunt")
	await skip_narration()
	PlayerStats.s.agi = 8
	frames = await fight(5000, func(): return int(PlayerStats.s.story) >= 3)
	print("Drax nach ", frames, " Frames")
	check(int(PlayerStats.s.story) == 3, "Drax besiegt → Der Riss")
	await shot("07_hall_after")
	# --- Ostflügel: Nest ---
	await place(Vector3(49, 0, -38), Vector3(0, 0, -1))
	await wait(40)
	await shot("08_eastwing_nest")
	PlayerStats.s.str = 14
	frames = await fight(6000, func(): return int(PlayerStats.s.story) >= 4)
	print("Nest nach ", frames, " Frames")
	check(int(PlayerStats.s.story) == 4, "Nest zerstört → Fragen ohne Antwort")
	await shot("09_nest_destroyed")
	# --- Relikt-Gespräch ---
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	await place(Academy.RELIC_POS + Vector3(0, 0, 2.4))
	await wait(5)
	check(main.interact_id == "relic_talk", "Protokoll-Gespräch verfügbar")
	main._interact()
	await skip_narration()
	check(int(PlayerStats.s.story) == 5, "Kapitel 1 abgeschlossen")
	await wait(20)
	await shot("10_chapter_done")
	# --- System-Menü ---
	PlayerStats.s.attr_points = 3
	PlayerStats.s.skill_points = 2
	for tab in ["status", "inventory", "skills", "quests"]:
		main.menu.open(tab)
		get_tree().paused = true
		await wait(6)
		await shot("11_menu_" + tab)
	var before := int(PlayerStats.s.agi)
	PlayerStats.raise_attr("agi")
	check(int(PlayerStats.s.agi) == before + 1, "Attributpunkt verteilt")
	main.toggle_menu()
	await wait(4)
	check(not get_tree().paused, "Menü geschlossen, Spiel läuft")
	# --- Verborgene Quest: Stunde Null ---
	PlayerStats.s.clock = 0.0 * 60.0 + 5.0
	await place(Academy.VAULT_SIGIL + Vector3(0, 0, 1.0), Vector3(0, 0, -1))
	await wait(20)
	await shot("12_vault_midnight")
	await skip_narration()
	check(PlayerStats.has_skill("eclipse"), "Verborgener Skill Eklipse erhalten")
	# --- Eklipse + Perfekter Dash ---
	await place(Vector3(49, 0, 2), Vector3(0, 0, -1))
	var k: Enemy = main.spawn_enemy("karkosa", Vector3(49, 0, -0.5), 1)
	k.aggro = true
	var waited := 0
	while k.state != "windup" and waited < 300:
		await get_tree().physics_frame
		waited += 1
	while k.state == "windup" and k.time_to_hit(main.player.global_position) > 0.25:
		await get_tree().physics_frame
	var pd := int(PlayerStats.s.perfect_dashes)
	main.player.dash()
	check(int(PlayerStats.s.perfect_dashes) == pd + 1, "Perfekter Dash erkannt")
	await wait(3)
	await shot("13_perfect_dash")
	await wait(40)
	PlayerStats.s.blood = 80.0
	main.player.skill("skill3")
	await wait(20)
	check(main.eclipse_active(), "Eklipse aktiv")
	await shot("14_eclipse")
	# --- Hunger & Tod ---
	PlayerStats.s.blood = 0.0
	await wait(30)
	check(PlayerStats.starving(), "Blutmangel aktiv")
	await shot("15_starving")
	PlayerStats.damage(9999, true)
	await wait(20)
	await shot("16_death")
	await get_tree().create_timer(4.0, true, false, true).timeout
	await wait(5)
	check(not main.player.dead, "Wiederbelebung am Relikt")
	# --- Speichern & Laden ---
	PlayerStats.save_game()
	var lvl := int(PlayerStats.s.level)
	PlayerStats.load_game()
	check(int(PlayerStats.s.level) == lvl and PlayerStats.has_skill("eclipse"), "Spielstand geladen")
	print("Tägliche Quests: ", PlayerStats.s.daily)
	print("FERTIG – Fehler: ", errors)
	get_tree().quit(errors)
