class_name WeaponHitbox
extends Area2D

signal hit_registered(target: Node)

const ENEMY_HURTBOX_LAYER := 2
const DEFAULT_HITBOX_SIZE := Vector2(48.0, 48.0)

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _shape := RectangleShape2D.new()
var _ignored_target: Node
var _damage: int = 0
var _direction: float = 1.0
var _knockback_force: float = 0.0
var _active: bool = false
var _generation: int = 0
var _hit_targets: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = ENEMY_HURTBOX_LAYER
	monitoring = false
	monitorable = false
	_shape.size = DEFAULT_HITBOX_SIZE
	if collision_shape != null:
		collision_shape.shape = _shape
		collision_shape.disabled = true
	area_entered.connect(_on_area_entered)


func activate(
	hitbox_size: Vector2,
	offset: float,
	facing: float,
	damage: int,
	direction: float,
	knockback_force: float,
	duration: float,
	ignored_target: Node = null
) -> void:
	deactivate()
	var generation := _generation
	_ignored_target = ignored_target
	_damage = maxi(damage, 0)
	_direction = direction
	_knockback_force = maxf(knockback_force, 0.0)
	_shape.size = Vector2(maxf(hitbox_size.x, 1.0), maxf(hitbox_size.y, 1.0))
	position = Vector2(facing * offset, 0.0)
	_active = true
	set_deferred("monitoring", true)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", false)
	_resolve_overlaps_after_physics(generation)
	if duration <= 0.0:
		deactivate()
		return
	get_tree().create_timer(duration).timeout.connect(_end_activation.bind(generation))


func deactivate() -> void:
	_generation += 1
	_active = false
	set_deferred("monitoring", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	_hit_targets.clear()
	_ignored_target = null


func is_active() -> bool:
	return _active


func _end_activation(generation: int) -> void:
	if generation == _generation:
		deactivate()


func _resolve_overlaps_after_physics(generation: int) -> void:
	await get_tree().physics_frame
	if not is_inside_tree() or generation != _generation or not _active:
		return
	_resolve_overlaps()


func _resolve_overlaps() -> void:
	for area in get_overlapping_areas():
		_try_hit(area)


func _on_area_entered(area: Area2D) -> void:
	if _active:
		_try_hit(area)


func _try_hit(area: Area2D) -> void:
	if not _active or _damage <= 0 or not is_instance_valid(area):
		return
	var target := area.get_parent()
	if (
		target == null
		or target == _ignored_target
		or not is_instance_valid(target)
		or not target.has_method("take_damage")
		or _hit_targets.has(target)
	):
		return
	_hit_targets[target] = true
	target.call("take_damage", _damage, _direction, _knockback_force)
	hit_registered.emit(target)
