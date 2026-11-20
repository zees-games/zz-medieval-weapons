class_name ZzGloveMesh
extends RefCounted

## The gloved fist the held arms wear, built once per hand from low-poly capsules and cached.

static var _gloves: Dictionary = {}

## A gloved fist closed round a grip along local +Y through the origin; the wrist is at +Z ([const ZzMedievalHeld.WRIST]),
## the back of a right hand faces +X (a left hand is its mirror, built rather than scaled so faces stay outward).
static func fist(left: bool) -> Mesh:
	if _gloves.has(left):
		return _gloves[left]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mx := -1.0 if left else 1.0
	var at := func(phi_deg: float, y: float, r: float) -> Vector3:
		var f := deg_to_rad(phi_deg)
		return Vector3(sin(f) * r * mx, y, cos(f) * r)
	# Fingers, index (toward +Y) to little: knuckle, then round the far side of the grip back to the palm.
	var fingers := [[0.029, 0.0092, 0.025], [0.009, 0.0095, 0.0255], [-0.011, 0.009, 0.025], [-0.029, 0.008, 0.0235]]
	for fg in fingers:
		var y := float(fg[0])
		var r := float(fg[1])
		var rc := float(fg[2])
		var pts := [at.call(95.0, y, rc + 0.004), at.call(170.0, y, rc), at.call(245.0, y, rc), at.call(305.0, y * 0.97, rc - 0.002)]
		for i in pts.size() - 1:
			_capsule(st, pts[i], pts[i + 1], r * (1.0 - 0.08 * i))
	# Back of the hand: knuckles to wrist; the heel of the palm closes the inside.
	_capsule(st, Vector3(0.022 * mx, 0.026, 0.0), Vector3(0.022 * mx, -0.026, 0.0), 0.012)
	for k in 5:
		var y := lerpf(0.026, -0.026, float(k) / 4.0)
		_capsule(st, Vector3(0.022 * mx, y, 0.0), Vector3(0.012 * mx, y * 0.6, ZzMedievalHeld.WRIST - 0.012), 0.0125)
	_capsule(st, Vector3(-0.004 * mx, 0.018, 0.028), Vector3(-0.004 * mx, -0.024, 0.03), 0.013)
	_capsule(st, Vector3(0.012 * mx, 0.0, ZzMedievalHeld.WRIST - 0.012), Vector3(-0.004 * mx, 0.0, 0.03), 0.02)
	# Thumb: from the heel over the front of the index finger.
	var t0 := Vector3(-0.010 * mx, 0.026, 0.045)
	var t1: Vector3 = at.call(275.0, 0.036, 0.03)
	var t2: Vector3 = at.call(225.0, 0.04, 0.031)
	var t3: Vector3 = at.call(185.0, 0.037, 0.03)
	_capsule(st, t0, t1, 0.0115)
	_capsule(st, t1, t2, 0.0105)
	_capsule(st, t2, t3, 0.0095)
	st.generate_normals()
	var m := st.commit()
	_gloves[left] = m
	return m


## A capsule from [param a] to [param b] appended to [param st] (low poly; normals are generated after).
static func _capsule(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var l := d.length()
	var y := d / l if l > 0.0001 else Vector3.UP
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	const SEG := 10
	const HALF := 4
	# Rings from the bottom pole through the shaft to the top pole.
	var rings: Array = []
	for i in range(HALF + 1):
		var t := float(i) / HALF * PI * 0.5
		rings.append([a - y * r * cos(t), r * sin(t)])
	for i in range(HALF + 1):
		var t := float(i) / HALF * PI * 0.5
		rings.append([b + y * r * sin(t), r * cos(t)])
	for i in rings.size() - 1:
		var c0: Vector3 = rings[i][0]
		var r0: float = rings[i][1]
		var c1: Vector3 = rings[i + 1][0]
		var r1: float = rings[i + 1][1]
		for j in SEG:
			var a0 := TAU * j / SEG
			var a1 := TAU * (j + 1) / SEG
			var p00 := c0 + (x * cos(a0) + z * sin(a0)) * r0
			var p01 := c0 + (x * cos(a1) + z * sin(a1)) * r0
			var p10 := c1 + (x * cos(a0) + z * sin(a0)) * r1
			var p11 := c1 + (x * cos(a1) + z * sin(a1)) * r1
			st.add_vertex(p00)
			st.add_vertex(p11)
			st.add_vertex(p10)
			st.add_vertex(p00)
			st.add_vertex(p01)
			st.add_vertex(p11)
