class_name BossGroundWave
extends Area2D

const PLAYER_LAYER := 1
const WORLD_LAYER := 1
const MIN_SPEED := 1.0

@export_range(1.0, 1200.0, 1.0) var speed: float = 280.0
@export_range(1, 200, 1) var damage: int = 18
@export_range(0.05, 10.0, 0.05) var lifetime: float = 3.0
@export var knockback_force: float = 340.0
@export_range(0.0, 200.0, 1.0) var floor_offset: float = 12.0
@export_range(4.0, 200.0, 1.0) var floor_probe_height: float = 32.0
@export_range(4.0, 400.0, 1.0) var floor_probe_depth: float = 140.0
@export_range(0.0, 4000.0, 10.0) var fall_gravity: float = 1600.0

var direction: float = -1.0
var _active: bool = false
var _age: float = 0.0
var _vertical_speed: float = 0.0
var _player: Node2D = null
var _hit_targets: Dictionary = {}


func _ready() -> void:
	add_to_group("boss_attack")
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_player = _find_player()


func launch(new_direction: float, new_damage: int = -1, new_speed: float = -1.0) -> bool:
	if is_zero_approx(new_direction):
		new_direction = -1.0
	direction = 1.0 if new_direction > 0.0 else -1.0
	if new_damage > 0:
		damage = new_damage
	if new_speed > 0.0:
		speed = new_speed
	scale.x = direction
	if not is_instance_valid(_player):
		_player = _find_player()
	_snap_to_floor()
	_active = true
	return true


func _physics_process(delta: float) -> void:
	if not _active or not is_inside_tree():
		return

	_age += delta
	if _age >= lifetime or _is_blocked_ahead():
		queue_free()
		return

	global_position.x += direction * maxf(speed, MIN_SPEED) * delta
	_update_floor(delta)

	for body in get_overlapping_bodies():
		_try_hit(body)


func _snap_to_floor() -> void:
	var floor_y := _probe_floor_y()
	if is_nan(floor_y):
		return
	global_position.y = floor_y - floor_offset
	_vertical_speed = 0.0


func _update_floor(delta: float) -> void:
	var floor_y := _probe_floor_y()
	if not is_nan(floor_y):
		global_position.y = floor_y - floor_offset
		_vertical_speed = 0.0
		return

	_vertical_speed += fall_gravity * delta
	global_position.y += _vertical_speed * delta


func _probe_floor_y() -> float:
	if not is_inside_tree():
		return NAN
	var space := get_world_2d().direct_space_state
	if space == null:
		return NAN

	var from := global_position + Vector2(0.0, -floor_probe_height)
	var query := PhysicsRayQueryParameters2D.create(
		from,
		from + Vector2(0.0, floor_probe_height + floor_probe_depth),
		WORLD_LAYER,
		_build_exclusions()
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return NAN

	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	if normal.y > -0.5:
		return NAN
	var hit_position: Vector2 = hit.get("position", from)
	return hit_position.y


func _is_blocked_ahead() -> bool:
	if _age < 0.05 or not is_inside_tree():
		return false
	var space := get_world_2d().direct_space_state
	if space == null:
		return false

	var from := global_position + Vector2(0.0, -floor_offset)
	var query := PhysicsRayQueryParameters2D.create(
		from,
		from + Vector2(direction * maxf(speed * 0.05, 16.0), 0.0),
		WORLD_LAYER,
		_build_exclusions()
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return false

	var normal: Vector2 = hit.get("normal", Vector2.ZERO)
	return absf(normal.x) > 0.7


func _build_exclusions() -> Array[RID]:
	var exclude: Array[RID] = [get_rid()]
	if is_instance_valid(_player) and _player is CollisionObject2D:
		exclude.append((_player as CollisionObject2D).get_rid())
	return exclude


func _find_player() -> Node2D:
	if not is_inside_tree():
		return null
	var node := get_tree().get_first_node_in_group("player")
	if node is Node2D:
		return node
	return null


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(body: Node2D) -> void:
	if not _active or not is_instance_valid(body):
		return
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	if _hit_targets.has(body):
		return

	_hit_targets[body] = true
	var offset := body.global_position.x - global_position.x
	var hit_direction := direction
	if not is_zero_approx(offset):
		hit_direction = signf(offset)

	var damaged := bool(body.call("take_damage", damage, self))
	if damaged and body.has_method("apply_knockback"):
		body.call("apply_knockback", hit_direction, knockback_force)
	if damaged:
		_active = false
		queue_free()
