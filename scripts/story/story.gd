class_name Story
extends Node
## Akt 1 – Die Erste Nacht. Dialoge, Entscheidungen und ihre (unumkehrbaren) Folgen.

const N := "DIE ERSTE NACHT"
const S := "SYSTEM"

var w: Node   # main

func _ps() -> Node:
	return PlayerStats

func say(lines: Array, choices: Array = [], cb: Callable = Callable(), focus: Variant = null) -> void:
	w.begin_talk(focus)
	w.hud.dialog(lines, choices, func(i):
		w.end_talk()
		if cb.is_valid():
			cb.call(i))

func consequence(text: String) -> void:
	PlayerStats.system_message.emit(text, "choice")

# ---------- Intro & Erwachen ----------

func intro() -> void:
	w.hud.fade_t = 0.0
	say([
		{"who": "", "text": "Veyra. Eine Kolonie am Rand der bekannten Sterne. Seit zwölf Jahren schneidet sie der Schleier – ein roter Sturm am Horizont – von der Erde ab."},
		{"who": "", "text": "Ohne Nachschub regiert die Wacht. Ordnung um jeden Preis."},
		{"who": "", "text": "Gestern sollte Soldat Kael das Dorf Morrow niederbrennen. Seuche, hieß es. Kael hat sich geweigert."},
		{"who": "", "text": "Kommandant Varek hat ihn eigenhändig erschossen und in den Ruinen der Alten liegen lassen. Für die Krähen."},
		{"who": "", "text": "Doch etwas anderes hat ihn gefunden."},
	], [], func(_i): _awaken())

func _awaken() -> void:
	w.awaken_fx()
	say([
		{"who": S, "text": "Blutsignatur erkannt.  Wirt: Kael.  Zustand: tot."},
		{"who": S, "text": "Korrektur … Zustand: verwandelt.  Sanguine-Protokoll aktiv."},
		{"who": N, "text": "Steh auf, Soldat. Sie haben dich weggeworfen. Ich nicht."},
		{"who": N, "text": "Ich bin älter als eure Schiffe. Älter als der Schleier. Ich gebe dir Stärke – und du gibst mir, wonach wir beide hungern."},
	], ["Was bist du?", "Ich schulde dir gar nichts.", "Was verlangst du von mir?"], _awaken_choice, w.places.spots.ruin_altar)

func _awaken_choice(i: int) -> void:
	var cont := func(_j): _after_awaken()
	match i:
		0:
			say([{"who": N, "text": "Die Erste Nacht. Die, die vor allem war. Mehr musst du noch nicht wissen."}], [], cont)
		1:
			PlayerStats.s.protocol = int(PlayerStats.s.protocol) - 1
			say([{"who": N, "text": "Trotz. Gut. Den wirst du brauchen. Aber der Hunger fragt nicht, wem du etwas schuldest."}], [], cont)
		_:
			PlayerStats.s.protocol = int(PlayerStats.s.protocol) + 1
			say([{"who": N, "text": "Blut. Nicht mehr, als du nehmen willst. Nicht weniger, als du brauchst. Du wirst lernen, wo die Grenze ist – oder nicht."}], [], cont)

func _after_awaken() -> void:
	PlayerStats.s.started = true
	PlayerStats.set_story(1)
	say([
		{"who": S, "text": "Der Hunger wächst in Echtzeit. Tiere, Menschen, Bestien – jedes Blut stillt ihn anders. Und jedes hat einen Preis."},
		{"who": S, "text": "Menschlichkeit: 70.  Je tiefer sie sinkt, desto stärker die Nacht – und desto grausamer die Sonne."},
		{"who": S, "text": "Steuerung: links laufen (ganz ausziehen = rennen), rechts wischen = umsehen. Kamerasymbol oben: Ego-Perspektive."},
	])

# ---------- Tamas (Wahl 1) ----------

func tamas_encounter(npc: HumanNpc) -> void:
	PlayerStats.set_flag("tamas_met")
	say([
		{"who": "Verwundeter", "text": "Hilfe … bitte … Banditen. Sie haben meinen Karren … mein Bein …"},
		{"who": "Tamas", "text": "Ich bin Tamas, aus Asch-Furt. Meine Frau Mara wartet auf mich. Bitte …"},
		{"who": N, "text": "Riechst du das? Warm. Frisch. Niemand würde es je erfahren."},
	], ["Ich verbinde deine Wunde.", "[Nippen] Nur ein wenig …", "[Aussaugen] Der Hunger ist stärker.", "Ich lasse dich liegen."], _tamas_choice.bind(npc), npc)

func _tamas_choice(i: int, npc: HumanNpc) -> void:
	match i:
		0:
			PlayerStats.set_flag("tamas", "helped")
			PlayerStats.change_humanity(5.0, "Tamas geholfen")
			PlayerStats.record_choice("Du hast Tamas' Wunde verbunden, obwohl dein Hunger schrie.")
			consequence("Tamas wird sich daran erinnern.")
			npc.role = "villager"
			npc.state = "work"
			(npc.model as Humanoid).play("")
			npc.work_spot = w.places.spots.village + Vector3(4, 0, -6)
			say([{"who": "Tamas", "text": "Danke … Fremder. Komm nach Asch-Furt. Mara kocht die beste Suppe der Kolonie. Ich erzähl allen, was du getan hast."},
				{"who": N, "text": "Gütig. Und hungrig. Wie lange noch?"}], [], func(_j): _to_village())
		1:
			PlayerStats.set_flag("tamas", "sipped")
			w.perform_feed(npc, "sip", true)
			PlayerStats.record_choice("Du hast von Tamas getrunken. Er hat deine roten Augen gesehen.")
			consequence("Tamas hat dein Gesicht gesehen. Er wird reden.")
			npc.role = "villager"
			npc.work_spot = w.places.spots.village + Vector3(4, 0, -6)
			_to_village()
		2:
			PlayerStats.set_flag("tamas", "drained")
			w.perform_feed(npc, "drain", true)
			PlayerStats.record_choice("Du hast Tamas ausgesaugt. Mara wartet vergeblich.")
			consequence("Tamas ist tot. Mara wird ihn suchen.")
			_to_village()
		3:
			PlayerStats.set_flag("tamas", "left")
			PlayerStats.change_humanity(-2.0, "Tamas zurückgelassen")
			PlayerStats.record_choice("Du hast Tamas verletzt am Weg liegen lassen.")
			consequence("Ohne Hilfe wird Tamas die Nacht nicht überleben.")
			npc.set_meta("dying", true)
			_to_village()

func _to_village() -> void:
	PlayerStats.set_story(2)
	PlayerStats.system_message.emit("Asch-Furt liegt im Südosten, an der Furt des Flusses. Folge dem Weg.", "quest")

# ---------- Asch-Furt ----------

func guard_greet(npc: HumanNpc) -> void:
	PlayerStats.set_flag("guard_met")
	var lines := [{"who": "Lenz", "text": "Halt. Wer bist du? Die Straße ist nicht sicher – erst recht nicht nachts."}]
	var t: String = PlayerStats.flag("tamas", "")
	if t == "helped" and PlayerStats.flag("tamas_arrived"):
		lines.append({"who": "Lenz", "text": "Moment … Tamas hat von dir erzählt. Du hast ihn gerettet. Willkommen in Asch-Furt."})
	elif t == "sipped":
		lines.append({"who": "Lenz", "text": "Du bist blass wie ein Toter. Tamas faselt von einem Dämon mit roten Augen. Ich behalte dich im Auge."})
	if PlayerStats.humanity() < 30.0:
		lines.append({"who": "Lenz", "text": "Deine Augen … Bei den Sternen. Verschwinde! Hier kommst du nicht rein!"})
		say(lines, [], func(_i): PlayerStats.set_flag("village_wary"), npc)
		return
	say(lines, ["Ein Reisender. Nichts weiter.", "Ich war Soldat der Wacht.", "Das geht dich nichts an."], _guard_choice.bind(npc), npc)

func _guard_choice(i: int, npc: HumanNpc) -> void:
	match i:
		0:
			say([{"who": "Lenz", "text": "Reisende gibt's keine mehr, seit der Schleier steht. Aber gut. Sprich mit Hanna, der Ältesten. Und mach keinen Ärger."}], [], Callable(), npc)
		1:
			PlayerStats.set_flag("told_wacht")
			PlayerStats.record_choice("Du hast Lenz verraten, dass du Soldat der Wacht warst.")
			say([{"who": "Lenz", "text": "Die Wacht. Die kommen bei Sonnenaufgang und hängen Jory. Wenn du einer von denen bist, halt dich von mir fern."}], [], Callable(), npc)
		_:
			say([{"who": "Lenz", "text": "Freundlich bist du nicht. Na schön. Hanna entscheidet, wer bleibt."}], [], Callable(), npc)

func hanna(npc: HumanNpc) -> void:
	var st := int(PlayerStats.s.story)
	if PlayerStats.flag("village_hostile"):
		say([{"who": "Hanna", "text": "Ich weiß, was du bist. Ich weiß, was du getan hast. Geh, bevor du uns alle tötest."}], [], Callable(), npc)
		return
	if st <= 2:
		var lines := [{"who": "Hanna", "text": "Ein Fremder. Selten geworden. Ich bin Hanna. Ich halte dieses Dorf zusammen, so gut es geht."}]
		match String(PlayerStats.flag("tamas", "")):
			"helped":
				lines.append({"who": "Hanna", "text": "Tamas sagt, du hast ihm das Leben gerettet. Dafür hast du hier ein Dach, solange du willst."})
			"sipped":
				lines.append({"who": "Hanna", "text": "Tamas kam halb tot zurück und redet von einem Blutdämon. Ich weiß nicht, was ich glauben soll. Du siehst … krank aus."})
			"drained", "left":
				lines.append({"who": "Hanna", "text": "Mara wartet seit gestern auf ihren Mann Tamas. Er wollte aus Morrow zurückkommen. Hast du jemanden gesehen?"})
		lines.append({"who": "Hanna", "text": "Wir haben eigene Sorgen. Jory – unser Jory – soll den Bauern Edrik erschlagen haben. Die Wacht holt ihn bei Sonnenaufgang. Sie hängen ihn am Turm."})
		lines.append({"who": "Hanna", "text": "Ich glaube es nicht. Aber Edriks Blut war an seinen Händen. Was soll ich tun?"})
		var choices := ["Ich sehe mir das an.", "Nicht mein Problem."]
		if String(PlayerStats.flag("tamas", "")) in ["drained", "left"]:
			choices.insert(0, "[Lügen] Ich habe niemanden gesehen.")
		var cb := func(i):
			var c: String = choices[i]
			if c.begins_with("[Lügen]"):
				PlayerStats.record_choice("Du hast Hanna ins Gesicht gelogen, was Tamas betrifft.")
				PlayerStats.set_flag("lied_tamas")
			_start_jory()
			if c == "Nicht mein Problem.":
				PlayerStats.set_flag("jory_ignored")
		say(lines, choices, cb, npc)
		return
	if st == 3:
		if PlayerStats.flag("has_amulet") and not PlayerStats.flag("jory_resolved"):
			say([
				{"who": "Hanna", "text": "Das … das ist Edriks Amulett. Woher hast du das?"},
				{"who": "Hanna", "text": "Krähes Bande. Also doch. Jory hat die Wahrheit gesagt."},
			], ["Ja. Lass ihn frei.", "[Behalten] Das Amulett ist wertvoll. Ich verkaufe es."], _amulet_choice.bind(npc), npc)
			return
		say([{"who": "Hanna", "text": "Die Sonne geht bald auf. Wenn du Jory helfen willst – Krähes Banditen hausen im Wald im Südwesten. Edrik trug ein Silberamulett."}], [], Callable(), npc)
		return
	var thanks := "Asch-Furt steht in deiner Schuld." if PlayerStats.flag("jory", "") == "proven" else "Wir leben weiter. Irgendwie."
	say([{"who": "Hanna", "text": thanks + " Wenn du am Tag Schutz vor der Sonne brauchst – Greta in der Schänke hat ein Zimmer."}], [], Callable(), npc)

func _amulet_choice(i: int, npc: HumanNpc) -> void:
	if i == 0:
		_free_jory_proven()
		return
	PlayerStats.set_flag("amulet_kept")
	PlayerStats.record_choice("Du hattest den Beweis für Jorys Unschuld – und hast ihn behalten.")
	PlayerStats.change_humanity(-4.0, "Beweis behalten")
	PlayerStats.add_shards(60)
	say([{"who": "Hanna", "text": "Dann soll die Wacht ihn eben holen. Ich hoffe, du kannst damit leben."}], [], Callable(), npc)

func _start_jory() -> void:
	if int(PlayerStats.s.story) < 3:
		var day := int(PlayerStats.s.day)
		if PlayerStats.clock_hour() >= 6:
			day += 1
		PlayerStats.set_flag("jory_deadline", day)
		PlayerStats.set_story(3)
		PlayerStats.system_message.emit("Die Wacht kommt bei Sonnenaufgang (06:00, Tag %d)." % day, "warn")

func jory(npc: HumanNpc) -> void:
	if int(PlayerStats.s.story) < 3:
		say([{"who": "Jory", "text": "Was glotzt du? Geh weiter. Bald hängt hier eh keiner mehr drin."}], [], Callable(), npc)
		return
	var lines := [
		{"who": "Jory", "text": "Du bist der Fremde. Hör zu – ich war es nicht! Ich hab Edrik gefunden, am Waldrand. Er hat noch gelebt."},
		{"who": "Jory", "text": "Krähes Leute hatten ihn überfallen. Für sein Silberamulett. Ich hab versucht, die Blutung zu stillen. Deshalb das Blut an mir."},
		{"who": N, "text": "Ein Mörder – oder ein Lügner. Was macht das für einen Unterschied? Sein Blut ist warm, und niemand wird um ihn weinen."},
	]
	var choices := ["Ich finde Beweise.", "Ich lasse dich frei.", "Halte durch."]
	var cb := func(i):
		if i == 0:
			PlayerStats.set_flag("jory_investigate")
			PlayerStats.system_message.emit("Krähes Banditenlager liegt im Wald im Südwesten.", "quest")
		elif i == 1:
			w.try_free_jory()
	say(lines, choices, cb, npc)

func _free_jory_proven() -> void:
	PlayerStats.set_flag("jory", "proven")
	PlayerStats.set_flag("jory_resolved")
	PlayerStats.change_humanity(8.0, "Jorys Unschuld bewiesen")
	PlayerStats.record_choice("Du hast Jorys Unschuld bewiesen. Asch-Furt hat ihn gefeiert.")
	consequence("Asch-Furt vertraut dir. Die Wacht wird nach dem fragen, der Jory gerettet hat.")
	PlayerStats.add_shards(80)
	w.free_jory_npc(false)
	w.spawn_loot(Items.make("relic", int(PlayerStats.s.level) + 1, 2), w.player.global_position + w.player.facing * 1.5)
	PlayerStats.set_story(4)

func jory_freed_secretly() -> void:
	PlayerStats.set_flag("jory", "freed")
	PlayerStats.set_flag("jory_resolved")
	PlayerStats.change_humanity(3.0, "Jory befreit")
	PlayerStats.record_choice("Du hast Jory nachts aus dem Käfig gelassen. Niemand weiß, dass du es warst – noch nicht.")
	consequence("Jory ist in den Wald geflohen. Asch-Furt wird morgen jemanden suchen, dem es die Schuld geben kann.")
	PlayerStats.set_story(4)

func jory_fed(mode: String) -> void:
	PlayerStats.set_flag("jory_resolved")
	if mode == "drain":
		PlayerStats.set_flag("jory", "drained")
		PlayerStats.record_choice("Du hast Jory im Käfig ausgesaugt. Er war unschuldig.")
		consequence("Jory ist tot. Ob er es getan hat, wird nie jemand beweisen.")
		PlayerStats.set_story(4)
	else:
		PlayerStats.record_choice("Du hast von Jory getrunken, während er hinter Gittern saß.")

func jory_hanged() -> void:
	PlayerStats.set_flag("jory", "hanged")
	PlayerStats.set_flag("jory_resolved")
	PlayerStats.mark_dead("jory")
	PlayerStats.record_choice("Die Wacht hat Jory bei Sonnenaufgang geholt und am Turm gehängt.")
	consequence("Jory wurde gehängt. Die Wacht ist jetzt in der Gegend.")
	PlayerStats.set_story(4)

# ---------- Andere Bewohner ----------

func mara(npc: HumanNpc) -> void:
	var t: String = PlayerStats.flag("tamas", "")
	if t == "helped":
		say([{"who": "Mara", "text": "Du hast meinen Tamas zurückgebracht. Ich habe nichts außer Suppe – aber die gehört dir. Jeden Tag."}], [], func(_i): PlayerStats.heal(30.0), npc)
	elif t == "sipped":
		say([{"who": "Mara", "text": "Tamas schläft kaum noch. Er schreit nachts. Er sagt, ein Toter mit roten Augen hätte von ihm getrunken … Warum schaust du so?"}], [], Callable(), npc)
	elif t in ["drained", "left"] and PlayerStats.flag("tamas_found"):
		var cb := func(i):
			if i == 0:
				PlayerStats.change_humanity(1.0)
		say([{"who": "Mara", "text": "Sie haben ihn gefunden. Bei der Ruine. Ohne einen Tropfen Blut im Leib. Wer tut so etwas?"}], ["Es tut mir leid.", "[Schweigen]"], cb, npc)
	else:
		say([{"who": "Mara", "text": "Hast du Tamas gesehen? Er wollte gestern zurück sein. Er hat einen Karren mit Saatgut."}], [], Callable(), npc)

func innkeeper(npc: HumanNpc) -> void:
	if PlayerStats.flag("village_hostile"):
		say([{"who": "Greta", "text": "Raus aus meiner Schänke!"}], [], Callable(), npc)
		return
	var trusted: bool = PlayerStats.flag("jory", "") == "proven" or PlayerStats.flag("tamas", "") == "helped" or PlayerStats.flag("greta_room")
	var lines := [{"who": "Greta", "text": "Willkommen in der „Furt“. Viel gibt's nicht seit dem Schleier, aber das Dach hält."}]
	var choices := ["Ich brauche ein Zimmer – bis zur Nacht.", "Ich brauche ein Zimmer – bis zum Morgen.", "Erzähl mir von der Gegend."]
	if not trusted:
		lines.append({"who": "Greta", "text": "Ein Zimmer kostet 15 Blutsplitter. Für Fremde."})
	say(lines, choices, _inn_choice.bind(npc, trusted), npc)

func _inn_choice(i: int, npc: HumanNpc, trusted: bool) -> void:
	match i:
		0, 1:
			if not trusted and int(PlayerStats.s.shards) < 15:
				say([{"who": "Greta", "text": "Kein Geld, kein Bett."}], [], Callable(), npc)
				return
			if not trusted:
				PlayerStats.add_shards(-15)
			w.sleep_until(21 if i == 0 else 7)
		2:
			say([
				{"who": "Greta", "text": "Im Westen die Ruinen der Alten. Keiner geht da hin. Im Südwesten haust Krähe mit seiner Bande. Im Osten der Turm der Wacht."},
				{"who": "Greta", "text": "Und nachts kommen die Reißer aus dem Wald. Bleib auf den Wegen. Und trau den roten Steinen nicht – die Alten haben sie nicht ohne Grund gebaut."},
			], [], Callable(), npc)

func smith(npc: HumanNpc) -> void:
	var cb := func(i):
		if i == 0:
			w.open_shop()
	say([{"who": "Oswin", "text": "Klingen gegen Blutsplitter. Ich frag nicht, woher du sie hast. Schau dir an, was ich habe."}], ["Zeig her.", "Später."], cb, npc)

func child(npc: HumanNpc) -> void:
	if PlayerStats.humanity() < 45.0:
		say([{"who": "Pip", "text": "D-deine Augen leuchten … Mama!"}], [], func(_i): npc.frighten(w.player.global_position), npc)
	else:
		say([{"who": "Pip", "text": "Bist du ein Soldat? Ich werd auch Soldat. Dann mach ich den Schleier kaputt!"}], [], Callable(), npc)

func generic(npc: HumanNpc) -> void:
	var lines := ["Kalt heute.", "Seit der Schleier steht, kommt kein Schiff mehr.", "Die Reißer werden jedes Jahr mehr.", "Halt dich von der Wacht fern, Fremder."]
	if PlayerStats.flag("murders", 0) > 0:
		lines = ["Wieder jemand tot. Ausgeblutet. Wir schließen nachts die Türen.", "Man sagt, ein Toter geht um."]
	say([{"who": npc.display_name, "text": lines[randi() % lines.size()]}], [], Callable(), npc)

# ---------- Banditen ----------

func krahe_downed(e: Enemy) -> void:
	say([
		{"who": "Krähe", "text": "Warte … warte! Ich weiß, was du bist. Ich hab Leute beim Kult. Die suchen dich, Blutgeborener."},
		{"who": "Krähe", "text": "Lass mich leben, und ich sag dir, wo sie sich treffen. Und das Amulett von dem Bauern liegt in der Truhe."},
	], ["Wer hat Edrik getötet?", "[Verschonen] Verschwinde.", "[Aussaugen]", "Hinrichten."], _krahe_choice.bind(e), e)

func _krahe_choice(i: int, e: Enemy) -> void:
	if i == 0:
		PlayerStats.set_flag("krahe_confessed")
		say([{"who": "Krähe", "text": "Ich war's. Der Narr wollte nicht loslassen. Jory? Der kam zu spät. Zufrieden?"}], ["[Verschonen] Verschwinde.", "[Aussaugen]", "Hinrichten."], func(j): _krahe_fate(e, j + 1), e)
	else:
		_krahe_fate(e, i)

func _krahe_fate(e: Enemy, i: int) -> void:
	match i:
		1:
			PlayerStats.set_flag("krahe", "spared")
			PlayerStats.set_flag("cult_lead")
			PlayerStats.record_choice("Du hast Krähe verschont. Er schuldet dir etwas – und kennt dein Geheimnis.")
			consequence("Krähe lebt. Er verrät dir den Treffpunkt des Kults: einen Schrein im Westen.")
			e.spare()
		2:
			PlayerStats.set_flag("krahe", "drained")
			PlayerStats.record_choice("Du hast Krähe ausgesaugt.")
			w.perform_feed(e, "drain", true)
		3:
			PlayerStats.set_flag("krahe", "executed")
			PlayerStats.record_choice("Du hast Krähe hingerichtet.")
			e.die()


# ---------- Ende von Akt 1 ----------

func finale() -> void:
	var h := PlayerStats.humanity()
	var lines := [{"who": N, "text": "Du bist zurück. Und du hast getrunken." if h < 60 else "Du bist zurück. Und du kämpfst noch gegen mich."}]
	if PlayerStats.flag("jory", "") == "proven":
		lines.append({"who": N, "text": "Du hast einen Unschuldigen gerettet. Rührend. Die Wacht wird wissen wollen, wer ihr ihre Hinrichtung gestohlen hat."})
	elif PlayerStats.flag("jory", "") == "drained":
		lines.append({"who": N, "text": "Der Junge im Käfig. Er war unschuldig, weißt du. Es hat trotzdem gut geschmeckt."})
	elif PlayerStats.flag("jory", "") == "hanged":
		lines.append({"who": N, "text": "Sie haben ihn gehängt, während du zugesehen hast. Die Wacht ist nah. Varek ist nah."})
	lines.append({"who": N, "text": "Ich kenne Vareks Schlafplatz. Bring mir das Blut eines Unschuldigen, und ich führe dich zu ihm."})
	say(lines, ["„Abgemacht.“", "„Ich hole mir Varek ohne dich.“", "„Ich werde einen Weg finden, dich zu zerstören.“"], _finale_choice, w.places.spots.ruin_altar)

func _finale_choice(i: int) -> void:
	match i:
		0:
			PlayerStats.s.protocol = int(PlayerStats.s.protocol) + 2
			PlayerStats.record_choice("Du hast der Ersten Nacht das Blut eines Unschuldigen versprochen.")
		1:
			PlayerStats.s.protocol = int(PlayerStats.s.protocol) - 1
			PlayerStats.record_choice("Du willst Varek – aber nicht zu ihrem Preis.")
		_:
			PlayerStats.s.protocol = int(PlayerStats.s.protocol) - 3
			PlayerStats.record_choice("Du hast geschworen, die Erste Nacht zu zerstören.")
	var end := func(_j):
		PlayerStats.set_story(5)
		w.show_chronicle()
	say([{"who": N, "text": ["Wir werden sehen, Soldat.", "Wir werden sehen, wer wen frisst.", "Versuch es. Ich bin geduldig."][mini(i, 2)]},
		{"who": S, "text": "AKT 1 ABGESCHLOSSEN.  Akt 2 beginnt: Die Kinder der Nacht. Krähe sprach von einem Schrein im Westen."}], [], end)
