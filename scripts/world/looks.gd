class_name Looks
extends RefCounted
## Aussehen aller Figuren von Veyra (Farben, Frisur, Kleidung). Gedeckte Kolonie-Töne.

static func kael() -> Dictionary:
	return {"suit": Color(0.16, 0.17, 0.19), "suit2": Color(0.08, 0.08, 0.09), "accent": Color(0.55, 0.06, 0.08), "accent_glow": 0.5,
		"hair": Color(0.08, 0.07, 0.07), "skin": Color(0.88, 0.74, 0.66), "eyes": Color(0.85, 0.8, 0.75), "glow": 0.4,
		"coat": true, "hair_style": "spiky", "metal": Color(0.32, 0.33, 0.35), "pads": true}

static func settler(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var suits: Array = [Color(0.4, 0.33, 0.24), Color(0.3, 0.32, 0.26), Color(0.36, 0.28, 0.24), Color(0.28, 0.3, 0.34), Color(0.42, 0.38, 0.3)]
	var hair: Array = [Color(0.35, 0.22, 0.12), Color(0.68, 0.55, 0.32), Color(0.1, 0.08, 0.07), Color(0.45, 0.16, 0.1), Color(0.55, 0.53, 0.5)]
	var skin: Array = [Color(0.92, 0.78, 0.68), Color(0.76, 0.58, 0.44), Color(0.95, 0.83, 0.75), Color(0.55, 0.38, 0.27), Color(0.85, 0.68, 0.56)]
	var su: Color = suits[rng.randi() % suits.size()]
	return {"suit": su, "suit2": su.darkened(0.4), "accent": su.lightened(0.25), "accent_glow": 0.0,
		"hair": hair[rng.randi() % hair.size()], "skin": skin[rng.randi() % skin.size()], "eyes": Color(0.2, 0.18, 0.16),
		"hair_style": ["short", "long", "buzz", "slick", "short"][rng.randi() % 5], "vest": rng.randf() < 0.5,
		"coat": rng.randf() < 0.3, "bulk": rng.randf_range(0.9, 1.15), "scale": rng.randf_range(0.94, 1.04)}

static func hanna() -> Dictionary:
	var l := settler(11)
	l.merge({"suit": Color(0.32, 0.26, 0.3), "suit2": Color(0.2, 0.15, 0.18), "accent": Color(0.6, 0.5, 0.3), "hair": Color(0.72, 0.72, 0.7),
		"hair_style": "long", "coat": true, "bulk": 0.92, "scale": 0.96}, true)
	return l

static func jory() -> Dictionary:
	var l := settler(23)
	l.merge({"suit": Color(0.3, 0.27, 0.22), "hair": Color(0.45, 0.16, 0.1), "hair_style": "spiky", "coat": false, "vest": false, "bulk": 0.92}, true)
	return l

static func tamas() -> Dictionary:
	var l := settler(31)
	l.merge({"suit": Color(0.36, 0.3, 0.22), "hair": Color(0.35, 0.22, 0.12), "hair_style": "short", "vest": true, "coat": false}, true)
	return l

static func innkeeper() -> Dictionary:
	var l := settler(41)
	l.merge({"suit": Color(0.42, 0.36, 0.28), "suit2": Color(0.55, 0.52, 0.46), "vest": true, "bulk": 1.3, "torso": 1.2, "hair_style": "buzz"}, true)
	return l

static func smith() -> Dictionary:
	var l := settler(53)
	l.merge({"suit": Color(0.24, 0.22, 0.2), "suit2": Color(0.32, 0.22, 0.14), "vest": true, "bulk": 1.25, "hair_style": "buzz", "metal": Color(0.4, 0.38, 0.36), "pads": true}, true)
	return l

static func child() -> Dictionary:
	var l := settler(67)
	l.merge({"scale": 0.62, "bulk": 0.9, "hair_style": "short", "coat": false, "vest": false}, true)
	return l

static func widow() -> Dictionary:
	var l := settler(71)
	l.merge({"suit": Color(0.14, 0.13, 0.14), "suit2": Color(0.09, 0.08, 0.09), "hair": Color(0.3, 0.2, 0.12), "hair_style": "long", "coat": true, "bulk": 0.9}, true)
	return l

static func village_guard() -> Dictionary:
	var l := settler(83)
	l.merge({"suit": Color(0.3, 0.3, 0.28), "suit2": Color(0.2, 0.19, 0.17), "vest": true, "pads": true, "metal": Color(0.45, 0.45, 0.46), "hair_style": "short"}, true)
	return l

static func bandit(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 1000
	var su := Color(0.22, 0.2, 0.18).lerp(Color(0.32, 0.22, 0.16), rng.randf())
	return {"suit": su, "suit2": su.darkened(0.45), "accent": Color(0.5, 0.12, 0.08), "accent_glow": 0.0,
		"hair": [Color(0.1, 0.08, 0.07), Color(0.4, 0.25, 0.12), Color(0.5, 0.48, 0.45)][rng.randi() % 3],
		"skin": [Color(0.86, 0.7, 0.6), Color(0.66, 0.5, 0.38), Color(0.5, 0.35, 0.25)][rng.randi() % 3], "eyes": Color(0.2, 0.15, 0.1),
		"hair_style": ["buzz", "spiky", "long", "short"][rng.randi() % 4], "vest": true, "coat": rng.randf() < 0.4,
		"pads": rng.randf() < 0.5, "metal": Color(0.38, 0.36, 0.33), "bulk": rng.randf_range(1.0, 1.2)}

static func krahe() -> Dictionary:
	var l := bandit(7)
	l.merge({"suit": Color(0.1, 0.1, 0.11), "suit2": Color(0.05, 0.05, 0.06), "coat": true, "cape": true, "cape_color": Color(0.08, 0.08, 0.09),
		"hair": Color(0.06, 0.06, 0.07), "hair_style": "long", "scale": 1.06, "pads": true}, true)
	return l

static func wacht(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed + 2000
	return {"suit": Color(0.2, 0.25, 0.34), "suit2": Color(0.12, 0.14, 0.18), "accent": Color(0.35, 0.65, 1.0), "accent_glow": 0.8,
		"hair": [Color(0.1, 0.08, 0.07), Color(0.6, 0.5, 0.3)][rng.randi() % 2], "skin": Color(0.88, 0.74, 0.64), "eyes": Color(0.2, 0.3, 0.4),
		"hair_style": "short", "vest": true, "pads": true, "metal": Color(0.5, 0.52, 0.55), "visor": rng.randf() < 0.5, "bulk": 1.1}

static func varek() -> Dictionary:
	var l := wacht(1)
	l.merge({"suit": Color(0.08, 0.09, 0.12), "accent": Color(1.0, 0.75, 0.3), "hair": Color(0.5, 0.5, 0.52), "hair_style": "buzz",
		"coat": true, "cape": true, "cape_color": Color(0.1, 0.12, 0.18), "scale": 1.12, "bulk": 1.25, "visor": false}, true)
	return l

static func cultist(seed: int) -> Dictionary:
	var l := settler(seed + 3000)
	l.merge({"suit": Color(0.25, 0.05, 0.07), "suit2": Color(0.12, 0.02, 0.03), "accent": Color(0.9, 0.1, 0.15), "accent_glow": 1.2,
		"coat": true, "cape": true, "cape_color": Color(0.2, 0.03, 0.05), "hair_style": "buzz"}, true)
	return l
