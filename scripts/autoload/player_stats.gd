extends Node
## Globaler Spielzustand (Autoload „PlayerStats“):
## Attribute, Blut-Hunger, Level, Buffs, Inventar, Skills, Quests, Verdacht, Ingame-Uhr und Spielstand.

signal stats_changed
signal leveled_up(level: int)
signal system_message(text: String, kind: String)  # kind: sys, blood, warn, quest, reward, level
signal quests_changed
signal player_died
signal suspicion_alarm
signal equipment_changed

const SAVE_PATH := "user://sanguine_save.json"
const SAVE_VERSION := 1

const BLOOD_TYPES := {
	"karkosa": {"name": "Karkosa-Blut", "blood": 22.0, "xp": 10, "color": Color(0.25, 0.95, 0.75),
		"desc": "Füllt Blut auf. 30 s: +25 % Rüstung, +30 % Nahkampfschaden."},
	"mutant": {"name": "Mutanten-Blut", "blood": 20.0, "xp": 12, "color": Color(0.72, 0.4, 1.0),
		"desc": "Füllt Blut auf. 30 s: +40 % Schattenschaden, −25 % Abklingzeit."},
	"human": {"name": "Menschliches Blut", "blood": 48.0, "xp": 60, "color": Color(1.0, 0.16, 0.22),
		"desc": "Stellt am meisten Blut her und gibt viel EXP – erhöht aber den Verdacht der Akademie."},
}

## Skill-Baum. req = Mindestwerte, cost = Skillpunkte, slot = eigener Aktionsknopf
const SKILLS := {
	"shadow_dash": {"name": "Schatten-Dash", "cost": 0, "req": {}, "slot": "dash",
		"desc": "Kurzer Sprung durch die Schatten. Unverwundbar während des Dashes. Ein Dash kurz vor einem Treffer ist perfekt: Zeitlupe."},
	"blood_scythe": {"name": "Blutsichel", "cost": 0, "req": {}, "slot": "skill1",
		"desc": "Kreisender Blutschnitt um dich herum. Kostet 12 Blut. Skaliert mit SHD."},
	"night_veil": {"name": "Nachtschleier", "cost": 1, "req": {"shd": 3}, "slot": "",
		"desc": "Halbiert den Verdacht durch menschliches Blut. Verdacht sinkt doppelt so schnell."},
	"crimson_feast": {"name": "Blutfest", "cost": 1, "req": {"str": 6}, "slot": "",
		"desc": "Jeder Nahkampftreffer stellt 1,5 Blut wieder her."},
	"iron_vessel": {"name": "Eisernes Gefäß", "cost": 1, "req": {"end": 6}, "slot": "",
		"desc": "Maximales Blut 130 statt 100."},
	"shadow_echo": {"name": "Schattenecho", "cost": 1, "req": {"shd": 5}, "slot": "",
		"desc": "Am Startpunkt jedes Dashes explodiert ein Schattenabbild."},
	"predator_sense": {"name": "Jägersinn", "cost": 1, "req": {"agi": 6}, "slot": "",
		"desc": "+10 % kritische Trefferchance. Verborgene Orte flackern leicht."},
	"blood_lance": {"name": "Blutlanze", "cost": 2, "req": {"shd": 8}, "slot": "skill2",
		"desc": "Durchschlagender Blutspeer in Blickrichtung. Kostet 18 Blut."},
	"eclipse": {"name": "Eklipse", "cost": 0, "req": {}, "slot": "skill3", "hidden": true,
		"desc": "Verborgener Skill. Die Welt erstarrt 4 s lang, deine Schläge zerreißen die Dunkelheit. Kostet 35 Blut."},
}

const DAILY_POOL := {
	"perfect_dash": {"text": "Absolviere %d perfekte Dashes", "goal": 20},
	"capsules": {"text": "Erbeute %d Blut-Kapseln", "goal": 5},
	"kill_karkosa": {"text": "Vernichte %d Karkosa", "goal": 12},
	"kill_any": {"text": "Besiege %d Gegner", "goal": 25},
	"skill_use": {"text": "Setze %d Blut-Skills ein", "goal": 10},
	"drink": {"text": "Trinke %d Blut-Essenzen", "goal": 6},
}

## Hauptstory – Kapitel 1
const STORY := [
	{"title": "Das alte Archiv", "text": "Untersuche das pulsierende Relikt in den Archivruinen."},
	{"title": "Erstes Blut", "text": "Überlebe den Karkosa-Einbruch im Archiv.", "goal": 6},
	{"title": "Rangordnung", "text": "Stelle dich Rivale Drax in der Trainingshalle.", "goal": 1},
	{"title": "Der Riss", "text": "Zerstöre das Karkosa-Nest im Ostflügel.", "goal": 1},
	{"title": "Fragen ohne Antwort", "text": "Kehre zum Relikt zurück. Das Protokoll will sprechen."},
	# Kapitel 2 – Knochen und Erinnerung
	{"title": "Ein Verbündeter?", "text": "Eine Kadettin namens Mira will dich im Schlafsaal sprechen.", "chapter": 2},
	{"title": "Gestohlene Karte", "text": "Besiege den Schlächter im Innenhof und hol Branns Zugangskarte zurück.", "goal": 1, "chapter": 2},
	{"title": "Abstieg", "text": "Nutze den alten Aufzug im Archiv (Südost-Ecke), um in die Katakomben zu gelangen.", "chapter": 2},
	{"title": "Erinnerungen in Knochen", "text": "Finde die Erinnerungsfragmente des ersten Wirts in den Katakomben.", "goal": 3, "chapter": 2},
	{"title": "Die Brutmutter", "text": "Töte die Brutmutter in der Brutkammer tief unter der Akademie.", "goal": 1, "chapter": 2},
	{"title": "Nachtfürst", "text": "Kapitel 2 abgeschlossen. Erkunde, jage, werde stärker – Kapitel 3 folgt.", "chapter": 2},
]

## Nebenquests (von NPCs)
const SIDE := {
	"mira_blood": {"title": "Blutschuld", "giver": "Mira", "text": "Bring Mira 2 Karkosa-Blut-Essenzen für ihre Forschung.", "goal": 2},
	"brann_pest": {"title": "Ungeziefer", "giver": "Brann", "text": "Vernichte 15 Karkosa für den Quartiermeister.", "goal": 15},
	"brann_crypt": {"title": "Gruftplünderer", "giver": "Brann", "text": "Besiege 10 Gegner in den Katakomben.", "goal": 10},
}

var s: Dictionary = {}
var buffs: Dictionary = {}  # name -> Restsekunden
var _save_timer := 0.0
var _warned_blood := false
var invulnerable := false
var paused_world := false  # Menü offen / Intro: Hunger pausiert

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not load_game():
		reset_game()

func reset_game() -> void:
	s = {
		"version": SAVE_VERSION,
		"awakened": false,
		"level": 1, "xp": 0, "attr_points": 0, "skill_points": 0,
		"str": 3, "agi": 3, "end": 3, "shd": 1,
		"hp": 110.0, "blood": 70.0,
		"suspicion": 0.0,
		"inventory": {"karkosa": 0, "mutant": 0, "human": 0},
		"drunk": {"karkosa": 0, "mutant": 0, "human": 0},
		"skills": ["shadow_dash", "blood_scythe"],
		"kills": {"karkosa": 0, "mutant": 0, "cadet": 0, "instructor": 0},
		"story": 0, "story_progress": 0,
		"daily": {},
		"penalty_until": 0,
		"hidden": {"midnight_vault": false, "chimera": false},
		"chimera": false,
		"clock": 21.0 * 60.0,  # Ingame-Minuten seit Mitternacht
		"perfect_dashes": 0,
		"deaths": 0,
		"equip": {"weapon": Items.make("weapon", 1, 0, "blade"), "armor": {}, "relic": {}},
		"bag": [],
		"shards": 0,
		"side": {},
		"lift_unlocked": false,
		"fragments": [],
		"shop": {"day": "", "items": []},
		"best_combo": 0,
	}
	buffs.clear()
	s.hp = max_hp()
	_roll_daily(true)

# ---------- Abgeleitete Werte ----------

func stat(key: String) -> int:
	var v: int = int(s[key])
	if s.chimera:
		v += 2
	return v

## Summe einer Eigenschaft über die angelegte Ausrüstung
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
	return 130.0 if has_skill("iron_vessel") else 100.0

func starving() -> bool:
	return float(s.blood) <= 0.0

func blood_drain() -> float:
	return 0.42 / (1.0 + stat("end") * 0.06) * maxf(0.4, 1.0 - gear("thrift"))

func move_speed() -> float:
	var v := 5.2 * (1.0 + stat("agi") * 0.02 + gear("speed"))
	if starving():
		v *= 0.82
	return v

func attack_speed() -> float:
	return (1.0 + stat("agi") * 0.035 + gear("aspd")) * float(weapon_def().aspd)

func melee_damage() -> float:
	var v := (9.0 + stat("str") * 2.4 + (int(s.level) - 1) * 0.8 + gear("atk")) * (1.0 + gear("dmg")) * float(weapon_def().dmg)
	if buffs.has("frenzy"):
		v *= 1.15
	if buffs.has("karkosa"):
		v *= 1.3
	if starving():
		v *= 0.75
	return v

func shadow_damage() -> float:
	var v := (14.0 + stat("shd") * 4.5 + (int(s.level) - 1) * 1.2) * (1.0 + gear("shadow"))
	if buffs.has("mutant"):
		v *= 1.4
	if starving():
		v *= 0.75
	return v

func cooldown_mult() -> float:
	var v := 1.0 / (1.0 + stat("shd") * 0.03 + gear("cdr"))
	if buffs.has("mutant"):
		v *= 0.75
	return v

func dodge_chance() -> float:
	return minf(0.4, stat("agi") * 0.008 + gear("dodge"))

func crit_chance() -> float:
	return 0.05 + stat("agi") * 0.005 + (0.1 if has_skill("predator_sense") else 0.0) + gear("crit")

func armor() -> float:
	var v := minf(0.4, stat("end") * 0.012) + gear("armor")
	if buffs.has("karkosa"):
		v += 0.25
	return minf(v, 0.6)

func xp_to_next() -> int:
	return int(80.0 * pow(float(s.level), 1.55))

func has_skill(id: String) -> bool:
	return (s.skills as Array).has(id)

func clock_text() -> String:
	var m := int(s.clock) % (24 * 60)
	return "%02d:%02d" % [m / 60, m % 60]

func clock_hour() -> int:
	return (int(s.clock) % (24 * 60)) / 60

# ---------- Ablauf ----------

func _process(delta: float) -> void:
	if s.is_empty():
		return
	for b in buffs.keys():
		buffs[b] -= delta
		if buffs[b] <= 0.0:
			buffs.erase(b)
			stats_changed.emit()
	if paused_world or not s.awakened:
		return
	s.clock = fmod(float(s.clock) + delta, 24.0 * 60.0)
	# Hunger
	var was_starving := starving()
	s.blood = max(0.0, float(s.blood) - blood_drain() * delta)
	if starving():
		if not was_starving:
			system_message.emit("BLUTMANGEL! Dein Körper zehrt sich selbst auf.", "warn")
		damage(3.0 * delta, true)
	elif float(s.blood) < 20.0 and not _warned_blood:
		_warned_blood = true
		system_message.emit("Warnung: Blutreserve unter 20 %.", "blood")
	if float(s.blood) > 30.0:
		_warned_blood = false
	# Verdacht klingt ab
	var decay := 0.12 * (2.0 if has_skill("night_veil") else 1.0)
	s.suspicion = max(0.0, float(s.suspicion) - decay * delta)
	# Tageswechsel der Daily Quests (Echtzeit)
	if s.daily.get("date", "") != Time.get_date_string_from_system():
		_roll_daily(false)
	_save_timer += delta
	if _save_timer > 20.0:
		_save_timer = 0.0
		save_game()

func damage(amount: float, true_damage := false) -> float:
	if float(s.hp) <= 0.0:
		return 0.0
	if invulnerable and not true_damage:
		return 0.0
	if not true_damage:
		if randf() < dodge_chance():
			system_message.emit("Ausgewichen", "mini")
			return -1.0
		amount *= 1.0 - armor()
	s.hp = max(0.0, float(s.hp) - amount)
	stats_changed.emit()
	if float(s.hp) <= 0.0:
		s.deaths = int(s.deaths) + 1
		player_died.emit()
	return amount

func heal(amount: float) -> void:
	s.hp = min(max_hp(), float(s.hp) + amount)
	stats_changed.emit()

func add_blood(amount: float) -> void:
	s.blood = clamp(float(s.blood) + amount, 0.0, max_blood())
	stats_changed.emit()

func spend_blood(amount: float) -> bool:
	if float(s.blood) < amount:
		system_message.emit("Nicht genug Blut.", "blood")
		return false
	s.blood = float(s.blood) - amount
	stats_changed.emit()
	return true

func add_xp(amount: int) -> void:
	s.xp = int(s.xp) + amount
	while int(s.xp) >= xp_to_next():
		s.xp = int(s.xp) - xp_to_next()
		s.level = int(s.level) + 1
		s.attr_points = int(s.attr_points) + 3
		s.skill_points = int(s.skill_points) + 1
		s.hp = max_hp()
		leveled_up.emit(int(s.level))
		system_message.emit("LEVEL UP!  Stufe %d erreicht.  +3 Attributpunkte, +1 Skillpunkt" % int(s.level), "level")
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
	## "owned", "ready" (kann gelernt werden), "locked"
	if has_skill(id):
		return "owned"
	var sk: Dictionary = SKILLS[id]
	if sk.get("hidden", false):
		return "locked"
	for k in sk.req:
		if stat(k) < int(sk.req[k]):
			return "locked"
	if int(s.skill_points) < int(sk.cost):
		return "locked"
	return "ready"

func learn_skill(id: String) -> bool:
	if skill_state(id) != "ready":
		return false
	s.skill_points = int(s.skill_points) - int(SKILLS[id].cost)
	(s.skills as Array).append(id)
	system_message.emit("Skill erlernt: %s" % SKILLS[id].name, "reward")
	stats_changed.emit()
	save_game()
	return true

func grant_skill(id: String) -> void:
	if not has_skill(id):
		(s.skills as Array).append(id)
		stats_changed.emit()

# ---------- Blut-Essenzen ----------

func pick_capsule(kind: String) -> void:
	s.inventory[kind] = int(s.inventory[kind]) + 1
	system_message.emit("+1 %s" % BLOOD_TYPES[kind].name, "mini")
	daily_progress("capsules")
	stats_changed.emit()

func best_capsule() -> String:
	## Was „Trinken“ nimmt: bei Hunger zuerst Menschenblut nur, wenn nichts anderes da ist.
	for k in ["karkosa", "mutant", "human"]:
		if int(s.inventory[k]) > 0:
			return k
	return ""

func capsule_count() -> int:
	return int(s.inventory.karkosa) + int(s.inventory.mutant) + int(s.inventory.human)

func drink(kind: String) -> bool:
	if kind == "" or int(s.inventory.get(kind, 0)) <= 0:
		return false
	var bt: Dictionary = BLOOD_TYPES[kind]
	s.inventory[kind] = int(s.inventory[kind]) - 1
	s.drunk[kind] = int(s.drunk[kind]) + 1
	add_blood(float(bt.blood))
	heal(8.0)
	match kind:
		"karkosa":
			buffs["karkosa"] = 30.0
			system_message.emit("Karkosa-Blut: Chitinhaut aktiv (30 s)", "blood")
		"mutant":
			buffs["mutant"] = 30.0
			system_message.emit("Mutanten-Blut: Schatten verstärkt (30 s)", "blood")
		"human":
			var gain := 22.0 * (0.5 if has_skill("night_veil") else 1.0)
			add_suspicion(gain)
			system_message.emit("Menschliches Blut … es schmeckt nach Leben.", "blood")
	add_xp(int(bt.xp))
	daily_progress("drink")
	_check_chimera()
	stats_changed.emit()
	return true

func add_suspicion(v: float) -> void:
	var before := float(s.suspicion)
	s.suspicion = min(100.0, before + v)
	if before < 50.0 and float(s.suspicion) >= 50.0:
		system_message.emit("Gerüchte machen die Runde. Verdacht 50 %.", "warn")
	if before < 80.0 and float(s.suspicion) >= 80.0:
		system_message.emit("Die Ausbilder werden aufmerksam! Verdacht 80 %.", "warn")
	if float(s.suspicion) >= 100.0:
		s.suspicion = 55.0
		system_message.emit("ENTDECKUNGSGEFAHR! Ein Ausbilder jagt dich.", "warn")
		suspicion_alarm.emit()
	stats_changed.emit()

func _check_chimera() -> void:
	if s.hidden.chimera:
		return
	if int(s.drunk.karkosa) >= 3 and int(s.drunk.mutant) >= 3 and int(s.drunk.human) >= 3:
		s.hidden.chimera = true
		s.chimera = true
		system_message.emit("VERBORGENE QUEST ABGESCHLOSSEN: „Drei Blutlinien“", "quest")
		system_message.emit("Legendär erhalten: Chimären-Herz  (+2 auf alle Attribute)", "reward")
		add_xp(250)
		save_game()

# ---------- Kills & Story ----------

func register_kill(kind: String, xp: int) -> void:
	s.kills[kind] = int(s.kills.get(kind, 0)) + 1
	add_xp(xp)
	daily_progress("kill_any")
	if kind == "karkosa":
		daily_progress("kill_karkosa")
	if kind == "cadet":
		add_suspicion(6.0 * (0.5 if has_skill("night_veil") else 1.0))
	if kind == "karkosa":
		side_progress("brann_pest")

func story_step() -> int:
	return int(s.story)

func story_title() -> String:
	return STORY[min(int(s.story), STORY.size() - 1)].title

func story_text() -> String:
	var st: Dictionary = STORY[min(int(s.story), STORY.size() - 1)]
	if st.has("goal") and int(st.goal) > 1:
		return "%s  (%d/%d)" % [st.text, int(s.story_progress), int(st.goal)]
	return st.text

func story_advance_progress(step: int) -> void:
	if int(s.story) != step:
		return
	s.story_progress = int(s.story_progress) + 1
	var st: Dictionary = STORY[step]
	if int(s.story_progress) >= int(st.get("goal", 1)):
		set_story(step + 1)
	else:
		quests_changed.emit()

func set_story(step: int) -> void:
	if step <= int(s.story):
		return
	s.story = step
	s.story_progress = 0
	if step > 1:
		add_xp(80 + step * 30)
	system_message.emit("Neue Hauptquest: %s" % STORY[min(step, STORY.size() - 1)].title, "quest")
	quests_changed.emit()
	save_game()

# ---------- Daily Quests ----------

func _roll_daily(fresh: bool) -> void:
	var today := Time.get_date_string_from_system()
	var old: Dictionary = s.get("daily", {})
	if not fresh and old.has("quests") and s.awakened:
		var all_done := true
		for q in old.quests:
			if not q.done:
				all_done = false
		if not all_done:
			s.penalty_until = Time.get_unix_time_from_system() + 30.0 * 60.0
			system_message.emit("SYSTEMSTRAFE: Tägliche Quests verfehlt. Quarantäne – max. HP −15 % für 30 min.", "warn")
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
		system_message.emit("Neue tägliche System-Quests verfügbar.", "quest")
	quests_changed.emit()

func daily_text(q: Dictionary) -> String:
	return DAILY_POOL[q.id].text % int(q.goal)

func daily_progress(id: String, amount := 1) -> void:
	if not s.awakened or not s.daily.has("quests"):
		return
	for q in s.daily.quests:
		if q.id == id and not q.done:
			q.progress = min(int(q.goal), int(q.progress) + amount)
			if int(q.progress) >= int(q.goal):
				q.done = true
				s.attr_points = int(s.attr_points) + 1
				system_message.emit("Tägliche Quest erfüllt: %s  (+1 Attributpunkt)" % daily_text(q), "quest")
				add_xp(120)
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
	system_message.emit("Alle täglichen Quests erfüllt!  +1 Skillpunkt", "reward")
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

func add_shards(n: int) -> void:
	s.shards = int(s.shards) + n
	stats_changed.emit()

func shop_items() -> Array:
	var today := Time.get_date_string_from_system() + str(int(s.story) / 3)
	if s.shop.get("day", "") != today or (s.shop.items as Array).is_empty():
		var lvl := int(s.level)
		var items: Array = []
		items.append(Items.make("weapon", lvl, 1 + int(randf() < 0.35)))
		items.append(Items.make("armor", lvl, 1 + int(randf() < 0.35)))
		items.append(Items.make("relic", lvl, 1 + int(randf() < 0.35)))
		items.append(Items.make(["weapon", "armor", "relic"][randi() % 3], lvl + 1, 2 + int(randf() < 0.15)))
		s.shop = {"day": today, "items": items}
	return s.shop.items

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

# ---------- Nebenquests ----------

func side_state(id: String) -> String:
	## "", "active", "ready" (Ziel erreicht), "done"
	var q: Dictionary = s.side.get(id, {})
	if q.is_empty():
		return ""
	if q.get("done", false):
		return "done"
	if int(q.progress) >= int(SIDE[id].goal):
		return "ready"
	return "active"

func side_start(id: String) -> void:
	if not s.side.has(id):
		s.side[id] = {"progress": 0, "done": false}
		system_message.emit("Neue Nebenquest: %s" % SIDE[id].title, "quest")
		quests_changed.emit()

func side_progress(id: String, amount := 1) -> void:
	if side_state(id) != "active":
		return
	s.side[id].progress = min(int(SIDE[id].goal), int(s.side[id].progress) + amount)
	if int(s.side[id].progress) >= int(SIDE[id].goal):
		system_message.emit("Nebenquest bereit zur Abgabe: %s (bei %s)" % [SIDE[id].title, SIDE[id].giver], "quest")
	quests_changed.emit()

func side_finish(id: String) -> void:
	s.side[id].done = true
	add_xp(150 + int(s.level) * 20)
	system_message.emit("Nebenquest abgeschlossen: %s" % SIDE[id].title, "quest")
	quests_changed.emit()
	save_game()

# ---------- Spielstand ----------

func save_game() -> void:
	if s.is_empty():
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(s))

func load_game() -> bool:
	if OS.get_environment("SP_FRESH") == "1" or not FileAccess.file_exists(SAVE_PATH):
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
	# JSON liefert Zahlen als float – Listen/Dicts bleiben erhalten
	return true

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
