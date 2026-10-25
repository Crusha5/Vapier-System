class_name Looks
extends RefCounted
## Aussehen aller Menschen-Figuren (Farben, Frisur, Kleidung).

static func player() -> Dictionary:
	return {"suit": Color(0.11, 0.11, 0.15), "suit2": Color(0.05, 0.05, 0.07), "accent": Toon.RED, "hair": Color(0.07, 0.06, 0.09),
		"skin": Color(0.88, 0.76, 0.72), "eyes": Color(0.85, 0.9, 1.0), "glow": 0.0, "coat": true, "hair_style": "spiky",
		"metal": Color(0.35, 0.36, 0.42)}

static func cadet(variant := -1) -> Dictionary:
	var v := variant if variant >= 0 else randi() % 4
	var hair: Array = [Color(0.45, 0.28, 0.16), Color(0.86, 0.72, 0.42), Color(0.1, 0.08, 0.08), Color(0.62, 0.22, 0.14)]
	var skin: Array = [Color(0.92, 0.78, 0.68), Color(0.75, 0.56, 0.42), Color(0.95, 0.82, 0.74), Color(0.55, 0.38, 0.28)]
	return {"suit": Color(0.66, 0.7, 0.78), "suit2": Color(0.26, 0.3, 0.4), "accent": Color(0.25, 0.6, 1.0), "hair": hair[v % hair.size()],
		"skin": skin[v % skin.size()], "vest": true, "hair_style": ["short", "short", "spiky", "slick"][v % 4], "eyes": Color(0.2, 0.3, 0.5)}

static func drax() -> Dictionary:
	return {"suit": Color(0.93, 0.92, 0.95), "suit2": Color(0.62, 0.5, 0.25), "accent": Color(1.0, 0.72, 0.18), "hair": Color(0.97, 0.88, 0.55),
		"skin": Color(0.93, 0.8, 0.72), "scale": 1.1, "bulk": 1.15, "cape": true, "cape_color": Color(0.95, 0.93, 0.96), "vest": true,
		"pads": true, "metal": Color(0.85, 0.7, 0.32), "hair_style": "slick", "eyes": Color(0.25, 0.45, 0.6)}

static func instructor() -> Dictionary:
	return {"suit": Color(0.09, 0.09, 0.11), "suit2": Color(0.18, 0.18, 0.2), "accent": Color(1.0, 0.82, 0.3), "hair": Color(0.55, 0.55, 0.57),
		"skin": Color(0.8, 0.66, 0.58), "scale": 1.2, "bulk": 1.28, "coat": true, "cape": true, "cape_color": Color(0.06, 0.06, 0.07),
		"visor": true, "pads": true, "metal": Color(0.75, 0.62, 0.3), "hair_style": "buzz"}

static func mutant() -> Dictionary:
	return {"mutant": true, "skin": Color(0.46, 0.4, 0.5), "suit": Color(0.2, 0.17, 0.2), "suit2": Color(0.14, 0.12, 0.14),
		"accent": Color(0.78, 0.38, 1.0), "hair": Color(0.25, 0.2, 0.26), "hair_style": "buzz", "eyes": Color(0.8, 0.4, 1.0), "glow": 3.0,
		"bulk": 1.25, "scale": 1.12, "torso": 1.35, "arm_r": 2.1, "arm_l": 0.8}

static func mira() -> Dictionary:
	return {"suit": Color(0.24, 0.26, 0.34), "suit2": Color(0.12, 0.13, 0.18), "accent": Color(0.35, 1.0, 0.75), "hair": Color(0.85, 0.32, 0.42),
		"skin": Color(0.95, 0.84, 0.78), "hair_style": "long", "vest": true, "eyes": Color(0.25, 0.65, 0.55), "bulk": 0.88, "scale": 0.96}

static func brann() -> Dictionary:
	return {"suit": Color(0.32, 0.3, 0.26), "suit2": Color(0.2, 0.18, 0.15), "accent": Color(1.0, 0.6, 0.2), "hair": Color(0.35, 0.3, 0.28),
		"skin": Color(0.78, 0.6, 0.5), "hair_style": "buzz", "bulk": 1.3, "scale": 1.08, "vest": true, "pads": true, "metal": Color(0.5, 0.48, 0.44),
		"torso": 1.15}
