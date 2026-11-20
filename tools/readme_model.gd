extends RefCounted

## The README studio model (tools/readme.cfg [shot] model_script): the pack's own model, plus the string a bow or
## crossbow draws at run time (ZzMedievalHeld redraws it each frame, so the glb has none), at rest: a rigged bow's
## limbs braced as in play, the string between the art table's tips.


static func instantiate(id: StringName) -> Node3D:
	var root := Node3D.new()
	var model := ZzMedievalModels.build(id)
	root.add_child(model)
	var row := ZzMedievalArtTable.row(id)
	if not row.has("string"):
		return root
	var sk := model.find_children("*", "Skeleton3D", true, false)
	if not sk.is_empty():
		var skel := sk[0] as Skeleton3D
		ZzMedievalHeld.flex_skeleton(skel, id, 0.0)
		# A skeleton out of the tree resets its pose on entering it: bend again once it is in the studio.
		skel.ready.connect(func() -> void: ZzMedievalHeld.flex_skeleton(skel, id, 0.0), CONNECT_DEFERRED)
	var n := ZzMedievalArtTable.string_point(id, 0.0)
	for tip in ZzMedievalArtTable.string_tips(id, 0.0):
		var mi := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(0.0045, 0.0045, 1.0)
		mi.mesh = m
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ZzMedievalModels.STRING
		mat.roughness = 0.75
		mi.material_override = mat
		root.add_child(mi)
		ZzMedievalHeld._span(mi, tip, n, false)
	return root
