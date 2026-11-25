class_name ZzGloveMesh
extends RefCounted

## The gloved fist the held arms wear, built once per hand from low-poly capsules and cached.

static var _gloves: Dictionary = {}

## Segments round each capsule.
const SEG := 12
## Finger tube radius; fingers sit [code]0.0195[/code] apart, so a groove shows between neighbours.
const FINGER_R := 0.0084


## A gloved fist closed round a grip along local +Y through the origin; the wrist is at +Z ([const ZzMedievalHeld.WRIST]),
## the back of a right hand faces +X (a left hand is its mirror, built rather than scaled so faces stay outward).
## Each finger is three jointed segments with a knuckle; each capsule carries its own smooth normals, so the parts
## read as fingers rather than melting into one mitten.
static func fist(left: bool) -> Mesh:
	if _gloves.has(left):
		return _gloves[left]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mx := -1.0 if left else 1.0
	var at := func(phi_deg: float, y: float, r: float) -> Vector3:
		var f := deg_to_rad(phi_deg)
		return Vector3(sin(f) * r * mx, y, cos(f) * r)
	var wrist := ZzMedievalHeld.WRIST
	# Fingers, index (toward +Y) to little: knuckle on the back of the grip, then three phalanges round its far side
	# back to the palm. [y, radius scale, wrap radius, length scale]
	var fingers := [[0.0295, 1.0, 0.0245, 1.0], [0.0098, 1.04, 0.025, 1.06], [-0.0097, 0.98, 0.0245, 1.0], [-0.0292, 0.88, 0.0232, 0.86]]
	for fg in fingers:
		var y := float(fg[0])
		var r := FINGER_R * float(fg[1])
		var rc := float(fg[2])
		var ls := float(fg[3])
		var knuckle: Vector3 = at.call(92.0, y, rc + 0.005)
		var j1: Vector3 = at.call(172.0, y, rc + 0.001)
		var j2: Vector3 = at.call(172.0 + 68.0 * ls, y, rc)
		var tip: Vector3 = at.call(172.0 + 118.0 * ls, y * 0.97, rc - 0.002)
		_capsule(st, knuckle, j1, r)
		_capsule(st, j1, j2, r * 0.95)
		_capsule(st, j2, tip, r * 0.88)
		# The knuckle ridge on the back of the fist.
		_capsule(st, knuckle, knuckle + Vector3(0.003 * mx, 0.0, 0.0), r * 1.08)
		# Metacarpal: knuckle back to the wrist, the four converging.
		_capsule(st, knuckle, Vector3(0.016 * mx, y * 0.55, wrist - 0.010), 0.0105)
	# Palm: the heel under the metacarpals, closing the inside of the fist against the grip.
	_capsule(st, Vector3(-0.002 * mx, 0.020, 0.030), Vector3(-0.002 * mx, -0.024, 0.031), 0.0125)
	_capsule(st, Vector3(0.006 * mx, 0.010, wrist - 0.012), Vector3(0.0, -0.004, 0.034), 0.0175)
	# Thumb: from the heel over the front of the index finger, two segments and a pad.
	var t0 := Vector3(-0.008 * mx, 0.024, 0.048)
	var t1: Vector3 = at.call(272.0, 0.037, 0.031)
	var t2: Vector3 = at.call(222.0, 0.042, 0.031)
	var t3: Vector3 = at.call(186.0, 0.039, 0.029)
	_capsule(st, t0, t1, 0.0118)
	_capsule(st, t1, t2, 0.0104)
	_capsule(st, t2, t3, 0.0094)
	var m := st.commit()
	_gloves[left] = m
	return m


## A capsule from [param a] to [param b] appended to [param st], with its own smooth normals.
static func _capsule(st: SurfaceTool, a: Vector3, b: Vector3, r: float) -> void:
	var d := b - a
	var l := d.length()
	var y := d / l if l > 0.0001 else Vector3.UP
	var ref := Vector3.RIGHT if absf(y.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	const HALF := 4
	# Rings from the bottom pole through the shaft to the top pole: [centre, radius, axial normal part, radial part].
	var rings: Array = []
	for i in range(HALF + 1):
		var t := float(i) / HALF * PI * 0.5
		rings.append([a - y * r * cos(t), r * sin(t), -cos(t), sin(t)])
	for i in range(HALF + 1):
		var t := float(i) / HALF * PI * 0.5
		rings.append([b + y * r * sin(t), r * cos(t), sin(t), cos(t)])
	for i in rings.size() - 1:
		var q0: Array = rings[i]
		var q1: Array = rings[i + 1]
		for j in SEG:
			var a0 := TAU * j / SEG
			var a1 := TAU * (j + 1) / SEG
			var e0 := x * cos(a0) + z * sin(a0)
			var e1 := x * cos(a1) + z * sin(a1)
			var v00 := [(q0[0] as Vector3) + e0 * float(q0[1]), y * float(q0[2]) + e0 * float(q0[3])]
			var v01 := [(q0[0] as Vector3) + e1 * float(q0[1]), y * float(q0[2]) + e1 * float(q0[3])]
			var v10 := [(q1[0] as Vector3) + e0 * float(q1[1]), y * float(q1[2]) + e0 * float(q1[3])]
			var v11 := [(q1[0] as Vector3) + e1 * float(q1[1]), y * float(q1[2]) + e1 * float(q1[3])]
			for v in [v00, v11, v10, v00, v01, v11]:
				st.set_normal((v[1] as Vector3).normalized())
				st.add_vertex(v[0])
