class_name CameraRig
extends Node3D
## Kamera: Third-Person über der Schulter (mit Kollision) oder Ego-Perspektive, umschaltbar.
## Gieren/Nicken per Touch-Wischen rechts; folgt beim Laufen sanft hinter die Figur.

var target: Node3D
var yaw := 0.0
var pitch := -0.18
var first_person := false
var camera: Camera3D
var arm: SpringArm3D
var pivot: Node3D
var shake := 0.0
var _idle_look := 0.0
var _fp_blend := 0.0
var cutscene := false
var cut_from := Vector3.ZERO
var cut_at := Vector3.ZERO
var zoom := 1.0

const ARM_LEN := 3.6
const SHOULDER := 0.55
const HEAD_Y := 1.62

func _ready() -> void:
	top_level = true
	pivot = Node3D.new()
	add_child(pivot)
	arm = SpringArm3D.new()
	arm.spring_length = ARM_LEN
	arm.collision_mask = 1
	arm.margin = 0.25
	var sh := SphereShape3D.new()
	sh.radius = 0.25
	arm.shape = sh
	pivot.add_child(arm)
	camera = Camera3D.new()
	camera.fov = 62.0
	camera.near = 0.08
	camera.far = 420.0
	arm.add_child(camera)
	camera.make_current()

func look(delta_px: Vector2) -> void:
	var sens := 0.0055 if not first_person else 0.0045
	yaw -= delta_px.x * sens
	pitch = clampf(pitch - delta_px.y * sens, -1.2 if first_person else -1.05, 1.1 if first_person else 0.55)
	_idle_look = 0.0

func set_first_person(v: bool) -> void:
	first_person = v

func _process(delta: float) -> void:
	if target == null:
		return
	_idle_look += delta
	_fp_blend = move_toward(_fp_blend, 1.0 if first_person else 0.0, delta * 4.0)
	var tp := target.global_position
	var head := tp + Vector3(0, HEAD_Y, 0)
	if cutscene:
		global_position = global_position.lerp(cut_from, minf(1.0, delta * 2.5))
		pivot.rotation = Vector3.ZERO
		arm.position = Vector3.ZERO
		arm.spring_length = 0.0
		camera.look_at(cut_at, Vector3.UP)
		return
	# Beim Laufen ohne Umsehen langsam hinter die Figur drehen (nur Third-Person)
	if not first_person and _idle_look > 1.6 and target.has_method("move_heading"):
		var mh: float = target.move_heading()
		if not is_nan(mh):
			yaw = lerp_angle(yaw, mh, minf(1.0, delta * 1.2))
	var follow_pos := head.lerp(tp + Vector3(0, 1.45, 0), 1.0 - _fp_blend)
	global_position = global_position.lerp(follow_pos, minf(1.0, delta * 18.0)) if global_position.distance_to(follow_pos) < 6.0 else follow_pos
	pivot.rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = lerpf(ARM_LEN * zoom, 0.0, _fp_blend)
	# Schulter-Versatz am Arm (die SpringArm setzt die Kamera-Position selbst)
	arm.position = Vector3(lerpf(SHOULDER, 0.0, _fp_blend), lerpf(0.15, 0.0, _fp_blend), 0)
	camera.rotation = Vector3.ZERO
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	if shake > 0.0:
		camera.h_offset = randf_range(-1, 1) * shake * 0.08
		camera.v_offset = randf_range(-1, 1) * shake * 0.08
		camera.rotation.z = randf_range(-1, 1) * shake * 0.01
		shake = maxf(0.0, shake - delta * 3.0)
	camera.fov = lerpf(62.0, 74.0, _fp_blend)

## Blickrichtung auf dem Boden (für die Bewegung)
func forward_flat() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

func right_flat() -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))

func aim_dir() -> Vector3:
	return -camera.global_transform.basis.z
