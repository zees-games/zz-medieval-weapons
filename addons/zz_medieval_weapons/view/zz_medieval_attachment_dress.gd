class_name ZzMedievalAttachmentDress
extends RefCounted

## Puts a fitting's attachment models on a medieval weapon's grip node: adds the `socket_<mount>` nodes at
## [method ZzMedievalArtTable.socket_points], then hands over to [GSWeaponAttachmentModels].


## Dresses [param grip] (the aligned grip-at-origin node holding [param id]'s model) with [param fitting]; returns how many models it placed.
static func dress(grip: Node3D, id: StringName, catalogue: GSWeaponAttachments, fitting: GSWeaponFitting) -> int:
	if grip == null:
		return 0
	var points := ZzMedievalArtTable.socket_points(id)
	for mount: StringName in ZzMedievalPack.MOUNTS.get(id, []):
		var key := String(mount)
		if not points.has(key) or grip.has_node(NodePath(GSWeaponAttachmentModels.SOCKET_PREFIX + key)):
			continue
		var socket := Node3D.new()
		socket.name = GSWeaponAttachmentModels.SOCKET_PREFIX + key
		socket.position = points[key] as Vector3
		if key == "magazine":
			socket.position = _butt(grip, socket.position)
		grip.add_child(socket)
	return GSWeaponAttachmentModels.dress(grip, catalogue, fitting)


## The weapon's butt end along its own axis (the lowest point of its meshes in grip space), so the counterweight sits on
## each model's real pommel rather than at a table guess; [param fallback] when the grip has no meshes yet.
static func _butt(grip: Node3D, fallback: Vector3) -> Vector3:
	var lo := INF
	var cx := 0.0
	var cz := 0.0
	for m: Node in grip.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var n: Node = mi
		while n != null and n != grip:
			if n is Node3D:
				xf = (n as Node3D).transform * xf
			n = n.get_parent()
		var b: AABB = xf * mi.get_aabb()
		if b.position.y < lo:
			lo = b.position.y
			cx = b.get_center().x
			cz = b.get_center().z
	if lo == INF:
		return fallback
	return Vector3(cx, lo + 0.012, cz)
