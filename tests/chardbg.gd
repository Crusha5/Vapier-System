extends Node3D
func _tree(n: Node, d := 0) -> void:
	var extra := ""
	if n is Skeleton3D:
		extra = " bones=%d" % (n as Skeleton3D).get_bone_count()
	if n is MeshInstance3D:
		extra = " mesh surf=%d skin=%s" % [(n as MeshInstance3D).mesh.get_surface_count(), (n as MeshInstance3D).skin != null]
	if n is AnimationPlayer:
		extra = " anims=" + str((n as AnimationPlayer).get_animation_list().slice(0, 60))
	if d < 5:
		print("TEST ", "  ".repeat(d), n.name, " (", n.get_class(), ")", extra)
	for c in n.get_children():
		_tree(c, d + 1)
func _ready() -> void:
	var k := (load("res://assets/chars/knight.glb") as PackedScene).instantiate()
	add_child(k)
	_tree(k)
	var c := (load("res://assets/chars/clips.glb") as PackedScene).instantiate()
	add_child(c)
	_tree(c)
	var ap := c.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var a := ap.get_animation("Walk_Loop")
	for i in mini(5, a.get_track_count()):
		print("TEST track ", a.track_get_path(i), " type ", a.track_get_type(i))
	var sk := k.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	print("TEST bones: ", [sk.get_bone_name(0), sk.get_bone_name(1), sk.get_bone_name(2), sk.get_bone_name(5)])
	get_tree().quit()
