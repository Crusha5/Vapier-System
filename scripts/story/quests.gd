class_name Quests
extends Node
## Nebenaufgaben in und um Asch-Furt sowie Akt 2 „Die Kinder der Nacht“.
## Zustand liegt in PlayerStats.s.quests: id -> {stage, count, done, failed}. Main ruft die Haken auf.

const N := "DIE ERSTE NACHT"
const S := "SYSTEM"

## Anzeige im Tagebuch: Titel, Auftraggeber, Text je Stufe
const DEFS := {
	"wolves": {"title": "Wölfe im Dunkeln", "giver": "Bauer Hallin", "goal": 3, "stages": [
		"Reißer jagen nachts am Waldrand westlich und nördlich des Dorfes. Erlege drei von ihnen.",
		"Die Reißer sind tot. Kehre zu Bauer Hallin zurück."]},
	"meat": {"title": "Wild für die Furt", "giver": "Greta", "goal": 3, "stages": [
		"Erlege drei Grauläufer für Gretas Küche. Sie grasen auf den Wiesen rund um das Dorf.",
		"Bring Greta das Fleisch."]},
	"steel": {"title": "Schleierstahl", "giver": "Schmied Oswin", "stages": [
		"Im Landerwrack „Hoffnung“ im Nordosten soll noch Schleierstahl liegen. Birg ihn.",
		"Bring Oswin den Schleierstahl – oder behalte ihn."]},
	"pip": {"title": "Pip ist verschwunden", "giver": "Mara", "stages": [
		"Pip ist nachts zu den roten Steinen nordwestlich des Dorfes gelaufen. Finde ihn, bevor die Reißer es tun.",
		"Bring Pip sicher nach Asch-Furt zurück.",
		"Pip ist zu Hause. Sprich mit Mara."]},
	"ring": {"title": "Ein Ring für Mara", "giver": "Mara", "stages": [
		"Tamas' Ehering fehlt. Er muss noch bei seinem Leichnam am Weg nahe der Ruine liegen.",
		"Bring Mara den Ring. Was du ihr sagst, entscheidest du."]},
	"ambush": {"title": "Die Weggabelung", "giver": "Lenz", "goal": 2, "stages": [
		"Nachts lauern zwei Banditen an der Weggabelung westlich des Dorfes. Mach den Weg wieder sicher.",
		"Die Weggabelung ist frei. Melde dich bei Lenz."]},
}

var w: Node   # main
var _cult: Array = []
var _raid: Array = []
var _cult_met := false

func q(id: String) -> Dictionary:
	var all: Dictionary = PlayerStats.s.get("quests", {})
	return all.get(id, {})

func stage(id: String) -> int:
	var d := q(id)
	if d.is_empty() or d.get("done", false) or d.get("failed", false):
		return -1
	return int(d.get("stage", 0))

func is_done(id: String) -> bool:
	return q(id).get("done", false)

func started(id: String) -> bool:
	return not q(id).is_empty()

func _store(id: String, d: Dictionary) -> void:
	if not PlayerStats.s.has("quests"):
		PlayerStats.s.quests = {}
	PlayerStats.s.quests[id] = d
	PlayerStats.quests_changed.emit()
	PlayerStats.save_game()

func start(id: String) -> void:
	_store(id, {"stage": 0, "count": 0, "done": false, "failed": false})
	PlayerStats.system_message.emit("Neue Aufgabe: %s" % DEFS[id].title, "quest")

func advance(id: String) -> void:
	var d := q(id).duplicate()
	d.stage = int(d.get("stage", 0)) + 1
	_store(id, d)
	PlayerStats.system_message.emit("%s: %s" % [DEFS[id].title, DEFS[id].stages[mini(int(d.stage), DEFS[id].stages.size() - 1)]], "quest")

func complete(id: String, xp: int, shards: int) -> void:
	var d := q(id).duplicate()
	d.done = true
	_store(id, d)
	PlayerStats.add_xp(xp)
	if shards > 0:
		PlayerStats.add_shards(shards)
	PlayerStats.system_message.emit("Aufgabe erledigt: %s" % DEFS[id].title, "reward")
	w.hud.show_banner("AUFGABE ERLEDIGT")

func fail(id: String, text: String) -> void:
	var d := q(id).duplicate()
	d.failed = true
	_store(id, d)
	PlayerStats.system_message.emit("Aufgabe gescheitert: %s" % DEFS[id].title, "warn")
	PlayerStats.record_choice(text)

func _count(id: String) -> void:
	var d := q(id).duplicate()
	d.count = int(d.get("count", 0)) + 1
	_store(id, d)
	var goal: int = DEFS[id].get("goal", 1)
	PlayerStats.system_message.emit("%s  %d/%d" % [DEFS[id].title, int(d.count), goal], "mini")
	if int(d.count) >= goal:
		advance(id)

func say(lines: Array, choices: Array = [], cb: Callable = Callable(), focus: Variant = null) -> void:
	w.story.say(lines, choices, cb, focus)

func hostile_village() -> bool:
	return PlayerStats.flag("village_hostile")

## Liste fürs Tagebuch: [{title, giver, text, state}]
func journal() -> Array:
	var out: Array = []
	for id in DEFS:
		var d := q(id)
		if d.is_empty():
			continue
		var st := "aktiv"
		if d.get("done", false):
			st = "erledigt"
		elif d.get("failed", false):
			st = "gescheitert"
		var stages: Array = DEFS[id].stages
		var txt: String = stages[mini(int(d.get("stage", 0)), stages.size() - 1)]
		if DEFS[id].has("goal") and int(d.get("stage", 0)) == 0 and st == "aktiv":
			txt += "  (%d/%d)" % [int(d.get("count", 0)), int(DEFS[id].goal)]
		out.append({"title": DEFS[id].title, "giver": DEFS[id].giver, "text": txt, "state": st})
	return out

# ---------- Gespräche (true = übernommen) ----------

func talk(n: HumanNpc) -> bool:
	if not PlayerStats.s.started:
		return false
	match n.npc_id:
		"hallin":
			return _talk_hallin(n)
		"greta":
			return _talk_greta(n)
		"oswin":
			return _talk_oswin(n)
		"mara":
			return _talk_mara(n)
		"lenz":
			return _talk_lenz(n)
		"pip":
			return _talk_pip(n)
	return false

func _talk_hallin(n: HumanNpc) -> bool:
	if hostile_village():
		return false
	if not started("wolves") and not PlayerStats.flag("q_declined_wolves"):
		say([{"who": "Bauer Hallin", "text": "Du siehst aus, als könntest du mit einer Klinge umgehen. Die Reißer holen sich jede Nacht einen meiner Grauläufer."},
			{"who": "Bauer Hallin", "text": "Drei der Biester streifen am Waldrand westlich und nördlich von hier. Nur nachts. Ich kann dir nicht viel zahlen – aber was ich habe, gehört dir."}],
			["Ich kümmere mich darum.", "Nicht jetzt."], _accept.bind("wolves"), n)
		return true
	if stage("wolves") == 1:
		complete("wolves", 140, 70)
		w.spawn_loot(Items.random_drop(int(PlayerStats.s.level) + 1, 0.1, 1), n.global_position + Vector3(1, 0, 1))
		say([{"who": "Bauer Hallin", "text": "Drei Reißer? Allein? Bei den Sternen … Die Herde ist sicher. Hier – Splitter und was der letzte Händler dagelassen hat."}], [], Callable(), n)
		return true
	if stage("wolves") == 0:
		say([{"who": "Bauer Hallin", "text": "Sie kommen erst, wenn es dunkel ist. Achte auf das Heulen am Waldrand."}], [], Callable(), n)
		return true
	return false

func _talk_greta(n: HumanNpc) -> bool:
	if hostile_village():
		return false
	if not started("meat") and not PlayerStats.flag("q_declined_meat") and int(PlayerStats.s.story) >= 3:
		say([{"who": "Greta", "text": "Seit der Schleier steht, gibt's kaum noch Fleisch. Die Leute essen Rübensuppe, Tag für Tag."},
			{"who": "Greta", "text": "Bring mir drei Grauläufer, und du hast ein Zimmer bei mir, wann immer du willst. Umsonst."}],
			["Abgemacht.", "Später."], _accept.bind("meat"), n)
		return true
	if stage("meat") == 1:
		complete("meat", 110, 30)
		PlayerStats.set_flag("greta_room")
		say([{"who": "Greta", "text": "Das reicht für eine Woche Eintopf! Das Zimmer gehört dir. Und frag nicht, warum ich dich nie bei Tag essen sehe – ich frag auch nicht."}], [], Callable(), n)
		return true
	return false

func _talk_oswin(n: HumanNpc) -> bool:
	if hostile_village():
		return false
	if not started("steel") and not PlayerStats.flag("q_declined_steel"):
		say([{"who": "Oswin", "text": "Klingen gegen Blutsplitter. Aber eins sag ich dir: Mit dem Schrott hier mach ich keine Klinge, die einen Reißer aufhält."},
			{"who": "Oswin", "text": "Im Wrack der „Hoffnung“ im Nordosten liegt Schleierstahl. Das Zeug, aus dem sie die Schiffshülle gemacht haben. Bring ihn mir, und ich schmiede dir was Besonderes."}],
			["Ich hole ihn.", "Zeig mir erst deine Ware.", "Kein Interesse."], _oswin_choice.bind(n), n)
		return true
	if stage("steel") == 1:
		say([{"who": "Oswin", "text": "Ist das … tatsächlich Schleierstahl? Gib her, ich schmiede die Nacht durch."}],
			["Gib ihm den Stahl.", "[Behalten] Ich verkaufe ihn lieber.", "Zeig mir deine Ware."], _steel_choice.bind(n), n)
		return true
	return false

func _oswin_choice(i: int, n: HumanNpc) -> void:
	if i == 0:
		start("steel")
	elif i == 1:
		w.open_shop()
	else:
		PlayerStats.set_flag("q_declined_steel")

func _steel_choice(i: int, n: HumanNpc) -> void:
	match i:
		0:
			complete("steel", 160, 0)
			var it := Items.make("weapon", int(PlayerStats.s.level) + 2, 3, "blade")
			it.name = "Schleierklinge"
			w.spawn_loot(it, n.global_position + Vector3(1.2, 0, 0.6))
			PlayerStats.record_choice("Du hast Oswin den Schleierstahl gebracht. Er schmiedete dir die Schleierklinge.")
			say([{"who": "Oswin", "text": "Da. Die beste Klinge, die je aus dieser Esse kam. Sie singt, wenn man sie schwingt. Pass auf sie auf."}], [], Callable(), n)
		1:
			complete("steel", 60, 140)
			PlayerStats.record_choice("Du hast den Schleierstahl für dich behalten und verkauft.")
			say([{"who": "Oswin", "text": "Wie du willst. Dann eben kein Meisterstück. Ich dachte, du wärst anders."}], [], Callable(), n)
		2:
			w.open_shop()

func _talk_mara(n: HumanNpc) -> bool:
	if hostile_village():
		return false
	# Ring: nur wenn Tamas tot gefunden wurde
	var t: String = PlayerStats.flag("tamas", "")
	if t in ["drained", "left"] and PlayerStats.flag("tamas_found") and not started("ring"):
		say([{"who": "Mara", "text": "Sie haben Tamas gefunden. Bei der Ruine. Ohne einen Tropfen Blut im Leib."},
			{"who": "Mara", "text": "Sein Ehering fehlt. Er hat ihn nie abgenommen, nicht ein einziges Mal. Bitte … bring ihn mir zurück."}],
			["Ich suche ihn.", "Ich kann nicht."], _accept.bind("ring"), n)
		return true
	if stage("ring") == 1:
		var opts := ["Hier ist sein Ring.", "[Gestehen] Ich war es."  if t == "drained" else "[Gestehen] Ich habe ihn sterbend liegen lassen.", "[Lügen] Ich habe nichts gefunden."]
		say([{"who": "Mara", "text": "Hast du … hast du ihn gefunden?"}], opts, _ring_choice.bind(n, t), n)
		return true
	# Pip: ab dem zweiten Tag nachts
	var h := PlayerStats.clock_hour()
	if not started("pip") and not PlayerStats.flag("q_declined_pip") and (int(PlayerStats.s.day) >= 2 or int(PlayerStats.s.story) >= 4) and (h >= 20 or h < 4) and w.npcs.has("pip") and is_instance_valid(w.npcs.pip):
		say([{"who": "Mara", "text": "Hast du Pip gesehen? Er ist weg! Er hat den ganzen Tag von den roten Steinen geredet – im Nordwesten, wo die Reißer jagen."},
			{"who": "Mara", "text": "Wenn er bis zum Morgen draußen ist … Bitte. Bring ihn zurück."}],
			["Ich finde ihn.", "Das ist nicht meine Sache."], _pip_accept.bind(n), n)
		return true
	if stage("pip") == 2:
		complete("pip", 160, 40)
		PlayerStats.change_humanity(4.0, "Pip gerettet")
		PlayerStats.record_choice("Du hast Pip nachts bei den roten Steinen gefunden und heimgebracht.")
		say([{"who": "Mara", "text": "Pip! Oh, Pip … Danke. Ich weiß nicht, was du bist, Fremder. Aber heute Nacht warst du ein Engel."}], [], Callable(), n)
		return true
	return false

func _ring_choice(i: int, n: HumanNpc, t: String) -> void:
	match i:
		0:
			complete("ring", 90, 0)
			PlayerStats.change_humanity(2.0, "Mara den Ring gebracht")
			say([{"who": "Mara", "text": "Danke. Jetzt kann ich ihn begraben, wie es sich gehört."}], [], Callable(), n)
		1:
			complete("ring", 120, 0)
			PlayerStats.change_humanity(6.0, "Mara die Wahrheit gesagt")
			if t == "drained":
				PlayerStats.record_choice("Du hast Mara gestanden, dass du Tamas getötet hast. Asch-Furt weiß jetzt, was du bist.")
				say([{"who": "Mara", "text": "Du … DU warst das? Hilfe! Mörder! Er ist das Ungeheuer!"}], [], func(_j): w._village_alarm("Mara schreit es durch das ganze Dorf."), n)
			else:
				PlayerStats.record_choice("Du hast Mara gestanden, dass du Tamas sterbend zurückgelassen hast.")
				say([{"who": "Mara", "text": "Du hast ihn liegen lassen … Geh. Bitte geh einfach."}], [], Callable(), n)
		2:
			complete("ring", 40, 50)
			PlayerStats.change_humanity(-3.0, "Mara belogen")
			PlayerStats.record_choice("Du hast Mara belogen und Tamas' Ring verkauft.")
			say([{"who": "Mara", "text": "Nichts? … Dann haben ihn die Krähen. Wie alles andere."}], [], Callable(), n)

func _pip_accept(i: int, n: HumanNpc) -> void:
	if i != 0:
		PlayerStats.set_flag("q_declined_pip")
		return
	start("pip")
	var pip: HumanNpc = w.npcs.pip
	var spot: Vector3 = w.places.spots.obelisks[0] if w.places.spots.has("obelisks") else w.terrain.ground(Vector3(-110, 0, -40))
	pip.global_position = w.terrain.ground(spot + Vector3(2.0, 0, 1.5)) + Vector3(0, 0.2, 0)
	pip.role = "lost"
	pip.state = "fixed"
	pip.asleep = false
	(pip.model as Humanoid).play("cower")
	# zwei Reißer lauern in der Nähe
	for k in 2:
		var e := Enemy.new()
		e.setup("reisser", w, w.terrain.ground(spot + Vector3(-9 + k * 4, 0, -7)) + Vector3(0, 0.3, 0), 3)
		w.add_child(e)

func _talk_pip(n: HumanNpc) -> bool:
	if stage("pip") == 0 and n.role == "lost":
		advance("pip")
		n.role = "child"
		n.state = "work"
		(n.model as Humanoid).play("")
		n.follow_target = w.player
		say([{"who": "Pip", "text": "D-du bist gekommen! Ich wollte nur die leuchtenden Steine sehen … und dann haben die Augen im Wald geleuchtet."},
			{"who": "Pip", "text": "Ich bleib ganz dicht bei dir. Versprochen."}], [], Callable(), n)
		return true
	if stage("pip") == 1:
		say([{"who": "Pip", "text": "Sind wir bald zu Hause?"}], [], Callable(), n)
		return true
	return false

func _talk_lenz(n: HumanNpc) -> bool:
	if hostile_village() or not PlayerStats.flag("guard_met"):
		return false
	if not started("ambush") and not PlayerStats.flag("q_declined_ambush") and int(PlayerStats.s.story) >= 3:
		say([{"who": "Lenz", "text": "Du willst helfen? Nachts lauern zwei von Krähes Leuten an der Weggabelung im Westen. Sie haben letzte Woche den Müller ausgeraubt."},
			{"who": "Lenz", "text": "Ich kann das Tor nicht verlassen. Wenn du sie loswirst, zahlt das Dorf."}],
			["Ich erledige das.", "Nicht meine Sache."], _accept.bind("ambush"), n)
		return true
	if stage("ambush") == 1:
		complete("ambush", 120, 55)
		say([{"who": "Lenz", "text": "Die Gabelung ist frei? Gut gemacht. Ich hab dich falsch eingeschätzt, Fremder."}], [], Callable(), n)
		return true
	return false

func _accept(i: int, id: String) -> void:
	if i == 0:
		start(id)
	else:
		PlayerStats.set_flag("q_declined_" + id)

# ---------- Ereignisse ----------

func on_kill(e: Enemy) -> void:
	if e.type == "reisser" and stage("wolves") == 0:
		_count("wolves")
	if e.npc_id.begins_with("ambush_") and stage("ambush") == 0:
		_count("ambush")
	if e.type in ["cultist", "ilva"] and int(PlayerStats.s.story) == 7 and not _cult_met:
		_cult_resolve(2)
	_check_raid()

func on_animal_killed(_a: Node) -> void:
	if stage("meat") == 0:
		_count("meat")

## Zusätzliche Interaktionen; gibt [id, text] zurück oder []
func interaction(pp: Vector3) -> Array:
	var sp: Dictionary = w.places.spots
	if stage("steel") == 0 and pp.distance_to(sp.lander) < 6.0:
		return ["q_steel", "SCHLEIERSTAHL BERGEN"]
	if stage("ring") == 0 and pp.distance_to(sp.wounded) < 3.0:
		return ["q_ring", "RING SUCHEN"]
	if int(PlayerStats.s.story) == 8 and pp.distance_to(sp.tower + Vector3(0, 0, 3.6)) < 3.0:
		return ["q_orders", "BEFEHLE DURCHSUCHEN"]
	return []

func interact(id: String) -> void:
	match id:
		"q_steel":
			advance("steel")
			say([{"who": "", "text": "Unter einer verbogenen Hüllenplatte glänzt bläuliches Metall. Es ist kalt – kälter, als es sein dürfte."}])
		"q_ring":
			advance("ring")
			say([{"who": "", "text": "Im Gras neben dem Weg liegt ein schlichter Silberring. Innen eingraviert: „T & M“."}])
		"q_orders":
			_read_orders()

# ---------- Ablauf (jede Sekunde) ----------

func tick() -> void:
	var h := PlayerStats.clock_hour()
	# Pip: am Morgen ist es zu spät
	if stage("pip") in [0, 1] and h >= 6 and h < 12:
		var pip: HumanNpc = w.npcs.get("pip")
		if pip and is_instance_valid(pip):
			pip.follow_target = null
			pip.role = "child"
			pip.state = "work"
			pip.global_position = w.places.spots.npc_child + Vector3(0, 0.2, 0)
			(pip.model as Humanoid).play("")
		fail("pip", "Du hast Pip nicht gefunden. Lenz brachte ihn am Morgen zurück – verletzt und stumm vor Angst.")
	if stage("pip") == 1:
		var pip2: HumanNpc = w.npcs.get("pip")
		if pip2 and is_instance_valid(pip2) and pip2.global_position.distance_to(w.places.spots.village) < 22.0:
			pip2.follow_target = null
			pip2.work_spot = w.places.spots.npc_child
			advance("pip")
	_act2_tick(h)

# ---------- Akt 2 ----------

func on_story(step: int) -> void:
	# Schritte überspringen, die schon erfüllt sind
	if step == 5 and PlayerStats.flag("shrine_read"):
		PlayerStats.set_story(6)
	elif step == 6:
		_check_stones()

func on_shrine_read() -> void:
	if int(PlayerStats.s.story) == 5:
		PlayerStats.set_story(6)

func _stones() -> int:
	var c := 0
	for i in 5:
		if PlayerStats.flag("obelisk_%d" % i):
			c += 1
	return c

func _check_stones() -> void:
	if int(PlayerStats.s.story) != 6:
		return
	PlayerStats.s.story_progress = mini(_stones(), 3)
	PlayerStats.quests_changed.emit()
	if _stones() >= 3:
		say([{"who": N, "text": "Drei Steine haben dein Blut geschmeckt. Meine Kinder wissen jetzt, wer du bist."},
			{"who": S, "text": "Neues Ziel: Die Versammlung – nachts am Schrein."}])
		PlayerStats.set_story(7)

func on_obelisk() -> void:
	_check_stones()

func _act2_tick(h: int) -> void:
	var st := int(PlayerStats.s.story)
	var sp: Dictionary = w.places.spots
	var night_ok := h >= 22 or h < 3
	# Die Versammlung
	if st == 7 and not _cult_met:
		var near: bool = w.player.global_position.distance_to(sp.shrine) < 70.0
		if night_ok and near and _cult.is_empty():
			_spawn_cult()
		elif (not night_ok or not near) and not _cult.is_empty() and not _cult_any_aggro():
			_despawn(_cult)
		if not _cult.is_empty() and w.state == "play" and w.player.global_position.distance_to(sp.shrine) < 8.0:
			_cult_meeting()
	# Die Nacht der Feuer
	if st == 9:
		var bd := int(PlayerStats.flag("burn_day", 0))
		var day := int(PlayerStats.s.day)
		if bd > 0 and _raid.is_empty() and not PlayerStats.flag("raid_started") and (day > bd or (day == bd and h >= 22)):
			_start_raid()
		if PlayerStats.flag("raid_started") and not PlayerStats.flag("raid_over"):
			# bis 2 Uhr Zeit, sonst brennt das Dorf
			var deadline := bd + 1
			if (day > deadline) or (day == deadline and h >= 2 and h < 12):
				_burn_village()
			else:
				_check_raid()

func _cult_any_aggro() -> bool:
	for e in _cult:
		if is_instance_valid(e) and e.aggro:
			return true
	return false

func _despawn(arr: Array) -> void:
	for e in arr:
		if is_instance_valid(e):
			e.queue_free()
	arr.clear()

func _spawn_cult() -> void:
	var sp: Vector3 = w.places.spots.shrine
	var ilva := Enemy.new()
	ilva.setup("ilva", w, w.terrain.ground(sp + Vector3(0, 0, -3.2)) + Vector3(0, 0.3, 0), int(PlayerStats.s.level) + 1, "ilva")
	ilva.peaceful = true
	w.add_child(ilva)
	_cult.append(ilva)
	for k in 3:
		var a := TAU * k / 3.0 + 0.5
		var e := Enemy.new()
		e.setup("cultist", w, w.terrain.ground(sp + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0)) + Vector3(0, 0.3, 0), int(PlayerStats.s.level), "cultist_%d" % k)
		e.peaceful = true
		w.add_child(e)
		_cult.append(e)
	PlayerStats.system_message.emit("Fackeln am Schrein. Gestalten in roten Kutten warten.", "quest")

func _cult_meeting() -> void:
	_cult_met = true
	var ilva: Node = _cult[0] if not _cult.is_empty() else null
	say([{"who": "Seherin Ilva", "text": "Blutgeborener. Die Steine haben dich angekündigt. Ich bin Ilva, die Stimme der Kinder der Ersten Nacht."},
		{"who": "Seherin Ilva", "text": "Varek weiß, dass du lebst. Er nennt dich ‚die Seuche‘. Und für eine Seuche kennt die Wacht nur eine Antwort: Feuer."},
		{"who": "Seherin Ilva", "text": "Asch-Furt wird brennen, wie Morrow gebrannt hat. Die Befehle liegen im Wachturm im Osten."},
		{"who": "Seherin Ilva", "text": "Wenn das Dorf brennt, kommen die Überlebenden zu uns. Verlorene sind die treuesten Kinder. Schließ dich uns an – und lass es brennen."},
		{"who": N, "text": "Meine Kinder. Hör ihnen zu. Oder trink sie."}],
		["Ich schließe mich euch an.", "Ich gehe meinen eigenen Weg.", "[Angreifen] Ihr dient dem Ding in meinem Kopf."], _cult_resolve, ilva)

func _cult_resolve(i: int) -> void:
	_cult_met = true
	match i:
		0:
			PlayerStats.set_flag("cult", "joined")
			PlayerStats.change_humanity(-6.0, "Dem Kult beigetreten")
			PlayerStats.s.skill_points = int(PlayerStats.s.skill_points) + 1
			PlayerStats.add_shards(60)
			PlayerStats.record_choice("Du hast dich den Kindern der Ersten Nacht angeschlossen.")
			say([{"who": "Seherin Ilva", "text": "Dann trink mit uns, Bruder. Die Nacht ist lang, und sie gehört uns."},
				{"who": S, "text": "Kult der Ersten Nacht: verbündet. +1 Fähigkeitspunkt."}])
		1:
			PlayerStats.set_flag("cult", "neutral")
			PlayerStats.record_choice("Du hast den Kult angehört – und bist deinen eigenen Weg gegangen.")
			say([{"who": "Seherin Ilva", "text": "Wie du willst. Aber die Erste Nacht lässt niemanden gehen. Wir sehen uns wieder."}])
		2:
			PlayerStats.set_flag("cult", "enemy")
			PlayerStats.change_humanity(3.0, "Gegen den Kult gestellt")
			PlayerStats.record_choice("Du hast die Versammlung der Kinder der Nacht angegriffen.")
			for e in _cult:
				if is_instance_valid(e):
					e.peaceful = false
					e.aggro = true
	if int(PlayerStats.s.story) == 7:
		PlayerStats.set_story(8)

func on_peaceful_attacked(e: Enemy) -> void:
	if e in _cult and int(PlayerStats.s.story) <= 8 and not PlayerStats.flag("cult"):
		w.end_talk()
		_cult_resolve(2)

func _read_orders() -> void:
	var h := PlayerStats.clock_hour()
	var day := int(PlayerStats.s.day)
	var bd := day + (1 if h >= 12 else 0)
	PlayerStats.set_flag("burn_day", bd)
	say([{"who": "", "text": "Auf dem Tisch im Turm liegt ein versiegelter Brief. Das Siegel zeigt Vareks Falken."},
		{"who": "Brief", "text": "„An Hauptmann Sorn. Die Seuche aus Morrow hat Asch-Furt erreicht. In der Nacht von Tag %d wird das Dorf gereinigt. Feuer an jedes Dach. Keine Überlebenden. – Kommandant Varek“" % bd},
		{"who": N, "text": "Deine Brüder in Rüstung. Sie haben Morrow verbrannt, und du hast dich geweigert. Weigerst du dich wieder?"},
		{"who": S, "text": "Die Wacht greift Asch-Furt in der Nacht von Tag %d um 22:00 Uhr an." % bd}])
	PlayerStats.record_choice("Du hast Vareks Befehl gelesen: Asch-Furt soll brennen.")
	PlayerStats.set_story(9)

## Hanna in Akt 2: warnen?
func talk_hanna(n: HumanNpc) -> bool:
	if int(PlayerStats.s.story) != 9 or PlayerStats.flag("warned_asked"):
		return false
	PlayerStats.set_flag("warned_asked")
	if hostile_village():
		say([{"who": "Hanna", "text": "Du wagst es, hierher zu kommen? Was immer du sagen willst – wir glauben einem Blutsauger kein Wort."}], [], Callable(), n)
		return true
	say([{"who": "Hanna", "text": "Du siehst aus, als hättest du einen Geist gesehen. Was ist los?"}],
		["Die Wacht kommt, um euch alle zu töten. Versteckt euch, wenn es dunkel wird.", "Nichts. Alles in Ordnung."], _warn_choice.bind(n), n)
	return true

func _warn_choice(i: int, n: HumanNpc) -> void:
	if i == 0:
		PlayerStats.set_flag("village_warned")
		PlayerStats.record_choice("Du hast Asch-Furt vor dem Angriff der Wacht gewarnt.")
		say([{"who": "Hanna", "text": "Die Wacht? Bei den Sternen … Wir verriegeln die Türen. Lenz und Oswin halten das Tor. Und du?"},
			{"who": "Hanna", "text": "Wenn du wirklich auf unserer Seite stehst, dann sei hier, wenn es dunkel wird."}], [], Callable(), n)
	else:
		PlayerStats.record_choice("Du hast Asch-Furt nicht gewarnt.")

func _start_raid() -> void:
	PlayerStats.set_flag("raid_started")
	var sp: Dictionary = w.places.spots
	var gate: Vector3 = sp.village_gate_w
	var center: Vector3 = sp.village
	var lvl := int(PlayerStats.s.level) + 1
	var sorn := Enemy.new()
	sorn.setup("sorn", w, w.terrain.ground(gate + Vector3(-6, 0, 0)) + Vector3(0, 0.3, 0), lvl + 1, "sorn")
	sorn.patrol = [center + Vector3(-8, 0, 0), center]
	w.add_child(sorn)
	_raid.append(sorn)
	for k in 5:
		var e := Enemy.new()
		e.setup("wacht", w, w.terrain.ground(gate + Vector3(-8 - k * 1.5, 0, -3 + k * 1.5)) + Vector3(0, 0.3, 0), lvl, "raid_%d" % k)
		e.patrol = [center + Vector3(-10 + k * 2, 0, -4 + k * 2), center + Vector3(k * 2 - 4, 0, 6 - k * 2)]
		w.add_child(e)
		_raid.append(e)
	PlayerStats.system_message.emit("Fackeln am Westtor! Die Wacht ist da.", "warn")
	w.hud.show_banner("DIE NACHT DER FEUER")
	if PlayerStats.flag("village_warned"):
		for id in w.npcs:
			var n: HumanNpc = w.npcs[id]
			if is_instance_valid(n) and n.alive and n.role != "guard":
				n.night_owl = false

func _check_raid() -> void:
	if not PlayerStats.flag("raid_started") or PlayerStats.flag("raid_over"):
		return
	var left := 0
	for e in _raid:
		if is_instance_valid(e) and e.alive and not e.downed and not e.spared:
			left += 1
	# Nach einem Neustart: Angreifer neu setzen
	if _raid.is_empty():
		_start_raid_again()
		return
	if left == 0:
		_village_saved()

func _start_raid_again() -> void:
	PlayerStats.set_flag("raid_started", false)
	_start_raid()

func _village_saved() -> void:
	PlayerStats.set_flag("raid_over")
	PlayerStats.set_flag("village_fate", "saved")
	PlayerStats.change_humanity(6.0, "Asch-Furt verteidigt")
	PlayerStats.add_shards(150)
	PlayerStats.record_choice("Du hast Asch-Furt gegen die Wacht verteidigt. Hauptmann Sorn ist gefallen.")
	var lines := [{"who": "", "text": "Die letzte Fackel erlischt im Schlamm. Asch-Furt steht."}]
	if PlayerStats.flag("village_hostile"):
		PlayerStats.set_flag("village_hostile", false)
		lines.append({"who": "Hanna", "text": "Du hast uns gerettet. Ausgerechnet du. Vielleicht … bist du nicht nur ein Ungeheuer. Du darfst bleiben."})
		PlayerStats.record_choice("Asch-Furt hat dir vergeben.")
	else:
		lines.append({"who": "Hanna", "text": "Ohne dich wären wir jetzt Asche. Asch-Furt wird das nie vergessen."})
	if PlayerStats.flag("cult", "") == "joined":
		lines.append({"who": "Seherin Ilva", "text": "(aus der Ferne) Du hast uns die Verlorenen genommen, Bruder. Das merkt sich die Nacht."})
	lines.append({"who": N, "text": "Du hast deine eigenen Brüder geschlachtet, um Fremde zu retten. Varek wird kommen. Diesmal selbst."})
	_end_act2(lines)

func _burn_village() -> void:
	PlayerStats.set_flag("raid_over")
	PlayerStats.set_flag("village_fate", "burned")
	_despawn(_raid)
	var warned: bool = PlayerStats.flag("village_warned")
	for id in w.npcs.keys():
		var n: HumanNpc = w.npcs[id]
		if not is_instance_valid(n):
			continue
		if n.faction == "village":
			if warned:
				PlayerStats.set_flag("fled_" + String(id))
			else:
				PlayerStats.mark_dead(String(id))
			n.queue_free()
			w.npcs.erase(id)
	w.places.burn_village()
	if warned:
		PlayerStats.record_choice("Asch-Furt ist niedergebrannt. Die Bewohner konnten dank deiner Warnung fliehen.")
	else:
		PlayerStats.record_choice("Asch-Furt ist niedergebrannt. Niemand hat überlebt.")
		PlayerStats.change_humanity(-4.0, "Asch-Furt brennen lassen")
	var lines := [{"who": "", "text": "Rauch steigt über der Furt auf. Wo Asch-Furt stand, glimmt nur noch Glut."}]
	if PlayerStats.flag("cult", "") == "joined":
		lines.append({"who": "Seherin Ilva", "text": "Die Verlorenen kommen zu uns. Du hast gut gewählt, Bruder."})
	lines.append({"who": N, "text": "Feuer und Asche. Genau wie in Morrow. Nur dass du diesmal zugesehen hast."})
	_end_act2(lines)

func _end_act2(lines: Array) -> void:
	lines.append({"who": S, "text": "AKT 2 ABGESCHLOSSEN. Deine Entscheidungen stehen in der Chronik. Akt 3 folgt."})
	say(lines, [], func(_j):
		PlayerStats.set_story(10)
		w.show_chronicle())

# ---------- Kompass ----------

func marks() -> Array:
	var m: Array = []
	var sp: Dictionary = w.places.spots
	var side := Color(0.55, 0.85, 1.0)
	if stage("wolves") == 0:
		m.append([w.terrain.ground(Vector3(-60, 0, 110)), side, "REISSER"])
	elif stage("wolves") == 1:
		m.append([sp.npc_farmer, side, "HALLIN"])
	if stage("meat") == 1:
		m.append([sp.npc_innkeeper, side, "GRETA"])
	if stage("steel") == 0:
		m.append([sp.lander, side, "WRACK"])
	elif stage("steel") == 1:
		m.append([sp.npc_smith, side, "OSWIN"])
	if stage("pip") == 0 and sp.has("obelisks"):
		m.append([sp.obelisks[0], Color(1.0, 0.8, 0.35), "PIP"])
	elif stage("pip") == 1:
		m.append([sp.village, Color(1.0, 0.8, 0.35), "HEIM"])
	elif stage("pip") == 2:
		m.append([sp.npc_widow, side, "MARA"])
	if stage("ring") == 0:
		m.append([sp.wounded, side, "RING"])
	elif stage("ring") == 1:
		m.append([sp.npc_widow, side, "MARA"])
	if stage("ambush") == 0:
		m.append([w.terrain.ground(Vector3(-40, 0, 52)), side, "GABELUNG"])
	elif stage("ambush") == 1:
		m.append([sp.npc_guard, side, "LENZ"])
	# Akt 2
	match int(PlayerStats.s.story):
		5:
			m.append([sp.shrine, Color(1.0, 0.25, 0.3), "SCHREIN"])
		6:
			if sp.has("obelisks"):
				for i in (sp.obelisks as Array).size():
					if not PlayerStats.flag("obelisk_%d" % i):
						m.append([sp.obelisks[i], Color(1.0, 0.25, 0.3), "STEIN"])
		7:
			m.append([sp.shrine, Color(1.0, 0.25, 0.3), "VERSAMMLUNG"])
		8:
			m.append([sp.tower, Color(1.0, 0.25, 0.3), "TURM"])
		9:
			m.append([sp.village, Color(1.0, 0.25, 0.3), "ASCH-FURT"])
	return m
