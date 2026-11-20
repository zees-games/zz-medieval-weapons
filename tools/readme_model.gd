extends RefCounted

## The README studio model (tools/readme.cfg [shot] model_script): the pack's own model, plus the string a bow or
## crossbow draws at run time (ZzMedievalHeld redraws it each frame, so the glb has none), at rest. The bow's
## string is tied to the real limb tips found in the mesh (the art table's tips sit a little off them).

const TIPS_FROM_MESH := {&"bow": true}

const INSET := {&"crossbow": 0.025}


static func instantiate(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.add_child(ZzMedievalModels.build(id))
	var row := ZzMedievalArtTable.row(id)
	if not row.has("string"):
		return root
	var pull := 0.0
	var s: Dictionary = row["string"]
	var n := ZzMedievalArtTable.string_point(id, pull)
	var tips: Array = s["tips"]
	tips = _limb_tips(root, (tips[1] - tips[0]).normalized())
	n = (tips[0] + tips[1]) * 0.5
	# the crossbow's outermost vertices are the back of its tip hooks: end a hair inside them, so the string ends in the nock rather than past it
	var inset: float = INSET.get(id, 0.0)
	tips = [tips[0].lerp(n, inset), tips[1].lerp(n, inset)]
	for tip in tips:
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.006, 0.006, 1.0)
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ZzMedievalModels.STRING
		mi.material_override = mat
		root.add_child(mi)
		ZzMedievalHeld._span(mi, tip, n, false)
	if pull > 0.0 and row.has("projectile"):
		var missile := ZzMedievalModels.projectile(StringName(row["projectile"]))
		var axis: Vector3 = row["nock_axis"]
		var plen := ZzMedievalModels.projectile_length(StringName(row["projectile"]))
		var up := Vector3(0, 0, 1) if absf(axis.y) > 0.9 else Vector3.UP
		var centre := n + axis * plen * 0.5 + (row.get("nock_lift", Vector3.ZERO) as Vector3)
		missile.transform = Transform3D(Basis.looking_at(axis, up), centre)
		root.add_child(missile)
	return root


## The two vertices furthest apart along [param axis] (tip to tip), in root space.
static func _limb_tips(root: Node3D, axis: Vector3) -> Array:
	var lo := Vector3.ZERO
	var hi := Vector3.ZERO
	var lo_d := INF
	var hi_d := -INF
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var node: Node = e[0]
		var xf: Transform3D = e[1]
		if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
			var mesh: Mesh = (node as MeshInstance3D).mesh
			for si in mesh.get_surface_count():
				var verts: PackedVector3Array = mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
				for v in verts:
					var w := xf * v
					var d := w.dot(axis)
					if d < lo_d:
						lo_d = d
						lo = w
					if d > hi_d:
						hi_d = d
						hi = w
		for c in node.get_children():
			if c is Node3D:
				stack.append([c, xf * (c as Node3D).transform])
	return [lo, hi]
