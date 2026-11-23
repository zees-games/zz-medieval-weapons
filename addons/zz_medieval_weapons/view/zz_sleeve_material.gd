class_name ZzSleeveMaterial
extends RefCounted

## The first-person sleeve and cuff: a woven cloth and a stitched leather, drawn into small tiling images (no art files),
## so an arm filling a quarter of the screen is cloth with a grain, a seam and a darker cuff, not a flat brown tube.

static var _cloth: StandardMaterial3D = null
static var _leather: StandardMaterial3D = null


## Twill-woven sleeve cloth in [param base], one stitched seam along its length.
static func cloth(base: Color) -> StandardMaterial3D:
	if _cloth != null:
		return _cloth
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var bump := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			# Twill: a diagonal over-two-under-one pattern with a little per-thread variation.
			var over := ((x + y) / 2) % 3 != 0
			var tone := 1.0 if over else 0.78
			tone *= 0.94 + 0.12 * _hash(x / 2, y / 2)
			# The seam: a darker stitched line at the u edge.
			if x < 3 or x > size - 4:
				tone *= 0.62 if (y / 4) % 2 == 0 else 0.8
			img.set_pixel(x, y, Color(base.r * tone, base.g * tone, base.b * tone))
			var h := 1.0 if over else 0.35
			bump.set_pixel(x, y, Color(h, h, h))
	_cloth = StandardMaterial3D.new()
	_cloth.albedo_texture = ImageTexture.create_from_image(img)
	_cloth.roughness = 0.92
	_cloth.uv1_scale = Vector3(3.0, 5.0, 1.0)
	_cloth.heightmap_enabled = false
	_cloth.normal_enabled = false
	return _cloth


## Grained leather for the cuff and the glove.
static func leather(base: Color) -> StandardMaterial3D:
	if _leather != null:
		return _leather
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var tone := 0.82 + 0.3 * _hash(x / 3, y / 3) * _hash(y / 5, x / 5 + 7)
			if y % 16 == 0:
				tone *= 0.7
			img.set_pixel(x, y, Color(base.r * tone, base.g * tone, base.b * tone))
	_leather = StandardMaterial3D.new()
	_leather.albedo_texture = ImageTexture.create_from_image(img)
	_leather.roughness = 0.6
	_leather.uv1_scale = Vector3(2.0, 1.0, 1.0)
	return _leather


static func _hash(x: int, y: int) -> float:
	var h: int = (x * 73856093) ^ (y * 19349663)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xFFFF) / 65535.0
