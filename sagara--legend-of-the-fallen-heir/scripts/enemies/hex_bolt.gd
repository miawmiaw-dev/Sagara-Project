class_name HexBolt
extends Area2D

const WORLD_LAYER := 1
const HEX_COLOR := Color(0.78, 0.35, 1.0, 1.0)

@export_range(1.0, 1500.0, 1.0) var speed: float = 260.0
@export_range(1, 200, 1) var damage: int = 12
@export_range(0.0, 1000.0, 1.0) var knockback_force: float = 240.0
@export_range(0.05, 10.0, 0.05) var lifetime: float = 3.5

var _direction: Vector2 = Vector2.RIGHT
var _active: bool = false
var _age: float = 0.0
var _shooter: Node = null

@onready var core: Polygon2D = get_node_or_null("Core") as Polygon2D
@onready var glow: CanvasItem = get_node_or_null("Glow") as CanvasItem
@onready var trail: CPUParticles2D = get_node_or_null("Trail") as CPUParticles2D


func _ready() -> void:
	collision_layer = 0
	collision_mask = WORLD_LAYER
	monitoring = false
	monitorable = false
	if trail != null:
		trail.emitting = false


func launch_toward(
	target_position: Vector2,
	new_damage: int = -1,
	new_speed: float = -1.0,
	shooter: Node = null
) -> bool:
	var offset := target_position - global_position
	if offset.length_squared() <= 0.0001:
		return false

	if new_damage > 0:
		damage = new_damage
	if new_speed > 0.0:
		speed = new_speed

	_shooter = shooter
	_direction = offset.normalized()
	rotation = _direction.angle()
	_age = 0.0
	_active = true

	if is_instance_valid(trail):
		trail.direction = Vector2.LEFT
		trail.emitting = true

	return true


func _physics_process(delta: float) -> void:
	if not _active:
		return

	_age += delta
	if _age >= lifetime:
		_shatter(global_position)
		return

	var from := global_position
	var to := from + _direction * speed * delta

	var space := get_world_2d().direct_space_state
	if space != null:
		var exclude: Array[RID] = [get_rid()]
		if _shooter is CollisionObject2D:
			exclude.append((_shooter as CollisionObject2D).get_rid())

		var query := PhysicsRayQueryParameters2D.create(
			from,
			to,
			WORLD_LAYER,
			exclude
		)
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit := space.intersect_ray(query)
		if not hit.is_empty():
			var hit_position: Vector2 = hit.get("position", to)
			global_position = hit_position
			var collider: Variant = hit.get("collider")
			if collider is Node2D and (collider as Node2D).is_in_group("player"):
				_hit_player(collider as Node2D)
			else:
				_shatter(hit_position)
			return

	global_position = to


func _hit_player(target: Node2D) -> void:
	_active = false

	var direction := signf(_direction.x)
	if is_zero_approx(direction):
		direction = 1.0

	var damaged := bool(target.call("take_damage", damage, self))
	if damaged and target.has_method("apply_knockback"):
		target.call("apply_knockback", direction, knockback_force)

	var impact := target.global_position + Vector2(0.0, -8.0)
	JuiceFX.spawn_hit_spark(impact, HEX_COLOR, direction, 1.0)
	JuiceFX.magic_burst(impact, HEX_COLOR, 0.65)
	if damaged:
		JuiceFX.shake_camera(2.4, 0.1)
		JuiceFX.flash_screen(Color(0.64, 0.2, 1.0, 0.06), 0.14)

	queue_free()


func _shatter(at_position: Vector2) -> void:
	if not _active:
		return

	_active = false
	JuiceFX.spawn_hit_spark(at_position, HEX_COLOR, _direction.x, 0.7)
	JuiceFX.magic_burst(at_position, HEX_COLOR, 0.45)
	queue_free()
