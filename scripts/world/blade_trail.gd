class_name BladeTrail
extends MeshInstance3D
## Leuchtende Klingenspur: speichert die letzten Positionen von Klingenwurzel und -spitze
## und zeichnet daraus ein ausblendendes Band (ImmediateMesh).

const LIFE := 0.16
const TRAIL_SHADER := preload("res://shaders/trail.gdshader")

var color := Color(1.0, 0.12, 0.22):
	set(v):
		color = v
		if _mat:
			_mat.set_shader_parameter("color", v)
var pts: Array = []   # [base, tip, age]
var im: ImmediateMesh
var _mat: ShaderMaterial

func _ready() -> void:
	im = ImmediateMesh.new()
	mesh = im
	_mat = ShaderMaterial.new()
	_mat.shader = TRAIL_SHADER
	_mat.set_shader_parameter("color", color)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true
	global_transform = Transform3D()

func feed(base: Vector3, tip: Vector3, active: bool, delta: float) -> void:
	for p in pts:
		p[2] += delta
	while pts.size() > 0 and float(pts[0][2]) > LIFE:
		pts.pop_front()
	if active:
		pts.append([base, tip, 0.0])
	im.clear_surfaces()
	if pts.size() < 2:
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for p in pts:
		var a := 1.0 - float(p[2]) / LIFE
		im.surface_set_color(Color(1, 1, 1, a * 0.15))
		im.surface_set_uv(Vector2(a, 0))
		im.surface_add_vertex(p[0])
		im.surface_set_color(Color(1, 1, 1, a))
		im.surface_set_uv(Vector2(a, 1))
		im.surface_add_vertex(p[1])
	im.surface_end()
