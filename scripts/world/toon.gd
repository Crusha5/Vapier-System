class_name Toon
extends RefCounted
## Materialien (Cel-Shading + Kontur) und kleine Geometrie-Bausteine.

const TOON := preload("res://shaders/toon.gdshader")
const TOON_ACTOR := preload("res://shaders/toon_actor.gdshader")
const OUTLINE := preload("res://shaders/outline.gdshader")
const OUTLINE_ACTOR := preload("res://shaders/outline_actor.gdshader")
const HOLO := preload("res://shaders/holo.gdshader")

# Palette (abgeleitet vom App-Icon: Neon-Rot, Cyan, dunkles Mauerwerk)
const RED := Color(1.0, 0.12, 0.2)
const RED_DEEP := Color(0.55, 0.03, 0.08)
const CYAN := Color(0.2, 0.92, 1.0)
const STONE := Color(0.3, 0.33, 0.4)
const STONE_DARK := Color(0.17, 0.19, 0.25)
const METAL := Color(0.42, 0.46, 0.53)
const CHITIN := Color(0.16, 0.32, 0.3)
const INK := Color(0.015, 0.012, 0.03)

static var _cache := {}

static func mat(color: Color, opts := {}) -> ShaderMaterial:
	var key := str(color) + str(opts)
	if _cache.has(key):
		return _cache[key]
	var actor: bool = opts.get("actor", false)
	var m := ShaderMaterial.new()
	m.shader = TOON_ACTOR if actor else TOON
	m.set_shader_parameter("albedo", color)
	if opts.has("emit"):
		m.set_shader_parameter("emission", opts.emit)
		m.set_shader_parameter("emission_energy", opts.get("energy", 1.0))
	if opts.has("rim"):
		m.set_shader_parameter("rim_strength", opts.rim)
		m.set_shader_parameter("rim_color", opts.get("rim_color", CYAN))
	if opts.has("spec"):
		m.set_shader_parameter("spec_strength", opts.spec)
	if opts.has("tiles"):
		m.set_shader_parameter("tiles", opts.tiles)
		m.set_shader_parameter("tile_size", opts.get("tile_size", 2.0))
	if opts.has("grime"):
		m.set_shader_parameter("grime", opts.grime)
	if opts.get("fade", false):
		m.set_shader_parameter("fade_occluder", true)
	if opts.get("outline", 0.0) > 0.0:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_ACTOR if actor else OUTLINE
		o.set_shader_parameter("thickness", opts.outline)
		o.set_shader_parameter("radial", opts.get("radial", 0.0))
		if opts.get("fade", false) and not actor:
			o.set_shader_parameter("fade_occluder", true)
		m.next_pass = o
	_cache[key] = m
	return m

## Material für Figuren (Treffer-Blitz/Färbung pro Instanz)
static func amat(color: Color, opts := {}) -> ShaderMaterial:
	var o := opts.duplicate()
	o["actor"] = true
	return mat(color, o)

static func holo(color: Color, energy := 1.6, rings := false, scan := 0.25) -> ShaderMaterial:
	var key := "holo" + str(color) + str(energy) + str(rings) + str(scan)
	if _cache.has(key):
		return _cache[key]
	var m := ShaderMaterial.new()
	m.shader = HOLO
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("ring_mode", 1.0 if rings else 0.0)
	m.set_shader_parameter("scan", scan)
	_cache[key] = m
	return m

# ---------- Geometrie ----------

static func mesh(parent: Node, m: Mesh, mt: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mt
	mi.position = pos
	mi.rotation = rot
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi

static func box(parent: Node, size: Vector3, pos: Vector3, mt: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh(parent, b, mt, pos, rot)

static func cyl(parent: Node, r_top: float, r_bot: float, h: float, pos: Vector3, mt: Material, segs := 8, rot := Vector3.ZERO) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segs
	c.rings = 1
	return mesh(parent, c, mt, pos, rot)

static func sphere(parent: Node, r: float, pos: Vector3, mt: Material, scale := Vector3.ONE, segs := 8) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segs
	s.rings = max(3, segs / 2)
	var mi := mesh(parent, s, mt, pos)
	mi.scale = scale
	return mi

static func prism(parent: Node, size: Vector3, pos: Vector3, mt: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var p := PrismMesh.new()
	p.size = size
	return mesh(parent, p, mt, pos, rot)

static func quad_holo(parent: Node, size: Vector2, pos: Vector3, mt: Material, rot := Vector3(-PI / 2, 0, 0)) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	var mi := mesh(parent, q, mt, pos, rot, false)
	return mi

## Statische Kollision (unsichtbar) – Kästen für Wände, Säulen, Kisten.
static func collider(parent: Node, size: Vector3, pos: Vector3, rot_y := 0.0) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	sb.add_child(cs)
	sb.position = pos
	sb.rotation.y = rot_y
	parent.add_child(sb)
	return sb

static func solid(parent: Node, size: Vector3, pos: Vector3, mt: Material, rot_y := 0.0) -> MeshInstance3D:
	var mi := box(parent, size, pos, mt, Vector3(0, rot_y, 0))
	collider(parent, size, pos, rot_y)
	return mi

## Rekursiv instance-Parameter setzen (Treffer-Blitz, Färbung)
static func set_param(n: Node, param: String, v: Variant) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).set_instance_shader_parameter(param, v)
	for c in n.get_children():
		set_param(c, param, v)
