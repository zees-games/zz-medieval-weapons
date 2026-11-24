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
		grip.add_child(socket)
	return GSWeaponAttachmentModels.dress(grip, catalogue, fitting)
