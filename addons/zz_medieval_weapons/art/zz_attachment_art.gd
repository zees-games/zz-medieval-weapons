class_name ZzAttachmentArt
extends RefCounted

## Procedural meshes and materials for the medieval attachments (all generated here; no vendored art).
## Meshes: [method sweep] lofts rings (a lathe when they are circles, a fitted sleeve when they are measured off a
## grip), [method blade] is a forged flat blade with a raised spine. Materials: leather strap wound in a spiral with
## a stitched edge, twisted cord, and pitted forged iron, each an albedo and a normal map drawn into 256 px tiles once.

const TEX := 256

static var _mats: Dictionary = {}


## A surface through [param rings] (bottom to top, each {y, c: Vector2 (x, z), h: Vector2 (x, z)}); a ring with h 0
## closes the end. Faceted along the profile (crisp bevels), smooth round it. UV: u round once per [param u_tiles],
## v the profile's length times [param v_per_m].
static func sweep(rings: Array, segs: int = 32, u_tiles: float = 1.0, v_per_m: float = 40.0) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v0 := 0.0
	for i in rings.size() - 1:
		var r0: Dictionary = rings[i]
		var r1: Dictionary = rings[i + 1]
		var seg_len := (_at(r1, 0.0) - _at(r0, 0.0)).length()
		var v1 := v0 + seg_len * v_per_m
		for j in segs:
			var a0 := TAU * float(j) / float(segs)
			var a1 := TAU * float(j + 1) / float(segs)
			var p00 := _at(r0, a0)
			var p01 := _at(r0, a1)
			var p10 := _at(r1, a0)
			var p11 := _at(r1, a1)
			var n00 := _normal(r0, r1, a0)
			var n01 := _normal(r0, r1, a1)
			var n10 := _smoothed(rings, i, 1, n00, a0)
			var n11 := _smoothed(rings, i, 1, n01, a1)
			n00 = _smoothed(rings, i, -1, n00, a0)
			n01 = _smoothed(rings, i, -1, n01, a1)
			var u0 := float(j) / float(segs) * u_tiles
			var u1 := float(j + 1) / float(segs) * u_tiles
			_quad(st, [p00, p01, p11, p10], [n00, n01, n11, n10], [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
		v0 = v1
	st.generate_tangents()
	return st.commit()


## A strap wound in a spiral over [param rings]: the sleeve [method sweep] would make, with each turn of the strap
## standing [param depth] proud of the one it overlaps, so the overlap is a real step in the outline, not only in the
## texture. [param pitch] is the strap's width along the grip (one turn of the spiral advances it by that much). UV:
## u once round, v one strap per unit, so [method leather]'s spiral lines up with the steps. The relief fades out over
## the last 4 mm at each end, where the strap is skived flush.
static func wound(rings: Array, segs: int, pitch: float, depth: float) -> ArrayMesh:
	var rr: Array = []
	for i in rings.size() - 1:
		var r0: Dictionary = rings[i]
		var r1: Dictionary = rings[i + 1]
		var n := maxi(1, ceili(absf(float(r1["y"]) - float(r0["y"])) / 0.0008))
		for k in n:
			rr.append(_mix(r0, r1, float(k) / float(n)))
	rr.append(rings[rings.size() - 1])
	var y_lo := float(rr[0]["y"])
	var y_hi := float(rr[rr.size() - 1]["y"])
	var grid: Array = []
	for r: Dictionary in rr:
		var y := float(r["y"])
		var fade := smoothstep(0.0, 0.004, y - y_lo) * smoothstep(0.0, 0.004, y_hi - y)
		var row := PackedVector3Array()
		for j in segs + 1:
			var a := TAU * float(j) / float(segs)
			var s := fposmod(float(j) / float(segs) + (y - y_lo) / pitch, 1.0)
			# A sawtooth: the strap rises across its width to its edge, then steps down onto the turn below.
			var lift := depth * fade * (0.3 + 0.7 * s) * smoothstep(1.0, 0.94, s)
			var c: Vector2 = r["c"]
			var h: Vector2 = r["h"]
			row.append(Vector3(c.x + (h.x + lift) * cos(a), y, c.y + (h.y + lift) * sin(a)))
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in grid.size() - 1:
		var g0: PackedVector3Array = grid[i]
		var g1: PackedVector3Array = grid[i + 1]
		var v0 := (float(rr[i]["y"]) - y_lo) / pitch
		var v1 := (float(rr[i + 1]["y"]) - y_lo) / pitch
		for j in segs:
			var u0 := float(j) / float(segs)
			var u1 := float(j + 1) / float(segs)
			var ns: Array = [_grid_normal(grid, i, j, segs), _grid_normal(grid, i, j + 1, segs), _grid_normal(grid, i + 1, j + 1, segs), _grid_normal(grid, i + 1, j, segs)]
			_quad(st, [g0[j], g0[j + 1], g1[j + 1], g1[j]], ns, [Vector2(u0, v0), Vector2(u1, v0), Vector2(u1, v1), Vector2(u0, v1)])
	st.generate_tangents()
	return st.commit()


static func _mix(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	return {"y": lerpf(float(a["y"]), float(b["y"]), t), "c": (a["c"] as Vector2).lerp(b["c"], t), "h": (a["h"] as Vector2).lerp(b["h"], t)}


## The outward normal of [method wound]'s grid at row [param i], column [param j], from its neighbours.
static func _grid_normal(grid: Array, i: int, j: int, segs: int) -> Vector3:
	var row: PackedVector3Array = grid[i]
	var round_d := row[(j + 1) % segs] - row[(j + segs - 1) % segs]
	var along := (grid[mini(i + 1, grid.size() - 1)] as PackedVector3Array)[j] - (grid[maxi(i - 1, 0)] as PackedVector3Array)[j]
	var n := along.cross(round_d)
	var out := Vector3(cos(TAU * j / segs), 0.0, sin(TAU * j / segs))
	if n.length() < 1e-12:
		return out
	n = n.normalized()
	return n if n.dot(out) >= 0.0 else -n


static func _at(r: Dictionary, a: float) -> Vector3:
	var c: Vector2 = r["c"]
	var h: Vector2 = r["h"]
	return Vector3(c.x + h.x * cos(a), float(r["y"]), c.y + h.y * sin(a))


## Outward normal of the band between [param r0] and [param r1] at angle [param a]: along the band crossed with round it.
## The normal of segment [param i]'s [param n] at its end ring ([param side] 1) or start ring (-1), averaged with the
## neighbouring segment's there unless the profile turns more than 60 degrees: a smooth profile shades smooth, not
## as a stack of lathe-turned bands, while a lip or step keeps its edge.
static func _smoothed(rings: Array, i: int, side: int, n: Vector3, a: float) -> Vector3:
	var j := i + side
	if j < 0 or j + 1 >= rings.size():
		return n
	var m := _normal(rings[j], rings[j + 1], a)
	if m.dot(n) < 0.5:
		return n
	return (m + n).normalized()


static func _normal(r0: Dictionary, r1: Dictionary, a: float) -> Vector3:
	var along := _at(r1, a) - _at(r0, a)
	var h0: Vector2 = r0["h"]
	var h1: Vector2 = r1["h"]
	var h := (h0 + h1) * 0.5
	var round_dir := Vector3(-h.x * sin(a), 0.0, h.y * cos(a))
	if round_dir.length() < 1e-6:
		round_dir = Vector3(-sin(a), 0.0, cos(a))
	var n := along.cross(round_dir)
	if n.length() < 1e-9:
		return Vector3(cos(a), 0.0, sin(a))
	return n.normalized()


## Two triangles of a quad, wound so their front faces [param ns]'s way (Godot fronts are clockwise).
static func _quad(st: SurfaceTool, ps: Array, ns: Array, uvs: Array) -> void:
	for tri: Array in [[0, 1, 2], [0, 2, 3]]:
		var a: Vector3 = ps[tri[0]]
		var b: Vector3 = ps[tri[1]]
		var c: Vector3 = ps[tri[2]]
		if (b - a).cross(c - a).length() < 1e-12:
			continue
		var n: Vector3 = (ns[tri[0]] as Vector3) + (ns[tri[1]] as Vector3) + (ns[tri[2]] as Vector3)
		var order: Array = tri if (b - a).cross(c - a).dot(n) < 0.0 else [tri[0], tri[2], tri[1]]
		for k: int in order:
			st.set_normal(ns[k])
			st.set_uv(uvs[k])
			st.add_vertex(ps[k])


## A circle ring for [method sweep]: radius [param r] at height [param y] round the axis.
static func ring(y: float, r: float, c := Vector2.ZERO) -> Dictionary:
	return {"y": y, "c": c, "h": Vector2(r, r)}


## A ring grown by [param by] metres all round (a sleeve over a measured ring).
static func grown(r: Dictionary, by: float, y_shift := 0.0) -> Dictionary:
	return {"y": float(r["y"]) + y_shift, "c": r["c"], "h": (r["h"] as Vector2) + Vector2(by, by)}


## A forged blade in the XY plane, tip up: [param half] is its right half outline from the spine's foot to the tip
## (x >= 0, mirrored for the left), [param spine] the thickness along x = 0, thinning toward the edge to
## [param edge] of it (a small forged blade keeps some body there, or its outline vanishes edge-on).
static func blade(half: PackedVector2Array, spine: float, edge: float = 0.3) -> ArrayMesh:
	var outline := PackedVector2Array(half)
	var width := 0.0
	for p in half:
		width = maxf(width, p.x)
	var tri := Geometry2D.triangulate_polygon(outline)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for mirror: float in [1.0, -1.0]:
		for face: float in [1.0, -1.0]:
			for t in range(0, tri.size(), 3):
				var ps: Array = []
				for k in 3:
					var q := outline[tri[t + k]]
					var z := face * spine * 0.5 * clampf(1.0 - q.x / maxf(width, 1e-4), edge, 1.0)
					ps.append(Vector3(q.x * mirror, q.y, z))
				var n: Vector3 = ((ps[1] as Vector3) - ps[0]).cross((ps[2] as Vector3) - ps[0]).normalized()
				if n.z * face < 0.0:
					n = -n
				_quad(st, [ps[0], ps[1], ps[2], ps[2]], [n, n, n, n], [Vector2(ps[0].x, ps[0].y) * 30.0, Vector2(ps[1].x, ps[1].y) * 30.0, Vector2(ps[2].x, ps[2].y) * 30.0, Vector2.ZERO])
		# The bevel between the two faces round the edge.
		for i in outline.size():
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			if a.x < 1e-5 and b.x < 1e-5:
				continue
			var za := spine * 0.5 * clampf(1.0 - a.x / maxf(width, 1e-4), edge, 1.0)
			var zb := spine * 0.5 * clampf(1.0 - b.x / maxf(width, 1e-4), edge, 1.0)
			var e := Vector3(b.x - a.x, b.y - a.y, 0.0)
			var n := Vector3(e.y, -e.x, 0.0).normalized()
			if n.dot(Vector3((a.x + b.x) * 0.5, 0, 0) - Vector3(0, 0, 0)) < 0.0 and absf(n.x) > 0.2:
				n = -n
			var ps := [Vector3(a.x * mirror, a.y, -za), Vector3(b.x * mirror, b.y, -zb), Vector3(b.x * mirror, b.y, zb), Vector3(a.x * mirror, a.y, za)]
			n.x *= mirror
			_quad(st, ps, [n, n, n, n], [Vector2.ZERO, Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	st.generate_tangents()
	return st.commit()


## Wound leather: one strap per tile, laid in a spiral (u round the grip, v along it), its overlap a dark groove,
## a running stitch along one edge, pebbled grain.
static func leather() -> StandardMaterial3D:
	if _mats.has(&"leather"):
		return _mats[&"leather"]
	var grain := _noise(7, 0.06)
	var h := PackedFloat32Array()
	h.resize(TEX * TEX)
	var alb := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	# Worn oxblood-brown leather: darker and browner than any wooden haft, so the wrap reads as its own part.
	var base := Color(0.27, 0.12, 0.065)
	var dark := Color(0.05, 0.022, 0.014)
	var thread := Color(0.40, 0.30, 0.19)
	for y in TEX:
		for x in TEX:
			var u := float(x) / TEX
			var v := float(y) / TEX
			var s := fposmod(u + v, 1.0)            # across the strap
			var along := fposmod((u - v) * 9.0, 1.0) # along it
			var g := grain.get_pixel(x, y).r
			var edge := smoothstep(0.0, 0.08, s) * smoothstep(1.0, 0.9, s)
			var height := 0.55 * edge + 0.3 * g
			# Pebbled, worn grain: the high spots rubbed lighter and browner by the hand.
			var col := dark.lerp(base, edge).lerp(Color(0.40, 0.23, 0.13), g * 0.55 * edge).darkened(0.25 * (1.0 - g))
			if absf(s - 0.2) < 0.022 and along < 0.55:
				col = thread.darkened(0.25 * (1.0 - g))
				height += 0.25
			elif absf(s - 0.2) < 0.04 and (along < 0.03 or absf(along - 0.58) < 0.03):
				col = col.darkened(0.4)
				height -= 0.15
			alb.set_pixel(x, y, col)
			h[y * TEX + x] = height
	var m := _material(alb, h, 4.5)
	m.roughness = 0.92
	_mats[&"leather"] = m
	return m


## Twisted cord: three strands crossing the band at a slant.
static func rope() -> StandardMaterial3D:
	if _mats.has(&"rope"):
		return _mats[&"rope"]
	var fib := _noise(11, 0.2)
	var h := PackedFloat32Array()
	h.resize(TEX * TEX)
	var alb := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	# Waxed cord, darkened by handling: it binds the leather's end without standing out of it, and with a low
	# specular, so a backlit band never glints as thin white streaks between the fingers.
	var base := Color(0.30, 0.21, 0.13)
	for y in TEX:
		for x in TEX:
			var u := float(x) / TEX
			var v := float(y) / TEX
			var s := fposmod((u * 3.0 + v * 2.0), 1.0)
			var f := fib.get_pixel(x, y).r
			var bulge := sin(s * PI)
			var height := 0.8 * bulge + 0.15 * f + 0.1 * sin((u * 40.0 - v * 25.0) * TAU) * bulge
			alb.set_pixel(x, y, base.darkened(0.55 * (1.0 - bulge)).lerp(base.lightened(0.1), f * 0.3))
			h[y * TEX + x] = height
	var m := _material(alb, h, 2.5)
	m.roughness = 0.95
	m.metallic_specular = 0.15
	_mats[&"rope"] = m
	return m


## Forged iron: satin metal with hammer facets, pitted with rust in the pits; triplanar, about 12 cm a tile.
static func iron() -> StandardMaterial3D:
	if _mats.has(&"iron"):
		return _mats[&"iron"]
	# Pits a few millimetres across and hammer facets a couple of centimetres: calm at view-model distance, not a
	# speckle of tiny bright dots.
	var pits := _noise(3, 0.035)
	var ham := _noise(5, 0.012)
	var h := PackedFloat32Array()
	h.resize(TEX * TEX)
	var alb := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	var rough := Image.create(TEX, TEX, false, Image.FORMAT_L8)
	var steel := Color(0.54, 0.55, 0.57)
	var rust := Color(0.34, 0.19, 0.10)
	for y in TEX:
		for x in TEX:
			var p := pits.get_pixel(x, y).r
			var hm := ham.get_pixel(x, y).r
			var pit := smoothstep(0.72, 0.9, p)
			var col := steel.darkened(0.28 * hm).lerp(rust, pit * 0.45)
			alb.set_pixel(x, y, col)
			# Black-forged, not polished: a satin sheen on the hammer facets, dull in the pits.
			rough.set_pixel(x, y, Color(0.4 + 0.18 * hm + 0.3 * pit, 0, 0))
			h[y * TEX + x] = 0.5 * hm - 0.35 * pit
	var m := _material(alb, h, 0.8)
	m.metallic = 0.88
	m.roughness = 1.0
	rough.generate_mipmaps()
	m.roughness_texture = ImageTexture.create_from_image(rough)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(8, 8, 8)
	_mats[&"iron"] = m
	return m


static func _noise(seed_v: int, freq: float) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = 3
	var img := n.get_seamless_image(TEX, TEX)
	img.convert(Image.FORMAT_RGBA8)
	return img


## A material from an albedo and a height field: the normal map is the height's slope, wrapping at the tile edge.
static func _material(alb: Image, h: PackedFloat32Array, strength: float) -> StandardMaterial3D:
	var nrm := Image.create(TEX, TEX, false, Image.FORMAT_RGBA8)
	for y in TEX:
		for x in TEX:
			var dx := h[y * TEX + (x + 1) % TEX] - h[y * TEX + (x + TEX - 1) % TEX]
			var dy := h[((y + 1) % TEX) * TEX + x] - h[((y + TEX - 1) % TEX) * TEX + x]
			var n := Vector3(-dx * strength, dy * strength, 1.0).normalized()
			nrm.set_pixel(x, y, Color(n.x * 0.5 + 0.5, n.y * 0.5 + 0.5, n.z * 0.5 + 0.5))
	alb.generate_mipmaps()
	nrm.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(alb)
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(nrm)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
