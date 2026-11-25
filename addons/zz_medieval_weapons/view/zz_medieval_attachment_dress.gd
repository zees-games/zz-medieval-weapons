class_name ZzMedievalAttachmentDress
extends RefCounted

## Puts a fitting's attachment models on a medieval weapon: adds a `socket_<mount>` node for each of the weapon's
## mounts ([constant ZzMedievalPack.MOUNTS]), hands over to [GSWeaponAttachmentModels], then fits each placed piece
## ([ZzAttachmentPiece]) to what [ZzAttachmentFit] measures on this weapon's model. The sockets sit at the grip's origin
## (pieces are built in the grip frame, so they ride every swing with the weapon), except the crossbow's muzzle, which
## goes on the bolt itself (its frame turned so +Y runs to the tip) and so is shown, nocked and hidden with it.

## The bolt's frame for a muzzle piece: the missile's -Z (its flight) turned onto +Y.
const MISSILE_FRAME := Transform3D(Basis(Vector3(1, 0, 0), PI / 2), Vector3.ZERO)


## Dresses [param grip] (the aligned grip-at-origin node holding [param model], weapon [param id]) with
## [param fitting]; [param missile] is the nocked bolt, if any. Returns how many models it placed.
static func dress(grip: Node3D, model: Node3D, id: StringName, catalogue: GSWeaponAttachments, fitting: GSWeaponFitting, missile: Node3D = null) -> int:
	if grip == null:
		return 0
	for old in grip.find_children(GSWeaponAttachmentModels.SOCKET_PREFIX + "*", "Node3D", true, false):
		old.get_parent().remove_child(old)
		old.queue_free()
	for mount: StringName in ZzMedievalPack.MOUNTS.get(id, []):
		var socket := Node3D.new()
		socket.name = GSWeaponAttachmentModels.SOCKET_PREFIX + String(mount)
		if mount == &"muzzle" and missile != null:
			socket.transform = MISSILE_FRAME.affine_inverse()
			missile.add_child(socket)
		else:
			grip.add_child(socket)
	var placed := GSWeaponAttachmentModels.dress(grip, catalogue, fitting)
	if placed == 0 or model == null:
		return placed
	var info := ZzAttachmentFit.of(id, model).duplicate()
	if missile != null:
		info["head"] = ZzAttachmentFit.head(missile, MISSILE_FRAME)
	for n in grip.find_children("*", "", true, false):
		if n.has_meta(&"gs_attachment_model") and n.has_method(&"fit"):
			n.call(&"fit", info)
	return placed


## Carries the nocked bolt's muzzle pieces onto [param flight_model], the bolt drawn in flight
## ([ZzProjectileFlight]), so what was fitted to the bolt on the stock is still on it when it flies. Both are the
## same projectile model, so each socket keeps its place on it. Returns how many pieces it carried.
static func dress_flight(missile: Node3D, flight_model: Node3D) -> int:
	if missile == null or flight_model == null:
		return 0
	var info := {"head": ZzAttachmentFit.head(flight_model, MISSILE_FRAME)}
	var carried := 0
	for socket in missile.get_children():
		if not String(socket.name).begins_with(GSWeaponAttachmentModels.SOCKET_PREFIX):
			continue
		var copy := socket.duplicate() as Node3D
		for n in copy.find_children("*", "", true, false):
			if n.has_meta(&"gs_attachment_model") and n.has_method(&"fit"):
				n.call(&"fit", info)
				carried += 1
		flight_model.add_child(copy)
	return carried
