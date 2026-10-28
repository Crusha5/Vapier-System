class_name Items
extends RefCounted
## Ausrüstung: Waffen, Uniformen und Relikte mit Seltenheit und zufälligen Eigenschaften.

const RARITY := [
	{"name": "Gewöhnlich", "color": Color(0.78, 0.8, 0.84), "affixes": 1, "mult": 1.0},
	{"name": "Selten", "color": Color(0.35, 0.7, 1.0), "affixes": 2, "mult": 1.25},
	{"name": "Episch", "color": Color(0.78, 0.42, 1.0), "affixes": 3, "mult": 1.55},
	{"name": "Legendär", "color": Color(1.0, 0.72, 0.2), "affixes": 4, "mult": 1.9},
]

const SLOTS := {"weapon": "Waffe", "armor": "Uniform", "relic": "Relikt"}

## Waffenarten verändern die Kampfweise
const WEAPONS := {
	"blade": {"name": "Blutklinge", "reach": 0.0, "aspd": 1.0, "dmg": 1.0, "arc": 0.15, "len": 0.95, "width": 0.05,
		"desc": "Ausgewogen."},
	"scythe": {"name": "Schattensense", "reach": 0.9, "aspd": 0.78, "dmg": 1.3, "arc": -0.25, "len": 1.45, "width": 0.09,
		"desc": "Große Reichweite, breiter Schwung, langsamer."},
	"daggers": {"name": "Zwillingsdolche", "reach": -0.45, "aspd": 1.4, "dmg": 0.78, "arc": 0.3, "len": 0.55, "width": 0.04,
		"desc": "Sehr schnell, zwei Klingen, kurze Reichweite."},
}
const ARMORS := ["Wacht-Uniform", "Schattenmantel", "Chitinharnisch", "Nachtjäger-Montur"]
const RELICS := ["Blutamulett", "Schleiersplitter", "Runensplitter", "Gruftsiegel"]
const LEGEND_PREFIX := ["Varek's", "Der Ersten Nacht", "Morrow-", "Eklipsen-", "Krähen-"]

## Eigenschaften: Anzeigename, Grundwert je Stufe, Format
const AFFIX := {
	"dmg": {"name": "Nahkampfschaden", "base": 0.06, "pct": true},
	"shadow": {"name": "Schattenschaden", "base": 0.08, "pct": true},
	"crit": {"name": "Kritische Chance", "base": 0.03, "pct": true},
	"aspd": {"name": "Angriffstempo", "base": 0.05, "pct": true},
	"leech": {"name": "Blut pro Treffer", "base": 0.5, "pct": false},
	"hp": {"name": "Max. HP", "base": 12.0, "pct": false, "lvl": true},
	"armor": {"name": "Rüstung", "base": 0.03, "pct": true},
	"speed": {"name": "Lauftempo", "base": 0.04, "pct": true},
	"cdr": {"name": "Abklingzeit", "base": 0.05, "pct": true},
	"thrift": {"name": "Blutverbrauch", "base": 0.06, "pct": true, "neg": true},
	"dodge": {"name": "Ausweichen", "base": 0.025, "pct": true},
}
const SLOT_AFFIX := {
	"weapon": ["dmg", "crit", "aspd", "leech", "shadow"],
	"armor": ["hp", "armor", "speed", "dodge", "thrift"],
	"relic": ["shadow", "cdr", "thrift", "leech", "crit", "hp"],
}

static func roll_rarity(luck := 0.0) -> int:
	var r := randf() - luck
	if r < 0.03:
		return 3
	if r < 0.14:
		return 2
	if r < 0.42:
		return 1
	return 0

static func make(slot: String, lvl: int, rarity: int, wtype := "") -> Dictionary:
	var it := {"id": randi(), "slot": slot, "lvl": lvl, "rarity": rarity, "base": {}, "aff": {}}
	var rm: float = RARITY[rarity].mult
	match slot:
		"weapon":
			var choices: Array[String] = ["blade", "blade", "scythe", "daggers"]
			var t: String = wtype if wtype != "" else choices[randi() % 4]
			it.type = t
			it.name = WEAPONS[t].name
			it.base = {"atk": snappedf((4.0 + lvl * 1.6) * rm, 0.1)}
		"armor":
			it.name = ARMORS[randi() % ARMORS.size()]
			it.base = {"hp": snappedf((14.0 + lvl * 5.0) * rm, 1.0), "armor": snappedf(0.02 * rm, 0.001)}
		"relic":
			it.name = RELICS[randi() % RELICS.size()]
			it.base = {"shadow": snappedf(0.06 * rm, 0.001)}
	if rarity == 3:
		var pre: String = LEGEND_PREFIX[randi() % LEGEND_PREFIX.size()]
		it.name = pre + ("" if pre.ends_with("-") else " ") + String(it.name)
	var pool: Array = (SLOT_AFFIX[slot] as Array).duplicate()
	pool.shuffle()
	for i in min(int(RARITY[rarity].affixes), pool.size()):
		var k: String = pool[i]
		var a: Dictionary = AFFIX[k]
		var v: float = float(a.base) * randf_range(0.7, 1.3) * (1.0 + rarity * 0.35)
		if a.get("lvl", false):
			v *= 1.0 + lvl * 0.25
		else:
			v *= 1.0 + lvl * 0.04
		it.aff[k] = snappedf(v, 0.001 if a.pct else 0.1)
	return it

static func random_drop(lvl: int, luck := 0.0, min_rarity := 0) -> Dictionary:
	var slot: String = ["weapon", "armor", "relic"][randi() % 3]
	return make(slot, lvl, max(min_rarity, roll_rarity(luck)))

## Aufwertung mit Bestienkristallen: jede Stufe +9 % auf die Grundwerte
static func plus(it: Dictionary) -> int:
	return int(it.get("plus", 0))

static func title(it: Dictionary) -> String:
	var p := plus(it)
	return String(it.name) + (" +%d" % p if p > 0 else "")

static func upgrade(it: Dictionary) -> void:
	if not it.has("base0"):
		it.base0 = (it.base as Dictionary).duplicate()
	it.plus = plus(it) + 1
	var b0: Dictionary = it.base0
	for k in b0:
		var v := float(b0[k]) * (1.0 + 0.12 * float(it.plus))
		it.base[k] = snappedf(v, 0.1 if k == "atk" or k == "hp" else 0.001)
	# Jede Stufe stärkt zusätzlich die Kerneigenschaft des Teils
	var core := {"weapon": ["dmg", 0.04], "armor": ["hp", 8.0 + float(it.lvl)], "relic": ["shadow", 0.04]}
	var c: Array = core.get(it.slot, ["dmg", 0.0])
	it.aff[c[0]] = snappedf(float(it.aff.get(c[0], 0.0)) + float(c[1]), 0.001)

static func color(it: Dictionary) -> Color:
	return RARITY[int(it.rarity)].color

static func value(it: Dictionary) -> int:
	return int(pow(int(it.rarity) + 1, 2) * (int(it.lvl) + 3)) + plus(it) * 12

static func price(it: Dictionary) -> int:
	return value(it) * 3

static func fmt(k: String, v: float) -> String:
	var a: Dictionary = AFFIX.get(k, {"name": k, "pct": false})
	if k == "atk":
		return "+%d Angriff" % int(v)
	if a.pct:
		return "%s%d %% %s" % ["−" if a.get("neg", false) else "+", int(round(v * 100.0)), a.name]
	return "+%s %s" % [str(snappedf(v, 0.1)).trim_suffix(".0"), a.name]

static func lines(it: Dictionary) -> Array:
	var sums := {}
	var order: Array = []
	for src in [it.base, it.aff]:
		for k in src:
			if not sums.has(k):
				sums[k] = 0.0
				order.append(k)
			sums[k] = float(sums[k]) + float(src[k])
	var out: Array = []
	for k in order:
		if k == "hp":
			out.append("+%d Max. HP" % int(sums[k]))
		else:
			out.append(fmt(k, float(sums[k])))
	return out

## Hauptwert zum Vergleichen
static func power(it: Dictionary) -> float:
	var p := 0.0
	for k in it.base:
		p += float(it.base[k]) * (1.0 if k == "atk" or k == "hp" else 100.0)
	for k in it.aff:
		p += float(it.aff[k]) * (1.0 if not AFFIX[k].pct else 100.0)
	return p
