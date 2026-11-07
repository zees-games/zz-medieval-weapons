class_name ZzMedievalModels
extends RefCounted

## The weapons' models: a vendored `assets/<id>.glb` (see CREDITS.md) or else a primitive placeholder, so a
## hand is never empty. Every model is +Y along the weapon with the origin at the grip.

const ASSET_DIR := "res://assets/"

const STEEL := Color(0.72, 0.74, 0.78)
const WOOD := Color(0.42, 0.28, 0.15)
const LEATHER := Color(0.25, 0.15, 0.1)
const IRON := Color(0.32, 0.32, 0.35)
const BRASS := Color(0.75, 0.6, 0.25)
const STRING := Color(0.9, 0.9, 0.8)


## Where the glbs are, first hit wins: `assets/` beside the project; for a pack a host mounted (dot-cloud puts it under
## `<prefix>/addons/zz_medieval_weapons/`) `<prefix>/assets/`; and for an addon that is only symlinked into a game's `addons/`
## (the glbs stay in the pack's own checkout, outside the game's `res://`) the `assets/` beside the link's target, an absolute
## path that [method build] reads at run time. Pass [param link_target] (addon dir `res://...` -> real directory, "" if not a link)
## to test the lookup without a real symlink.
static func asset_dirs(script_path: String = "", link_target: Callable = Callable()) -> Array[String]:
	if script_path == "":
		script_path = (ZzMedievalModels as Script).resource_path
	var dirs: Array[String] = []
	var at := script_path.find("/addons/")
	if at > 0:
		dirs.append(script_path.substr(0, at + 1) + "assets/")
	if not dirs.has(ASSET_DIR):
		dirs.append(ASSET_DIR)
	if at >= 0:
		var addon_end := script_path.find("/", at + 8)
		var real: String = (link_target if link_target.is_valid() else _resolve_link).call(script_path.substr(0, addon_end) if addon_end > 0 else script_path)
		if real != "":
			# <checkout>/addons/<addon> -> <checkout>/assets/
			dirs.append(real.get_base_dir().get_base_dir().path_join("assets") + "/")
	return dirs


static func model_path(id: StringName) -> String:
	var file := String(id) + ".glb"
	for dir in asset_dirs():
		if _exists(dir + file):
			return dir + file
	return ASSET_DIR + file


static func build(id: StringName) -> Node3D:
	var path := model_path(id)
	var model: Node3D = null
	if path.begins_with("res://"):
		if ResourceLoader.exists(path):
			var scene: PackedScene = load(path)
			if scene != null:
				model = scene.instantiate() as Node3D
	elif FileAccess.file_exists(path):
		model = _read_glb(path)
	if model == null:
		return placeholder(id)
	model.transform = ZzMedievalArtTable.model_transform(id)
	return model


static func is_placeholder(id: StringName) -> bool:
	return not _exists(model_path(id))


## Whether the glb is a path the engine's importer owns (`res://`), which a host's rig can load, rather than one found beside a linked addon.
static func is_imported(id: StringName) -> bool:
	return model_path(id).begins_with("res://") and not is_placeholder(id)


static func _exists(path: String) -> bool:
	return ResourceLoader.exists(path) if path.begins_with("res://") else FileAccess.file_exists(path)


## A glb read straight from disk, for a pack outside the project (no import, so no .godot cache to go stale).
static func _read_glb(path: String) -> Node3D:
	var doc := GLTFDocument.new()
	var state := GLTFState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state) as Node3D


## Where `res://addons/<pack>` really lives when it is a symlink (followed through a chain of links), else "".
static func _resolve_link(addon_res: String) -> String:
	var path := ProjectSettings.globalize_path(addon_res)
	var followed := false
	for _hop in 8:
		var dir := DirAccess.open(path.get_base_dir())
		if dir == null or not dir.is_link(path):
			break
		var to := dir.read_link(path)
		path = to if to.is_absolute_path() else path.get_base_dir().path_join(to).simplify_path()
		followed = true
	return path if followed else ""


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
			_segment(root, Vector3(0, -0.7, 0), Vector3(0, 0.7, 0), 0.006, STRING).name = "string"
		"crossbow":
			_box(root, Vector3(0.06, 0.7, 0.08), Vector3(0, 0.25, 0), WOOD)
			_box(root, Vector3(0.7, 0.04, 0.05), Vector3(0, 0.55, 0), IRON)
			_segment(root, Vector3(-0.35, 0.55, 0), Vector3(0, 0.45, 0), 0.006, STRING).name = "string"
			_segment(root, Vector3(0.35, 0.55, 0), Vector3(0, 0.45, 0), 0.006, STRING).name = "string2"
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


## How long [method projectile] is, for the nock to seat its tail on the string.
static func projectile_length(projectile_id: StringName) -> float:
	return 0.9 if projectile_id == &"arrow" else 0.4


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
