class_name ZzArmArt
extends RefCounted

## The held arms' surfaces, generated once and cached: a pebbled glove leather with seams for the fists and gauntlet
## cuffs, and a coarse woven wool for the sleeves. Built with [ZzAttachmentArt]'s noise and normal-map helpers.

static var _mats: Dictionary = {}


## Glove leather: dark brown, pebbled, creased across, triplanar in the mesh's own space (about 6 cm a tile), so the
## fists (which carry no UVs) and the cuffs share it.
static func glove() -> StandardMaterial3D:
	if _mats.has(&"glove"):
		return _mats[&"glove"]
	var tex := ZzAttachmentArt.TEX
	var grain := ZzAttachmentArt._noise(23, 0.09)
	var crease := ZzAttachmentArt._noise(41, 0.02)
	var h := PackedFloat32Array()
	h.resize(tex * tex)
	var alb := Image.create(tex, tex, false, Image.FORMAT_RGBA8)
	var base := Color(0.30, 0.19, 0.11)
	var worn := Color(0.46, 0.32, 0.20)
	var deep := Color(0.10, 0.06, 0.035)
	for y in tex:
		for x in tex:
			var g := grain.get_pixel(x, y).r
			var c := crease.get_pixel(x, y).r
			# Creases: thin dark valleys where the slow noise crosses its middle.
			var fold := 1.0 - smoothstep(0.0, 0.035, absf(c - 0.5))
			var height := 0.45 * g - 0.5 * fold
			var col := base.lerp(worn, smoothstep(0.45, 0.85, g) * 0.6).lerp(deep, fold * 0.7)
			alb.set_pixel(x, y, col)
			h[y * tex + x] = height
	var m := ZzAttachmentArt._material(alb, h, 3.5)
	m.roughness = 0.78
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(16, 16, 16)
	_mats[&"glove"] = m
	return m


## Sleeve wool: a coarse brown twill, in the cylinder's own UVs (the arm spans stretch a unit cylinder, so the tiling
## is set for a forearm about 30 cm long).
static func sleeve() -> StandardMaterial3D:
	if _mats.has(&"sleeve"):
		return _mats[&"sleeve"]
	var tex := ZzAttachmentArt.TEX
	var fuzz := ZzAttachmentArt._noise(57, 0.12)
	var h := PackedFloat32Array()
	h.resize(tex * tex)
	var alb := Image.create(tex, tex, false, Image.FORMAT_RGBA8)
	var base := Color(0.33, 0.22, 0.13)
	var light := Color(0.47, 0.34, 0.21)
	var shade := Color(0.16, 0.10, 0.06)
	const PERIOD := 8 # a thread is eight texels (the shifts below are by three)
	for y in tex:
		for x in tex:
			var f := fuzz.get_pixel(x, y).r
			# Twill: threads over two, under two, stepping one each row.
			var over := (((x >> 3) + (y >> 3)) >> 1) % 2 == 0
			var across := float((y if over else x) % PERIOD) / PERIOD
			var thread := sin(across * PI)
			var height := thread * (0.6 if over else 0.4) + 0.25 * f
			var col := shade.lerp(base if over else base.darkened(0.12), thread).lerp(light, f * 0.35)
			alb.set_pixel(x, y, col)
			h[y * tex + x] = height
	var m := ZzAttachmentArt._material(alb, h, 2.5)
	m.roughness = 0.95
	m.uv1_scale = Vector3(3, 6, 1)
	_mats[&"sleeve"] = m
	return m
