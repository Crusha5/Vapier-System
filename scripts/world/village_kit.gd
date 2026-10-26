class_name VillageKit
extends RefCounted
## Baut Häuser aus dem Quaternius „Medieval Village MegaKit“ (CC0): 2-m-Wandmodule, Ecken,
## Satteldach mit Giebeln, Fenster, Türen, Läden, Schornstein, Ranken. Materialien düster getönt.

static var _scenes := {}
static var _mats := {}
static var glass: Array[StandardMaterial3D] = []

static func piece(parent: Node3D, name: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> Node3D:
	if not _scenes.has(name):
		_scenes[name] = load("res://assets/village/%s.gltf" % name)
	var ps: PackedScene = _scenes[name]
	if ps == null:
		return null
	var n := ps.instantiate() as Node3D
	n.position = pos
	n.rotation.y = rot_y
	if scale != 1.0:
		n.scale = Vector3.ONE * scale
	parent.add_child(n)
	_tint(n)
	return n

## Materialien einmalig abdunkeln und entsättigen (alle Instanzen teilen sie)
static func _tint(n: Node) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var m := mi.mesh.surface_get_material(i)
			if m == null:
				continue
			var key := m.get_instance_id()
			if not _mats.has(key):
				var sm := m as StandardMaterial3D
				if sm:
					var nm := sm.duplicate() as StandardMaterial3D
					var c := Color(0.78, 0.76, 0.74)
					if sm.resource_name.contains("Glass"):
						# Fenster leuchten warm
						nm.emission_enabled = true
						nm.emission = Color(1.0, 0.62, 0.3)
						nm.emission_energy_multiplier = 1.4
						c = Color(1, 0.8, 0.6)
						glass.append(nm)
					elif sm.resource_name.contains("Plaster"):
						c = Color(0.7, 0.68, 0.66)
					elif sm.resource_name.contains("RoundTiles"):
						c = Color(0.5, 0.4, 0.4)
					nm.albedo_color = sm.albedo_color * c
					nm.roughness = 1.0
					nm.metallic_specular = 0.2
					nm.normal_enabled = false
					nm.roughness_texture = null
					_mats[key] = nm
				else:
					_mats[key] = m
			mi.set_surface_override_material(i, _mats[key])
	for c in n.get_children():
		_tint(c)

## Haus mit W x D Metern (Vielfache von 2), Tür vorne (−Z). Gibt die Tür-Mitte (x) zurück.
## style: "plaster" (Fachwerk/Putz) oder "brick" (Bruchstein)
static func house(root: Node3D, w: int, d: int, style: String, rng: RandomNumberGenerator) -> float:
	var hw := w * 0.5
	var hd := d * 0.5
	var nx := w / 2
	var nz := d / 2
	var pre := "Wall_Plaster_" if style == "plaster" else "Wall_UnevenBrick_"
	var door_i := nx / 2 if nx % 2 == 1 else nx / 2 - (rng.randi() % 2)
	var door_x := -hw + 1.0 + door_i * 2.0
	# Vorderseite (Tür)
	for i in nx:
		var x := -hw + 1.0 + i * 2.0
		var nm := pre + ("Door_Round" if i == door_i else ("Window_Wide_Round" if (i + 1) % 2 == 0 or nx == 1 else "Straight"))
		piece(root, nm, Vector3(x, 0, -hd), PI)
		if i == door_i:
			# offene Tür an der Angel
			var door := piece(root, "Door_1_Round", Vector3(x + 0.53, 0, -hd + 0.02), PI)
			if door:
				door.rotation.y = PI - 1.7
		elif nm.contains("Window"):
			piece(root, "Window_Wide_Round1", Vector3(x, 0, -hd), PI)
			if rng.randf() < 0.6:
				piece(root, "WindowShutters_Wide_Round_Open", Vector3(x, 0, -hd), PI)
	# Rückseite
	for i in nx:
		var x := -hw + 1.0 + i * 2.0
		var win := i % 2 == 1
		piece(root, pre + ("Window_Thin_Round" if win else ("WoodGrid" if style == "plaster" and rng.randf() < 0.5 else "Straight")) if not (style != "plaster" and not win) else pre + "Straight", Vector3(x, 0, hd), 0.0)
		if win:
			piece(root, "Window_Thin_Round1", Vector3(x, 0, hd), 0.0)
	# Seiten
	for k in nz:
		var z := -hd + 1.0 + k * 2.0
		var win := k == nz / 2
		for side in [-1, 1]:
			var nm := pre + ("Window_Thin_Round" if win else "Straight")
			if style == "plaster" and not win and rng.randf() < 0.35:
				nm = "Wall_Plaster_WoodGrid"
			piece(root, nm, Vector3(side * hw, 0, z), side * PI * 0.5)
			if win:
				piece(root, "Window_Thin_Round1", Vector3(side * hw, 0, z), side * PI * 0.5)
	# Ecken
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			piece(root, "Corner_Exterior_Wood", Vector3(sx * hw, 0, sz * hd))
	# Dach: First entlang Z, Giebel vorne/hinten
	var roof := "Roof_RoundTiles_6x6" if d <= 6 else "Roof_RoundTiles_6x8"
	var rs := float(w) / 6.0
	var r := piece(root, roof, Vector3(0, 3.12, 0))
	if r:
		r.scale = Vector3(rs, 1.0 + (rs - 1.0) * 0.5, 1.0 if d == 6 or d == 8 else float(d) / 6.0)
	var gable := "Roof_Front_Brick6" if w >= 6 else "Roof_Front_Brick4"
	for s in [-1, 1]:
		var g := piece(root, gable, Vector3(0, 3.12, s * hd), 0.0 if s > 0 else PI)
		if g and w > 6:
			g.scale = Vector3(rs, 1.0 + (rs - 1.0) * 0.5, 1.0)
	# Boden innen
	for i in nx:
		for k in nz:
			piece(root, "Floor_WoodDark", Vector3(-hw + 1.0 + i * 2.0, 0.03, -hd + 1.0 + k * 2.0))
	if rng.randf() < 0.7:
		var cx := hw * 0.45
		var ry := 3.12 + 4.89 - cx / (4.12 * rs) * 5.67
		piece(root, "Prop_Chimney", Vector3(cx, ry - 1.2, hd * 0.4))
	if rng.randf() < 0.6:
		var vs: Array = ["Prop_Vine1", "Prop_Vine2", "Prop_Vine4"]
		piece(root, vs[rng.randi() % 3], Vector3(-hw + 1.0, 3.0, -hd - 0.12), PI)
	return door_x

## Fensterleuchten: nachts hell, tagsüber kaum
static func set_night(n: float) -> void:
	for g in glass:
		g.emission_energy_multiplier = lerpf(0.15, 1.8, n)
