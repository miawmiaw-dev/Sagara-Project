class_name EnvironmentalTrap
extends Area2D

const RETRY_DELAY := 0.2
const DEFAULT_SPARK_COLOR := Color(1.0, 0.32, 0.24, 1.0)
const DEFAULT_FLASH_COLOR := Color(1.0, 0.82, 0.72, 1.0)
const DEFAULT_SCREEN_FLASH_COLOR := Color(1.0, 0.12, 0.1, 0.09)

@export_group("Damage")
@export var damage: int = 20
@export_range(0.05, 5.0, 0.05) var hit_cooldown: float = 1.1
@export var knockback_force: float = 260.0
@export_range(0.0, 2.0, 0.05) var stun_duration: float = 0.0
@export var respawn_on_hit: bool = false

@export_group("Juice")
@export var spark_color: Color = DEFAULT_SPARK_COLOR
@export var flash_color: Color = DEFAULT_FLASH_COLOR
@export_range(0.05, 1.0, 0.01) var flash_duration: float = 0.12
@export var shake_intensity: float = 2.6
@export var shake_duration: float = 0.16
@export var shake_frequency: float = 40.0
@export var screen_flash_enabled: bool = true
@export var screen_flash_color: Color = DEFAULT_SCREEN_FLASH_COLOR

var _cooldown_timers: Dictionary = {}
var _flash_tween: Tween
var _original_modulate: Color = Color.WHITE


func _ready() -> void:
	add_to_group("environmental_trap")
	_original_modulate = modulate
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(delta: float) -> void:
	if not monitoring:
		return

	for body in _cooldown_timers.keys():
		if not is_instance_valid(body):
			_cooldown_timers.erase(body)
			continue
		_cooldown_timers[body] = maxf(float(_cooldown_timers[body]) - delta, 0.0)

	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_try_hit(body)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_try_hit(body)


func _on_body_exited(body: Node2D) -> void:
	_cooldown_timers.erase(body)


func _try_hit(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return
	if float(_cooldown_timers.get(body, 0.0)) > 0.0:
		return

	var hit_position := body.global_position + Vector2(0.0, -8.0)
	var damaged := bool(body.call("take_damage", damage, self))

	if respawn_on_hit:
		_cooldown_timers[body] = maxf(hit_cooldown, 0.05)
		if damaged:
			_play_hit_juice(hit_position, body)
		if body.has_method("respawn"):
			body.call_deferred("respawn")
		return

	if not damaged:
		_cooldown_timers[body] = RETRY_DELAY
		return

	_cooldown_timers[body] = maxf(hit_cooldown, 0.05)
	_play_hit_juice(hit_position, body)
	_apply_knockback(body)


func _get_knockback_direction(body: Node2D) -> float:
	var direction := signf(body.global_position.x - global_position.x)
	if is_zero_approx(direction):
		direction = signf(global_transform.x.x)
	if is_zero_approx(direction):
		direction = 1.0
	return direction


func _apply_knockback(body: Node2D) -> void:
	if not body.has_method("apply_knockback"):
		return
	body.call(
		"apply_knockback",
		_get_knockback_direction(body),
		knockback_force,
		stun_duration
	)


func _play_hit_juice(hit_position: Vector2, body: Node2D) -> void:
	_flash()
	JuiceFX.spawn_hit_spark(
		hit_position,
		spark_color,
		_get_knockback_direction(body),
		0.85
	)
	JuiceFX.shake_camera(shake_intensity, shake_duration, shake_frequency)
	if screen_flash_enabled:
		JuiceFX.flash_screen(screen_flash_color, 0.16)


func _flash() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", _original_modulate, flash_duration)
