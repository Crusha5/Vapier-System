extends Node
## Globaler Spielzustand (Autoload „PlayerStats“): Werte, Blut-Hunger, Menschlichkeit, Ausrüstung,
## Story-Flags, tote Figuren, Uhrzeit, tägliche Quests – und genau EIN Spielstand (kein Zurück).

signal stats_changed
signal leveled_up(level: int)
signal system_message(text: String, kind: String)  # sys, blood, warn, quest, reward, level, mini, choice, loot0..3
signal quests_changed
signal player_died
signal humanity_changed(old: float, new: float)
signal equipment_changed

const SAVE_PATH := "user://veyra_save.json"
const SAVE_VERSION := 3

## Stufen der Menschlichkeit
const TIERS := [
	[75.0, "Mensch", "Du spürst noch Wärme. Die Sonne brennt kaum."],
	[50.0, "Zwiegespalten", "Der Hunger flüstert. Du hörst noch weg."],
	[25.0, "Raubtier", "Menschen riechen nach Beute. Die Sonne brennt."],
	[0.0, "Bestie", "Nichts Menschliches mehr in deinen Augen. Der Tag ist dein Feind."],
]

const BLOOD_TYPES := {
	"animal": {"name": "Tierblut", "blood": 14.0, "xp": 4, "color": Color(0.55, 0.12, 0.1), "desc": "Stillt kaum. Schadet niemandem."},
	"beast": {"name": "Bestienblut", "blood": 24.0, "xp": 12, "color": Color(0.45, 0.2, 0.6), "desc": "Wild und bitter. 30 s: +30 % Schaden."},
	"human": {"name": "Menschenblut", "blood": 45.0, "xp": 40, "color": Color(0.9, 0.05, 0.12), "desc": "Das, wonach du dich sehnst. Jede Phiole kostet Menschlichkeit."},
}

## Skillbaum: neutral, Beschützer (braucht hohe Menschlichkeit), Bestie (braucht niedrige)
const SKILLS := {
	"shadow_dash": {"name": "Schattenschritt", "cost": 0, "req": {}, "path": "neutral", "slot": "dash",
		"desc": "Kurzer Sprung durch die Schatten. Unverwundbar. Kurz vor einem Treffer: Zeitlupe."},
	"blood_sense": {"name": "Blutsinn", "cost": 0, "req": {}, "path": "neutral", "slot": "sense",
		"desc": "Du siehst Herzschläge durch Wände und frische Blutspuren."},
	"blood_scythe": {"name": "Blutsichel", "cost": 1, "req": {"shd": 3}, "path": "neutral", "slot": "skill1",
		"desc": "Kreisender Blutschnitt. Kostet 12 Blut."},
	"mending": {"name": "Heilendes Blut", "cost": 1, "req": {"humanity_min": 55}, "path": "guardian",
		"desc": "Du kannst Verwundete mit deinem Blut heilen. Nippen nimmt weniger und tut nicht weh."},
	"warden": {"name": "Wächterblut", "cost": 1, "req": {"humanity_min": 65, "end": 5}, "path": "guardian",
		"desc": "+15 % Rüstung. Sonnenschaden halbiert."},
	"radiance": {"name": "Rote Morgenröte", "cost": 2, "req": {"humanity_min": 75, "shd": 6}, "path": "guardian", "slot": "skill2",
		"desc": "Eine Welle aus Blutlicht stößt Feinde zurück und heilt dich. Kostet 20 Blut."},
	"frenzy": {"name": "Raserei", "cost": 1, "req": {"humanity_max": 45}, "path": "beast",
		"desc": "Jeder Treffer stellt 2 Blut her. +20 % Angriffstempo bei Nacht."},
	"claws": {"name": "Klauen der Nacht", "cost": 1, "req": {"humanity_max": 35, "str": 5}, "path": "beast",
		"desc": "+25 % Nahkampfschaden. Getötete bluten mehr."},
	"dread": {"name": "Schreckensruf", "cost": 2, "req": {"humanity_max": 25, "shd": 6}, "path": "beast", "slot": "skill2",
		"desc": "Ein Schrei, der Menschen und Tiere in Panik versetzt. Kostet 18 Blut."},
}

const DAILY_POOL := {
	"feed_animal": {"text": "Trinke von %d Tieren", "goal": 3},
	"perfect_dash": {"text": "Absolviere %d perfekte Schattenschritte", "goal": 8},
	"kill_beast": {"text": "Erlege %d Bestien", "goal": 4},
	"kill_any": {"text": "Besiege %d Gegner", "goal": 10},
	"explore": {"text": "Entdecke %d neue Orte", "goal": 2},
	"spare": {"text": "Verschone %d Leben (nur nippen)", "goal": 2},
}

## Akt 1 – Die Erste Nacht
const STORY := [
	{"title": "Erwachen", "text": "Etwas ruft dich aus der Dunkelheit. Steh auf."},
	{"title": "Der Hunger", "text": "Verlass die Ruine. Du brauchst Blut."},
	{"title": "Asch-Furt", "text": "Folge dem Weg nach Südosten zum Dorf an der Furt."},
	{"title": "Der Gefangene", "text": "Jory soll bei Sonnenaufgang der Wacht ausgeliefert werden. Entscheide, was mit ihm geschieht."},
	{"title": "Was du bist", "text": "Kehre zur Ruine zurück. Die Erste Nacht will sprechen."},
	{"title": "Ende von Akt 1", "text": "Die Wacht weiß, dass du lebst. Akt 2 folgt. Bis dahin: Veyra gehört dir."},
]

var s: Dictionary = {}
var buffs: Dictionary = {}
var _save_timer := 0.0
var _warned_blood := false
var invulnerable := false
var paused_world := false
var in_sun := 0.0      # 0..1, von der Welt gesetzt
var night := 0.0       # von der Welt gesetzt
var brightness := 1.0  # Geräte-Einstellung, unabhängig vom Spielstand
signal settings_changed

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://settings.cfg") == OK:
		brightness = clampf(float(cf.get_value("video", "brightness", 1.0)), 0.6, 2.2)

func set_brightness(v: float) -> void:
	brightness = clampf(v, 0.6, 2.2)
	var cf := ConfigFile.new()
	cf.set_value("video", "brightness", brightness)
	cf.save("user://settings.cfg")
	settings_changed.emit()

func _ready() -> void:
	load_settings()
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not load_game():
		reset_game()

func reset_game() -> void:
	s = {
		"version": SAVE_VERSION,
		"started": false,
		"level": 1, "xp": 0, "attr_points": 0, "skill_points": 0,
		"str": 3, "agi": 3, "end": 3, "shd": 2,
		"hp": 100.0, "blood": 25.0,
		"humanity": 70.0,
		"protocol": 0,           # + gehorcht, − widersprochen
		"inventory": {"animal": 0, "beast": 0, "human": 0},
		"skills": ["shadow_dash", "blood_sense"],
		"kills": {"bandit": 0, "beast": 0, "animal": 0, "human": 0, "wacht": 0},
		"story": 0, "story_progress": 0,
		"flags": {},
		"dead": [],
		"fed": {},
		"discovered": [],
		"choices": [],           # Chronik der Entscheidungen
		"daily": {},
		"penalty_until": 0,
		"minutes": 19.0 * 60.0 + 20.0,
		"day": 1,
		"pos": [],
		"perfect_dashes": 0,
		"deaths": 0,
		"equip": {"weapon": Items.make("weapon", 1, 0, "blade"), "armor": {}, "relic": {}},
		"bag": [],
		"shards": 0,
		"camera_fp": false,
	}
	buffs.clear()
	s.hp = max_hp()
	_roll_daily(true)

# ---------- Abgeleitete Werte ----------

func stat(key: String) -> int:
	return int(s[key])

func humanity() -> float:
	return float(s.humanity)

func tier() -> int:
	for i in TIERS.size():
		if humanity() >= float(TIERS[i][0]):
			return i
	return TIERS.size() - 1

func tier_name() -> String:
	return TIERS[tier()][1]

func beastliness() -> float:
	return 1.0 - humanity() / 100.0

func gear(key: String) -> float:
	var v := 0.0
	for slot in s.equip:
		var it: Dictionary = s.equip[slot]
		if it.is_empty():
			continue
		v += float(it.base.get(key, 0.0)) + float(it.aff.get(key, 0.0))
	return v

func weapon_type() -> String:
	var w: Dictionary = s.equip.get("weapon", {})
	return String(w.get("type", "blade")) if not w.is_empty() else "blade"

func weapon_def() -> Dictionary:
	return Items.WEAPONS[weapon_type()]

func penalty_active() -> bool:
	return Time.get_unix_time_from_system() < float(s.penalty_until)

func max_hp() -> float:
	var v := 80.0 + stat("end") * 10.0 + (int(s.level) - 1) * 6.0 + gear("hp")
	if penalty_active():
		v *= 0.85
	return v

func max_blood() -> float:
	return 100.0

func starving() -> bool:
	return float(s.blood) <= 0.0

## Hunger: je mehr Bestie, desto schneller leer
func blood_drain() -> float:
	return 0.18 * (0.7 + beastliness() * 0.9) / (1.0 + stat("end") * 0.05) * maxf(0.4, 1.0 - gear("thrift"))

## Nachtbonus wächst mit der Bestie in dir
func night_power() -> float:
	return 1.0 + night * (0.05 + beastliness() * 0.3)

func move_speed() -> float:
	var v := 4.6 * (1.0 + stat("agi") * 0.02 + gear("speed")) * (1.0 + night * beastliness() * 0.15)
	if starving():
		v *= 0.82
	return v

func attack_speed() -> float:
	var v := (1.0 + stat("agi") * 0.035 + gear("aspd")) * float(weapon_def().aspd)
	if has_skill("frenzy") and night > 0.5:
		v *= 1.2
	return v

func melee_damage() -> float:
	var v := (9.0 + stat("str") * 2.4 + (int(s.level) - 1) * 0.8 + gear("atk")) * (1.0 + gear("dmg")) * float(weapon_def().dmg)
	v *= night_power()
	if has_skill("claws"):
		v *= 1.25
	if buffs.has("beast"):
		v *= 1.3
	if starving():
		v *= 0.75
	return v

func shadow_damage() -> float:
	var v := (14.0 + stat("shd") * 4.5 + (int(s.level) - 1) * 1.2) * (1.0 + gear("shadow")) * night_power()
	if starving():
		v *= 0.75
	return v

func cooldown_mult() -> float:
	return 1.0 / (1.0 + stat("shd") * 0.03 + gear("cdr"))

func dodge_chance() -> float:
	return minf(0.4, stat("agi") * 0.008 + gear("dodge"))

func crit_chance() -> float:
	return 0.05 + stat("agi") * 0.005 + gear("crit")

func armor() -> float:
	var v := minf(0.4, stat("end") * 0.012) + gear("armor")
	if has_skill("warden"):
		v += 0.15
	return minf(v, 0.65)

## Sonnenschaden pro Sekunde in voller Sonne
func sun_dps() -> float:
	var v := 0.4 + beastliness() * beastliness() * 9.0
	if has_skill("warden"):
		v *= 0.5
	return v

func xp_to_next() -> int:
	return int(80.0 * pow(float(s.level), 1.55))

func has_skill(id: String) -> bool:
	return (s.skills as Array).has(id)

func flag(k: String, default: Variant = false) -> Variant:
	return s.flags.get(k, default)

func set_flag(k: String, v: Variant = true) -> void:
	s.flags[k] = v
	save_game()

func is_dead(id: String) -> bool:
	return (s.dead as Array).has(id)

func clock_text() -> String:
	var m := int(s.minutes) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]

func clock_hour() -> int:
	return (int(s.minutes) % (24 * 60)) / 60

# ---------- Ablauf ----------

func _process(delta: float) -> void:
	if s.is_empty():
		return
	for b in buffs.keys():
		buffs[b] -= delta
		if buffs[b] <= 0.0:
			buffs.erase(b)
			stats_changed.emit()
	if paused_world or not s.started:
		return
	var before := float(s.minutes)
	s.minutes = float(s.minutes) + delta
	if s.minutes >= 24.0 * 60.0:
		s.minutes = float(s.minutes) - 24.0 * 60.0
		s.day = int(s.day) + 1
	var was_starving := starving()
	s.blood = maxf(0.0, float(s.blood) - blood_drain() * delta)
	if starving():
		if not was_starving:
			system_message.emit("BLUTMANGEL! Dein Körper zehrt sich selbst auf.", "warn")
		damage(2.5 * delta, true)
	elif float(s.blood) < 20.0 and not _warned_blood:
		_warned_blood = true
		system_message.emit("Der Hunger wird lauter. Blut unter 20 %.", "blood")
	if float(s.blood) > 30.0:
		_warned_blood = false
	if in_sun > 0.05:
		damage(sun_dps() * in_sun * delta, true)
	if s.daily.get("date", "") != Time.get_date_string_from_system():
		_roll_daily(false)
	_save_timer += delta
	if _save_timer > 15.0:
		_save_timer = 0.0
		save_game()

func damage(amount: float, true_damage := false) -> float:
	if float(s.hp) <= 0.0:
		return 0.0
	if invulnerable and not true_damage:
		return 0.0
	if not true_damage:
		if randf() < dodge_chance():
			return -1.0
		amount *= 1.0 - armor()
	s.hp = maxf(0.0, float(s.hp) - amount)
	stats_changed.emit()
	if float(s.hp) <= 0.0:
		s.deaths = int(s.deaths) + 1
		player_died.emit()
	return amount

func heal(amount: float) -> void:
	s.hp = minf(max_hp(), float(s.hp) + amount)
	stats_changed.emit()

func add_blood(amount: float) -> void:
	s.blood = clampf(float(s.blood) + amount, 0.0, max_blood())
	stats_changed.emit()

func spend_blood(amount: float) -> bool:
	if float(s.blood) < amount:
		system_message.emit("Nicht genug Blut.", "blood")
		return false
	s.blood = float(s.blood) - amount
	stats_changed.emit()
	return true

func change_humanity(delta_h: float, reason := "") -> void:
	var old := humanity()
	var old_tier := tier()
	s.humanity = clampf(old + delta_h, 0.0, 100.0)
	if absf(delta_h) >= 0.5:
		var sign_txt := "+" if delta_h > 0 else "−"
		system_message.emit("Menschlichkeit %s%d%s" % [sign_txt, int(round(absf(delta_h))), ("  ·  " + reason) if reason != "" else ""], "humanity_up" if delta_h > 0 else "humanity_down")
	if tier() != old_tier:
		system_message.emit("%s – %s" % [tier_name().to_upper(), TIERS[tier()][2]], "warn" if tier() > old_tier else "reward")
	humanity_changed.emit(old, humanity())
	stats_changed.emit()
	save_game()

func record_choice(text: String) -> void:
	(s.choices as Array).append({"day": int(s.day), "text": text})
	save_game()

func add_xp(amount: int) -> void:
	s.xp = int(s.xp) + amount
	while int(s.xp) >= xp_to_next():
		s.xp = int(s.xp) - xp_to_next()
		s.level = int(s.level) + 1
		s.attr_points = int(s.attr_points) + 3
		s.skill_points = int(s.skill_points) + 1
		s.hp = max_hp()
		leveled_up.emit(int(s.level))
		system_message.emit("STUFE %d.  +3 Attributpunkte, +1 Skillpunkt" % int(s.level), "level")
		save_game()
	stats_changed.emit()

func raise_attr(key: String) -> void:
	if int(s.attr_points) <= 0:
		return
	var old_max := max_hp()
	s[key] = int(s[key]) + 1
	s.attr_points = int(s.attr_points) - 1
	if key == "end":
		s.hp = float(s.hp) + (max_hp() - old_max)
	stats_changed.emit()

func skill_state(id: String) -> String:
	if has_skill(id):
		return "owned"
	var sk: Dictionary = SKILLS[id]
	for k in sk.req:
		if k == "humanity_min":
			if humanity() < float(sk.req[k]):
				return "locked"
		elif k == "humanity_max":
			if humanity() > float(sk.req[k]):
				return "locked"
		elif stat(k) < int(sk.req[k]):
			return "locked"
	if int(s.skill_points) < int(sk.cost):
		return "locked"
	return "ready"

func learn_skill(id: String) -> bool:
	if skill_state(id) != "ready":
		return false
	s.skill_points = int(s.skill_points) - int(SKILLS[id].cost)
	(s.skills as Array).append(id)
	system_message.emit("Fähigkeit erlernt: %s" % SKILLS[id].name, "reward")
	stats_changed.emit()
	save_game()
	return true

func grant_skill(id: String) -> void:
	if not has_skill(id):
		(s.skills as Array).append(id)
		stats_changed.emit()

# ---------- Blut ----------

func pick_vial(kind: String) -> void:
	s.inventory[kind] = int(s.inventory[kind]) + 1
	system_message.emit("+1 %s" % BLOOD_TYPES[kind].name, "mini")
	stats_changed.emit()

func best_vial() -> String:
	for k in ["animal", "beast", "human"]:
		if int(s.inventory[k]) > 0:
			return k
	return ""

func vial_count() -> int:
	return int(s.inventory.animal) + int(s.inventory.beast) + int(s.inventory.human)

func drink_vial(kind: String) -> bool:
	if kind == "" or int(s.inventory.get(kind, 0)) <= 0:
		return false
	var bt: Dictionary = BLOOD_TYPES[kind]
	s.inventory[kind] = int(s.inventory[kind]) - 1
	add_blood(float(bt.blood))
	heal(6.0)
	if kind == "beast":
		buffs["beast"] = 30.0
	if kind == "human":
		change_humanity(-2.0, "Phiole Menschenblut")
	add_xp(int(bt.xp))
	stats_changed.emit()
	return true

## Trinken direkt von einem Wesen. victim: {id, kind: animal/beast/human, innocent: bool, name}
## mode: "sip" (lebt weiter) oder "drain" (stirbt)
func feed(victim: Dictionary, mode: String) -> float:
	var kind: String = victim.get("kind", "animal")
	var innocent: bool = victim.get("innocent", true)
	var gained := 0.0
	match kind:
		"animal":
			gained = 18.0 if mode == "drain" else 9.0
			daily_progress("feed_animal")
		"beast":
			gained = 26.0 if mode == "drain" else 12.0
			buffs["beast"] = 30.0
		"human":
			gained = 70.0 if mode == "drain" else 28.0
			if has_skill("mending") and mode == "sip":
				gained *= 0.8
			if mode == "drain":
				change_humanity(-16.0 if innocent else -6.0, "%s ausgesaugt" % victim.get("name", "Mensch"))
			else:
				change_humanity(-1.0 if has_skill("mending") else -3.0, "von %s getrunken" % victim.get("name", "einem Menschen"))
				daily_progress("spare")
	add_blood(gained)
	heal(gained * 0.25)
	add_xp(int(gained * (1.2 if kind == "human" else 0.5)))
	if victim.has("id") and kind == "human":
		s.fed[victim.id] = mode
	save_game()
	return gained

# ---------- Kills ----------

func register_kill(kind: String, xp: int, npc_id := "", innocent := false) -> void:
	s.kills[kind] = int(s.kills.get(kind, 0)) + 1
	if npc_id != "" and not is_dead(npc_id):
		(s.dead as Array).append(npc_id)
	add_xp(xp)
	daily_progress("kill_any")
	if kind == "beast":
		daily_progress("kill_beast")
	if innocent:
		change_humanity(-10.0, "Unschuldigen getötet")
	save_game()

func mark_dead(npc_id: String) -> void:
	if OS.has_environment("SP_TRACE"):
		print("TEST mark_dead ", npc_id, " ", get_stack())
	if not is_dead(npc_id):
		(s.dead as Array).append(npc_id)
		save_game()

func discover(place_id: String, name: String) -> bool:
	if (s.discovered as Array).has(place_id):
		return false
	(s.discovered as Array).append(place_id)
	system_message.emit("Entdeckt: %s" % name, "quest")
	add_xp(40)
	daily_progress("explore")
	save_game()
	return true

# ---------- Story ----------

func story_title() -> String:
	return STORY[mini(int(s.story), STORY.size() - 1)].title

func story_text() -> String:
	var st: Dictionary = STORY[mini(int(s.story), STORY.size() - 1)]
	if st.has("goal") and int(st.goal) > 1:
		return "%s  (%d/%d)" % [st.text, int(s.story_progress), int(st.goal)]
	return st.text

func set_story(step: int) -> void:
	if step <= int(s.story):
		return
	s.story = step
	s.story_progress = 0
	if step > 1:
		add_xp(60 + step * 30)
	system_message.emit("Ziel: %s" % STORY[mini(step, STORY.size() - 1)].title, "quest")
	quests_changed.emit()
	save_game()

# ---------- Tägliche Quests ----------

func _roll_daily(fresh: bool) -> void:
	var today := Time.get_date_string_from_system()
	var old: Dictionary = s.get("daily", {})
	if not fresh and old.has("quests") and s.started:
		var all_done := true
		for q in old.quests:
			if not q.done:
				all_done = false
		if not all_done:
			s.penalty_until = Time.get_unix_time_from_system() + 30.0 * 60.0
			system_message.emit("SYSTEMSTRAFE: Tägliche Aufgaben verfehlt. Max. HP −15 % für 30 min.", "warn")
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(today)
	var keys := DAILY_POOL.keys()
	var picks: Array = []
	while picks.size() < 3:
		var k: String = keys[rng.randi() % keys.size()]
		if not picks.has(k):
			picks.append(k)
	var qs: Array = []
	for k in picks:
		qs.append({"id": k, "goal": int(DAILY_POOL[k].goal), "progress": 0, "done": false})
	s.daily = {"date": today, "quests": qs, "bonus": false}
	if not fresh:
		system_message.emit("Neue tägliche Aufgaben des Protokolls.", "quest")
	quests_changed.emit()

func daily_text(q: Dictionary) -> String:
	return DAILY_POOL[q.id].text % int(q.goal)

func daily_progress(id: String, amount := 1) -> void:
	if not s.started or not s.daily.has("quests"):
		return
	for q in s.daily.quests:
		if q.id == id and not q.done:
			q.progress = mini(int(q.goal), int(q.progress) + amount)
			if int(q.progress) >= int(q.goal):
				q.done = true
				s.attr_points = int(s.attr_points) + 1
				system_message.emit("Aufgabe erfüllt: %s  (+1 Attributpunkt)" % daily_text(q), "quest")
				add_xp(100)
				_check_daily_bonus()
			quests_changed.emit()

func _check_daily_bonus() -> void:
	if s.daily.bonus:
		return
	for q in s.daily.quests:
		if not q.done:
			return
	s.daily.bonus = true
	s.skill_points = int(s.skill_points) + 1
	system_message.emit("Alle Aufgaben erfüllt!  +1 Skillpunkt", "reward")
	save_game()

# ---------- Ausrüstung ----------

func add_item(it: Dictionary) -> bool:
	if (s.bag as Array).size() >= 30:
		system_message.emit("Tasche voll! Zerlege Gegenstände im System-Menü.", "warn")
		return false
	(s.bag as Array).append(it)
	system_message.emit("%s: %s" % [Items.RARITY[int(it.rarity)].name, it.name], "loot%d" % int(it.rarity))
	stats_changed.emit()
	return true

func equip_item(idx: int) -> void:
	var bag: Array = s.bag
	if idx < 0 or idx >= bag.size():
		return
	var it: Dictionary = bag[idx]
	var old: Dictionary = s.equip.get(it.slot, {})
	var old_max := max_hp()
	bag.remove_at(idx)
	if not old.is_empty():
		bag.insert(idx, old)
	s.equip[it.slot] = it
	s.hp = clampf(float(s.hp) + (max_hp() - old_max), 1.0, max_hp())
	equipment_changed.emit()
	stats_changed.emit()
	save_game()

func salvage(idx: int) -> void:
	var bag: Array = s.bag
	if idx < 0 or idx >= bag.size():
		return
	var it: Dictionary = bag[idx]
	bag.remove_at(idx)
	var v := Items.value(it)
	s.shards = int(s.shards) + v
	system_message.emit("Zerlegt: %s  (+%d Blutsplitter)" % [it.name, v], "mini")
	stats_changed.emit()

func shop_items() -> Array:
	var today := str(int(s.day))
	var sh: Dictionary = s.get("shop", {})
	if sh.get("day", "") != today or (sh.get("items", []) as Array).is_empty():
		var lvl := int(s.level)
		var items: Array = []
		items.append(Items.make("weapon", lvl, 1 + int(randf() < 0.35)))
		items.append(Items.make("armor", lvl, 1 + int(randf() < 0.35)))
		items.append(Items.make("relic", lvl, 1 + int(randf() < 0.35)))
		items.append(Items.make(["weapon", "armor", "relic"][randi() % 3], lvl + 1, 2 + int(randf() < 0.15)))
		sh = {"day": today, "items": items}
		s.shop = sh
	return sh.items

func buy(idx: int) -> bool:
	var items: Array = s.shop.items
	if idx < 0 or idx >= items.size():
		return false
	var it: Dictionary = items[idx]
	var p := Items.price(it)
	if int(s.shards) < p:
		system_message.emit("Nicht genug Blutsplitter.", "warn")
		return false
	if not add_item(it):
		return false
	s.shards = int(s.shards) - p
	items.remove_at(idx)
	save_game()
	return true

func add_shards(n: int) -> void:
	s.shards = int(s.shards) + n
	stats_changed.emit()

# ---------- Spielstand (nur einer) ----------

func save_game() -> void:
	if s.is_empty() or not s.get("started", false):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and OS.get_environment("SP_FRESH") != "1"

func load_game() -> bool:
	if not has_save():
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or int(data.get("version", 0)) != SAVE_VERSION:
		return false
	reset_game()
	for k in data:
		s[k] = data[k]
	return true

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
