class_name JuiceCamera
extends Camera2D

const MAX_SHAKE_INTENSITY := 48.0
const MAX_SHAKE_DURATION := 3.0
const DEFAULT_SHAKE_FREQUENCY := 34.0

@export var shake_enabled: bool = true
@export_range(0.0, 3.0, 0.01) var shake_scale: float = 1.0
@export_range(0.0, 0.1, 0.001) var rotation_shake_strength: float = 0.008

var _shake_time_left: float = 0.0
var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
var _shake_frequency: float = DEFAULT_SHAKE_FREQUENCY
var _shake_elapsed: float = 0.0
var _base_offset: Vector2 = Vector2.ZERO
var _base_rotation: float = 0.0
var _shaking: bool = false


func _ready() -> void:
	add_to_group("juice_camera")
	set_process(false)


func _exit_tree() -> void:
	_restore_camera()


func shake(
	intensity: float,
	duration: float,
	frequency: float = DEFAULT_SHAKE_FREQUENCY
) -> void:
	if not shake_enabled or not is_inside_tree():
		return
	if intensity <= 0.0 or duration <= 0.0:
		return

	var safe_intensity := clampf(
		intensity * maxf(shake_scale, 0.0),
		0.0,
		MAX_SHAKE_INTENSITY
	)
	if safe_intensity <= 0.0:
		return

	var safe_duration := clampf(duration, 0.01, MAX_SHAKE_DURATION)
	if not _shaking:
		_base_offset = offset
		_base_rotation = rotation
		_shaking = true

	_shake_intensity = maxf(_shake_intensity * _get_envelope(), safe_intensity)
	_shake_time_left = maxf(_shake_time_left, safe_duration)
	_shake_duration = maxf(_shake_duration, safe_duration)
	_shake_frequency = maxf(frequency, 1.0)
	_shake_elapsed = 0.0
	set_process(true)


func _process(delta: float) -> void:
	if not _shaking:
		set_process(false)
		return

	_shake_time_left = maxf(_shake_time_left - delta, 0.0)
	if _shake_time_left <= 0.0:
		_restore_camera()
		return

	_shake_elapsed += delta
	var amplitude := _shake_intensity * _get_envelope()
	var phase := _shake_elapsed * TAU * _shake_frequency
	var offset_x := (sin(phase) + sin(phase * 2.17 + 1.7) * 0.5) / 1.5
	var offset_y := (cos(phase * 1.31) + sin(phase * 2.71 + 0.4) * 0.5) / 1.5
	offset = _base_offset + Vector2(offset_x, offset_y) * amplitude
	if rotation_shake_strength > 0.0:
		rotation = _base_rotation + sin(phase * 1.7) * rotation_shake_strength * amplitude


func _get_envelope() -> float:
	if _shake_duration <= 0.0:
		return 0.0
	var normalized := clampf(_shake_time_left / _shake_duration, 0.0, 1.0)
	return normalized * normalized


func _restore_camera() -> void:
	if not _shaking:
		return
	offset = _base_offset
	rotation = _base_rotation
	_shaking = false
	_shake_time_left = 0.0
	_shake_duration = 0.0
	_shake_intensity = 0.0
	_shake_elapsed = 0.0
	set_process(false)
