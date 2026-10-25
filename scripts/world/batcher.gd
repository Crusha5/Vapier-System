class_name Batcher
extends RefCounted
## Fasst statische Level-Meshes je Material und 16-m-Feld zu wenigen großen Meshes zusammen.
## Spart auf dem Handy hunderte Draw-Calls. Die Konturrichtung „vom Objektmittelpunkt weg“
## wird vorher in die Vertexfarbe geschrieben, damit die Comic-Kontur ohne Lücken bleibt.

static func merge(root: Node3D, chunk := 16.0) -> int:
	var groups := {}
	var removed := 0
	for c in root.get_children():
		if not (c is MeshInstance3D):
			continue
		var mi := c as MeshInstance3D
		if mi.has_meta("keep") or not (mi.mesh is PrimitiveMesh) or mi.material_override == null:
			continue
		var p := mi.position
		var key := "%d|%d|%d|%d" % [mi.material_override.get_instance_id(), int(floor(p.x / chunk)), int(floor(p.z / chunk)), int(mi.cast_shadow)]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mi)
	for key in groups:
		var list: Array = groups[key]
		if list.size() < 2:
			continue
		var verts := PackedVector3Array()
		var norms := PackedVector3Array()
		var uvs := PackedVector2Array()
		var cols := PackedColorArray()
		var idx := PackedInt32Array()
		for mi in list:
			var arr: Array = (mi.mesh as PrimitiveMesh).get_mesh_arrays()
			var xf: Transform3D = mi.transform
			var nb := xf.basis.inverse().transposed()
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
			var ii: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var base := verts.size()
			for i in v.size():
				verts.append(xf * v[i])
				norms.append((nb * n[i]).normalized())
				var rd := (xf.basis * (v[i] + Vector3(0.0001, 0.0001, 0.0001))).normalized()
				cols.append(Color(rd.x * 0.5 + 0.5, rd.y * 0.5 + 0.5, rd.z * 0.5 + 0.5, 0.0))  # Alpha 0 = gebackene Richtung
				uvs.append(uv[i] if i < uv.size() else Vector2.ZERO)
			if ii.size() > 0:
				for i in ii:
					idx.append(base + i)
			else:
				for i in v.size():
					idx.append(base + i)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = norms
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_COLOR] = cols
		arrays[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var first: MeshInstance3D = list[0]
		var out := MeshInstance3D.new()
		out.mesh = am
		out.material_override = first.material_override
		out.cast_shadow = first.cast_shadow
		root.add_child(out)
		for mi in list:
			root.remove_child(mi)
			mi.queue_free()
			removed += 1
	return removed
