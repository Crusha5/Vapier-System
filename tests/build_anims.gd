extends Node
## Werkzeug: zieht ausgewählte Animationen aus UAL1/UAL2 (Quaternius, CC0) in eine AnimationLibrary.
## Nur Rotationen (plus Position für root/pelvis), komprimiert. Ergebnis: res://assets/chars/anims.res

const PICK := {
	"res://_ual/UAL1.glb": ["Idle_Loop", "Walk_Loop", "Jog_Fwd_Loop", "Sprint_Loop", "Sword_Idle", "Sword_Attack", "Roll", "Dodge_Left", "Dodge_Right",
		"Hit_Chest", "Hit_Head", "Death01", "Death02", "Sitting_Idle_Loop", "Sitting_Talking_Loop", "GroundSit_Idle_Loop", "Idle_Talking_Loop",
		"Idle_Tired_Loop", "Crouch_Idle_Loop", "Crouch_Fwd_Loop", "Fixing_Kneeling", "PickUp_Kneeling", "Interact", "Crying", "Spell_Simple_Shoot",
		"Punch_Cross", "Kick", "Idle_LookAround_Loop", "Idle_Torch_Loop", "Drink", "Walk_Formal_Loop", "Swim_Fwd_Loop", "Swim_Idle_Loop",
		"Jump_Start", "Jump_Loop", "Jump_Land", "Counter_Idle_Loop", "Sitting_Enter", "Sitting_Exit"],
	"res://_ual/UAL2.glb": ["Sword_Regular_A", "Sword_Regular_B", "Sword_Regular_C", "Sword_Heavy_A", "Sword_Dash", "Sword_Block", "Hit_Knockback",
		"IdleToLay", "LayToIdle", "Zombie_Bite", "Idle_FoldArms_Loop", "Idle_Lantern_Loop", "Farm_Harvest", "Mining_Loop", "TreeChopping_Loop",
		"Bow_Shoot", "Bow_Aim_Neutral", "Idle_No_Loop", "Yes", "Surprise", "Consume", "Bandage_Loop", "Chest_Open", "Melee_Hook",
		"Walk_Carry_Loop", "Shield_OneShot", "Idle_Shield_Loop", "Walk_Fwd_Loop", "Zombie_Scratch"],
}

func _ready() -> void:
	var lib := AnimationLibrary.new()
	for path in PICK:
		var sc := (load(path) as PackedScene).instantiate()
		var ap := sc.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var names := ap.get_animation_list()
		print("TEST ", path, " hat ", names.size(), " Animationen, Beispielspur: ", ap.get_animation(names[1]).track_get_path(0))
		for want in PICK[path]:
			var key: String = want.replace("_Loop", "")
			if not ap.has_animation(key) and ap.has_animation(want):
				key = want
			if not ap.has_animation(key):
				print("TEST fehlt ", want)
				continue
			var a := (ap.get_animation(key) as Animation).duplicate(true) as Animation
			var i := a.get_track_count() - 1
			while i >= 0:
				var t := a.track_get_type(i)
				var p := String(a.track_get_path(i))
				var bone := p.get_slice(":", 1)
				if t == Animation.TYPE_SCALE_3D or (t == Animation.TYPE_POSITION_3D and bone != "root" and bone != "pelvis") or t not in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D, Animation.TYPE_SCALE_3D]:
					a.remove_track(i)
				i -= 1
			if want.ends_with("_Loop"):
				a.loop_mode = Animation.LOOP_LINEAR
			a.compress()
			lib.add_animation(want.replace("_Loop", ""), a)
		sc.free()
	print("TEST Bibliothek: ", lib.get_animation_list().size(), " Animationen")
	var err := ResourceSaver.save(lib, "res://assets/chars/anims.res", ResourceSaver.FLAG_COMPRESS)
	print("TEST gespeichert ", err)
	get_tree().quit()
