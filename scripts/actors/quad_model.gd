class_name QuadModel
extends Node3D
## Vierbeiner aus Quaternius „Ultimate Animated Animals“ (CC0): Grauläufer = Hirschkuh/Hirsch, Reißer = Wolf.
## Gleiche Schnittstelle wie früher: play(action), animate(delta, speed), action, action_t.

const DEF := {
	"grazer": {"file": "res://assets/animals/deer.glb", "height": 1.25, "tint": Color(0.62, 0.62, 0.66), "prefix": "",
		"idle": "Idle", "walk": "Walk", "run": "Gallop", "graze": "Eating", "dead": "Death", "lie": "Idle_Headlow", "hurt": "Idle_HitReact_Left",
		"attack": "Attack_Headbutt", "windup": "Idle_2", "alert": "Idle_2"},
	"stag": {"file": "res://assets/animals/stag.glb", "height": 1.45, "tint": Color(0.6, 0.6, 0.64), "prefix": "",
		"idle": "Idle", "walk": "Walk", "run": "Gallop", "graze": "Eating", "dead": "Death", "lie": "Idle_Headlow", "hurt": "Idle_HitReact_Left",
		"attack": "Attack_Headbutt", "windup": "Idle_2", "alert": "Idle_2"},
	"reisser": {"file": "res://assets/animals/Wolf.glb", "height": 1.15, "tint": Color(0.38, 0.32, 0.34), "prefix": "AnimalArmature|",
		"idle": "Idle", "walk": "Walk", "run": "Gallop", "graze": "Eating", "dead": "Death", "lie": "Idle_2_HeadLow", "hurt": "Idle_HitReact_Left",
		"attack": "Attack", "windup": "Idle_2_HeadLow", "alert": "Idle_2"},
}

var kind := "grazer"
var action := ""
var action_t := 0.0
var move_amt := 0.0
var rig: Node3D
var anim: AnimationPlayer
var _cfg: Dictionary
var _cur := ""
var _walk_ref := 1.4
var _run_ref := 5.0

func _init(k := "grazer") -> void:
	kind = k

func _ready() -> void:
	_cfg = DEF.get(kind, DEF.grazer)
	var ps := load(_cfg.file) as PackedScene
	rig = ps.instantiate() as Node3D
	rig.rotation.y = PI    # Modelle schauen nach +Z, unsere Vorderseite ist −Z
	add_child(rig)
	anim = rig.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for n in ["idle", "walk", "run", "graze", "lie", "alert"]:
		var a := anim.get_animation(_cfg.prefix + _cfg[n])
		if a:
			a.loop_mode = Animation.LOOP_LINEAR
	_play("idle", 0.0)
	anim.advance(randf() * 2.0)
	# auf Zielhöhe skalieren (Knochen der Ruhepose vermessen)
	var sk := rig.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var top := 0.0
	for i in sk.get_bone_count():
		top = maxf(top, (sk.global_transform * sk.get_bone_global_rest(i)).origin.y - rig.global_position.y)
	if top > 0.001:
		rig.scale = Vector3.ONE * (float(_cfg.height) / (top * 1.08))
	# Farbe und Augen
	var tint: Color = _cfg.tint
	for mi in rig.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		for i in m3.mesh.get_surface_count():
			var m := m3.get_active_material(i) as StandardMaterial3D
			if m == null:
				continue
			var nm := m.duplicate() as StandardMaterial3D
			var low := m.resource_name.to_lower()
			if kind == "reisser" and (low.contains("eye") or low.contains("black") and m.albedo_color.v < 0.1):
				nm.emission_enabled = true
				nm.emission = Color(1.0, 0.1, 0.12)
				nm.emission_energy_multiplier = 2.5
			else:
				var c := m.albedo_color
				var l := c.r * 0.3 + c.g * 0.59 + c.b * 0.11
				nm.albedo_color = Color(l, l, l).lerp(c, 0.35) * tint * 1.6
			nm.roughness = 0.95
			m3.set_surface_override_material(i, nm)

func _play(key: String, blend := 0.2) -> void:
	var name: String = _cfg.prefix + _cfg.get(key, _cfg.idle)
	if name == _cur or not anim.has_animation(name):
		return
	_cur = name
	anim.play(name, blend)

func play(a: String) -> void:
	action = a
	action_t = 0.0
	if a != "" and _cfg.has(a):
		_play(a, 0.12 if a in ["attack", "hurt"] else 0.25)

func animate(delta: float, speed: float) -> void:
	move_amt = lerpf(move_amt, clampf(speed / 4.5, 0.0, 1.6), minf(1.0, delta * 8.0))
	if action != "" and action != "dead" and action != "graze" and action != "lie":
		action_t += delta / 0.45
		if action_t >= 1.0 and action != "windup":
			action = ""
	anim.speed_scale = 1.0
	if action == "":
		if speed < 0.3:
			_play("idle")
		elif speed < 3.2:
			_play("walk")
			anim.speed_scale = clampf(speed / _walk_ref, 0.6, 1.8)
		else:
			_play("run")
			anim.speed_scale = clampf(speed / _run_ref, 0.7, 1.6)
	anim.advance(delta)
