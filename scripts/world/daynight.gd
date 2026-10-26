class_name DayNight
extends Node3D
## Himmel, Sonne/Mond, Umgebungslicht und Nebel abhängig von der Tageszeit (Minuten seit Mitternacht).
## Dazu Wetter (Regen, dichter Nebel) und der Schleier am Weltrand.

const SKY_SHADER := preload("res://shaders/sky.gdshader")
const VEIL_SHADER := preload("res://shaders/veil.gdshader")

var env: Environment
var sun: DirectionalLight3D
var sky_mat: ShaderMaterial
var minutes := 21.0 * 60.0
var night := 0.0       # 0 = Tag, 1 = tiefe Nacht
var daylight := 1.0    # Sonnenstärke 0..1 (für Sonnenschaden)
var rain := 0.0
var rain_target := 0.0
var _rain_t := 120.0
var rain_fx: GPUParticles3D
var follow: Node3D
var veil_mat: ShaderMaterial

# Farbpaletten: [Himmel oben, Horizont, Umgebung, Nebel, Sonnenlicht]
const DAY := [Color(0.24, 0.36, 0.56), Color(0.6, 0.63, 0.66), Color(0.5, 0.53, 0.58), Color(0.5, 0.54, 0.58), Color(1.0, 0.93, 0.82)]
const DUSK := [Color(0.18, 0.16, 0.28), Color(0.7, 0.38, 0.28), Color(0.56, 0.44, 0.46), Color(0.42, 0.3, 0.28), Color(1.0, 0.58, 0.36)]
const NIGHT := [Color(0.05, 0.07, 0.15), Color(0.16, 0.17, 0.27), Color(0.46, 0.52, 0.72), Color(0.12, 0.14, 0.21), Color(0.62, 0.72, 1.0)]

func _ready() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ShaderMaterial.new()
	sky_mat.shader = SKY_SHADER
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 1.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.55
	env.glow_bloom = 0.04
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_begin = 30.0
	env.fog_depth_end = 230.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.1
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.08
	env.adjustment_saturation = 0.88
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 42.0
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.shadow_blur = 1.5
	add_child(sun)
	_build_veil()
	_build_rain()
	update(0.0)

func _build_veil() -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 302.0
	cm.bottom_radius = 302.0
	cm.height = 160.0
	cm.radial_segments = 96
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	var m := ShaderMaterial.new()
	m.shader = VEIL_SHADER
	mi.material_override = m
	veil_mat = m
	mi.position.y = 60.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)

func _build_rain() -> void:
	rain_fx = GPUParticles3D.new()
	rain_fx.amount = 1400
	rain_fx.lifetime = 0.9
	rain_fx.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(16, 1, 16)
	pm.direction = Vector3(0.1, -1, 0.05)
	pm.spread = 3.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 22.0
	pm.gravity = Vector3(0, -4, 0)
	rain_fx.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.015, 0.5)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.albedo_color = Color(0.7, 0.75, 0.85, 0.35)
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	q.material = qm
	rain_fx.draw_pass_1 = q
	rain_fx.emitting = false
	add_child(rain_fx)

func is_night() -> bool:
	return night > 0.5

## Sonnenhöhe 0..1 über dem Horizont
func _sun_height(m: float) -> float:
	# Sonnenaufgang 6:00, Untergang 20:00
	# stetig: unter dem Horizont negativ (bis −0.25), keine Sprünge um 6 und 20 Uhr
	var t := fmod(m - 6.0 * 60.0 + 24.0 * 60.0, 24.0 * 60.0) / (14.0 * 60.0)
	if t > 1.0:
		t = t - 24.0 * 60.0 / (14.0 * 60.0) if t > 1.36 else t
	return clampf(sin(t * PI), -0.25, 1.0)

func update(delta: float) -> void:
	var sh := _sun_height(minutes)
	night = clampf(1.0 - (sh + 0.12) / 0.3, 0.0, 1.0)
	daylight = clampf(sh * 1.6, 0.0, 1.0) * (1.0 - rain * 0.6)
	var dusk := clampf(1.0 - absf(sh - 0.08) / 0.22, 0.0, 1.0) * (1.0 - night * 0.6)
	var pal: Array = []
	for i in DAY.size():
		var c: Color = (DAY[i] as Color).lerp(NIGHT[i], night)
		c = c.lerp(DUSK[i], dusk * 0.75)
		pal.append(c)
	# Regen dämpft alles ins Graue
	for i in 4:
		pal[i] = (pal[i] as Color).lerp(Color(0.3, 0.32, 0.35) * (1.0 - night * 0.75), rain * 0.5)
	sky_mat.set_shader_parameter("top_color", pal[0])
	sky_mat.set_shader_parameter("horizon_color", pal[1])
	sky_mat.set_shader_parameter("night", night)
	env.ambient_light_color = pal[2]
	env.ambient_light_energy = lerpf(0.9, 1.35, night)
	env.fog_light_color = pal[3]
	env.fog_depth_end = lerpf(320.0, 170.0, maxf(night * 0.7, rain))
	env.fog_depth_begin = lerpf(45.0, 25.0, maxf(rain, night * 0.4))
	env.tonemap_exposure = 1.15 * PlayerStats.brightness
	# Sonne bzw. Mond
	var t := (minutes - 6.0 * 60.0) / (14.0 * 60.0)
	var ang := clampf(t, -0.1, 1.1) * PI
	var dir := Vector3(cos(ang), sin(ang) * 0.85 + 0.05, -0.35).normalized()
	if night > 0.5:
		var tn := fmod(minutes - 20.0 * 60.0 + 24.0 * 60.0, 24.0 * 60.0) / (10.0 * 60.0)
		var an := clampf(tn, 0.0, 1.0) * PI
		dir = Vector3(-cos(an), sin(an) * 0.7 + 0.15, 0.4).normalized()
	sky_mat.set_shader_parameter("sun_dir", dir if night < 0.5 else -dir)
	sky_mat.set_shader_parameter("sun_color", pal[4])
	sun.look_at_from_position(Vector3.ZERO, -dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.FORWARD)
	sun.light_color = pal[4]
	sun.light_energy = lerpf(maxf(0.25, sh) * 1.2, 0.95, night) * (1.0 - rain * 0.35)
	sun.shadow_opacity = lerpf(0.8, 0.55, night)
	veil_mat.set_shader_parameter("strength", lerpf(0.3, 0.7, night))
	# Wetter
	_rain_t -= delta
	if _rain_t <= 0.0:
		_rain_t = randf_range(150.0, 420.0)
		rain_target = 1.0 if randf() < 0.28 else 0.0
	rain = move_toward(rain, rain_target, delta * 0.05)
	rain_fx.emitting = rain > 0.15
	rain_fx.amount_ratio = clampf(rain, 0.0, 1.0)
	if follow:
		rain_fx.global_position = follow.global_position + Vector3(0, 12, 0)
		sun.global_position = follow.global_position
