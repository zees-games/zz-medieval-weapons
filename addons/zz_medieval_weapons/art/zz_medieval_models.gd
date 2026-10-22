class_name ZzMedievalModels
extends RefCounted

## The weapons' models. Each id first looks for a vendored `assets/<id>.glb` (the Sketchfab
## models listed in CREDITS.md, once downloaded); until then it builds a PLACEHOLDER from
## primitives, so a game never meets an empty hand. Every model is +Y along the weapon with
## the origin at the grip (the same convention zee-dot-weapons states for melee).
##
## TODO(art): the placeholders are in use for all eight; the downloads need a Sketchfab
## token (see CREDITS.md).

const ASSET_DIR := "res://assets/"

const STEEL := Color(0.72, 0.74, 0.78)
const WOOD := Color(0.42, 0.28, 0.15)
const LEATHER := Color(0.25, 0.15, 0.1)
const IRON := Color(0.32, 0.32, 0.35)
const BRASS := Color(0.75, 0.6, 0.25)
const STRING := Color(0.9, 0.9, 0.8)


static func build(id: StringName) -> Node3D:
	var path := ASSET_DIR + String(id) + ".glb"
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		if scene != null:
			return scene.instantiate() as Node3D
	return placeholder(id)


static func is_placeholder(id: StringName) -> bool:
	return not ResourceLoader.exists(ASSET_DIR + String(id) + ".glb")


static func placeholder(id: StringName) -> Node3D:
	var root := Node3D.new()
	root.name = String(id)
	match String(id):
		"longsword": _sword(root, 0.95, 0.05, 0.3)
		"dagger": _sword(root, 0.3, 0.035, 0.12)
		"battle_axe":
			_haft(root, 1.1)
			_box(root, Vector3(0.28, 0.24, 0.03), Vector3(0.14, 0.85, 0), STEEL)
			_box(root, Vector3(0.05, 0.3, 0.05), Vector3(0.0, 0.85, 0), IRON)
		"mace":
			_haft(root, 0.75)
			_sphere(root, 0.1, Vector3(0, 0.72, 0), IRON)
			for a in 6:
				var ang := a * TAU / 6.0
				_spike(root, Vector3(0, 0.72, 0), Vector3(cos(ang), 0, sin(ang)))
			_spike(root, Vector3(0, 0.72, 0), Vector3.UP)
		"spear":
			_haft(root, 2.0)
			var tip := _cyl(root, 0.0, 0.3, Vector3(0, 1.95, 0), STEEL)
			(tip.mesh as CylinderMesh).bottom_radius = 0.04
		"round_shield":
			var m := _cyl(root, 0.4, 0.05, Vector3.ZERO, LEATHER)
			m.rotation.x = PI / 2
			var boss := _sphere(root, 0.1, Vector3(0, 0, 0.03), BRASS)
			boss.scale = Vector3(1, 1, 0.5)
		"bow":
			# An arc of short segments, then the string.
			var prev := Vector3.ZERO
			for i in range(0, 9):
				var t := float(i) / 8.0 * 2.0 - 1.0
				var p := Vector3(-0.12 * (1.0 - t * t), t * 0.7, 0)
				if i > 0:
					_segment(root, prev, p, 0.025, WOOD)
				prev = p
			_segment(root, Vector3(0, -0.7, 0), Vector3(0, 0.7, 0), 0.006, STRING)
		"crossbow":
			_box(root, Vector3(0.06, 0.7, 0.08), Vector3(0, 0.25, 0), WOOD)
			_box(root, Vector3(0.7, 0.04, 0.05), Vector3(0, 0.55, 0), IRON)
			_segment(root, Vector3(-0.35, 0.55, 0), Vector3(0, 0.45, 0), 0.006, STRING)
			_segment(root, Vector3(0.35, 0.55, 0), Vector3(0, 0.45, 0), 0.006, STRING)
		_:
			_box(root, Vector3(0.1, 0.1, 0.1), Vector3.ZERO, Color.MAGENTA)
	return root


## The arrow or bolt a bow or crossbow looses: along -Z, the way a projectile flies.
static func projectile(projectile_id: StringName) -> Node3D:
	var root := Node3D.new()
	var length := 0.9 if projectile_id == &"arrow" else 0.4
	_segment(root, Vector3(0, 0, length * 0.5), Vector3(0, 0, -length * 0.5), 0.016, WOOD)
	var tip := _cyl(root, 0.0, 0.07, Vector3(0, 0, -length * 0.5 - 0.03), STEEL)
	(tip.mesh as CylinderMesh).bottom_radius = 0.02
	tip.rotation = Vector3(-PI / 2, 0, 0)
	return root


static func _sword(root: Node3D, blade: float, width: float, guard: float) -> void:
	_cyl(root, 0.015, 0.14, Vector3.ZERO, LEATHER)
	_sphere(root, 0.028, Vector3(0, -0.08, 0), BRASS)
	_box(root, Vector3(guard, 0.03, 0.04), Vector3(0, 0.08, 0), BRASS)
	_box(root, Vector3(width, blade, 0.012), Vector3(0, 0.09 + blade * 0.5, 0), STEEL)
	var tip := _cyl(root, 0.0, 0.08, Vector3(0, 0.09 + blade + 0.04, 0), STEEL)
	(tip.mesh as CylinderMesh).bottom_radius = width * 0.5
	tip.scale = Vector3(1, 1, 0.24)


static func _haft(root: Node3D, length: float) -> void:
	_cyl(root, 0.022, length, Vector3(0, length * 0.5 - 0.2, 0), WOOD)


static func _add(root: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi


static func _box(root: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add(root, m, pos, color)


static func _sphere(root: Node3D, r: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	return _add(root, m, pos, color)


static func _cyl(root: Node3D, r: float, h: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = r
	m.bottom_radius = r
	m.height = h
	return _add(root, m, pos, color)


## A mace spike: a cone from the head's centre outward along [param dir].
static func _spike(root: Node3D, centre: Vector3, dir: Vector3) -> void:
	var tip := _cyl(root, 0.0, 0.08, centre + dir * 0.12, IRON)
	(tip.mesh as CylinderMesh).bottom_radius = 0.025
	tip.basis = Basis(Quaternion(Vector3.UP, dir))


## A thin box from [param a] to [param b].
static func _segment(root: Node3D, a: Vector3, b: Vector3, thick: float, color: Color) -> MeshInstance3D:
	var dir := (b - a).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.99 else Vector3.RIGHT
	var mi := _box(root, Vector3(thick, thick, a.distance_to(b)), Vector3.ZERO, color)
	mi.transform = Transform3D(Basis.looking_at(dir, up), (a + b) * 0.5)
	return mi
