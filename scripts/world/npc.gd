class_name Npc
extends StaticBody3D
## Freundliche Figur (Mira, Brann): steht herum, dreht sich zum Spieler, gestikuliert beim Reden.

var id := ""
var display := ""
var model: Humanoid
var world: Node
var talking := false
var talk_range := 2.6
var _face := 0.0
var _home_rot := 0.0
var marker: Label3D

static func create(npc_id: String, name: String, look: Dictionary, pos: Vector3, rot_y: float, w: Node) -> Npc:
	var n := Npc.new()
	n.id = npc_id
	n.display = name
	n.world = w
	n.position = pos
	n._home_rot = rot_y
	n._face = rot_y
	n.model = Humanoid.new(look)
	n.model.weapon_pose = false
	return n

func _ready() -> void:
	collision_layer = 1
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.4
	sh.height = 1.7
	cs.shape = sh
	cs.position.y = 0.85
	add_child(cs)
	add_child(model)
	model.rotation.y = _home_rot
	marker = Label3D.new()
	marker.text = "!"
	marker.font = HoloUI.F_BOLD
	marker.font_size = 96
	marker.pixel_size = 0.006
	marker.modulate = Color(1.0, 0.8, 0.3)
	marker.outline_size = 18
	marker.outline_modulate = Color(0, 0, 0, 0.8)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.position = Vector3(0, 2.35, 0)
	marker.visible = false
	add_child(marker)

func set_marker(v: bool, text := "!") -> void:
	marker.visible = v
	marker.text = text

func _process(delta: float) -> void:
	if world == null or world.player == null:
		return
	var p: Vector3 = world.player.global_position
	var d := p - global_position
	d.y = 0
	var target := _home_rot
	if d.length() < 5.0:
		target = atan2(-d.x, -d.z)
	_face = lerp_angle(_face, target, clampf(delta * 5.0, 0.0, 1.0))
	model.rotation.y = _face
	if talking and model.action != "talk":
		model.play("talk")
	elif not talking and model.action == "talk":
		model.action = ""
	model.animate(delta, 0.0)
	if marker.visible:
		marker.position.y = 2.35 + sin(Time.get_ticks_msec() * 0.005) * 0.08
