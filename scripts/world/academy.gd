class_name Academy
extends Node3D
## Vanguard-Akademie, Sektor 7: Archivruinen, Neon-Korridor, Trainingshalle, Ostflügel (Karkosa-Riss)
## und das verborgene Mitternachtsgewölbe. Alles prozedural, mit Kollision und Navigationsnetz.

const WALL_H := 3.2
const LOW_H := 1.0  # Südwände (zur Kamera) bleiben niedrig – Durchblick wie in einem Schnittmodell
const WALL_T := 0.8

const ZONES := {
	"vault": Rect2(-24, -5, 10, 10),
	"archive": Rect2(-14, -12, 28, 24),
	"corridor": Rect2(14, -3, 20, 6),
	"hall": Rect2(34, -15, 30, 30),
	"passage": Rect2(46, -33, 6, 18),
	"eastwing": Rect2(34, -62, 30, 29),
	"courtyard": Rect2(16, 3, 16, 21),
	"dorm": Rect2(-2, 14, 18, 14),
	"mensa": Rect2(32, 17, 18, 14),
	"crypt": Rect2(-72, -38, 24, 18),
	"tunnel": Rect2(-78, -32, 6, 6),
	"ossuary": Rect2(-104, -44, 26, 28),
	"descent": Rect2(-63, -50, 6, 12),
	"brood": Rect2(-74, -76, 28, 26),
}
const SAFE_ZONES := ["dorm", "mensa"]
const CRYPT_ZONES := ["crypt", "tunnel", "ossuary", "descent", "brood"]
const ZONE_NAMES := {
	"vault": "??? – Versiegelte Kammer", "archive": "Altes Archiv – Ruinen", "corridor": "Verbindungskorridor S7",
	"hall": "Trainingshalle Vanguard", "passage": "Wartungsgang Ost", "eastwing": "Ostflügel – Karkosa-Riss",
	"courtyard": "Innenhof der Gründer", "dorm": "Schlafsaal – Block C", "mensa": "Mensa",
	"crypt": "Katakomben – Gruft", "tunnel": "Katakomben – Schacht", "ossuary": "Ossarium", "descent": "Abstieg", "brood": "Brutkammer",
}

var nav: NavigationRegion3D
var spawns := {
	"archive": [Vector3(-9, 0, -8), Vector3(9, 0, -8), Vector3(9, 0, 8), Vector3(-9, 0, 8), Vector3(0, 0, 9)],
	"breach": [Vector3(6, 0, -10), Vector3(3, 0, -10.2), Vector3(9, 0, -10)],
	"corridor": [Vector3(21, 0, 0), Vector3(29, 0, 1)],
	"hall": [Vector3(42, 0, -8), Vector3(56, 0, -8), Vector3(42, 0, 8), Vector3(56, 0, 8), Vector3(49, 0, -10)],
	"passage": [Vector3(49, 0, -24)],
	"eastwing": [Vector3(40, 0, -40), Vector3(58, 0, -40), Vector3(40, 0, -57), Vector3(58, 0, -57), Vector3(49, 0, -40)],
	"courtyard": [Vector3(19, 0, 8), Vector3(29, 0, 8), Vector3(20, 0, 20), Vector3(29, 0, 20)],
	"crypt": [Vector3(-67, 0, -34), Vector3(-52, 0, -34), Vector3(-54, 0, -24)],
	"ossuary": [Vector3(-99, 0, -40), Vector3(-84, 0, -40), Vector3(-99, 0, -21), Vector3(-90, 0, -30), Vector3(-82, 0, -21)],
}
const PLAYER_START := Vector3(-5, 0, 6)
const RELIC_POS := Vector3(0, 0, -5)
const RESPAWN := Vector3(0, 0, -1.8)
const VAULT_SIGIL := Vector3(-19.5, 0, 0)
const NEST_POS := Vector3(49, 0, -51)
const DRAX_POS := Vector3(49, 0, -3)
const LIFT_POS := Vector3(11.3, 0, 7.6)
const CRYPT_LIFT := Vector3(-60, 0, -23.2)
const CRYPT_RESPAWN := Vector3(-60, 0, -26.5)
const BUTCHER_POS := Vector3(24, 0, 12)
const BROOD_POS := Vector3(-60, 0, -66)
const MIRA_POS := Vector3(5.5, 0, 19.5)
const BRANN_POS := Vector3(41, 0, 19.8)
const FRAGMENTS := [Vector3(-97, 0, -36), Vector3(-83, 0, -19.5), Vector3(-51.5, 0, -35)]

var relic: Node3D
var relic_core: MeshInstance3D
var relic_ring: MeshInstance3D
var vault_glyph: MeshInstance3D
var vault_light: OmniLight3D
var red_lights: Array[OmniLight3D] = []
var candles: Array[OmniLight3D] = []
var lift_glow: MeshInstance3D
var fragment_nodes: Array = []
var env: Environment
var sun: DirectionalLight3D
var _t := 0.0

var m_floor: Material
var m_floor_hall: Material
var m_wall: Material
var m_wall_dark: Material
var m_metal: Material
var m_trim: Material
var m_neon_c: Material
var m_neon_r: Material
var m_resin: Material
var m_wall_low: Material
var m_wall_dark_low: Material
var m_trim_low: Material

func _ready() -> void:
	m_floor = Toon.mat(Color(0.27, 0.27, 0.3), {"tiles": 0.55, "tile_size": 2.0, "grime": 0.4})
	m_floor_hall = Toon.mat(Color(0.32, 0.33, 0.36), {"tiles": 0.35, "tile_size": 3.0})
	m_wall = Toon.mat(Toon.STONE, {"outline": 0.05, "radial": 1.0, "fade": true, "grime": 0.6})
	m_wall_dark = Toon.mat(Toon.STONE_DARK, {"outline": 0.05, "radial": 1.0, "fade": true, "grime": 0.6})
	m_metal = Toon.mat(Toon.METAL, {"outline": 0.035, "radial": 1.0, "spec": 0.5, "fade": true})
	m_trim = Toon.mat(Color(0.12, 0.13, 0.17), {"outline": 0.03, "radial": 1.0, "fade": true})
	m_wall_low = Toon.mat(Toon.STONE, {"outline": 0.05, "radial": 1.0, "grime": 0.6})
	m_wall_dark_low = Toon.mat(Toon.STONE_DARK, {"outline": 0.05, "radial": 1.0, "grime": 0.6})
	m_trim_low = Toon.mat(Color(0.12, 0.13, 0.17), {"outline": 0.03, "radial": 1.0})
	m_neon_c = Toon.mat(Toon.CYAN, {"emit": Toon.CYAN, "energy": 3.0})
	m_neon_r = Toon.mat(Toon.RED, {"emit": Toon.RED, "energy": 3.0})
	m_resin = Toon.mat(Color(0.18, 0.26, 0.17), {"outline": 0.04, "radial": 1.0, "rim": 0.4, "rim_color": Color(0.6, 1.0, 0.3)})
	nav = NavigationRegion3D.new()
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.agent_radius = 0.5
	nm.agent_height = 1.75
	nm.agent_max_climb = 0.25
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	nm.filter_baking_aabb = AABB(Vector3(-108, -1, -80), Vector3(176, 4, 116))
	nav.navigation_mesh = nm
	add_child(nav)
	_environment()
	_build_archive()
	_build_vault()
	_build_corridor()
	_build_hall()
	_build_passage()
	_build_eastwing()
	_build_courtyard()
	_build_dorm()
	_build_mensa()
	_build_lift()
	_build_catacombs()
	relic_ring.set_meta("keep", true)
	vault_glyph.set_meta("keep", true)
	var merged := Batcher.merge(self)
	print("Level: ", merged, " Meshes zusammengefasst → ", get_child_count(), " Knoten")
	nav.bake_navigation_mesh(false)

# ---------- Umgebung & Licht ----------

func _environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.3, 0.31, 0.4)
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.fog_enabled = true
	env.fog_light_color = Color(0.05, 0.06, 0.1)
	env.fog_density = 0.012
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	env.adjustment_contrast = 1.06
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.78, 0.82, 1.0)
	sun.light_energy = 0.85
	sun.rotation = Vector3(deg_to_rad(-62), deg_to_rad(28), 0)
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	sun.shadow_bias = 0.06
	add_child(sun)

func _omni(pos: Vector3, c: Color, energy := 1.6, rng := 7.0, shadow := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = c
	l.light_energy = energy
	l.omni_range = rng
	l.omni_attenuation = 1.4
	l.shadow_enabled = shadow
	add_child(l)
	return l

# ---------- Baukasten ----------

func _floor(r: Rect2, mt: Material) -> void:
	# in 8-m-Stücke teilen, damit jedes Stück seine eigenen Lichter bekommt
	var x := r.position.x
	while x < r.end.x - 0.01:
		var w: float = min(8.0, r.end.x - x)
		var z := r.position.y
		while z < r.end.y - 0.01:
			var d: float = min(8.0, r.end.y - z)
			var mi := Toon.box(self, Vector3(w, 0.2, d), Vector3(x + w * 0.5, -0.1, z + d * 0.5), mt)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			z += d
		x += w
	Toon.collider(nav, Vector3(r.size.x, 0.2, r.size.y), Vector3(r.get_center().x, -0.1, r.get_center().y))

## Wand entlang X (konstantes z) von x0 bis x1 mit Öffnungen [[a, b], …]
func _wall_x(x0: float, x1: float, z: float, gaps: Array = [], mt: Material = null, h := WALL_H) -> void:
	for seg in _segments(x0, x1, gaps):
		var len: float = seg.y - seg.x
		if len < 0.05:
			continue
		var c := Vector3((seg.x + seg.y) * 0.5, h * 0.5, z)
		_wall_block(Vector3(len, h, WALL_T), c, mt)

func _wall_z(z0: float, z1: float, x: float, gaps: Array = [], mt: Material = null, h := WALL_H) -> void:
	for seg in _segments(z0, z1, gaps):
		var len: float = seg.y - seg.x
		if len < 0.05:
			continue
		var c := Vector3(x, h * 0.5, (seg.x + seg.y) * 0.5)
		_wall_block(Vector3(WALL_T, h, len), c, mt)

func _wall_block(size: Vector3, c: Vector3, mt: Material) -> void:
	var m := mt if mt else m_wall
	var trim := m_trim
	if size.y < 2.0:
		m = m_wall_dark_low if m == m_wall_dark else m_wall_low
		trim = m_trim_low
	# lange Wände in Stücke, sonst wirkt die Kontur weich und Lichter fehlen
	var long_x := size.x > size.z
	var total := size.x if long_x else size.z
	var n := int(ceil(total / 6.0))
	var piece := total / n
	for i in n:
		var off := -total * 0.5 + piece * (i + 0.5)
		var pc := c + (Vector3(off, 0, 0) if long_x else Vector3(0, 0, off))
		var ps := Vector3(piece, size.y, size.z) if long_x else Vector3(size.x, size.y, piece)
		Toon.box(self, ps, pc, m)
		# Sockel und Krone
		Toon.box(self, ps + Vector3(0.12, -size.y + 0.25, 0.12), pc + Vector3(0, -size.y * 0.5 + 0.12, 0), trim)
		Toon.box(self, ps + Vector3(0.1, -size.y + 0.18, 0.1), pc + Vector3(0, size.y * 0.5, 0), trim)
	Toon.collider(nav, size, c)

func _segments(a: float, b: float, gaps: Array) -> Array:
	var out := []
	var cur := a
	var gs := gaps.duplicate()
	gs.sort_custom(func(p, q): return p[0] < q[0])
	for g in gs:
		out.append(Vector2(cur, g[0]))
		cur = g[1]
	out.append(Vector2(cur, b))
	return out

func _pillar(pos: Vector3, h := WALL_H + 0.4, broken := false) -> void:
	var hh := h * (randf_range(0.35, 0.7) if broken else 1.0)
	Toon.box(self, Vector3(1.0, 0.3, 1.0), pos + Vector3(0, 0.15, 0), m_trim)
	Toon.cyl(self, 0.36, 0.42, hh, pos + Vector3(0, hh * 0.5, 0), m_wall_dark, 8)
	if not broken:
		Toon.box(self, Vector3(1.0, 0.3, 1.0), pos + Vector3(0, hh, 0), m_trim)
	else:
		Toon.prism(self, Vector3(0.7, 0.4, 0.7), pos + Vector3(0, hh + 0.1, 0), m_wall_dark, Vector3(0.3, 0.5, 0))
	Toon.collider(nav, Vector3(0.9, 2.0, 0.9), pos + Vector3(0, 1.0, 0))

func _crate(pos: Vector3, s := 1.0, rot := 0.0) -> void:
	var sz := Vector3(1.1, 0.9, 1.1) * s
	Toon.box(self, sz, pos + Vector3(0, sz.y * 0.5, 0), m_metal, Vector3(0, rot, 0))
	Toon.box(self, Vector3(sz.x * 1.02, 0.08, sz.z * 1.02), pos + Vector3(0, sz.y * 0.75, 0), m_neon_c if randf() < 0.5 else m_trim, Vector3(0, rot, 0))
	Toon.collider(nav, sz, pos + Vector3(0, sz.y * 0.5, 0), rot)

func _rubble(pos: Vector3, n := 5, spread := 1.2) -> void:
	for i in n:
		var s := randf_range(0.2, 0.55)
		Toon.box(self, Vector3(s, s * 0.7, s * 1.2), pos + Vector3(randf_range(-spread, spread), s * 0.3, randf_range(-spread, spread)),
			m_wall_dark, Vector3(randf() * 0.6, randf() * TAU, randf() * 0.6))

func _neon(size: Vector3, pos: Vector3, red: bool) -> void:
	var mi := Toon.box(self, size, pos, m_neon_r if red else m_neon_c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

# ---------- Archiv ----------

func _build_archive() -> void:
	var r: Rect2 = ZONES.archive
	_floor(r, m_floor)
	_wall_x(-14, 14, -12)
	_wall_x(-14, 14, 12, [], null, LOW_H)
	_wall_z(-12, 12, -14, [[-1.1, 1.1]])
	_wall_z(-12, 12, 14, [[-2.2, 2.2]])
	# Riss in der Nordwand (Karkosa brechen hier ein)
	for i in 6:
		Toon.box(self, Vector3(randf_range(0.6, 1.4), randf_range(0.3, 1.6), 0.5), Vector3(4.2 + i * 0.75, randf_range(0.6, 2.4), -11.5),
			m_resin, Vector3(randf() * 0.5, 0, randf() * 0.8))
	_neon(Vector3(3.6, 0.06, 0.06), Vector3(6, 0.05, -11.2), true)
	red_lights.append(_omni(Vector3(6, 2.0, -10), Color(1.0, 0.2, 0.25), 1.6, 7.0))
	# Säulen entlang der Wände
	for x in [-10.0, -4.0, 4.0, 10.0]:
		_pillar(Vector3(x, 0, -10.6), WALL_H + 0.4, x == 4.0)
		_pillar(Vector3(x, 0, 10.6), 2.2, true)
	# Datenregale (teils umgestürzt)
	var shelf_m := Toon.mat(Color(0.22, 0.2, 0.22), {"outline": 0.035, "radial": 1.0, "fade": true})
	for row in [[-10.5, -5.5], [-10.5, 0.5], [9.5, -5.5], [9.5, 3.5]]:
		var p := Vector3(row[0], 0, row[1])
		var toppled: bool = row[1] > 0.0 and row[0] > 0.0
		if toppled:
			Toon.box(self, Vector3(0.7, 3.4, 2.4), p + Vector3(0, 0.4, 0), shelf_m, Vector3(0, 0, PI * 0.5 - 0.15))
			Toon.collider(nav, Vector3(3.2, 0.9, 2.4), p + Vector3(0, 0.45, 0))
			_rubble(p + Vector3(1.4, 0, 1.6), 6, 1.0)
		else:
			Toon.box(self, Vector3(0.7, 2.6, 3.8), p + Vector3(0, 1.3, 0), shelf_m)
			for k in 4:
				var lit := Toon.box(self, Vector3(0.72, 0.05, 3.5), p + Vector3(0, 0.4 + k * 0.6, 0), m_neon_c if (k + int(row[1])) % 3 == 0 else m_trim)
				lit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Toon.collider(nav, Vector3(0.7, 2.6, 3.8), p + Vector3(0, 1.3, 0))
	_rubble(Vector3(-6, 0, -9), 7, 1.4)
	_rubble(Vector3(11, 0, -2), 5, 1.0)
	_rubble(Vector3(-12.5, 0, 1.8), 6, 0.6)  # halb verschütteter Durchgang zum Gewölbe
	_crate(Vector3(5, 0, 9), 1.0, 0.3)
	_crate(Vector3(6.3, 0, 9.4), 0.8, -0.2)
	_crate(Vector3(-11, 0, 9.5), 1.1, 0.1)
	# Relikt auf achteckigem Podest
	var dais := Toon.cyl(self, 2.6, 2.8, 0.18, RELIC_POS + Vector3(0, 0.09, 0), Toon.mat(Color(0.2, 0.2, 0.26), {"outline": 0.04}), 8)
	dais.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring := Toon.quad_holo(self, Vector2(5.0, 5.0), RELIC_POS + Vector3(0, 0.2, 0), Toon.holo(Toon.CYAN, 1.4, true, 0.15))
	relic_ring = ring
	relic = Node3D.new()
	relic.position = RELIC_POS + Vector3(0, 1.5, 0)
	add_child(relic)
	Toon.cyl(self, 0.35, 0.6, 0.8, RELIC_POS + Vector3(0, 0.55, 0), m_metal, 8)
	Toon.collider(nav, Vector3(1.2, 1.2, 1.2), RELIC_POS + Vector3(0, 0.6, 0))
	var core_m := Toon.mat(Toon.RED_DEEP, {"emit": Toon.RED, "energy": 1.6, "outline": 0.03, "radial": 1.0, "spec": 1.0})
	relic_core = Toon.sphere(relic, 0.38, Vector3.ZERO, core_m, Vector3(1.0, 1.2, 1.0), 10)
	var bone := Toon.mat(Color(0.6, 0.62, 0.68), {"outline": 0.025, "radial": 1.0, "spec": 0.8})
	for i in 6:
		var a := TAU * i / 6.0
		Toon.prism(relic, Vector3(0.12, 0.55, 0.12), Vector3(cos(a) * 0.42, 0.05 * (1 if i % 2 == 0 else -1), sin(a) * 0.42), bone, Vector3(0, -a, PI * 0.5 + 0.4))
	for k in 2:
		var tor := TorusMesh.new()
		tor.inner_radius = 0.62 + k * 0.18
		tor.outer_radius = 0.66 + k * 0.18
		tor.rings = 24
		tor.ring_segments = 4
		var ti := Toon.mesh(relic, tor, Toon.mat(Toon.CYAN if k == 0 else Toon.RED, {"emit": Toon.CYAN if k == 0 else Toon.RED, "energy": 2.5}), Vector3.ZERO, Vector3(0.5 + k, 0, 0.3), false)
		ti.name = "Ring%d" % k
	_omni(RELIC_POS + Vector3(0, 2.0, 0), Color(1.0, 0.25, 0.3), 2.2, 8.0)
	_omni(Vector3(-8, 2.4, 4), Color(0.3, 0.8, 1.0), 1.2, 8.0)
	_omni(Vector3(9, 2.4, 6), Color(0.3, 0.8, 1.0), 1.0, 7.0)

# ---------- Verborgenes Gewölbe ----------

func _build_vault() -> void:
	var r: Rect2 = ZONES.vault
	_floor(r, Toon.mat(Color(0.16, 0.15, 0.2), {"tiles": 0.6, "tile_size": 1.5, "grime": 0.6}))
	_wall_x(-24, -14, -5, [], m_wall_dark)
	_wall_x(-24, -14, 5, [], m_wall_dark, LOW_H)
	_wall_z(-5, 5, -24, [], m_wall_dark)
	vault_glyph = Toon.quad_holo(self, Vector2(3.4, 3.4), VAULT_SIGIL + Vector3(0, 0.04, 0), Toon.holo(Color(0.75, 0.1, 0.25), 1.2, true, 0.0))
	Toon.set_alpha(vault_glyph, 0.08)
	# Sarkophag des ersten Wirts
	Toon.box(self, Vector3(1.2, 0.8, 2.4), Vector3(-22.6, 0.4, 0), Toon.mat(Color(0.25, 0.24, 0.3), {"outline": 0.04, "radial": 1.0, "fade": true}))
	Toon.box(self, Vector3(0.08, 0.04, 2.0), Vector3(-22.6, 0.82, 0), m_neon_r)
	Toon.box(self, Vector3(1.0, 0.04, 0.08), Vector3(-22.6, 0.82, -0.4), m_neon_r)
	Toon.collider(nav, Vector3(1.2, 0.8, 2.4), Vector3(-22.6, 0.4, 0))
	for z in [-3.6, 3.6]:
		_pillar(Vector3(-17, 0, z), WALL_H + 0.2, false)
	vault_light = _omni(VAULT_SIGIL + Vector3(0, 1.8, 0), Color(0.9, 0.1, 0.3), 0.3, 6.0)

# ---------- Korridor ----------

func _build_corridor() -> void:
	var r: Rect2 = ZONES.corridor
	_floor(r, m_floor)
	_wall_x(14, 34, -3)
	_wall_x(14, 34, 3, [[22, 26]], null, LOW_H)
	var x := 16.0
	var i := 0
	while x < 33.0:
		# Nordseite: hohe Pfeiler mit Cyan-Neon, Südseite: niedrige Poller mit Rot – wie im Emblem
		Toon.box(self, Vector3(0.7, WALL_H + 0.2, 0.5), Vector3(x, (WALL_H + 0.2) * 0.5, -2.55), m_trim)
		_neon(Vector3(0.08, 1.8, 0.08), Vector3(x + 0.38, 1.4, -2.32), false)
		if absf(x - 24.0) > 1.5:
			Toon.box(self, Vector3(0.7, LOW_H + 0.25, 0.5), Vector3(x, (LOW_H + 0.25) * 0.5, 2.55), m_trim_low)
			_neon(Vector3(0.5, 0.06, 0.06), Vector3(x, LOW_H + 0.1, 2.28), true)
		_neon(Vector3(2.6, 0.05, 0.08), Vector3(x + 1.9, 0.08, -2.5), false)
		_neon(Vector3(2.6, 0.05, 0.08), Vector3(x + 1.9, 0.08, 2.5), true)
		if i % 2 == 0:
			_omni(Vector3(x + 1.9, 2.2, -1.5), Color(0.25, 0.85, 1.0), 1.6, 6.0)
		else:
			_omni(Vector3(x + 1.9, 2.2, 1.5), Color(1.0, 0.2, 0.28), 1.6, 6.0)
		x += 4.0
		i += 1
	_crate(Vector3(25, 0, -2.0), 0.8, 0.4)

# ---------- Trainingshalle ----------

func _build_hall() -> void:
	var r: Rect2 = ZONES.hall
	_floor(r, m_floor_hall)
	_wall_x(34, 64, -15, [[46, 52]])
	_wall_x(34, 64, 15, [], null, LOW_H)
	_wall_z(-15, 15, 34, [[-2.2, 2.2]])
	_wall_z(-15, 15, 64)
	var c := Vector3(49, 0, 0)
	var arena := Toon.quad_holo(self, Vector2(18, 18), c + Vector3(0, 0.03, 0), Toon.holo(Toon.CYAN, 0.35, true, 0.0))
	arena.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Tribüne an der Südwand
	for k in 3:
		var hgt := 0.32 * (k + 1)
		Toon.box(self, Vector3(22, hgt, 1.4), Vector3(49, hgt * 0.5, 11.3 + k * 1.4), m_trim)
	Toon.collider(nav, Vector3(22, 1.0, 4.2), Vector3(49, 0.5, 12.7))
	for x in [40.0, 45.0, 53.0, 58.0]:
		_neon(Vector3(3.6, 0.05, 0.05), Vector3(x, 0.34, 10.58), false)
	# Trainingspuppen
	var dummy_m := Toon.mat(Color(0.65, 0.55, 0.38), {"outline": 0.035, "radial": 1.0})
	for p in [Vector3(38, 0, -11), Vector3(41, 0, -11.5), Vector3(57, 0, -11.5), Vector3(60, 0, -11), Vector3(61, 0, 6)]:
		Toon.cyl(self, 0.08, 0.08, 1.2, p + Vector3(0, 0.6, 0), m_metal, 6)
		Toon.cyl(self, 0.32, 0.32, 0.9, p + Vector3(0, 1.4, 0), dummy_m, 8)
		Toon.sphere(self, 0.2, p + Vector3(0, 2.05, 0), dummy_m)
		Toon.collider(nav, Vector3(0.7, 2.0, 0.7), p + Vector3(0, 1.0, 0))
	# Banner der Akademie
	for x in [39.0, 49.0, 59.0]:
		Toon.box(self, Vector3(2.2, 2.4, 0.06), Vector3(x, 1.9, -14.55), Toon.mat(Color(0.1, 0.18, 0.32), {"outline": 0.02}))
		_neon(Vector3(0.9, 0.9, 0.04), Vector3(x, 2.0, -14.5), false)
	_crate(Vector3(36.5, 0, 12.3), 1.0)
	_crate(Vector3(62, 0, -2), 1.0, 0.2)
	_crate(Vector3(62.2, 0, -0.6), 0.7, -0.3)
	for p in [Vector3(40, 3.0, -7), Vector3(58, 3.0, -7), Vector3(40, 3.0, 7), Vector3(58, 3.0, 7)]:
		_omni(p, Color(0.7, 0.85, 1.0), 1.5, 11.0)
	_omni(c + Vector3(0, 2.5, 0), Color(0.3, 0.85, 1.0), 1.4, 10.0)

# ---------- Wartungsgang ----------

func _build_passage() -> void:
	var r: Rect2 = ZONES.passage
	_floor(r, m_floor)
	_wall_z(-33, -15, 46)
	_wall_z(-33, -15, 52)
	for z in [-18.0, -24.0, -30.0]:
		var l := _omni(Vector3(49, 2.6, z), Color(1.0, 0.15, 0.15), 1.6, 6.0)
		red_lights.append(l)
		_neon(Vector3(0.06, 0.4, 0.8), Vector3(46.45, 2.6, z), true)
		_neon(Vector3(0.06, 0.4, 0.8), Vector3(51.55, 2.6, z), true)
	_rubble(Vector3(47.5, 0, -27), 5, 0.7)
	_resin_blob(Vector3(51, 0, -31), 1.2)

# ---------- Ostflügel ----------

func _resin_blob(pos: Vector3, s: float) -> void:
	Toon.sphere(self, s, pos + Vector3(0, -s * 0.4, 0), m_resin, Vector3(1.4, 0.6, 1.1), 8)
	var g := Toon.sphere(self, s * 0.25, pos + Vector3(s * 0.3, s * 0.1, 0), Toon.mat(Color(0.6, 0.9, 0.2), {"emit": Color(0.55, 0.95, 0.15), "energy": 1.8}), Vector3.ONE, 6)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_eastwing() -> void:
	var r: Rect2 = ZONES.eastwing
	_floor(r, Toon.mat(Color(0.22, 0.25, 0.24), {"tiles": 0.5, "tile_size": 2.0, "grime": 0.7}))
	_wall_x(34, 64, -33, [[46, 52]], null, LOW_H)
	_wall_x(34, 64, -62)
	_wall_z(-62, -33, 34)
	_wall_z(-62, -33, 64)
	for p in [Vector3(38, 0, -38), Vector3(60, 0, -37), Vector3(37, 0, -58), Vector3(61, 0, -59), Vector3(44, 0, -46), Vector3(56, 0, -55),
			Vector3(52, 0, -45), Vector3(42, 0, -55)]:
		_resin_blob(p, randf_range(0.9, 1.6))
	# zerbrochene Laborbehälter
	var glass := Toon.holo(Color(0.3, 0.9, 0.8), 0.22, false, 0.5)
	for p in [Vector3(38, 0, -46), Vector3(38, 0, -50), Vector3(60, 0, -46), Vector3(60, 0, -50)]:
		Toon.cyl(self, 0.75, 0.8, 0.3, p + Vector3(0, 0.15, 0), m_metal, 10)
		Toon.cyl(self, 0.75, 0.8, 0.3, p + Vector3(0, 2.6, 0), m_metal, 10)
		var tube := Toon.cyl(self, 0.7, 0.7, 2.2, p + Vector3(0, 1.4, 0), glass, 12)
		tube.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Toon.collider(nav, Vector3(1.5, 2.6, 1.5), p + Vector3(0, 1.3, 0))
	_crate(Vector3(36, 0, -35.5), 1.0, 0.5)
	_crate(Vector3(62, 0, -60), 1.1, -0.3)
	_rubble(Vector3(55, 0, -36), 7, 1.2)
	_rubble(Vector3(41, 0, -60), 6, 1.2)
	_omni(NEST_POS + Vector3(0, 3.0, 4.0), Color(0.55, 1.0, 0.25), 1.6, 12.0)
	_omni(Vector3(40, 2.6, -40), Color(0.4, 0.9, 0.5), 1.0, 9.0)
	_omni(Vector3(58, 2.6, -58), Color(0.4, 0.9, 0.5), 1.0, 9.0)
	red_lights.append(_omni(Vector3(49, 2.6, -36), Color(1.0, 0.15, 0.15), 1.4, 7.0))

# ---------- Innenhof ----------

func _tree(pos: Vector3, s := 1.0) -> void:
	var bark := Toon.mat(Color(0.22, 0.16, 0.14), {"outline": 0.03, "radial": 1.0})
	var leaf := Toon.mat(Color(0.12, 0.3, 0.28), {"outline": 0.04, "radial": 1.0, "rim": 0.5, "rim_color": Color(0.3, 1.0, 0.8)})
	Toon.cyl(self, 0.16 * s, 0.24 * s, 2.2 * s, pos + Vector3(0, 1.1 * s, 0), bark, 7)
	Toon.sphere(self, 1.1 * s, pos + Vector3(0, 2.7 * s, 0), leaf, Vector3(1.0, 0.8, 1.0), 8)
	Toon.sphere(self, 0.8 * s, pos + Vector3(0.5 * s, 3.3 * s, 0.2 * s), leaf, Vector3.ONE, 7)
	Toon.sphere(self, 0.7 * s, pos + Vector3(-0.5 * s, 3.2 * s, -0.3 * s), leaf, Vector3.ONE, 7)
	Toon.collider(nav, Vector3(0.6, 2.0, 0.6) * s, pos + Vector3(0, 1.0, 0))

func _lamp(pos: Vector3) -> void:
	Toon.cyl(self, 0.06, 0.09, 3.0, pos + Vector3(0, 1.5, 0), m_trim_low, 6)
	var g := Toon.sphere(self, 0.18, pos + Vector3(0, 3.05, 0), m_neon_c, Vector3.ONE, 8)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_omni(pos + Vector3(0, 2.8, 0), Color(0.45, 0.85, 1.0), 1.2, 7.0)
	Toon.collider(nav, Vector3(0.3, 2.0, 0.3), pos + Vector3(0, 1.0, 0))

func _build_courtyard() -> void:
	var r: Rect2 = ZONES.courtyard
	var grass := Toon.mat(Color(0.14, 0.24, 0.2), {"grime": 0.8})
	var path := Toon.mat(Color(0.3, 0.3, 0.33), {"tiles": 0.5, "tile_size": 1.0})
	_floor(r, grass)
	for pr in [[Vector3(24, 0.02, 13.5), Vector3(2.4, 0.04, 21)], [Vector3(24, 0.02, 19.5), Vector3(16, 0.04, 2.0)], [Vector3(24, 0.02, 13), Vector3(16, 0.04, 2.0)]]:
		var mi := Toon.box(self, pr[1], pr[0], path)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall_z(3, 24, 16, [[18, 21]])
	_wall_z(3, 24, 32, [[19, 22]])
	_wall_x(16, 32, 24, [], null, LOW_H)
	# Gründer-Statue auf Sockel
	Toon.cyl(self, 1.6, 1.8, 0.5, Vector3(24, 0.25, 13), m_wall_low, 8)
	Toon.cyl(self, 0.9, 1.0, 1.4, Vector3(24, 1.2, 13), m_wall_dark_low, 8)
	Toon.collider(nav, Vector3(2.4, 2.0, 2.4), Vector3(24, 1.0, 13))
	var ring := Toon.quad_holo(self, Vector2(5.0, 5.0), Vector3(24, 0.06, 13), Toon.holo(Toon.CYAN, 0.5, true, 0.0))
	ring.set_meta("keep", true)
	var statue := Humanoid.new({"skin": Color(0.55, 0.57, 0.62), "suit": Color(0.5, 0.52, 0.57), "suit2": Color(0.42, 0.44, 0.5),
		"accent": Color(0.3, 0.9, 1.0), "hair": Color(0.45, 0.47, 0.52), "coat": true, "cape": true, "cape_color": Color(0.46, 0.48, 0.53),
		"scale": 1.5, "hair_style": "slick", "pads": true, "metal": Color(0.5, 0.52, 0.57)})
	statue.position = Vector3(24, 1.9, 13)
	statue.rotation.y = PI
	statue.set_meta("keep", true)
	add_child(statue)
	statue.add_blade(Color(0.3, 0.9, 1.0), 1.4, 0.07)
	statue.animate(0.016, 0.0)
	for p in [Vector3(18.5, 0, 6), Vector3(29.5, 0, 6), Vector3(18.5, 0, 22), Vector3(29.5, 0, 22)]:
		_tree(p, randf_range(0.9, 1.15))
	for p in [Vector3(21, 0, 9), Vector3(27, 0, 9), Vector3(21, 0, 17), Vector3(27, 0, 17)]:
		_lamp(p)
	var wood := Toon.mat(Color(0.32, 0.22, 0.16), {"outline": 0.03, "radial": 1.0})
	for p in [Vector3(18.2, 0, 13), Vector3(29.8, 0, 13)]:
		Toon.box(self, Vector3(0.6, 0.12, 2.2), p + Vector3(0, 0.45, 0), wood)
		Toon.box(self, Vector3(0.12, 0.5, 2.2), p + Vector3(0.3 * (1 if p.x > 24 else -1), 0.75, 0), wood)
		Toon.collider(nav, Vector3(0.6, 0.6, 2.2), p + Vector3(0, 0.3, 0))
	_omni(Vector3(24, 3.5, 13), Color(0.55, 0.65, 1.0), 1.3, 12.0)

# ---------- Schlafsaal ----------

func _build_dorm() -> void:
	var r: Rect2 = ZONES.dorm
	var wood_floor := Toon.mat(Color(0.3, 0.24, 0.21), {"tiles": 0.3, "tile_size": 1.0})
	_floor(r, wood_floor)
	_wall_x(-2, 16, 14)
	_wall_x(-2, 16, 28, [], null, LOW_H)
	_wall_z(14, 28, -2)
	_wall_z(24, 28, 16)
	var frame := Toon.mat(Color(0.2, 0.21, 0.25), {"outline": 0.03, "radial": 1.0})
	var sheet := Toon.mat(Color(0.65, 0.68, 0.74), {"outline": 0.02, "radial": 1.0})
	var blanket := Toon.mat(Color(0.18, 0.28, 0.48), {"outline": 0.02, "radial": 1.0})
	for i in 5:
		var x := 0.5 + i * 3.2
		for z in [15.6, 26.2]:
			if z > 20.0 and i == 4:
				continue
			for lvl in [0.45, 1.55]:
				Toon.box(self, Vector3(1.0, 0.12, 2.0), Vector3(x, lvl, z), frame)
				Toon.box(self, Vector3(0.9, 0.12, 1.9), Vector3(x, lvl + 0.12, z), sheet)
				Toon.box(self, Vector3(0.92, 0.08, 1.2), Vector3(x, lvl + 0.2, z + (0.35 if z < 20 else -0.35)), blanket)
			for cx in [-0.45, 0.45]:
				for cz in [-0.95, 0.95]:
					Toon.box(self, Vector3(0.08, 2.0, 0.08), Vector3(x + cx, 1.0, z + cz), frame)
			Toon.collider(nav, Vector3(1.0, 2.0, 2.0), Vector3(x, 1.0, z))
	for i in 4:
		var lz := 17.0 + i * 1.0
		Toon.box(self, Vector3(0.6, 2.0, 0.9), Vector3(-1.3, 1.0, lz), m_metal)
		_neon(Vector3(0.04, 0.3, 0.04), Vector3(-0.98, 1.3, lz + 0.2), false)
	Toon.collider(nav, Vector3(0.6, 2.0, 4.0), Vector3(-1.3, 1.0, 18.5))
	_omni(Vector3(3, 2.6, 20), Color(1.0, 0.82, 0.6), 1.4, 9.0)
	_omni(Vector3(12, 2.6, 21), Color(1.0, 0.82, 0.6), 1.1, 8.0)

# ---------- Mensa ----------

func _build_mensa() -> void:
	var r: Rect2 = ZONES.mensa
	_floor(r, Toon.mat(Color(0.34, 0.32, 0.3), {"tiles": 0.4, "tile_size": 1.5}))
	_wall_x(32, 50, 17)
	_wall_x(32, 50, 31, [], null, LOW_H)
	_wall_z(17, 31, 50)
	_wall_z(24, 31, 32)
	var wood := Toon.mat(Color(0.4, 0.28, 0.2), {"outline": 0.03, "radial": 1.0})
	var tray_m := Toon.mat(Color(0.6, 0.62, 0.66), {"outline": 0.01})
	for tz in [25.0, 28.5]:
		for tx in [36.0, 44.0]:
			Toon.box(self, Vector3(5.0, 0.12, 1.2), Vector3(tx, 0.85, tz), wood)
			for lx in [-2.2, 2.2]:
				Toon.box(self, Vector3(0.12, 0.8, 1.0), Vector3(tx + lx, 0.4, tz), m_trim_low)
			for bz in [-0.95, 0.95]:
				Toon.box(self, Vector3(4.8, 0.1, 0.4), Vector3(tx, 0.48, tz + bz), wood)
			for k in 4:
				var tray := Toon.box(self, Vector3(0.45, 0.04, 0.3), Vector3(tx - 1.8 + k * 1.2, 0.93, tz + (0.25 if k % 2 == 0 else -0.25)), tray_m)
				tray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			Toon.collider(nav, Vector3(5.0, 0.9, 2.4), Vector3(tx, 0.45, tz))
	# Ausgabetheke, der Quartiermeister steht dahinter
	Toon.box(self, Vector3(9.0, 1.1, 0.9), Vector3(41, 0.55, 21.6), m_metal)
	Toon.box(self, Vector3(9.2, 0.08, 1.0), Vector3(41, 1.12, 21.6), m_trim_low)
	_neon(Vector3(9.0, 0.05, 0.05), Vector3(41, 1.0, 22.08), false)
	Toon.collider(nav, Vector3(9.0, 1.1, 0.9), Vector3(41, 0.55, 21.6))
	for x in [37.0, 45.0]:
		Toon.box(self, Vector3(2.4, 2.4, 0.6), Vector3(x, 1.2, 17.8), m_trim)
		for k in 3:
			Toon.box(self, Vector3(0.6, 0.5, 0.45), Vector3(x - 0.7 + k * 0.7, 0.9 + (k % 2) * 0.8, 17.9), m_metal)
	var sign := Label3D.new()
	sign.text = "MENSA · QUARTIERMEISTER"
	sign.font = HoloUI.F_BOLD
	sign.font_size = 64
	sign.pixel_size = 0.008
	sign.modulate = Color(0.5, 0.95, 1.0)
	sign.outline_size = 0
	sign.position = Vector3(41, 2.6, 17.45)
	add_child(sign)
	_omni(Vector3(41, 2.6, 20.5), Color(1.0, 0.85, 0.65), 1.6, 9.0)
	_omni(Vector3(40, 2.6, 27), Color(1.0, 0.85, 0.65), 1.2, 10.0)

# ---------- Aufzug ----------

func _build_lift() -> void:
	for pos in [LIFT_POS, CRYPT_LIFT]:
		var base := Toon.cyl(self, 1.1, 1.2, 0.16, pos + Vector3(0, 0.08, 0), m_metal, 10)
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for k in 4:
			var a := TAU * k / 4.0 + PI * 0.25
			Toon.box(self, Vector3(0.18, 2.8, 0.18), pos + Vector3(cos(a) * 1.15, 1.4, sin(a) * 1.15), m_trim_low)
		for k in 4:
			var a2 := TAU * k / 4.0 + PI * 0.25
			var lamp := Toon.sphere(self, 0.09, pos + Vector3(cos(a2) * 1.15, 2.85, sin(a2) * 1.15), m_neon_c, Vector3.ONE, 6)
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var g := Toon.quad_holo(self, Vector2(2.0, 2.0), pos + Vector3(0, 0.2, 0), Toon.holo(Color(1.0, 0.7, 0.2), 1.0, true, 0.0))
		g.set_meta("keep", true)
		if pos == LIFT_POS:
			lift_glow = g
		_omni(pos + Vector3(0, 2.4, 0), Color(1.0, 0.75, 0.35), 1.0, 5.0)

# ---------- Katakomben ----------

func _bones(pos: Vector3, n := 6, spread := 0.8) -> void:
	var bone := Toon.mat(Color(0.62, 0.58, 0.5), {"outline": 0.02, "radial": 1.0})
	for i in n:
		var p := pos + Vector3(randf_range(-spread, spread), 0.06, randf_range(-spread, spread))
		if randf() < 0.3:
			Toon.sphere(self, 0.13, p + Vector3(0, 0.08, 0), bone, Vector3(1.0, 0.9, 1.1), 7)
		else:
			Toon.cyl(self, 0.035, 0.035, randf_range(0.35, 0.6), p, bone, 5, Vector3(PI * 0.5, randf() * TAU, 0))

func _candles(pos: Vector3) -> void:
	var wax := Toon.mat(Color(0.85, 0.8, 0.7), {"outline": 0.01})
	var flame := Toon.mat(Color(1.0, 0.6, 0.2), {"emit": Color(1.0, 0.55, 0.15), "energy": 3.0})
	for i in 3:
		var p := pos + Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
		var h := randf_range(0.15, 0.35)
		Toon.cyl(self, 0.04, 0.045, h, p + Vector3(0, h * 0.5, 0), wax, 6)
		var f := Toon.sphere(self, 0.03, p + Vector3(0, h + 0.04, 0), flame, Vector3(1, 1.6, 1), 5)
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	candles.append(_omni(pos + Vector3(0, 0.8, 0), Color(1.0, 0.55, 0.2), 1.3, 6.0))

func _coffin(pos: Vector3, rot := 0.0) -> void:
	var stone := Toon.mat(Color(0.26, 0.25, 0.28), {"outline": 0.035, "radial": 1.0, "grime": 0.6})
	Toon.box(self, Vector3(1.0, 0.7, 2.2), pos + Vector3(0, 0.35, 0), stone, Vector3(0, rot, 0))
	Toon.box(self, Vector3(1.1, 0.12, 2.3), pos + Vector3(0, 0.76, 0), m_wall_dark_low, Vector3(0, rot, 0))
	Toon.collider(nav, Vector3(1.0, 0.8, 2.2), pos + Vector3(0, 0.4, 0), rot)

func _build_catacombs() -> void:
	var crypt_floor := Toon.mat(Color(0.2, 0.19, 0.22), {"tiles": 0.6, "tile_size": 1.5, "grime": 0.8})
	var crypt_wall := Toon.mat(Color(0.22, 0.2, 0.25), {"outline": 0.05, "radial": 1.0, "fade": true, "grime": 0.8})
	for z in ["crypt", "tunnel", "ossuary", "descent"]:
		_floor(ZONES[z], crypt_floor)
	_floor(ZONES.brood, Toon.mat(Color(0.16, 0.2, 0.15), {"tiles": 0.4, "tile_size": 2.0, "grime": 0.9}))
	# Gruft
	_wall_x(-72, -48, -38, [[-63, -57]], crypt_wall)
	_wall_x(-72, -48, -20, [], null, LOW_H)
	_wall_z(-38, -20, -72, [[-32, -26]], crypt_wall)
	_wall_z(-38, -20, -48, [], crypt_wall)
	for p in [Vector3(-68, 0, -35), Vector3(-52, 0, -35)]:
		_coffin(p)
	_coffin(Vector3(-67, 0, -24), PI * 0.5)
	for p in [Vector3(-66, 0, -30), Vector3(-54, 0, -30)]:
		_pillar(p, WALL_H + 0.3, false)
	for p in [Vector3(-70, 0, -21.5), Vector3(-50, 0, -21.5), Vector3(-64, 0, -37), Vector3(-56, 0, -37)]:
		_candles(p)
	_bones(Vector3(-57, 0, -25), 7, 1.0)
	# Schacht
	_wall_x(-78, -72, -32, [], crypt_wall)
	_wall_x(-78, -72, -26, [], null, LOW_H)
	# Ossarium
	_wall_x(-104, -78, -44, [], crypt_wall)
	_wall_x(-104, -78, -16, [], null, LOW_H)
	_wall_z(-44, -16, -104, [], crypt_wall)
	_wall_z(-44, -16, -78, [[-32, -26]], crypt_wall)
	var bone := Toon.mat(Color(0.55, 0.52, 0.46), {"outline": 0.035, "radial": 1.0, "fade": true, "grime": 0.7})
	for p in [Vector3(-96, 0, -30), Vector3(-88, 0, -36), Vector3(-88, 0, -24), Vector3(-96, 0, -22), Vector3(-96, 0, -40)]:
		Toon.cyl(self, 0.55, 0.65, 3.4, p + Vector3(0, 1.7, 0), bone, 8)
		for k in 4:
			var sk := Toon.sphere(self, 0.16, p + Vector3(0.55, 0.6 + k * 0.75, 0).rotated(Vector3.UP, k * 1.3), bone, Vector3(1.0, 0.9, 1.1), 6)
			sk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Toon.collider(nav, Vector3(1.2, 2.0, 1.2), p + Vector3(0, 1.0, 0))
	for p in [Vector3(-101, 0, -42), Vector3(-80, 0, -42), Vector3(-101, 0, -18), Vector3(-92, 0, -30)]:
		_candles(p)
	for p in [Vector3(-84, 0, -32), Vector3(-100, 0, -33), Vector3(-90, 0, -19)]:
		_bones(p, 8, 1.2)
	_omni(Vector3(-91, 3.0, -30), Color(0.55, 0.35, 0.9), 1.2, 14.0)
	# Abstieg
	_wall_z(-50, -38, -63, [], null, LOW_H)
	_wall_z(-50, -38, -57, [], null, LOW_H)
	red_lights.append(_omni(Vector3(-60, 2.4, -44), Color(1.0, 0.2, 0.5), 1.4, 7.0))
	# Brutkammer
	_wall_x(-74, -46, -76, [], m_wall_dark)
	_wall_x(-74, -46, -50, [[-63, -57]], null, LOW_H)
	_wall_z(-76, -50, -74, [], m_wall_dark)
	_wall_z(-76, -50, -46, [], m_wall_dark)
	for p in [Vector3(-70, 0, -72), Vector3(-50, 0, -72), Vector3(-70, 0, -55), Vector3(-50, 0, -55), Vector3(-66, 0, -63), Vector3(-54, 0, -68)]:
		_resin_blob(p, randf_range(1.0, 1.7))
	var arena := Toon.quad_holo(self, Vector2(16, 16), BROOD_POS + Vector3(0, 0.05, 0), Toon.holo(Color(1.0, 0.25, 0.7), 0.35, true, 0.0))
	arena.set_meta("keep", true)
	_omni(BROOD_POS + Vector3(0, 3.5, 4), Color(1.0, 0.3, 0.75), 1.6, 14.0)
	_omni(Vector3(-68, 2.4, -58), Color(0.5, 1.0, 0.3), 1.0, 8.0)
	_omni(Vector3(-52, 2.4, -58), Color(0.5, 1.0, 0.3), 1.0, 8.0)
	# Erinnerungsfragmente (schwebende Blutkristalle)
	for fp in FRAGMENTS:
		var n := Node3D.new()
		n.position = fp + Vector3(0, 1.2, 0)
		n.set_meta("keep", true)
		add_child(n)
		var crystal := PrismMesh.new()
		crystal.size = Vector3(0.3, 0.6, 0.3)
		var c := Toon.mesh(n, crystal, Toon.mat(Color(1.0, 0.2, 0.3), {"emit": Color(1.0, 0.15, 0.3), "energy": 2.2, "outline": 0.02, "radial": 1.0}), Vector3.ZERO, Vector3.ZERO, false)
		Toon.mesh(n, crystal, c.material_override, Vector3(0, -0.6, 0), Vector3(PI, 0, 0), false)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.25, 0.35)
		l.light_energy = 1.4
		l.omni_range = 4.0
		n.add_child(l)
		fragment_nodes.append(n)

# ---------- Laufzeit ----------

func zone_at(p: Vector3) -> String:
	for k in ZONES:
		if (ZONES[k] as Rect2).grow(0.3).has_point(Vector2(p.x, p.z)):
			return k
	return ""

func _process(delta: float) -> void:
	_t += delta
	if relic:
		relic.rotation.y += delta * 0.6
		var p := 1.0 + sin(_t * 3.0) * 0.06 + maxf(0.0, sin(_t * 6.0)) * 0.05
		relic_core.scale = Vector3(p, p * 1.2, p)
		relic.position.y = RELIC_POS.y + 1.5 + sin(_t * 1.3) * 0.1
		for k in 2:
			var ring := relic.get_node("Ring%d" % k) as Node3D
			ring.rotation.x += delta * (0.8 + k * 0.5)
			ring.rotation.z += delta * (0.4 - k * 0.3)
	for i in red_lights.size():
		red_lights[i].light_energy = 0.6 + 1.4 * max(0.0, sin(_t * 3.0 + i * 1.7))
	for i in candles.size():
		candles[i].light_energy = 1.1 + 0.25 * sin(_t * 11.0 + i * 2.3) + 0.15 * sin(_t * 23.0 + i)
	if lift_glow:
		Toon.set_alpha(lift_glow, 1.0 if PlayerStats.s.get("lift_unlocked", false) else 0.15)
	var frags: Array = PlayerStats.s.get("fragments", [])
	for i in fragment_nodes.size():
		var n: Node3D = fragment_nodes[i]
		n.visible = int(PlayerStats.s.story) >= 8 and not frags.has(i)
		n.rotation.y += delta * 1.5
		n.position.y = 1.2 + sin(_t * 2.0 + i) * 0.12
	# Nacht: etwas dunkler, Gewölbe-Glyphe glimmt um Mitternacht
	var h := PlayerStats.clock_hour()
	var night := 1.0 if (h >= 22 or h < 5) else 0.0
	var amb := 0.62 - night * 0.12
	if absf(env.ambient_light_energy - amb) > 0.01:
		env.ambient_light_energy = move_toward(env.ambient_light_energy, amb, delta * 0.1)
	var midnight := h == 0
	var ga := (0.6 + sin(_t * 4.0) * 0.3) if midnight else (0.08 + (0.07 * maxf(0.0, sin(_t * 2.0)) if PlayerStats.has_skill("predator_sense") else 0.0))
	Toon.set_alpha(vault_glyph, ga)
	vault_light.light_energy = 2.2 if midnight else 0.3
