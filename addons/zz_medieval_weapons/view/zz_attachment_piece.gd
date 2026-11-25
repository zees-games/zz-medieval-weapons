class_name ZzAttachmentPiece
extends Node3D

## One medieval attachment, built to the weapon it goes on. [method fit] takes what [ZzAttachmentFit] measured on
## that weapon (the grip's rings, the butt, the crossbow's stock line, the shield's boss, the bolt's head) and builds
## the piece in its socket's space: the grip frame (+Y along the weapon, the hand at the origin) or, for the bolt
## head, the bolt's frame (+Y along the bolt). Shown on its own (an icon, a catalogue preview) it builds to a
## typical grip. Meshes and materials come from [ZzAttachmentArt].

@export_enum("wrap", "counterweight", "boss", "sight", "heads") var kind := "wrap"

var _fitted := false


func _ready() -> void:
	if not _fitted:
		_build({})


## Rebuilds the piece for [param info] (see [method ZzAttachmentFit.of]; the bolt head comes as "head").
func fit(info: Dictionary) -> void:
	_fitted = true
	_build(info)


func _build(info: Dictionary) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	match kind:
		"wrap":
			_wrap(info.get("wrap", {}))
		"counterweight":
			_counterweight(info.get("butt", {}))
		"boss":
			_boss(info.get("boss", {}))
		"sight":
			_sight(info.get("top", []))
		"heads":
			_heads(info.get("head", {}))


func _mesh(mesh: Mesh, mat: Material, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xf
	add_child(mi)
	return mi


## Leather wound over the hand's span of the grip, under 2 mm proud, its ends skived down flush and bound with cord.
func _wrap(w: Dictionary) -> void:
	var rs: Array = w.get("rings", [])
	if rs.size() < 4:
		rs = []
		for i in 25:
			rs.append(ZzAttachmentArt.ring(-0.05 + i * 0.005, 0.015))
	rs = _smooth(rs, 2)
	var leather: Array = []
	for i in rs.size():
		var t := minf(i, rs.size() - 1 - i)
		leather.append(ZzAttachmentArt.grown(rs[i], 0.0006 + 0.0011 * clampf(t / 2.0, 0.0, 1.0)))
	# A 26 mm strap laid at a steep lead, each turn stepping over the last: a spiral, not a stack of hoops.
	_mesh(ZzAttachmentArt.wound(leather, 48, 0.026, 0.0016), ZzAttachmentArt.leather())
	for end: int in [0, rs.size() - 1]:
		var step := 1 if end == 0 else -1
		var r0: Dictionary = rs[end]
		var r1: Dictionary = rs[clampi(end + step, 0, rs.size() - 1)]
		var y0 := float(r0["y"])
		var dy := 0.0055 * step
		var band := [
			ZzAttachmentArt.grown(r0, 0.0012, -0.0006 * step),
			ZzAttachmentArt.grown(r0, 0.0024, 0.0008 * step),
			ZzAttachmentArt.grown(r1, 0.0026, dy * 0.5 - (float(r1["y"]) - y0)),
			ZzAttachmentArt.grown(r1, 0.0024, dy - 0.0008 * step - (float(r1["y"]) - y0)),
			ZzAttachmentArt.grown(r1, 0.0012, dy + 0.0006 * step - (float(r1["y"]) - y0)),
		]
		if step < 0:
			band.reverse()
		_mesh(ZzAttachmentArt.sweep(band, 32, 6.0, 80.0), ZzAttachmentArt.rope())


## Pommel weapons: a forged iron cup over the pommel's lower half (clear of the hand that closes above it), its lip
## at the pommel's widest, with a square peen block on the end. Hafted weapons: a flared iron shoe over the butt,
## riveted through, closed in a dome with a peened button.
func _counterweight(b: Dictionary) -> void:
	var rs: Array = b.get("rings", [])
	if rs.size() < 4:
		rs = []
		for i in 14:
			rs.append(ZzAttachmentArt.ring(-0.2 + i * 0.005, 0.017))
		b = {"y": -0.2025, "rings": rs, "pommel": false}
	rs = _smooth(rs, 1)
	var y0 := float(b.get("y", float(rs[0]["y"])))
	var iron := ZzAttachmentArt.iron()
	if bool(b.get("pommel", false)):
		var iw := 0
		for i in rs.size():
			if _radius(rs[i]) > _radius(rs[iw]):
				iw = i
		# Every ring follows the pommel's own section (a wheel pommel is far flatter than it is wide). The cup stops at
		# the widest ring with a rolled lip, so the pommel's upper half shows above it as its seat.
		var c: Vector2 = rs[0]["c"]
		var bot := ZzAttachmentArt.grown(rs[0], 0.003)
		var cap: Array = [
			ZzAttachmentArt.ring(y0 - 0.0055, 0.0, c), _scaled(bot, 0.5, y0 - 0.0052),
			_scaled(bot, 0.85, y0 - 0.004), _scaled(bot, 1.0, y0 - 0.0015),
		]
		for i in iw + 1:
			cap.append(ZzAttachmentArt.grown(rs[i], 0.003))
		var w: Dictionary = rs[iw]
		cap.append(ZzAttachmentArt.grown(w, 0.0052, 0.001))
		cap.append(ZzAttachmentArt.grown(w, 0.0052, 0.0028))
		cap.append(ZzAttachmentArt.grown(w, 0.0025, 0.0036))
		cap.append(ZzAttachmentArt.grown(w, -0.002, 0.0036))
		_mesh(ZzAttachmentArt.sweep(cap, 28, 1.0, 20.0), iron)
		# The tang's end peened over a square block, its corners chamfered.
		var block := [
			ZzAttachmentArt.ring(y0 - 0.0135, 0.0, c), ZzAttachmentArt.ring(y0 - 0.013, 0.0042, c),
			ZzAttachmentArt.ring(y0 - 0.0115, 0.0062, c), ZzAttachmentArt.ring(y0 - 0.006, 0.0062, c),
			ZzAttachmentArt.ring(y0 - 0.004, 0.0048, c),
		]
		_mesh(ZzAttachmentArt.sweep(block, 4, 1.0, 20.0), iron, Transform3D(Basis(Vector3.UP, PI / 4), Vector3.ZERO))
		return
	# Hafted: the ferrule round the widest of the bottom 6 cm, so it slides on and never cuts into the haft.
	var ferrule: Array = []
	var r_max := 0.0
	var c0: Vector2 = rs[0]["c"]
	for r: Dictionary in rs:
		if float(r["y"]) > y0 + 0.06:
			break
		r_max = maxf(r_max, _radius(r))
	var r := r_max + 0.0035
	var top_y := y0 + 0.045
	# The shoe flares from its collar to a bulb half again as wide as the haft, closed in a dome (no flat end face
	# to read as a pipe's open mouth from below), with the haft's peened button at its pole.
	ferrule = [
		ZzAttachmentArt.ring(y0 - 0.0225, 0.0, c0),
		ZzAttachmentArt.ring(y0 - 0.022, r * 0.35, c0),
		ZzAttachmentArt.ring(y0 - 0.0205, r * 0.5, c0),
		ZzAttachmentArt.ring(y0 - 0.019, r * 0.62, c0),
		ZzAttachmentArt.ring(y0 - 0.0175, r * 0.95, c0),
		ZzAttachmentArt.ring(y0 - 0.0135, r * 1.28, c0),
		ZzAttachmentArt.ring(y0 - 0.0075, r * 1.4, c0),
		ZzAttachmentArt.ring(y0 - 0.001, r * 1.3, c0),
		ZzAttachmentArt.ring(y0 + 0.008, r * 1.08, c0),
		ZzAttachmentArt.ring(y0 + 0.018, r * 1.0, c0),
		ZzAttachmentArt.ring(top_y - 0.008, r, c0),
		ZzAttachmentArt.ring(top_y - 0.007, r + 0.0018, c0),
		ZzAttachmentArt.ring(top_y - 0.002, r + 0.0018, c0),
		ZzAttachmentArt.ring(top_y - 0.001, r, c0),
		ZzAttachmentArt.ring(top_y, r - 0.002, c0),
	]
	_mesh(ZzAttachmentArt.sweep(ferrule, 40, 1.0, 20.0), iron)
	for side: float in [1.0, -1.0]:
		var rivet := SphereMesh.new()
		rivet.radius = 0.0042
		rivet.height = 0.0042
		rivet.radial_segments = 12
		rivet.rings = 6
		var at := Vector3(c0.x + side * r, top_y - 0.016, c0.y)
		_mesh(rivet, iron, Transform3D(Basis(Vector3(0, 0, 1), side * -PI / 2), at))


## An iron spike boss over the shield's own boss: a flange riveted to the board, a dome, a forged spike.
func _boss(b: Dictionary) -> void:
	var face := float(b.get("face", 0.0))
	var apex := float(b.get("z", face + 0.04))
	var base_r := float(b.get("r", 0.07)) + 0.008
	var top := apex + 0.006
	var pts: Array = [Vector2(base_r + 0.02, -0.001), Vector2(base_r + 0.021, 0.002), Vector2(base_r + 0.019, 0.005), Vector2(base_r + 0.004, 0.006), Vector2(base_r, 0.008)]
	for i in range(1, 9):
		var t := float(i) / 8.0 * PI / 2.0
		var rr := maxf(base_r * cos(t), 0.036)
		pts.append(Vector2(rr, 0.008 + (top - face - 0.008) * sin(t)))
	# A stout forged spike: a collar where it is welded to the dome, then a 9 cm cone, half the dome wide at the root.
	var s0 := top - face
	pts.append(Vector2(0.036, s0 + 0.004))
	pts.append(Vector2(0.03, s0 + 0.014))
	pts.append(Vector2(0.023, s0 + 0.032))
	pts.append(Vector2(0.016, s0 + 0.052))
	pts.append(Vector2(0.009, s0 + 0.07))
	pts.append(Vector2(0.004, s0 + 0.085))
	pts.append(Vector2(0.0, s0 + 0.092))
	var lathe := _lathe_rings(pts, Vector2.ZERO, face, 1.0)
	var to_front := Basis(Vector3(1, 0, 0), PI / 2)
	_mesh(ZzAttachmentArt.sweep(lathe, 40, 1.0, 20.0), ZzAttachmentArt.iron(), Transform3D(to_front, Vector3.ZERO))
	for i in 6:
		var a := TAU * float(i) / 6.0 + PI / 6.0
		var rivet := SphereMesh.new()
		rivet.radius = 0.0095
		rivet.height = 0.0095
		rivet.radial_segments = 12
		rivet.rings = 6
		var at := Vector3(cos(a) * (base_r + 0.012), sin(a) * (base_r + 0.012), face + 0.005)
		_mesh(rivet, ZzAttachmentArt.iron(), Transform3D(to_front, at))


## A peep sight on the stock's top just behind the nut: a forged foot hugging the stock, a leaf, and a ring to look
## through along the bolt's line (+Y).
func _sight(top: Array) -> void:
	# Back on the stock towards the eye (the nut is at y 0.12): behind the trigger hand round the origin, clear of the
	# fore hand at y 0.16 and of the string, which never comes back past the nut.
	var y := -0.1
	var z := 0.017
	var slope := 0.0
	if top.size() >= 2:
		var best := 0
		for i in top.size():
			if absf((top[i] as Vector2).x - y) < absf((top[best] as Vector2).x - y):
				best = i
		var a: Vector2 = top[maxi(best - 1, 0)]
		var b: Vector2 = top[mini(best + 1, top.size() - 1)]
		slope = atan2(b.y - a.y, b.x - a.x) if b.x != a.x else 0.0
		z = (top[best] as Vector2).y
	var at := Transform3D(Basis(Vector3(1, 0, 0), slope), Vector3(0, y, z))
	var up := Basis(Vector3(1, 0, 0), PI / 2)   # lathe +Y to the stock's up (+Z)
	var iron := ZzAttachmentArt.iron()
	var foot := [
		{"y": -0.0015, "c": Vector2.ZERO, "h": Vector2(0.0125, 0.019)},
		{"y": 0.002, "c": Vector2.ZERO, "h": Vector2(0.0125, 0.019)},
		{"y": 0.004, "c": Vector2.ZERO, "h": Vector2(0.011, 0.017)},
		{"y": 0.0055, "c": Vector2.ZERO, "h": Vector2(0.008, 0.012)},
		{"y": 0.006, "c": Vector2.ZERO, "h": Vector2.ZERO},
	]
	_mesh(ZzAttachmentArt.sweep(foot, 24, 1.0, 20.0), iron, at * Transform3D(up, Vector3.ZERO))
	var leaf := [
		{"y": 0.005, "c": Vector2.ZERO, "h": Vector2(0.0042, 0.0022)},
		{"y": 0.022, "c": Vector2.ZERO, "h": Vector2(0.0028, 0.0016)},
		{"y": 0.0275, "c": Vector2.ZERO, "h": Vector2(0.0028, 0.0016)},
	]
	_mesh(ZzAttachmentArt.sweep(leaf, 16, 1.0, 20.0), iron, at * Transform3D(up, Vector3.ZERO))
	# A forged collar where the leaf meets the ring, so the ring reads as welded on, not floating on a stalk.
	var collar := [
		{"y": 0.0245, "c": Vector2.ZERO, "h": Vector2(0.0034, 0.0022)},
		{"y": 0.026, "c": Vector2.ZERO, "h": Vector2(0.0048, 0.003)},
		{"y": 0.0275, "c": Vector2.ZERO, "h": Vector2(0.0048, 0.003)},
	]
	_mesh(ZzAttachmentArt.sweep(collar, 16, 1.0, 20.0), iron, at * Transform3D(up, Vector3.ZERO))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.0062
	ring.outer_radius = 0.0105
	ring.rings = 32
	ring.ring_segments = 12
	_mesh(ring, iron, at * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0365)))


## Barbed broadheads over the bolt's own head: a socket sleeve on the shaft and two crossed forged blades, each with a
## barb swept back. Built in the bolt's frame (+Y towards the tip).
func _heads(h: Dictionary) -> void:
	var tip := float(h.get("tip", 0.2))
	var hlen := float(h.get("len", 0.03))
	var hr := float(h.get("r", 0.008))
	var shaft := float(h.get("shaft", 0.005))
	var yb := tip - hlen - 0.004
	var iron := ZzAttachmentArt.iron()
	var sleeve := [
		ZzAttachmentArt.ring(yb - 0.026, shaft + 0.0006),
		ZzAttachmentArt.ring(yb - 0.025, shaft + 0.0016),
		ZzAttachmentArt.ring(yb - 0.006, shaft + 0.0016),
		ZzAttachmentArt.ring(yb + 0.002, maxf(hr * 0.55, shaft + 0.002)),
		ZzAttachmentArt.ring(tip - hlen * 0.3, maxf(hr * 0.35, shaft * 0.6)),
		ZzAttachmentArt.ring(tip + 0.004, 0.0),
	]
	_mesh(ZzAttachmentArt.sweep(sleeve, 16, 1.0, 20.0), iron)
	var w := hr + 0.004
	var s := shaft + 0.002
	# Each barb swept well back, a deep notch between it and the point's shoulder, so the barbed outline reads at a
	# distance; the cross is turned 45 degrees off the stirrup's plane, which the nocked head sits in.
	var half := PackedVector2Array([Vector2(0, yb), Vector2(s, yb), Vector2(w + 0.006, yb - 0.017), Vector2(s + 0.0015, yb + 0.002), Vector2(w + 0.002, yb + 0.011), Vector2(0, tip + 0.002)])
	var blade := ZzAttachmentArt.blade(half, 0.007)
	for turn: float in [PI / 4, 3 * PI / 4]:
		_mesh(blade, iron, Transform3D(Basis(Vector3(0, 1, 0), turn), Vector3.ZERO))


## A lathe from a profile of Vector2(radius, height) (bottom to top), round [param c], starting at [param y].
func _lathe(profile: Array, c: Vector2, y: float, segs: int) -> Mesh:
	return ZzAttachmentArt.sweep(_lathe_rings(profile, c, y, 1.0), segs, 1.0, 20.0)


func _lathe_rings(profile: Array, c: Vector2, y: float, dir: float) -> Array:
	var out: Array = []
	for p: Vector2 in profile:
		out.append(ZzAttachmentArt.ring(y + p.y * dir, p.x, c))
	return out


static func _smooth(rs: Array, k: int) -> Array:
	var out: Array = []
	for i in rs.size():
		var c := Vector2.ZERO
		var h := Vector2.ZERO
		var n := 0
		for j in range(maxi(i - k, 0), mini(i + k, rs.size() - 1) + 1):
			c += rs[j]["c"]
			h += rs[j]["h"]
			n += 1
		out.append({"y": rs[i]["y"], "c": c / n, "h": h / n})
	return out


static func _radius(r: Dictionary) -> float:
	var h: Vector2 = r["h"]
	return maxf(h.x, h.y)


## [param ring] scaled about its centre by [param k], moved to height [param y].
static func _scaled(ring: Dictionary, k: float, y: float) -> Dictionary:
	return {"y": y, "c": ring["c"], "h": (ring["h"] as Vector2) * k}
