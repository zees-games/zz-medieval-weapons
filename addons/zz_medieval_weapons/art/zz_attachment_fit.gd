class_name ZzAttachmentFit
extends RefCounted

## Measures a weapon model where an attachment goes on it, so each attachment mesh is built to that weapon's own
## haft, grip, pommel, stock or boss rather than to a table guess. The model's triangles are cut by planes across
## its long axis (+Y in the aligned grip space, the hand at the origin); each cut gives a ring: its centre and half
## extents in x and z. Results are cached per weapon id: the glbs never change at runtime.

const STEP := 0.005
## A ring this much wider than the hand's ring is no longer grip (a guard, a pommel, a head).
const SWELL := 1.4

static var _cache: Dictionary = {}


## The rings of [param root]'s meshes in [param frame] (root space to a space with the long axis on +Y), one per
## [constant STEP] from the lowest point to [param top]: Array of {y, c: Vector2 (x, z), h: Vector2 (x, z)}.
static func rings(root: Node3D, frame: Transform3D = Transform3D.IDENTITY, top: float = INF) -> Array:
	var tris := PackedVector3Array()
	var meshes: Array[Node] = []
	if root is MeshInstance3D:
		meshes.append(root)
	meshes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for m: Node in meshes:
		var mi := m as MeshInstance3D
		if mi.mesh == null or mi.has_meta(&"gs_attachment_model") or _is_attachment(mi, root):
			continue
		var xf := frame * _to(root, mi)
		for v: Vector3 in mi.mesh.get_faces():
			tris.append(xf * v)
	if tris.is_empty():
		return []
	var lo := INF
	var hi := -INF
	for p in tris:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	hi = minf(hi, top)
	var n := int(floor((hi - lo) / STEP))
	if n <= 0:
		return []
	var mn: Array[Vector2] = []
	var mx: Array[Vector2] = []
	mn.resize(n)
	mx.resize(n)
	mn.fill(Vector2(INF, INF))
	mx.fill(Vector2(-INF, -INF))
	# Each triangle only visits the planes it spans.
	for t in range(0, tris.size(), 3):
		var a := tris[t]
		var b := tris[t + 1]
		var c := tris[t + 2]
		var k0 := maxi(int(ceil((minf(a.y, minf(b.y, c.y)) - lo) / STEP - 0.5)), 0)
		var k1 := mini(int(floor((maxf(a.y, maxf(b.y, c.y)) - lo) / STEP - 0.5)), n - 1)
		for k in range(k0, k1 + 1):
			var y := lo + (float(k) + 0.5) * STEP
			for e in 3:
				var p := tris[t + e]
				var q := tris[t + (e + 1) % 3]
				if (p.y - y) * (q.y - y) <= 0.0 and p.y != q.y:
					var r := p.lerp(q, (y - p.y) / (q.y - p.y))
					mn[k] = Vector2(minf(mn[k].x, r.x), minf(mn[k].y, r.z))
					mx[k] = Vector2(maxf(mx[k].x, r.x), maxf(mx[k].y, r.z))
	var out: Array = []
	for k in n:
		if mn[k].x == INF:
			continue
		out.append({"y": lo + (float(k) + 0.5) * STEP, "c": (mn[k] + mx[k]) * 0.5, "h": (mx[k] - mn[k]) * 0.5})
	return out


## What an attachment on [param id] fits: measured once from [param model] (the weapon model under the grip node,
## already aligned). Keys: wrap {lo, hi, rings}, butt {y, rings, pommel}, top (crossbow: Array of Vector2(y, z) along
## the stock's top), boss {z, r} (shield). Missing keys mean the weapon has no such place.
static func of(id: StringName, model: Node3D) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	var grip := model.get_parent() as Node3D
	var fit := {}
	if grip == null:
		return fit
	if id == &"round_shield":
		fit["boss"] = _boss(model, grip)
	else:
		var rs := rings(model, model.transform, 0.5)
		if id == &"crossbow":
			fit["top"] = _top(model, grip)
		elif not rs.is_empty():
			fit["wrap"] = _wrap(rs)
			fit["butt"] = _butt(rs)
	_cache[id] = fit
	return fit


## The bolt's head: {tip, len, r} along +Y in [param frame] (the missile turned so it flies along +Y).
static func head(missile: Node3D, frame: Transform3D) -> Dictionary:
	var rs := rings(missile, frame)
	if rs.is_empty():
		return {"tip": 0.2, "len": 0.03, "r": 0.008, "shaft": 0.005}
	var tip := float(rs[-1]["y"]) + STEP * 0.5
	var shaft := _radius(rs[rs.size() / 2])
	var r := shaft
	var base := tip
	for i in range(rs.size() - 1, -1, -1):
		var rr := _radius(rs[i])
		if float(rs[i]["y"]) < tip - 0.08:
			break
		if rr > shaft * 1.25:
			base = float(rs[i]["y"])
			r = maxf(r, rr)
	return {"tip": tip, "len": maxf(tip - base, 0.02), "r": r, "shaft": shaft}


static func _radius(ring: Dictionary) -> float:
	var h: Vector2 = ring["h"]
	return maxf(h.x, h.y)


## The hand's span of grip: the rings round the origin no wider than the ring the hand holds, from a little
## below the hand to where the weapon swells (a guard or a head), at most 22 cm.
static func _wrap(rs: Array) -> Dictionary:
	var at := _nearest(rs, 0.0)
	var hand := _radius(rs[at])
	var lo := at
	while lo > 0 and float(rs[lo - 1]["y"]) > -0.09 and _radius(rs[lo - 1]) < hand * SWELL:
		lo -= 1
	var hi := at
	while hi < rs.size() - 1 and float(rs[hi + 1]["y"]) - float(rs[lo]["y"]) < 0.22 and _radius(rs[hi + 1]) < hand * SWELL:
		hi += 1
	# Off the ends by a few millimetres: the end rings are where the grip starts to flare.
	lo = mini(lo + 1, at)
	hi = maxi(hi - 1, at)
	return {"lo": float(rs[lo]["y"]), "hi": float(rs[hi]["y"]), "rings": rs.slice(lo, hi + 1)}


## The bottom end: the lowest 7 cm of rings, and whether it is a pommel (wider than the grip above it) or a bare butt.
static func _butt(rs: Array) -> Dictionary:
	var lo := float(rs[0]["y"]) - STEP * 0.5
	var out: Array = []
	for r: Dictionary in rs:
		if float(r["y"]) > lo + 0.07:
			break
		out.append(r)
	var widest := 0.0
	for r: Dictionary in out.slice(0, maxi(out.size() * 2 / 3, 1)):
		widest = maxf(widest, _radius(r))
	var above := _radius(out[-1]) if not out.is_empty() else widest
	return {"y": lo, "rings": out, "pommel": widest > above * 1.35}


## The crossbow stock's top line near the centre plane: Vector2(y, top z) every 2 cm from 6 cm behind the hand to the prod.
static func _top(model: Node3D, grip: Node3D) -> Array:
	var out: Array = []
	var pts := PackedVector3Array()
	for m: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := _to(grip, mi)
		for v: Vector3 in mi.mesh.get_faces():
			pts.append(xf * v)
	var y := -0.06
	while y <= 0.36:
		var top := -INF
		for t in range(0, pts.size(), 3):
			for e in 3:
				var p := pts[t + e]
				var q := pts[t + (e + 1) % 3]
				if (p.y - y) * (q.y - y) <= 0.0 and p.y != q.y:
					var r := p.lerp(q, (y - p.y) / (q.y - p.y))
					if absf(r.x) < 0.012:
						top = maxf(top, r.z)
		if top > -INF:
			out.append(Vector2(y, top))
		y += 0.02
	return out


## The shield's boss: its apex (front is +Z) and the radius where it meets the board.
static func _boss(model: Node3D, grip: Node3D) -> Dictionary:
	var apex := -INF
	var board := INF
	var pts := PackedVector3Array()
	for m: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh != null:
			var xf := _to(grip, mi)
			for v: Vector3 in mi.mesh.get_faces():
				pts.append(xf * v)
	for p in pts:
		var d := Vector2(p.x, p.y).length()
		if d < 0.01:
			apex = maxf(apex, p.z)
	# The board's front face: the highest z on a ring well outside the boss.
	var face := -INF
	for p in pts:
		var d := Vector2(p.x, p.y).length()
		if d > 0.18 and d < 0.22:
			face = maxf(face, p.z)
	# The boss radius: the farthest point still clearly above the board.
	var r := 0.0
	for p in pts:
		var d := Vector2(p.x, p.y).length()
		if d < 0.2 and p.z > face + 0.006:
			r = maxf(r, d)
	board = face
	return {"z": apex, "face": board, "r": r}


static func _nearest(rs: Array, y: float) -> int:
	var best := 0
	for i in rs.size():
		if absf(float(rs[i]["y"]) - y) < absf(float(rs[best]["y"]) - y):
			best = i
	return best


static func _is_attachment(n: Node, root: Node) -> bool:
	while n != null and n != root:
		if n.has_meta(&"gs_attachment_model") or String(n.name).begins_with("socket_"):
			return true
		n = n.get_parent()
	return false


## [param n]'s transform in [param root]'s space.
static func _to(root: Node, n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	while n != null and n != root:
		if n is Node3D:
			xf = (n as Node3D).transform * xf
		n = n.get_parent()
	return xf
