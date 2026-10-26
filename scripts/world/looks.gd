class_name Looks
extends RefCounted
## Aussehen aller Figuren von Veyra: Grundkörper + Kleidung (Quaternius-Baukasten), Haare, Bart,
## Rüstung, Farben. Gedeckte Kolonie-Töne.

const HAIR_M := ["hair.buzzed.hair-1", "hair.simple-parted.hair-1", "hair.long.hair-1", "hair.swept.hair-1", "hair.tied.hair-1", "hair.receding.hair-1", "hair.buzzed.hair-2", "hair.simple-parted.hair-2"]
const HAIR_F := ["female.hair.buns.hair-1", "female.hair.long.hair-1", "female.hair.buns.hair-2", "female.hair.long.hair-2"]
const BEARDS := ["", "", "beard.short", "beard.full", "beard.moustache", "beard.goatee"]
const HAIR_COLORS := [Color(0.05, 0.04, 0.03), Color(0.2, 0.1, 0.05), Color(0.32, 0.18, 0.08), Color(0.55, 0.42, 0.22), Color(0.6, 0.58, 0.55), Color(0.35, 0.12, 0.06)]
const TONES := [Color(1.05, 1.0, 0.97), Color(1, 1, 1), Color(0.88, 0.8, 0.7), Color(0.75, 0.62, 0.5)]

static func kael() -> Dictionary:
	return {"body": "male.outfit.class.rogue.skin.light", "armor": "armor.class.rogue.default", "cloth": Color(0.55, 0.55, 0.6),
		"accent": Color(0.45, 0.04, 0.06), "skin_tone": Color(0.95, 0.92, 0.92), "hair_color": Color(0.05, 0.04, 0.04)}

static func _rng(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r

static func settler(seed: int) -> Dictionary:
	var r := _rng(seed)
	var female := r.randf() < 0.45
	var light := r.randf() < 0.65
	var l := {"hair_color": HAIR_COLORS[r.randi() % HAIR_COLORS.size()], "scale": r.randf_range(0.95, 1.04),
		"cloth": Color(1, 1, 1).lerp(Color(0.75, 0.72, 0.7), r.randf()), "skin_tone": TONES[r.randi() % TONES.size()] if light else Color(1, 1, 1),
		"idle": ["Idle", "Idle_LookAround", "Idle_FoldArms", "Idle"][r.randi() % 4]}
	if female:
		l.merge({"female": true, "body": "female.outfit.tanner%s.lod1" % (".skin.light" if light else ""), "armor": "armor.tanner.default",
			"hair": HAIR_F[r.randi() % HAIR_F.size()]})
	else:
		var outfit: String = ["farmer", "farmer", "innkeeper", "monk"][r.randi() % 4]
		l.merge({"body": "male.outfit.%s%s.lod1" % [outfit, ".skin.light" if light else ""], "armor": "armor.%s.default" % outfit,
			"hair": HAIR_M[r.randi() % HAIR_M.size()], "beard": BEARDS[r.randi() % BEARDS.size()]})
		if outfit == "farmer" and r.randf() < 0.3:
			l.hat = "equipment.hat.straw.default"
	return l

static func hanna() -> Dictionary:
	return {"female": true, "body": "female.outfit.tanner.skin.light.lod1", "armor": "armor.tanner.default", "hair": "female.hair.buns.hair-1",
		"hair_color": Color(0.72, 0.71, 0.68), "cloth": Color(0.62, 0.58, 0.66), "scale": 0.97, "idle": "Idle_FoldArms"}

static func jory() -> Dictionary:
	return {"body": "male.outfit.farmer.skin.light.lod1", "armor": "armor.farmer.default", "hair": "hair.long.hair-1",
		"hair_color": Color(0.38, 0.13, 0.06), "cloth": Color(0.7, 0.66, 0.6), "scale": 0.97}

static func tamas() -> Dictionary:
	return {"body": "male.outfit.farmer.lod1", "armor": "armor.farmer.default", "hair": "hair.receding.hair-1", "beard": "beard.moustache",
		"hair_color": Color(0.22, 0.12, 0.06)}

static func innkeeper() -> Dictionary:
	return {"female": true, "body": "female.outfit.tanner.lod1", "armor": "armor.tanner.default", "hair": "female.hair.long.hair-1",
		"hair_color": Color(0.32, 0.18, 0.08), "cloth": Color(0.85, 0.78, 0.68), "idle": "Counter_Idle"}

static func smith() -> Dictionary:
	return {"body": "male.outfit.innkeeper.lod1", "armor": "armor.innkeeper.default", "hair": "hair.buzzed.hair-1", "beard": "beard.full",
		"hair_color": Color(0.08, 0.06, 0.05), "cloth": Color(0.55, 0.5, 0.48), "scale": 1.05, "idle": "Idle_FoldArms"}

static func child() -> Dictionary:
	return {"body": "male.outfit.farmer.skin.light.lod1", "armor": "armor.farmer.default", "hair": "hair.swept.hair-1",
		"hair_color": Color(0.55, 0.42, 0.22), "scale": 0.62}

static func widow() -> Dictionary:
	return {"female": true, "body": "female.outfit.tanner.skin.light.lod1", "armor": "armor.tanner.default", "hair": "female.hair.long.hair-2",
		"hair_color": Color(0.25, 0.15, 0.08), "cloth": Color(0.35, 0.34, 0.38), "scale": 0.98}

static func village_guard() -> Dictionary:
	return {"body": "male.outfit.soldier.skin.light.lod1", "armor": "armor.soldier.default", "faction": Color(0.32, 0.22, 0.12),
		"hair": "hair.buzzed.hair-1", "beard": "beard.short", "hair_color": Color(0.3, 0.18, 0.08), "idle": "Idle_FoldArms"}

static func bandit(seed: int) -> Dictionary:
	var r := _rng(seed + 1000)
	var light := r.randf() < 0.6
	var l := {"hair_color": HAIR_COLORS[r.randi() % 4], "skin_tone": TONES[r.randi() % TONES.size()] if light else Color(1, 1, 1),
		"cloth": Color(0.8, 0.78, 0.76).lerp(Color(0.6, 0.55, 0.5), r.randf()), "beard": BEARDS[r.randi() % BEARDS.size()]}
	if r.randf() < 0.6:
		l.merge({"body": "male.outfit.redbrand%s.lod1" % (".skin.light" if light else ""), "armor": "armor.redbrand.default",
			"hair": HAIR_M[r.randi() % HAIR_M.size()]})
	else:
		l.merge({"body": "male.outfit.class.rogue%s.lod1" % (".skin.light" if light else ""), "armor": "armor.class.rogue.default",
			"accent": Color(0.4, 0.08, 0.05)})
	return l

static func bandit_archer(seed: int) -> Dictionary:
	var l := bandit(seed)
	l.merge({"body": "male.lod1", "armor": "armor.class.ranger.default", "cloth": Color(0.6, 0.55, 0.5), "weapon": "equipment.dagger.blackened.default"}, true)
	return l

static func krahe() -> Dictionary:
	return {"body": "male.outfit.class.necromancer.skin.light.lod1", "armor": "armor.class.necromancer.default", "cloth": Color(0.6, 0.6, 0.66),
		"accent": Color(0.25, 0.22, 0.25), "scale": 1.06}

static func wacht(seed: int) -> Dictionary:
	var r := _rng(seed + 2000)
	var light := r.randf() < 0.7
	if r.randf() < 0.5:
		return {"body": "male.outfit.knight%s.lod1" % (".skin.light" if light else ""), "armor": "armor.knight.default",
			"faction": Color(0.08, 0.12, 0.22), "hair": "hair.buzzed.hair-1", "hair_color": Color(0.1, 0.07, 0.05)}
	return {"body": "male.outfit.soldier%s.lod1" % (".skin.light" if light else ""), "armor": "armor.soldier.default",
		"faction": Color(0.08, 0.12, 0.22), "beard": BEARDS[r.randi() % BEARDS.size()], "hair_color": Color(0.2, 0.12, 0.06)}

static func varek() -> Dictionary:
	return {"body": "male.outfit.knight.skin.light.lod1", "armor": "armor.knight.default", "faction": Color(0.45, 0.32, 0.08),
		"hair": "hair.simple-parted.hair-1", "beard": "beard.full", "hair_color": Color(0.6, 0.58, 0.55), "scale": 1.08}

static func cultist(seed: int) -> Dictionary:
	var r := _rng(seed + 3000)
	return {"body": "male.outfit.class.necromancer%s.lod1" % (".skin.light" if r.randf() < 0.6 else ""), "armor": "armor.class.necromancer.default",
		"cloth": Color(0.55, 0.12, 0.14), "accent": Color(0.6, 0.05, 0.08)}

static func ilva() -> Dictionary:
	return {"female": true, "body": "female.outfit.tanner.skin.light.lod1", "armor": "armor.tanner.default", "hair": "female.hair.long.hair-2",
		"hair_color": Color(0.85, 0.84, 0.82), "cloth": Color(0.55, 0.1, 0.12), "skin_tone": Color(0.92, 0.88, 0.9), "scale": 1.02}
