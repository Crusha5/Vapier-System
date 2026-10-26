class_name Batcher
extends RefCounted
## Fasst statische Meshes eines Teilbaums je Material, Schattenmodus und 32-m-Feld zu wenigen
## großen Meshes zusammen. Spart auf dem Handy tausende Draw-Calls (Häuser aus dem Baukasten,
## Palisaden, Requisiten). Knoten mit Meta „keep“ (und alles darunter) bleiben unangetastet.

static func merge(root: Node3D, cell := 32.0, vis_range := 300.0) -> int:
	var groups := {}
	var mats := {}
	var found: Array = []
	_collect(root, found)
	var inv := root.global_transform.affine_inverse()
	for mi: MeshInstance3D in found:
		var mesh := mi.mesh
		var xf: Transform3D = inv * mi.global_transform
		var p := xf.origin
		for s in mesh.get_surface_count():
			if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
				continue
			var mat: Material = mi.material_override
			if mat == null:
				mat = mi.get_surface_override_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			if mat == null:
				continue
			var fmt := -1
			if mesh is ArrayMesh:
				fmt = (mesh as ArrayMesh).surface_get_format(s) & (Mesh.ARRAY_FORMAT_TEX_UV | Mesh.ARRAY_FORMAT_COLOR | Mesh.ARRAY_FORMAT_TANGENT)
			var key := "%d|%d|%d|%d|%d" % [mat.get_instance_id(), int(floor(p.x / cell)), int(floor(p.z / cell)), int(mi.cast_shadow), fmt]
			if not groups.has(key):
				groups[key] = []
				mats[key] = [mat, mi.cast_shadow]
			groups[key].append([mesh, s, xf])
	var removed := found.size()
	for key in groups:
		var center := Vector3.ZERO
		for e in groups[key]:
			center += (e[2] as Transform3D).origin
		center /= float((groups[key] as Array).size())
		var st := SurfaceTool.new()
		for e in groups[key]:
			var xf: Transform3D = e[2]
			xf.origin -= center
			st.append_from(e[0], e[1], xf)
		var am := st.commit()
		var out := MeshInstance3D.new()
		out.position = center
		out.mesh = am
		out.material_override = mats[key][0]
		out.cast_shadow = mats[key][1]
		out.visibility_range_end = vis_range
		root.add_child(out)
	for mi: MeshInstance3D in found:
		mi.get_parent().remove_child(mi)
		mi.queue_free()
	return removed

static func _collect(n: Node, out: Array) -> void:
	if n.has_meta("keep"):
		return
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null and mi.visible and not (mi.mesh is ImmediateMesh):
			out.append(mi)
	for c in n.get_children():
		_collect(c, out)
