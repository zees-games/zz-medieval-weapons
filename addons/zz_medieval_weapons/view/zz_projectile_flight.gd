class_name ZzProjectileFlight
extends Node3D

## The picture of an arrow or bolt in the air: a model flown along the same arc the
## simulation's projectile takes (speed from the draw, drop from [code]gravity_scale[/code]),
## stuck in whatever it meets. [b]It is not the projectile.[/b] Damage and the true flight are
## [DotWeaponProjectile]'s on the server; this is what a client draws for one it did not
## spawn itself (a watcher seeing another player loose an arrow). A game that draws the real
## projectile turns the view's [code]spawn_flight[/code] off, so nothing flies twice.

signal landed(point: Vector3, normal: Vector3, collider: Object)

const GRAVITY := 9.8

var velocity: Vector3 = Vector3.ZERO
var gravity_scale: float = 1.0
var life: float = 4.0
var stuck_for: float = 3.0
var stuck: bool = false
## Collision mask for the flight's ray; 0 flies through everything.
var mask: int = 1
var surface: StringName = &"wood"

var _age: float = 0.0


## Builds a flight of [param projectile_id] ("arrow" or "bolt") at [param xf], flying at
## [param speed] along its -Z.
static func launch(parent: Node, projectile_id: StringName, xf: Transform3D, speed: float, gravity: float) -> ZzProjectileFlight:
	var f := ZzProjectileFlight.new()
	f.name = "Flight"
	f.add_child(ZzMedievalModels.projectile(projectile_id))
	parent.add_child(f)
	f.global_transform = xf
	f.velocity = -xf.basis.z.normalized() * speed
	f.gravity_scale = gravity
	return f


func _process(delta: float) -> void:
	step(delta)


func step(dt: float) -> void:
	_age += dt
	if stuck:
		if _age > stuck_for:
			queue_free()
		return
	if _age > life:
		queue_free()
		return
	velocity.y -= GRAVITY * gravity_scale * dt
	var from := global_position
	var to := from + velocity * dt
	if mask != 0 and is_inside_tree():
		var q := PhysicsRayQueryParameters3D.create(from, to, mask)
		var r := get_world_3d().direct_space_state.intersect_ray(q)
		if not r.is_empty():
			_land(r["position"], r["normal"], r["collider"])
			return
	global_position = to
	if velocity.length_squared() > 0.01:
		look_at(to + velocity, Vector3.UP if absf(velocity.normalized().y) < 0.99 else Vector3.RIGHT)


func _land(point: Vector3, normal: Vector3, collider: Object) -> void:
	stuck = true
	_age = 0.0
	global_position = point
	ZzMedievalImpacts.burst(get_parent(), point, normal, surface)
	landed.emit(point, normal, collider)
