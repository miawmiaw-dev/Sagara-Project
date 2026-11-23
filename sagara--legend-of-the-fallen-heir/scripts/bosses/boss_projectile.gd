class_name BossProjectile
extends Area2D

const PLAYER_LAYER := 1

@export_range(1.0, 1200.0, 1.0) var speed: float = 290.0
@export_range(1, 200, 1) var damage: int = 16
@export_range(0.05, 10.0, 0.05) var lifetime: float = 4.5
@export var knockback_force: float = 280.0

var direction: float = -1.0
var _active: bool = false
var _age: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _use_velocity: bool = false


func _ready() -> void:
	add_to_group("boss_attack")
	collision_layer = 0
	collision_mask = PLAYER_LAYER
	monitoring = true
	monitorable = false
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func launch(new_direction: float, new_damage: int = -1, new_speed: float = -1.0) -> void:
	if not is_zero_approx(new_direction):
		direction = signf(new_direction)
	if new_damage > 0:
		damage = new_damage
	if new_speed > 0.0:
		speed = new_speed
	_use_velocity = false
	_velocity = Vector2.ZERO
	rotation = 0.0
	scale = Vector2.ONE
	scale.x = direction
	_active = true


func launch_velocity(new_velocity: Vector2, new_damage: int = -1) -> bool:
	var length := new_velocity.length()
	if length <= 0.0001 or is_nan(length) or is_inf(length):
		return false
	if new_damage > 0:
		damage = new_damage
	_velocity = new_velocity
	direction = 1.0 if new_velocity.x >= 0.0 else -1.0
	rotation = _velocity.angle()
	scale = Vector2.ONE
	_use_velocity = true
	_active = true
	return true


func launch_toward(
	target_position: Vector2,
	new_damage: int = -1,
	new_speed: float = -1.0
) -> bool:
	var offset := target_position - global_position
	if offset.length_squared() <= 0.0001:
		return false
	var launch_speed := speed
	if new_speed > 0.0:
		launch_speed = new_speed
		speed = new_speed
	if is_nan(launch_speed) or is_inf(launch_speed) or launch_speed <= 0.0:
		return false
	return launch_velocity(offset.normalized() * launch_speed, new_damage)


func _physics_process(delta: float) -> void:
	if not _active:
		return

	if _use_velocity:
		global_position += _velocity * delta
	else:
		global_position.x += direction * speed * delta
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	for body in get_overlapping_bodies():
		_try_hit(body)


func _on_body_entered(body: Node2D) -> void:
	_try_hit(body)


func _try_hit(body: Node2D) -> void:
	if not _active or not is_instance_valid(body):
		return
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return

	_active = false
	var damaged := bool(body.call("take_damage", damage, self))
	if damaged and body.has_method("apply_knockback"):
		body.call("apply_knockback", direction, knockback_force)
	queue_free()
